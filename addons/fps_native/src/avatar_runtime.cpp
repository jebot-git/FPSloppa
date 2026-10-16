#include "avatar_runtime.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
using namespace godot;
namespace {
constexpr double pi = 3.14159265358979323846;
constexpr const char *head_key = "head", *left_key = "left",
                     *right_key = "right", *weapon_key = "weapon",
                     *offhand_key = "offhand_weapon";
Vector3 vec(const Variant &value) {
  if (value.get_type() == Variant::VECTOR3)
    return value;
  Array a = value;
  return a.size() >= 3 ? Vector3(a[0], a[1], a[2]) : Vector3();
}
Node3D *node(Node3D *rig, const char *name) {
  return Object::cast_to<Node3D>(rig->get(name).get_validated_object());
}
double toward(double value, double target, double delta) {
  return value < target ? std::min(value + delta, target)
                        : std::max(value - delta, target);
}
Vector3 cone(Vector3 axis, Vector3 center, double limit) {
  axis.normalize();
  double angle = std::acos(std::clamp(double(center.dot(axis)), -1., 1.));
  if (angle <= limit)
    return axis;
  Vector3 tangent = axis - center * axis.dot(center);
  if (tangent.length_squared() < .000001)
    tangent = Vector3(0, 0, -1);
  return center * std::cos(limit) + tangent.normalized() * std::sin(limit);
}
Transform3D between(Vector3 ra, Vector3 rb, Vector3 a, Vector3 b) {
  Quaternion q((rb - ra).normalized(), (b - a).normalized());
  return {Basis(q), a - q.xform(ra)};
}
} // namespace
Dictionary FPSAvatar::Arm::dictionary() const {
  Dictionary d;
  d["upper"] = upper;
  d["fore"] = fore;
  d["shoulder"] = shoulder;
  d["elbow"] = elbow;
  d["hand"] = hand;
  d["target"] = target;
  d["clamped"] = clamped;
  d["upper_length"] = upper_length;
  d["fore_length"] = fore_length;
  return d;
}
bool FPSAvatar::configure(Node3D *rig, const Array &clips,
                          const Dictionary &profile, const Array &lods) {
  if (std::this_thread::get_id() != owner_thread)
    return false;
  if (!rig || clips.is_empty() || lods.size() < 3)
    return false;
  auto *visual = Object::cast_to<MeshInstance3D>(
      rig->get("visual").get_validated_object());
  if (!visual || visual->get_mesh().is_null())
    return false;
  Ref<Mesh> canonical = lods[0];
  if (canonical.is_null())
    return false;
  uint64_t key = uint64_t(canonical->get_instance_id());
  std::shared_ptr<Model> m;
  auto found = models.find(key);
  if (found != models.end())
    m = found->second.lock();
  if (m && (m->profile_hash != profile.hash() || m->clips_hash != clips.hash()))
    m.reset();
  if (!m) {
    m = std::make_shared<Model>();
    m->profile_hash = profile.hash();
    m->clips_hash = clips.hash();
    for (int i = 0; i < clips.size(); ++i) {
      Dictionary c = clips[i];
      Clip clip{c["name"], c["start"], std::max(1, int(c["count"])),
                double(c["fps"])};
      auto name = clip.name.to_lower().utf8();
      if (!m->names.count(name.get_data()))
        m->names[name.get_data()] = m->clips.size();
      m->clips.push_back(clip);
    }
    int fallback = 0;
    for (size_t i = 0; i < m->clips.size(); ++i)
      if (m->clips[i].name.to_lower() != "all") {
        fallback = i;
        break;
      }
    const std::vector<std::vector<const char *>> names = {
        {"Dead1", "Death", "Dead2"},
        {"StillFrRp", "Fire", "StillFrSm", "AimLg"},
        {"JumpLg", "JumpSm", "Jump"},
        {"DuckWlkL", "DuckWlkS", "Crouch"},
        {"RunLg", "RunSm", "Run"},
        {"WalkLg", "WalkSm", "Walk"},
        {"Breath1", "Breath2", "Idle", "StillLg", "StillSm"}};
    for (size_t i = 0; i < names.size(); ++i) {
      m->choices[i] = fallback;
      for (auto name : names[i]) {
        auto found = m->names.find(String(name).to_lower().utf8().get_data());
        if (found != m->names.end()) {
          m->choices[i] = found->second;
          break;
        }
      }
    }
    m->choices[7] = fallback;
    m->reference_frame=int(profile.get("reference_frame",0));
    Array sockets = profile.get("sockets", Array());
    for (int i = 0; i < sockets.size(); ++i) {
      Array row = sockets[i];
      if (row.size() < 9)
        return false;
      m->sockets.push_back({Vector3(row[0], row[1], row[2]),
                            Vector3(row[3], row[4], row[5]),
                            Vector3(row[6], row[7], row[8])});
    }
    if (!m->sockets.empty()) {
      for (int side = 0; side < 2; ++side) {
        Array points = profile.get(side == 0 ? "left" : "right", Array());
        if (points.size() < 3)
          return false;
        for (int i = 0; i < 3; ++i)
          m->arms[side][i] = vec(points[i]);
      }
      m->neck = vec(profile["neck"]);
      m->head = vec(profile["head"]);
      m->eye = vec(profile["eye"]);
      if (profile.has("head_correction")) {
        Array q = profile["head_correction"];
        if (q.size() == 4) {
          m->correction = Basis(Quaternion(q[0], q[1], q[2], q[3]));
          m->corrected = true;
        }
      }
    }
    Dictionary attachments = profile.get("attachments", Dictionary());
    const char *keys[] = {"left", "right", "back"};
    for (int i = 0; i < 3; ++i) {
      Dictionary a = attachments.get(keys[i], Dictionary());
      if (a.is_empty())
        continue;
      PackedVector3Array rows = a["samples"];
      auto &out = m->attachments[i];
      out.reference = a["reference"];
      out.present = !rows.is_empty();
      for (int j = 0; j < rows.size(); ++j)
        out.samples.push_back(rows[j]);
    }
    for (int i = 0; i < 3; ++i)
      m->lods[i] = lods[i];
    models[key] = m;
  }
  actors[uint64_t(rig->get_instance_id())] = {
      ObjectID(rig->get_instance_id()), ObjectID(visual->get_instance_id()), m};
  return true;
}
void FPSAvatar::detach(Node3D *rig) {
  if (std::this_thread::get_id() != owner_thread)
    return;
  if (rig)
    actors.erase(uint64_t(rig->get_instance_id()));
  for (auto it = models.begin(); it != models.end();)
    if (it->second.expired())
      it = models.erase(it);
    else
      ++it;
}
FPSAvatar::View FPSAvatar::view(Camera3D *camera) {
  View v;
  if (!camera)
    return v;
  v.present = true;
  v.xr = camera->is_class("XRCamera3D");
  v.position = camera->get_global_position();
  v.orthogonal = camera->get_projection() == Camera3D::PROJECTION_ORTHOGONAL;
  v.scale = v.orthogonal ? camera->get_size() / (2 * std::tan(85 * pi / 360))
                         : std::tan(camera->get_fov() * pi / 360) /
                               std::tan(85 * pi / 360);
  return v;
}
Vector3 FPSAvatar::socket(const Model &m, Vector3 frames, int index) {
  if (m.sockets.empty())
    return {};
  int a = std::clamp(int(frames.x), 0, int(m.sockets.size()) - 1),
      b = std::clamp(int(frames.y), 0, int(m.sockets.size()) - 1);
  return m.sockets[a][index].lerp(m.sockets[b][index],
                                  std::clamp(double(frames.z), 0., 1.));
}
Vector3 FPSAvatar::attachment(const Attachment &a, Vector3 frames) {
  if (a.samples.empty())
    return {};
  int first = std::clamp(int(frames.x), 0, int(a.samples.size()) - 1),
      second = std::clamp(int(frames.y), 0, int(a.samples.size()) - 1);
  return a.samples[first].lerp(a.samples[second], frames.z);
}
FPSAvatar::Arm FPSAvatar::solve_arm(const std::array<Vector3, 3> &points,
                                    Vector3 shoulder, Vector3 target,
                                    bool left) {
  double upper = points[0].distance_to(points[1]),
         fore = points[1].distance_to(points[2]);
  target.z = std::min(double(target.z), double(shoulder.z) + .12);
  target.x =
      left ? std::min(double(target.x), .20) : std::max(double(target.x), -.20);
  if (std::abs(target.x) < .22 && target.y > .92 && target.y < 1.52)
    target.z = std::min(double(target.z), -.22);
  Vector3 displacement = target - shoulder,
          axis = cone(displacement.length_squared() > .000001
                          ? displacement.normalized()
                          : Vector3(0, -1, 0),
                      Vector3(0, -1, 0), 125 * pi / 180);
  double minimum = std::sqrt(upper * upper + fore * fore +
                             2 * upper * fore * std::cos(145 * pi / 180)),
         maximum = std::sqrt(upper * upper + fore * fore +
                             2 * upper * fore * std::cos(15 * pi / 180)),
         reach = std::clamp(double(displacement.length()), minimum, maximum);
  Vector3 hand = shoulder + axis * reach, pole(left ? -1 : 1, -.35, .25),
          bend = pole - axis * pole.dot(axis);
  if (bend.length_squared() < .000001)
    bend = Vector3(0, -1, 0) - axis * Vector3(0, -1, 0).dot(axis);
  if (bend.length_squared() < .000001)
    bend = Vector3(0, 0, -1);
  bend.normalize();
  double along = (upper * upper - fore * fore + reach * reach) / (2 * reach);
  Vector3 elbow = shoulder + axis * along +
                  bend * std::sqrt(std::max(0., upper * upper - along * along));
  return {between(points[0], points[1], shoulder, elbow),
          between(points[1], points[2], elbow, hand),
          shoulder,
          elbow,
          hand,
          target,
          upper,
          fore,
          hand.distance_to(target) > .001};
}
FPSAvatar::Head FPSAvatar::solve_head(const Model &m, Vector3 neck,
                                      Transform3D head) {
  Vector3 angles = head.basis.get_euler();
  angles.x = std::clamp(double(angles.x), -50 * pi / 180, 50 * pi / 180);
  angles.y = std::clamp(double(angles.y), -75 * pi / 180, 75 * pi / 180);
  angles.z = std::clamp(double(angles.z), -25 * pi / 180, 25 * pi / 180);
  Basis rotation = Basis::from_euler(angles);
  if (m.corrected)
    rotation = rotation * m.correction;
  Vector3 shift = (head.origin - Vector3(0, 1.65, 0)).limit_length(.065),
          eye = neck + (m.eye - m.neck) + shift,
          pivot = eye - rotation.xform(m.eye - m.head),
          direction = cone(pivot - neck, Vector3(0, 1, 0), 40 * pi / 180);
  pivot = neck + direction * m.neck.distance_to(m.head);
  Transform3D head_transform(rotation, pivot - rotation.xform(m.head));
  return {between(m.neck, m.head, neck, pivot), head_transform,
          head_transform.xform(m.eye)};
}
void FPSAvatar::write_transform(MeshInstance3D *mesh, int index,
                                const Transform3D &t) {
  static const StringName q_names[] = {"neck_q",        "head_q",
                                       "left_upper_q",  "left_fore_q",
                                       "right_upper_q", "right_fore_q"};
  static const StringName t_names[] = {"neck_t",        "head_t",
                                       "left_upper_t",  "left_fore_t",
                                       "right_upper_t", "right_fore_t"};
  Quaternion q = t.basis.get_rotation_quaternion();
  mesh->set_instance_shader_parameter(q_names[index],
                                      Vector4(q.x, q.y, q.z, q.w));
  mesh->set_instance_shader_parameter(t_names[index], t.origin);
}
void FPSAvatar::advance_actor(Actor &actor, double delta, const View &camera) {
  auto *rig = Object::cast_to<Node3D>(ObjectDB::get_instance(actor.rig));
  auto *mesh =
      Object::cast_to<MeshInstance3D>(ObjectDB::get_instance(actor.visual));
  if (!rig || !mesh || !rig->is_inside_tree())
    return;
  auto &m = *actor.model;
  Dictionary pose = rig->get("target_xr_pose");
  bool dead = rig->get("dead"), left_handed = rig->get("left_handed");
  double old_yaw = rig->get("tracking_yaw"), yaw = old_yaw;
  if (!dead) {
    yaw = 0;
    if (pose.has(head_key)) {
      Transform3D head = pose[head_key];
      Vector3 f = -head.basis.get_column(2);
      yaw = double(f.x) * f.x + double(f.z) * f.z < .0001
                ? old_yaw
                : std::atan2(-double(f.x), -double(f.z));
    }
  }
  bool seated = bool(rig->get("seated_bike")) && !dead;
  if(seated) yaw = double(rig->get("seated_heading"))-(rig->get_parent_node_3d() ? rig->get_parent_node_3d()->get_global_rotation().y : 0);
  Vector3 rotation = rig->get_rotation();
  if(seated) rotation.y=yaw; else rotation.y += yaw - old_yaw;
  rig->set_rotation(rotation);
  rig->set("tracking_yaw", yaw);
  Dictionary local = pose.duplicate();
  Array keys = local.keys();
  Transform3D inverse(Basis(Vector3(0, 1, 0), -yaw), Vector3());
  for (int i = 0; i < keys.size(); ++i)
    if (local[keys[i]].get_type() == Variant::TRANSFORM3D)
      local[keys[i]] = inverse * Transform3D(local[keys[i]]);
  rig->set("local_xr_pose", local);
  if (pose.has("left_handed")) {
    left_handed = pose["left_handed"];
    rig->set("left_handed", left_handed);
  }
  double firing = std::max(0., double(rig->get("firing")) - delta);
  rig->set("firing", firing);
  if (dead)
    rig->set("death_time", double(rig->get("death_time")) + delta);
  int preview = rig->get("preview_mode");
  double speed = rig->get("speed");
  String stance = rig->get("stance"), selected = rig->get("selected_sequence");
  bool grounded = rig->get("grounded");
  int choice = 6;
  if (!selected.is_empty()) {
    auto found = m.names.find(selected.to_lower().utf8().get_data());
    choice = 7;
    int index = found == m.names.end() ? m.choices[7] : found->second;
    choice = -index - 1;
  } else if (dead)
    choice = 0;
  else if (preview == 3 || (preview < 0 && firing > 0 && speed <= .1))
    choice = 1;
  else if (preview < 0 && !grounded)
    choice = 2;
  else if (preview < 0 && (stance == "crouch" || stance == "prone"))
    choice = 3;
  else if (preview == 2 || speed > 3)
    choice = 4;
  else if (preview == 1 || speed > .1)
    choice = 5;
  else if (!grounded)
    choice = 2;
  else if (stance == "crouch" || stance == "prone")
    choice = 3;
  const Clip &clip = m.clips[choice < 0 ? -choice - 1 : m.choices[choice]];
  double time =
      String(rig->get("clip_name")) == clip.name ? double(rig->get("time")) : 0;
  time += delta;
  rig->set("time", time);
  rig->set("clip_name", clip.name);
  double frame = dead ? std::min(time * clip.fps, double(clip.count - 1))
                      : std::fmod(time * clip.fps, clip.count);
  if (frame < 0)
    frame += clip.count;
  int a = int(std::floor(frame)),
      b = dead ? std::min(a + 1, clip.count - 1) : (a + 1) % clip.count;
  Vector3 frames(clip.start + a, clip.start + b, frame - a);
  if(seated) frames=Vector3(m.reference_frame,m.reference_frame,0);
  rig->set("animation_frames", frames);
  mesh->set_instance_shader_parameter("animation_frames", seated ? Vector3(frames.x,frames.y,-1) : frames);
  double distance =
      camera.present
          ? (camera.orthogonal && !camera.xr
                 ? camera.scale
                 : rig->get_global_position().distance_to(camera.position) *
                       (camera.xr ? 1 : camera.scale))
          : 0;
  rig->set("effective_distance", distance);
  bool detailed =
           bool(rig->get("first_person")) || preview >= 0 || !camera.present,
       near = rig->get("ik_near");
  if (detailed || !bool(rig->get("distance_ik_enabled")))
    near = true;
  else if (near && distance > 12 * 1.15)
    near = false;
  else if (!near && distance < 12 * .85)
    near = true;
  rig->set("ik_near", near);
  bool eligible = bool(rig->get("tracked_arms_enabled")) && !dead &&
                  !m.sockets.empty() && pose.has(head_key);
  double old_weight = rig->get("ik_weight"),
         weight = eligible ? toward(old_weight, near ? 1 : 0,
                                    std::max(0., delta) / .15)
                           : 0;
  if (weight != old_weight) {
    rig->set("ik_weight", weight);
    mesh->set_instance_shader_parameter("ik_weight", weight);
  }
  int tier = rig->get("mesh_tier");
  if (detailed || !bool(rig->get("mesh_lod_enabled")))
    tier = 0;
  else {
    const double thresholds[] = {18, 45};
    while (tier < 2 && distance > thresholds[tier] * 1.15)
      ++tier;
    while (tier > 0 && distance < thresholds[tier - 1] * .85)
      --tier;
  }
  if (tier != int(rig->get("mesh_tier"))) {
    rig->set("mesh_tier", tier);
    mesh->set_mesh(m.lods[tier]);
  }
  Transform3D body;
  if (stance == "prone" && !dead && !seated)
    body = {Basis(Vector3(1, 0, 0), -pi / 2), Vector3(0, .3, .4)};
  if (!dead && !seated && stance == "crouch" &&
      !clip.name.to_lower().begins_with("duck") &&
      clip.name.to_lower() != "crouch")
    body.basis = body.basis.scaled(Vector3(1, .65, 1));
  mesh->set_transform(body);
  Dictionary solved;
  bool arms_active = false;
  double arm_us = 0;
  if (weight > 0) {
    auto started = std::chrono::steady_clock::now();
    bool head_active = !m.sockets.empty() && local.has(head_key);
    arms_active = head_active && local.has(left_key) && local.has(right_key);
    mesh->set_instance_shader_parameter("tracked_arms", arms_active);
    mesh->set_instance_shader_parameter("tracked_head", head_active);
    if (head_active) {
      Transform3D h = local[head_key];
      Head head = solve_head(m, socket(m, frames, 2), h);
      write_transform(mesh, 0, head.neck);
      write_transform(mesh, 1, head.head);
      if (arms_active) {
        for (int side = 0; side < 2; ++side) {
          Transform3D controller = local[side == 0 ? left_key : right_key];
          Vector3 desired = body.affine_inverse().xform(
              head.eye + controller.origin - h.origin);
          Arm arm = solve_arm(m.arms[side], socket(m, frames, side), desired,
                              side == 0);
          solved[side == 0 ? "left" : "right"] = arm.dictionary();
          write_transform(mesh, side == 0 ? 2 : 4, arm.upper);
          write_transform(mesh, side == 0 ? 3 : 5, arm.fore);
        }
      }
    }
    arm_us = std::chrono::duration<double, std::micro>(
                 std::chrono::steady_clock::now() - started)
                 .count();
    rig->set("ik_uniforms_active", true);
  } else if (bool(rig->get("ik_uniforms_active"))) {
    mesh->set_instance_shader_parameter("tracked_arms", false);
    mesh->set_instance_shader_parameter("tracked_head", false);
    rig->set("ik_uniforms_active", false);
  }
  rig->set("solved_arms", solved);
  rig->set("tracked_arms_active", arms_active);
  rig->set("arm_update_ms", arm_us / 1000.);
  if (arms_active)
    ++tracked;
  Vector3 left = socket(m, frames, 0), right = socket(m, frames, 1),
          neck = socket(m, frames, 2);
  Basis torso;
  if (!m.sockets.empty()) {
    Vector3 x = (right - left).normalized(), up = neck - (left + right) * .5,
            y = (up - x * up.dot(x)).normalized();
    if (x.length_squared() >= .5 && y.length_squared() >= .5)
      torso = Basis(x, y, x.cross(y)).orthonormalized();
  }
  if (auto *pack = node(rig, "backpack"))
    pack->set_global_transform(
        rig->get_global_transform() * body *
        Transform3D(torso, attachment(m.attachments[2], frames) +
                               torso.xform(Vector3(0, 0, .10))));
  bool show = !dead && !bool(rig->get("unarmed"));
  for (int item = 0; item < 2; ++item)
    if (auto *equipment =
            node(rig, item == 0 ? "carried_radio" : "carried_utility")) {
      equipment->set_visible(show);
      bool use_left = item == 0 ? left_handed : !left_handed;
      Transform3D mount =
          m.sockets.empty()
              ? Transform3D(Basis(), Vector3(use_left ? -.23 : .23, 1.4, 0))
              : body * Transform3D(torso, (use_left ? left : right) +
                                              torso.xform(Vector3(0, .035, 0)));
      Vector3 scale = equipment->get_scale();
      equipment->set_transform(mount);
      if (item == 1)
        equipment->set_scale(scale);
    }
  Array mounts = rig->get("native_weapon_mounts");
  double pitch = rig->get("aim_pitch");
  for (int offhand = 0; offhand < 2; ++offhand)
    if (auto *gun = node(rig, offhand ? "offhand_gun" : "gun")) {
      gun->set_visible(show);
      int side = left_handed != bool(offhand) ? 0 : 1;
      const char *side_name = side == 0 ? "left" : "right";
      Vector3 p = attachment(m.attachments[side], frames);
      Basis basis = body.basis.inverse() * Basis(Vector3(1, 0, 0), pitch);
      if (solved.has(side_name)) {
        Dictionary arm = solved[side_name];
        Vector3 hand =
            m.attachments[side].present
                ? Transform3D(arm["fore"]).xform(m.attachments[side].reference)
                : Vector3(arm["hand"]);
        p = p.lerp(hand, weight);
        auto key = offhand ? offhand_key : weapon_key;
        if (local.has(key))
          basis = body.basis.inverse() * Transform3D(local[key]).basis;
      }
      Transform3D grip = body * Transform3D(basis, p);
      double scale = .48 + (.65 - .48) * weight;
      Vector3 offset =
          mounts.size() > offhand ? Vector3(mounts[offhand]) : Vector3();
      gun->set_transform({grip.basis.scaled(Vector3(1, 1, 1) * scale),
                          grip.origin + grip.basis.xform(offset * scale)});
    }
  ++updated;
}
bool FPSAvatar::advance_one(Node3D *rig, double delta, Camera3D *camera) {
  if (std::this_thread::get_id() != owner_thread)
    return false;
  if (!rig || !std::isfinite(delta) || delta < 0)
    return false;
  auto found = actors.find(uint64_t(rig->get_instance_id()));
  if (found == actors.end())
    return false;
  updated = 0;
  tracked = 0;
  auto started = std::chrono::steady_clock::now();
  advance_actor(found->second, delta, view(camera));
  elapsed_us = std::chrono::duration<double, std::micro>(
                   std::chrono::steady_clock::now() - started)
                   .count();
  return updated > 0;
}
int FPSAvatar::advance(double delta, Camera3D *camera) {
  if (std::this_thread::get_id() != owner_thread)
    return 0;
  if (!std::isfinite(delta) || delta < 0)
    return 0;
  updated = 0;
  tracked = 0;
  auto started = std::chrono::steady_clock::now();
  auto context = view(camera);
  for (auto it = actors.begin(); it != actors.end();) {
    auto *rig = Object::cast_to<Node3D>(ObjectDB::get_instance(it->second.rig));
    if (!rig) {
      it = actors.erase(it);
      continue;
    }
    if (rig->is_inside_tree() && rig->is_processing() && rig->can_process())
      advance_actor(it->second, delta, context);
    ++it;
  }
  elapsed_us = std::chrono::duration<double, std::micro>(
                   std::chrono::steady_clock::now() - started)
                   .count();
  return updated;
}
Dictionary FPSAvatar::metrics() const {
  Dictionary d;
  if (std::this_thread::get_id() != owner_thread)
    return d;
  d["registered"] = int64_t(actors.size());
  d["models"] = int64_t(models.size());
  d["updated"] = updated;
  d["tracked"] = tracked;
  d["elapsed_us"] = elapsed_us;
  return d;
}
void FPSAvatar::_bind_methods() {
  ClassDB::bind_method(D_METHOD("configure", "rig", "clips", "profile", "lods"),
                       &FPSAvatar::configure);
  ClassDB::bind_method(D_METHOD("detach", "rig"), &FPSAvatar::detach);
  ClassDB::bind_method(D_METHOD("advance_one", "rig", "delta", "camera"),
                       &FPSAvatar::advance_one);
  ClassDB::bind_method(D_METHOD("advance", "delta", "camera"),
                       &FPSAvatar::advance);
  ClassDB::bind_method(D_METHOD("metrics"), &FPSAvatar::metrics);
}
