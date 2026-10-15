#include "authority.h"
#include <godot_cpp/classes/box_shape3d.hpp>
#include <godot_cpp/classes/cylinder_shape3d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/kinematic_collision3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/static_body3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
using namespace godot;
namespace {
Vector3 gv(cqauthority::V v) { return {real_t(v.x), real_t(v.y), real_t(v.z)}; }
cqauthority::V cv(Vector3 v) { return {v.x, v.y, v.z}; }
cqauthority::B cb(const Basis &b) {
  return {cv(b.get_column(0)), cv(b.get_column(1)), cv(b.get_column(2))};
}
cqauthority::T ct(const Transform3D &t) { return {cb(t.basis), cv(t.origin)}; }
Transform3D gt(const cqauthority::T &t) {
  return {Basis(gv(t.basis.x), gv(t.basis.y), gv(t.basis.z)), gv(t.origin)};
}
bool read_pose(const Variant &value, cqauthority::Pose &p) {
  if (value.get_type() != Variant::DICTIONARY)
    return false;
  Dictionary d = value;
  if (d.size() < 5 || d.size() > 7)
    return false;
  for (int i = 0; i < d.keys().size(); ++i) {
    String k = d.keys()[i];
    if (k != "head" && k != "left" && k != "right" && k != "weapon" &&
        k != "offhand_weapon" && k != "height" && k != "left_handed")
      return false;
  }
  if (!d.has("left_handed") || d["left_handed"].get_type() != Variant::BOOL)
    return false;
  for (const char *key : {"head", "left", "right", "weapon"})
    if (!d.has(key) || d[key].get_type() != Variant::TRANSFORM3D)
      return false;
  p.tracked = true;
  p.left_handed = d["left_handed"];
  p.head = ct(d["head"]);
  p.left = ct(d["left"]);
  p.right = ct(d["right"]);
  p.weapon = ct(d["weapon"]);
  if (d.has("offhand_weapon")) {
    if (d["offhand_weapon"].get_type() != Variant::TRANSFORM3D)
      return false;
    p.has_offhand = true;
    p.offhand = ct(d["offhand_weapon"]);
  }
  if (d.has("height")) {
    if (d["height"].get_type() != Variant::FLOAT &&
        d["height"].get_type() != Variant::INT)
      return false;
    p.has_height = true;
    p.height = d["height"];
  }
  return p.valid();
}
Dictionary pose_dict(const cqauthority::Pose &p) {
  Dictionary d;
  if (!p.tracked)
    return d;
  d["head"] = gt(p.head);
  d["left"] = gt(p.left);
  d["right"] = gt(p.right);
  d["weapon"] = gt(p.weapon);
  d["left_handed"] = p.left_handed;
  if (p.has_offhand)
    d["offhand_weapon"] = gt(p.offhand);
  if (p.has_height)
    d["height"] = p.height;
  return d;
}
bool number(const Variant &v) {
  return v.get_type() == Variant::FLOAT || v.get_type() == Variant::INT;
}
} // namespace
void FPSAuthority::_bind_methods() {
  ClassDB::bind_method(D_METHOD("stage_player", "id"), &FPSAuthority::stage_player);
  ClassDB::bind_method(D_METHOD("configure_stress", "id", "enabled"),
                       &FPSAuthority::configure_stress);
  ClassDB::bind_method(D_METHOD("request_restart"),
                       &FPSAuthority::request_restart);
  ClassDB::bind_method(D_METHOD("configure_spawn", "team", "position"),
                       &FPSAuthority::configure_spawn);
  ClassDB::bind_method(D_METHOD("configure_player", "id", "life", "profile"),
                       &FPSAuthority::configure_player);
  ClassDB::bind_method(D_METHOD("terrain_sample", "position"),
                       &FPSAuthority::terrain_sample);
  ClassDB::bind_method(D_METHOD("configure_lamps", "lamps"),
                       &FPSAuthority::configure_lamps);
  ClassDB::bind_method(D_METHOD("configure_world", "node"),
                       &FPSAuthority::configure_world);
  ClassDB::bind_method(D_METHOD("attach_vehicle", "kind", "body", "yaw", "team"),
                       &FPSAuthority::attach_vehicle, DEFVAL(0.0), DEFVAL(-1));
  ClassDB::bind_method(
      D_METHOD("attach_actor", "id", "body", "shape", "team", "owned", "ammo"),
      &FPSAuthority::attach_actor);
  ClassDB::bind_method(D_METHOD("detach_actor", "id", "life"),
                       &FPSAuthority::detach_actor);
  ClassDB::bind_method(D_METHOD("submit", "id", "command"),
                       &FPSAuthority::submit);
  ClassDB::bind_method(D_METHOD("submit_packet", "id", "packet"),
                       &FPSAuthority::submit_packet);
  ClassDB::bind_method(D_METHOD("validate_pose", "pose"),
                       &FPSAuthority::validate_pose);
  ClassDB::bind_method(D_METHOD("configure_jetpack", "id", "enabled"),
                       &FPSAuthority::configure_jetpack);
  ClassDB::bind_method(D_METHOD("advance"), &FPSAuthority::advance);
  ClassDB::bind_method(
      D_METHOD("request_action", "id", "life", "seq", "kind", "a", "b", "c"),
      &FPSAuthority::request_action, DEFVAL(0), DEFVAL(0), DEFVAL(0));
  ClassDB::bind_method(D_METHOD("configure_terrain", "terrain"),
                       &FPSAuthority::configure_terrain);
  ClassDB::bind_method(D_METHOD("configure_cq", "settings"),
                       &FPSAuthority::configure_cq);
  ClassDB::bind_method(D_METHOD("configure_zone", "position", "radius"),
                       &FPSAuthority::configure_zone);
  ClassDB::bind_method(D_METHOD("choose_class", "id", "life", "role"),
                       &FPSAuthority::choose_class);
  ClassDB::bind_method(
      D_METHOD("choose_gear", "id", "life", "role", "slot", "value"),
      &FPSAuthority::choose_gear);
  ClassDB::bind_method(D_METHOD("configure_reach", "id", "profile"),
                       &FPSAuthority::configure_reach);
  ClassDB::bind_method(D_METHOD("configure_frames", "extended"),
                       &FPSAuthority::configure_frames);
  ClassDB::bind_method(D_METHOD("snapshot"), &FPSAuthority::snapshot);
  ClassDB::bind_method(D_METHOD("inspect", "id"), &FPSAuthority::inspect);
  ClassDB::bind_method(D_METHOD("squad_roster"), &FPSAuthority::squad_roster);
  ClassDB::bind_method(D_METHOD("metrics"), &FPSAuthority::metrics);
}
FPSAuthority::FPSAuthority() {
  ray.instantiate();
  ray->set_collision_mask(3);
  ray->set_hit_from_inside(true);
  posture_query.instantiate();
  upper.instantiate();
  sweep_shape.instantiate();
  sweep_query.instantiate();
  sweep_query->set_shape(sweep_shape);
  sweep_query->set_margin(.001);
  sweep_query->set_collision_mask(1);
  upper->set_radius(.3);
  posture_query->set_shape(upper);
  posture_query->set_collision_mask(3);
  posture_query->set_margin(.001);
}
CharacterBody3D *FPSAuthority::body(int64_t id) const {
  auto it = actors.find(id);
  auto *actor = it == actors.end()
                    ? nullptr
                    : Object::cast_to<CharacterBody3D>(
                          ObjectDB::get_instance(it->second.body));
  return actor && actor->is_inside_tree() ? actor : nullptr;
}
int64_t FPSAuthority::attach_actor(int64_t id, CharacterBody3D *actor,
                                   CollisionShape3D *shape, int team, int owned,
                                   const PackedInt32Array &ammo) {
  if (!on_owner() || advancing || !actor || !shape ||
      !actor->is_inside_tree() || shape->get_parent() != actor ||
      ammo.size() != 4 || owned < 1 || owned > 4095 ||
      identities.count(uint64_t(actor->get_instance_id())))
    return 0;
  Ref<CylinderShape3D> hull = shape->get_shape();
  if (hull.is_null() || !Math::is_equal_approx(double(hull->get_radius()), .3))
    return 0;
  for (auto &item : actors) {
    auto *other = body(item.first);
    if (other && other->get_world_3d() != actor->get_world_3d())
      return 0;
  }
  auto h = core.join(id, team, cv(actor->get_global_position()),
                     uint16_t(owned), {ammo[0], ammo[1], ammo[2], ammo[3]});
  if (!h.id)
    return 0;
  // Give each body an exclusive mutable collider; shared scene resources cannot
  // leak posture.
  Ref<CylinderShape3D> unique;
  unique.instantiate();
  unique->set_radius(.3);
  unique->set_height(1.65);
  shape->set_shape(unique);
  shape->set_position(Vector3(0, .83, 0));
  actor->set_collision_layer(2);
  actor->set_collision_mask(3);
  actor->set_floor_snap_length(.0625);
  actor->set_floor_max_angle(std::acos(.7));
  actor->set_wall_min_slide_angle(0);
  actor->set_safe_margin(.001);
  actors.emplace(id, Actor{ObjectID(actor->get_instance_id()),
                           ObjectID(shape->get_instance_id()), h});
  identities[uint64_t(actor->get_instance_id())] = h;
  return h.life;
}
bool FPSAuthority::detach_actor(int64_t id, int64_t life) {
  if (!on_owner() || advancing || life < 1 || life > UINT32_MAX ||
      !core.leave({id, uint32_t(life)}))
    return false;
  auto it = actors.find(id);
  if (it != actors.end()) {
    identities.erase(uint64_t(it->second.body));
    actors.erase(it);
  }
  return true;
}
bool FPSAuthority::submit(int64_t id, const Dictionary &d) {
  // Decode and validate once at ingress. No Variant/Dictionary is retained in
  // the core.
  if (!on_owner())
    return false;
  auto *p = core.find(id);
  if (!p || advancing || d.size() < 13 || d.size() > 19)
    return false;
  for (const char *key : {"life", "seq", "weapon"})
    if (!d.has(key) || d[key].get_type() != Variant::INT)
      return false;
  for (const char *key : {"move", "yaw", "pitch", "fire", "jump", "reload",
                          "slow", "crouch", "prone", "blocked"})
    if (!d.has(key))
      return false;
  if (d["move"].get_type() != Variant::VECTOR2 || !number(d["yaw"]) ||
      !number(d["pitch"]))
    return false;
  for (const char *key :
       {"fire", "jump", "reload", "slow", "crouch", "prone", "blocked"})
    if (d[key].get_type() != Variant::BOOL)
      return false;
  int64_t life = d["life"], weapon = d["weapon"];
  if (life < 1 || life > UINT32_MAX || weapon < 0 || weapon >= 12)
    return false;
  Vector2 v = d["move"];
  cqauthority::Command c;
  c.life = uint32_t(life);
  c.seq = d["seq"];
  c.x = v.x;
  c.z = v.y;
  c.yaw = d["yaw"];
  c.pitch = d["pitch"];
  c.weapon = int(weapon);
  c.fire = d["fire"];
  c.jump = d["jump"];
  c.reload = d["reload"];
  c.slow = d["slow"];
  c.crouch = d["crouch"];
  c.prone = d["prone"];
  c.blocked = d["blocked"];
  Array keys = d.keys();
  for (int i = 0; i < keys.size(); ++i) {
    String k = keys[i];
    if (k != "life" && k != "seq" && k != "weapon" && k != "move" &&
        k != "yaw" && k != "pitch" && k != "fire" && k != "jump" &&
        k != "reload" && k != "slow" && k != "crouch" && k != "prone" &&
        k != "blocked" && k != "xr" && k != "room" && k != "reload_grip" && k != "reload_trigger" &&
        k != "vr_device" && k != "jetpack" && k != "offhand_fire")
      return false;
  }
  for (const char *key :
       {"reload_grip", "reload_trigger", "vr_device", "jetpack", "offhand_fire"})
    if (d.has(key) && d[key].get_type() != Variant::BOOL)
      return false;
  c.vr = d.get("vr_device", false);
  c.reload_grip = d.get("reload_grip", false);
  c.reload_trigger = d.get("reload_trigger", false);
  c.jetpack = d.get("jetpack", false);
  c.offhand_fire = d.get("offhand_fire", false);
  if (d.has("xr")) {
    if (d["xr"].get_type() != Variant::DICTIONARY)
      return false;
    Dictionary pose = d["xr"];
    if (pose.is_empty()) {
      if (!c.vr)
        return false;
    } else if (!read_pose(pose, c.pose))
      return false;
  }
  if (d.has("room")) {
    if (d["room"].get_type() != Variant::VECTOR3)
      return false;
    c.room = cv(d["room"]);
  }
  return core.submit(p->handle, c);
}
bool FPSAuthority::configure_terrain(const Dictionary &d) {
  if (!on_owner() || advancing || core.tick() != 0)
    return false;
  for (const char *name : {"main_bins", "access_bins"})
    if (!d.has(name) || d[name].get_type() != Variant::DICTIONARY)
      return false;
  for (const char *name : {"pads", "rivers"})
    if (!d.has(name) || d[name].get_type() != Variant::ARRAY)
      return false;
  if (!d.has("port") || d["port"].get_type() != Variant::VECTOR3 ||
      !d.has("extent") || !number(d["extent"]) || !d.has("tile") ||
      !number(d["tile"]))
    return false;
  cqauthority::Terrain t;
  t.port = cv(d["port"]);
  t.extent = d["extent"];
  t.tile = d["tile"];
  if (!t.port.finite() || !std::isfinite(t.extent) || !std::isfinite(t.tile) ||
      t.extent <= 0 || t.tile <= 0)
    return false;
  for (const char *name : {"main_bins", "access_bins"}) {
    Dictionary bins = d[name];
    if (bins.size() > 20000)
      return false;
    auto &output = String(name) == "main_bins" ? t.main : t.access;
    Array keys = bins.keys();
    for (int i = 0; i < keys.size(); ++i) {
      if (keys[i].get_type() != Variant::VECTOR2I ||
          bins[keys[i]].get_type() != Variant::ARRAY)
        return false;
      Vector2i k = keys[i];
      Array rows = bins[keys[i]];
      if (rows.size() > 2000)
        return false;
      auto &target = output[cqauthority::Terrain::key(k.x, k.y)];
      for (int j = 0; j < rows.size(); ++j) {
        if (rows[j].get_type() != Variant::DICTIONARY)
          return false;
        Dictionary row = rows[j];
        if (!row.has("a") || !row.has("b") ||
            row["a"].get_type() != Variant::VECTOR3 ||
            row["b"].get_type() != Variant::VECTOR3 || !row.has("width") ||
            !number(row["width"]))
          return false;
        cqauthority::TerrainRoad r{cv(row["a"]), cv(row["b"]),
                                   double(row["width"])};
        if (!r.a.finite() || !r.b.finite() || !std::isfinite(r.width) ||
            r.width <= 0 || std::hypot(r.a.x - r.b.x, r.a.z - r.b.z) < .0001)
          return false;
        target.push_back(r);
      }
    }
  }
  Array pads = d["pads"];
  if (pads.size() > 128)
    return false;
  for (int i = 0; i < pads.size(); ++i) {
    if (pads[i].get_type() != Variant::DICTIONARY)
      return false;
    Dictionary row = pads[i];
    if (!row.has("center") || row["center"].get_type() != Variant::VECTOR3 ||
        !row.has("radius") || !number(row["radius"]))
      return false;
    cqauthority::TerrainPad p{cv(row["center"]), double(row["radius"])};
    if (!p.center.finite() || !std::isfinite(p.radius) || p.radius <= 0)
      return false;
    t.pads.push_back(p);
  }
  Array rivers = d["rivers"];
  if (rivers.size() > 4096)
    return false;
  for (int i = 0; i < rivers.size(); ++i) {
    if (rivers[i].get_type() != Variant::DICTIONARY)
      return false;
    Dictionary row = rivers[i];
    for (const char *key : {"a", "b"})
      if (!row.has(key) || row[key].get_type() != Variant::VECTOR3)
        return false;
    for (const char *key : {"width", "depth"})
      if (!row.has(key) || !number(row[key]))
        return false;
    cqauthority::River r{cv(row["a"]), cv(row["b"]), double(row["width"]),
                         double(row["depth"])};
    if (!r.a.finite() || !r.b.finite() || !std::isfinite(r.width) ||
        !std::isfinite(r.depth) || r.width <= 0 || r.depth <= 0 ||
        std::hypot(r.a.x - r.b.x, r.a.z - r.b.z) < .0001)
      return false;
    t.rivers.push_back(r);
  }
  t.configured = true;
  core.terrain = std::move(t);
  return true;
}
bool FPSAuthority::water(cqauthority::V p) {
  auto water = core.terrain.water_sample(p.x, p.z);
  if (core.terrain.configured) {
    if (water.x <= .5 || p.y >= water.y)
      return false;
  } else if (p.y >= core.cq.water_level)
    return false;
  auto floor = world_trace(p + cqauthority::V{0, .2, 0},
                           p - cqauthority::V{0, 2, 0}, {});
  return !floor.blocked || p.y > floor.position.y - .15;
}
bool FPSAuthority::configure_cq(const Dictionary &d) {
  if (!on_owner() || advancing)
    return false;
  cqauthority::CqConfig c;
  c.enabled = true;
  for (const char *key : {"map_limit", "fall_limit", "water_level",
                          "light_fraction", "cycle_seconds", "cycle_offset",
                          "round_seconds", "intermission_seconds"})
    if (d.has(key) && (!number(d[key]) || !std::isfinite(double(d[key]))))
      return false;
  c.map_limit = d.get("map_limit", c.map_limit);
  c.fall_limit = d.get("fall_limit", c.fall_limit);
  c.water_level = d.get("water_level", c.water_level);
  c.light_fraction = d.get("light_fraction", c.light_fraction);
  for (const char *key : {"auto_respawn", "day_cycle", "squads"})
    if (d.has(key) && d[key].get_type() != Variant::BOOL)
      return false;
  c.squads = d.get("squads", false);
  c.auto_respawn = d.get("auto_respawn", true);
  c.day_cycle = d.get("day_cycle", false);
  c.cycle_seconds = d.get("cycle_seconds", c.cycle_seconds);
  c.cycle_offset = d.get("cycle_offset", c.cycle_offset);
  c.round_seconds = d.get("round_seconds", c.round_seconds);
  c.intermission_seconds =
      d.get("intermission_seconds", c.intermission_seconds);
  if (c.light_fraction < 0 || c.light_fraction > 1)
    return false;
  return core.configure_cq(c);
}
bool FPSAuthority::configure_zone(const Vector3 &position, double radius) {
  return on_owner() && !advancing && core.configure_zone(cv(position), radius);
}
bool FPSAuthority::choose_class(int64_t id, int64_t life, int role) {
  return on_owner() && !advancing && life > 0 && life <= UINT32_MAX &&
         core.choose_class({id, uint32_t(life)}, role);
}
bool FPSAuthority::choose_gear(int64_t id, int64_t life, int role, int slot,
                               int value) {
  return on_owner() && !advancing && life > 0 && life <= UINT32_MAX &&
         core.choose_gear({id, uint32_t(life)}, role, slot, value);
}
void FPSAuthority::teleport(cqauthority::Handle h, cqauthority::V where) {
  auto *actor = body(h.id);
  if (!actor)
    return;
  actor->set_global_position(gv(where));
  actor->set_velocity(Vector3());
  actor->set_collision_layer(2);
  actor->set_collision_mask(3);
  auto it = actors.find(h.id);
  if (it != actors.end())
    if (auto *shape = Object::cast_to<CollisionShape3D>(
            ObjectDB::get_instance(it->second.shape))) {
      Ref<CylinderShape3D> hull = shape->get_shape();
      if (hull.is_valid()) {
        hull->set_height(1.65);
        shape->set_position(Vector3(0, .83, 0));
      }
    }
}
bool FPSAuthority::configure_reach(int64_t id, const Dictionary &d) {
  if (!on_owner() || advancing)
    return false;
  auto *p = core.find(id);
  if (!p)
    return false;
  if (d.is_empty()) {
    p->reach = {};
    return true;
  }
  auto vec = [](const Variant &v, cqauthority::V &target) {
    if (v.get_type() != Variant::ARRAY)
      return false;
    Array a = v;
    if (a.size() != 3)
      return false;
    for (int i = 0; i < 3; ++i)
      if (!number(a[i]) || !std::isfinite(double(a[i])) ||
          std::abs(double(a[i])) > 10)
        return false;
    target = {double(a[0]), double(a[1]), double(a[2])};
    return true;
  };
  cqauthority::ReachProfile r;
  if (!vec(d.get("neck", Variant()), r.neck) ||
      !vec(d.get("head", Variant()), r.head) ||
      !vec(d.get("eye", Variant()), r.eye) || !d.has("sockets") ||
      d["sockets"].get_type() != Variant::ARRAY)
    return false;
  Array sockets = d["sockets"];
  if (sockets.is_empty() || sockets[0].get_type() != Variant::ARRAY)
    return false;
  Array first = sockets[0];
  if (first.size() < 9)
    return false;
  for (int i = 0; i < 9; ++i)
    if (!number(first[i]) || !std::isfinite(double(first[i])) ||
        std::abs(double(first[i])) > 10)
      return false;
  r.left_shoulder = {double(first[0]), double(first[1]), double(first[2])};
  r.right_shoulder = {double(first[3]), double(first[4]), double(first[5])};
  r.neck_socket = {double(first[6]), double(first[7]), double(first[8])};
  for (const char *side : {"left", "right"}) {
    if (!d.has(side) || d[side].get_type() != Variant::ARRAY)
      return false;
    Array points = d[side];
    if (points.size() != 3)
      return false;
    auto *rest = String(side) == "left" ? r.left_rest : r.right_rest;
    for (int i = 0; i < 3; ++i)
      if (!vec(points[i], rest[i]))
        return false;
    if ((rest[0] - rest[1]).length() < .01 ||
        (rest[1] - rest[2]).length() < .01)
      return false;
  }
  if (d.has("head_correction")) {
    if (d["head_correction"].get_type() != Variant::ARRAY)
      return false;
    Array a = d["head_correction"];
    if (a.size() != 4)
      return false;
    for (int i = 0; i < 4; ++i)
      if (!number(a[i]) || !std::isfinite(double(a[i])))
        return false;
    Quaternion q(a[0], a[1], a[2], a[3]);
    if (!q.is_normalized())
      return false;
    r.correction = cb(Basis(q));
  }
  r.enabled = true;
  p->reach = r;
  return true;
}
bool FPSAuthority::configure_frames(bool extended) {
  if (!on_owner() || advancing || core.tick() != 0)
    return false;
  core.extended_frames = extended;
  return true;
}
bool FPSAuthority::validate_pose(const Variant &value) const {
  if (!on_owner())
    return false;
  cqauthority::Pose pose;
  return read_pose(value, pose);
}
bool FPSAuthority::configure_jetpack(int64_t id, bool enabled) {
  if (!on_owner() || advancing)
    return false;
  auto *p = core.find(id);
  if (!p)
    return false;
  if (p->jetpack_enabled && !enabled)
    p->jetpack = {};
  p->jetpack_enabled = enabled;
  return true;
}
bool FPSAuthority::submit_packet(int64_t id, const PackedByteArray &packet) {
  if (!on_owner() || advancing)
    return false;
  return core.submit_packet(id, packet.ptr(), packet.size());
}
bool FPSAuthority::edge(const cqauthority::Motion &m) {
  auto *actor = body(m.actor.id);
  if (!actor)
    return false;
  Vector3 offset = Vector3(m.velocity.x, 0, m.velocity.z).normalized() * .5;
  double rise = 0;
  if (actor->is_on_floor()) {
    auto normal = actor->get_floor_normal();
    if (normal.y > .7)
      rise = std::max(0., double(-normal.dot(offset) / normal.y));
  }
  Vector3 from = gv(m.position) + offset + Vector3(0, rise + .02, 0);
  ray->set_collision_mask(3);
  ray->set_from(from);
  ray->set_to(from - Vector3(0, 34. / 32, 0));
  TypedArray<RID> exclude;
  exclude.push_back(actor->get_rid());
  ray->set_exclude(exclude);
  return actor->get_world_3d()
      ->get_direct_space_state()
      ->intersect_ray(ray)
      .is_empty();
}
double FPSAuthority::posture(cqauthority::Handle h, double requested) {
  auto *actor = body(h.id);
  auto it = actors.find(h.id);
  auto *p = core.find(h.id);
  if (!actor || it == actors.end() || !p)
    return p ? p->height : 1.65;
  auto *shape = Object::cast_to<CollisionShape3D>(
      ObjectDB::get_instance(it->second.shape));
  double height = p->height;
  if (shape && !Math::is_equal_approx(requested, height)) {
    bool allowed = true;
    if (requested > height) {
      upper->set_height(requested - height + .6);
      Transform3D at = actor->get_global_transform();
      at.origin += Vector3(0, (height + requested) * .5 - .3 + .005, 0);
      posture_query->set_transform(at);
      TypedArray<RID> exclude;
      exclude.push_back(actor->get_rid());
      posture_query->set_exclude(exclude);
      allowed = actor->get_world_3d()
                    ->get_direct_space_state()
                    ->intersect_shape(posture_query, 1)
                    .is_empty();
    }
    if (allowed) {
      Ref<CylinderShape3D> hull = shape->get_shape();
      if (hull.is_valid()) {
        height = requested;
        hull->set_height(height);
        shape->set_position(Vector3(0, height * .5 + .005, 0));
      }
    }
  }
  return height;
}
cqauthority::Moved FPSAuthority::move(const cqauthority::Motion &m, double) {
  auto *actor = body(m.actor.id);
  auto it = actors.find(m.actor.id);
  if (!actor || it == actors.end())
    return {m.position, {}, m.height, false};
  double height = m.height;
  actor->set_rotation(Vector3(0, m.yaw, 0));
  actor->set_velocity(gv(m.velocity));
  // Match Fighter.step_up: sweep up/forward/down only from grounded walking.
  // The successful sweep consumes horizontal travel; never move it twice.
  auto step = [&]() {
    Vector3 travel = gv({m.velocity.x * cqauthority::DT, 0, m.velocity.z * cqauthority::DT});
    if (!m.step || !m.grounded || m.velocity.y > 0 || travel.length() < .001) return false;
    Ref<KinematicCollision3D> obstacle;obstacle.instantiate();
    Transform3D before = actor->get_global_transform();
    if (!actor->test_move(before, travel, obstacle, actor->get_safe_margin(), true, 4)) return false;
    bool blocked = false;
    for (int i=0;i<obstacle->get_collision_count();++i)
      blocked |= obstacle->get_normal(i).dot(travel) < -.0000001;
    if (!blocked) return false;
    double rise = m.height < .8 ? .20 : .55;
    Ref<KinematicCollision3D> ceiling;ceiling.instantiate();
    if (actor->test_move(before, Vector3(0,rise,0), ceiling)) rise = std::max(0.,double(ceiling->get_travel().y));
    if (rise < .001) return false;
    Transform3D raised=before;raised.origin.y+=rise;
    if (actor->test_move(raised,travel)) return false;
    raised.origin+=travel;
    Ref<KinematicCollision3D> landing;landing.instantiate();
    if (!actor->test_move(raised,Vector3(0,-rise-.05,0),landing) ||
        Object::cast_to<CharacterBody3D>(landing->get_collider())) return false;
    double tread = landing->get_position().y;
    if (landing->get_normal().dot(Vector3(0,1,0)) < Math::cos(actor->get_floor_max_angle())) {
      Vector3 into=-landing->get_normal().slide(Vector3(0,1,0)).normalized();
      Vector3 edge=landing->get_position()+into*.02;
      auto support=world_trace(cv(edge+Vector3(0,.05,0)),cv(edge-Vector3(0,.1,0)),m.actor);
      if (!support.blocked || support.normal.y < Math::cos(actor->get_floor_max_angle())) return false;
      tread=support.position.y;
    }
    if (tread-before.origin.y-.005>rise+.001) return false;
    Vector3 target=raised.origin+landing->get_travel();
    if (target.y-before.origin.y <= .00001 || target.y-before.origin.y > rise+.001) return false;
    actor->set_global_position(target);
    actor->set_velocity(Vector3(m.velocity.x,0,m.velocity.z));
    return true;
  };
  if (!step()) actor->move_and_slide();
  if (m.step && !actor->is_on_floor())
    actor->apply_floor_snap();
  return {cv(actor->get_global_position()), cv(actor->get_velocity()), height,
          actor->is_on_floor(), actor->is_on_ceiling()};
}
bool FPSAuthority::request_action(int64_t id, int64_t life, int64_t seq,
                                  int kind, int a, int b, int c) {
  if (!on_owner() || advancing || life < 1 || life > UINT32_MAX || kind < 0 ||
      kind > 12)
    return false;
  cqauthority::Action action;
  action.seq = seq;
  action.kind = cqauthority::ActionKind(kind);
  action.a = a;
  action.b = b;
  action.c = c;
  return core.queue_action({id, uint32_t(life)}, action);
}
double FPSAuthority::world_fraction(cqauthority::V from, cqauthority::V to,
                                    double radius, cqauthority::Handle h) {
  if (radius <= 0) {
    auto hit = world_trace(from, to, h);
    return hit.blocked ? (hit.position - from).length() /
                             std::max(.00001, (to - from).length())
                       : cqauthority::infinity;
  }
  auto *root = world();
  if (!root)
    return cqauthority::infinity;
  auto *space = root->get_world_3d()->get_direct_space_state();
  sweep_shape->set_radius(radius);
  sweep_query->set_transform(Transform3D(Basis(), gv(from)));
  sweep_query->set_motion(Vector3());
  TypedArray<RID> exclude;
  if (auto *owner_actor = body(h.id))
    exclude.push_back(owner_actor->get_rid());
  auto entity = entity_bodies.find(excluded_entity);
  if (entity != entity_bodies.end())
    if (auto *node = Object::cast_to<CollisionObject3D>(
            ObjectDB::get_instance(entity->second)))
      exclude.push_back(node->get_rid());
  sweep_query->set_exclude(exclude);
  if (!space->intersect_shape(sweep_query, 1).is_empty())
    return 0;
  sweep_query->set_motion(gv(to - from));
  auto fractions = space->cast_motion(sweep_query);
  return fractions.size() && fractions[0] < 1 ? double(fractions[0])
                                              : cqauthority::infinity;
}
cqauthority::Hit FPSAuthority::sweep_world(cqauthority::V from,
                                           cqauthority::V to, double radius,
                                           cqauthority::Handle h,
                                           uint64_t ignore) {
  const uint64_t old = excluded_entity;
  excluded_entity = ignore;
  if (radius <= 0) {
    auto hit = world_trace(from, to, h);
    excluded_entity = old;
    return hit;
  }
  double fraction = world_fraction(from, to, radius, h);
  if (!std::isfinite(fraction)) {
    excluded_entity = old;
    return {};
  }
  auto point = from + (to - from) * fraction;
  auto *root = world();
  cqauthority::Hit hit;
  if (root) {
    sweep_query->set_motion(Vector3());
    sweep_query->set_transform(
        Transform3D(Basis(), gv(point + (to - from).unit() * .003)));
    auto info = root->get_world_3d()->get_direct_space_state()->get_rest_info(
        sweep_query);
    if (!info.is_empty())
      hit = contact(info);
  }
  if (!hit.blocked)
    hit = world_trace(from, to, h);
  hit.blocked = true;
  hit.position = point;
  hit.fraction = fraction;
  excluded_entity = old;
  return hit;
}
cqauthority::V FPSAuthority::room_move(cqauthority::Handle h,
                                       cqauthority::V requested, double yaw) {
  auto *actor = body(h.id);
  if (!actor)
    return {};
  auto before = actor->get_global_position();
  actor->move_and_collide(gv(cqauthority::B::yaw(yaw).apply(requested)));
  return cv(actor->get_global_position() - before);
}
cqauthority::Hit FPSAuthority::world_trace(cqauthority::V from,
                                           cqauthority::V to,
                                           cqauthority::Handle h) {
  return cast_ray(from, to, h, 1);
}
cqauthority::Hit FPSAuthority::trace(cqauthority::V from, cqauthority::V to,
                                     cqauthority::Handle h) {
  return cast_ray(from, to, h, 3);
}
cqauthority::Hit FPSAuthority::cast_ray(cqauthority::V from, cqauthority::V to,
                                        cqauthority::Handle owner,
                                        uint32_t mask) {
  auto *root = world();
  if (!root)
    return {};
  ray->set_collision_mask(mask);
  ray->set_from(gv(from));
  ray->set_to(gv(to));
  TypedArray<RID> exclude;
  if (auto *actor = body(owner.id);
      actor && core.find(owner.id) && core.find(owner.id)->handle == owner)
    exclude.push_back(actor->get_rid());
  auto entity = entity_bodies.find(excluded_entity);
  if (entity != entity_bodies.end())
    if (auto *node = Object::cast_to<CollisionObject3D>(
            ObjectDB::get_instance(entity->second)))
      exclude.push_back(node->get_rid());
  ray->set_exclude(exclude);
  auto result =
      root->get_world_3d()->get_direct_space_state()->intersect_ray(ray);
  if (result.is_empty())
    return {};
  return contact(result);
}

bool FPSAuthority::advance() {
  // CharacterBody3D movement uses the engine physics delta. Enforce the core's
  // fixed tick contract.
  if (!on_owner() || advancing ||
      Engine::get_singleton()->get_physics_ticks_per_second() != 30 ||
      !Engine::get_singleton()->is_in_physics_frame() ||
      last_physics_frame == Engine::get_singleton()->get_physics_frames())
    return false;
  last_physics_frame = Engine::get_singleton()->get_physics_frames();
  advancing = true;
  for (auto &item : actors)
    if (!body(item.first) ||
        !Object::cast_to<CollisionShape3D>(
            ObjectDB::get_instance(item.second.shape)) ||
        Object::cast_to<CollisionShape3D>(
            ObjectDB::get_instance(item.second.shape))
                ->get_parent() != body(item.first)) {
      core.leave(item.second.handle);
      identities.erase(uint64_t(item.second.body));
    }
  core.advance(*this);
  sync_turrets();
  for (auto it = actors.begin(); it != actors.end();) {
    auto *p = core.find(it->first);
    if (!p) {
      it = actors.erase(it);
      continue;
    }
    if (it->second.handle != p->handle) {
      it->second.handle = p->handle;
      identities[uint64_t(it->second.body)] = p->handle;
    }
    if (p->dead) {
      if (auto *actor = body(it->first))
        actor->set_collision_layer(0);
    }
    ++it;
  }
  advancing = false;
  return true;
}
PackedByteArray FPSAuthority::snapshot() const {
  PackedByteArray bytes;
  if (!on_owner())
    return bytes;
  bytes.resize(core.frame().size());
  if (bytes.size())
    std::copy(core.frame().begin(), core.frame().end(), bytes.ptrw());
  return bytes;
}
Dictionary FPSAuthority::inspect(int64_t id) const {
  Dictionary d;
  if (!on_owner())
    return d;
  auto *p = core.find(id);
  if (!p)
    return d;
  d["team"] = p->team;
  d["squad"] = p->squad;d["combat_until"]=p->combat_until;d["staging"]=p->staging;d["dead"]=p->dead;
  d["kills"] = p->kills;
  d["deaths"] = p->deaths;
  d["life"] = int64_t(p->handle.life);
  d["position"] = gv(p->position);
  d["velocity"] = gv(p->velocity);
  d["hp"] = p->hp;
  d["armor"] = p->armor;
  d["incapacitated"] = p->incapacitated;
  d["bleed_remaining"] = p->bleed_remaining;
  d["inject_progress"] = p->inject_progress;
  d["invulnerable"] = p->invulnerable;
  const auto &c = p->classes;
  Dictionary cls;
  cls["role"] = int(c.role);
  cls["next"] = int(c.next);
  cls["level"] = c.level();
  cls["box_limit"] = c.box_limit();
  cls["equipped_t2"] = c.equipped_t2;
  cls["nv"] = c.nvg;
  cls["nb"] = c.blind_until;
  cls["box_ready"] = c.box_ready;
  PackedInt32Array xp;
  for (int n : c.xp)
    xp.push_back(n);
  cls["xp"] = xp;
  int primary = 0, secondary = 0, utility = 0;
  for (int i = 0; i < 4; ++i) {
    primary |= c.primary_t2[i] << i;
    secondary |= c.secondary_t2[i] << i;
    utility |= c.utility_t2[i] << i;
  }
  cls["primary"] = primary;
  cls["secondary"] = secondary;
  cls["utility"] = utility;
  cls["cloak_ready"] = c.cloak_ready;
  cls["cloak_until"] = c.cloak_until;
  cls["drone_ready"] = c.drone_ready;
  cls["strike_ready"] = c.strike_ready;
  cls["turret_ready"] = c.turret_ready;
  d["class_state"] = cls;

  d["dead"] = p->dead;
  d["height"] = p->height;
  d["shots"] = int64_t(p->shots);
  d["last_seq"] = p->last_seq;
  d["queued"] = int64_t(p->count);
  d["grounded"] = p->grounded;
  d["xr"] = pose_dict(p->pose);
  if (p->pose.tracked) {
    d["weapon_pose"] = gt(p->reach.weapon_pose(p->pose));
    if (p->pose.has_offhand)
      d["offhand_pose"] = gt(p->reach.weapon_pose(p->pose, true));
  }
  d["pose_stamp"] = p->pose_stamp;
  d["reload_at"] = p->reload_at;
  d["reloading"] = p->reloading;
  d["cycling"] = p->cycling;
  d["cycle_at"] = p->cycle_at;
  PackedInt32Array clips, ammo;
  for (int n : p->clips)
    clips.push_back(n);
  for (int n : p->ammo)
    ammo.push_back(n);
  d["clips"] = clips;
  d["ammo"] = ammo;
  Dictionary physical;
  for (int w = 0; w < 12; ++w) {
    const auto &q = p->physical[w];
    if (!q.initialised)
      continue;
    Dictionary r;
    r["mag"] = q.mag;
    r["ready"] = q.ready;
    r["locked"] = q.locked;
    r["grip"] = q.grip;
    r["eject"] = q.eject;
    r["pulled"] = q.pulled;
    r["left_pouch"] = q.left_pouch;
    r["side"] = q.side;
    r["carry"] = q.carry;
    r["carried_rounds"] = q.carried_rounds;
    r["event"] = int64_t(q.event);
    r["stroke"] = q.stroke;
    r["started"] = q.started;
    r["removed_depth"] = q.removed_depth;
    r["anchor"] = gv(q.anchor);
    r["pack_until"] = q.pack_until;
    r["grab"] = q.grab == cqauthority::Grab::NONE       ? ""
                : q.grab == cqauthority::Grab::MAGAZINE ? "magazine"
                : q.grab == cqauthority::Grab::AMMO     ? "ammo"
                                                        : "rack";
    physical[w] = r;
  }
  d["physical"] = physical;
  Dictionary jet;
  jet["mode"] = p->jetpack.mode;
  jet["age"] = p->jetpack.age;
  jet["cooldown"] = p->jetpack.cooldown;
  jet["tap"] = p->jetpack.tap;
  jet["distance"] = p->jetpack.distance;
  jet["activation"] = int64_t(p->jetpack.activation);
  jet["time"] = p->jetpack.time;
  jet["heading"] = Vector2(p->jetpack.heading.x, p->jetpack.heading.z);
  d["jetpack"] = jet;

  return d;
}
Dictionary FPSAuthority::metrics() const {
  Dictionary d;
  if (!on_owner())
    return d;
  d["tick"] = int64_t(core.tick());
  d["time"] = core.time();
  d["accepted"] = int64_t(core.counters.accepted);
  d["rejected"] = int64_t(core.counters.rejected);
  d["overflow"] = int64_t(core.counters.overflow);
  d["shots"] = int64_t(core.counters.shots);
  d["damage"] = int64_t(core.counters.damage);
  d["deaths"] = int64_t(core.counters.deaths);
  d["projectile_full"] = int64_t(core.counters.projectile_full);
  PackedInt32Array scores;
  scores.push_back(core.points.scores[0]);
  scores.push_back(core.points.scores[1]);
  d["scores"] = scores;
  d["winner"] = core.points.winner;
  d["intermission"] = core.intermission();
  d["round_remaining"] = core.round_remaining();
  d["round_epoch"] = core.round_epoch();
  d["mode_us"] = core.timings.mode_us;
  d["ai_us"] = core.timings.ai_us;
  d["movement_us"] = core.timings.movement_us;
  d["combat_us"] = core.timings.combat_us;
  d["snapshot_us"] = core.timings.snapshot_us;
  return d;
}

bool FPSAuthority::configure_player(int64_t id, int64_t life,
                                    const Dictionary &d) {
  if (!on_owner() || advancing || life <= 0 || life > UINT32_MAX ||
      !d.has("xp") || d["xp"].get_type() != Variant::ARRAY)
    return false;
  Array xp = d["xp"];
  if (xp.size() != 4)
    return false;
  int role = d.get("role", 0), next = d.get("next", role);
  if (role < 0 || role > 3 || next < 0 || next > 3)
    return false;
  cqauthority::ClassState c;
  c.role = cqauthority::Role(role);
  c.next = cqauthority::Role(next);
  for (int i = 0; i < 4; ++i) {
    if (xp[i].get_type() != Variant::INT || int64_t(xp[i]) < 0 ||
        int64_t(xp[i]) > INT32_MAX)
      return false;
    c.xp[i] = xp[i];
  }
  int primary = d.get("primary", 0), secondary = d.get("secondary", 0),
      utility = d.get("utility", 0);
  if ((primary | secondary | utility) & ~15)
    return false;
  for (int i = 0; i < 4; ++i) {
    c.primary_t2[i] = primary & (1 << i);
    c.secondary_t2[i] = secondary & (1 << i);
    c.utility_t2[i] = utility & (1 << i);
  }
  if (d.has("cooldowns")) {
    if (d["cooldowns"].get_type() != Variant::ARRAY)
      return false;
    Array values = d["cooldowns"];
    if (values.size() != 5)
      return false;
    std::array<double *, 5> fields{&c.box_ready, &c.cloak_ready, &c.drone_ready,
                                   &c.strike_ready, &c.turret_ready};
    for (int i = 0; i < 5; ++i) {
      if (!number(values[i]) || !std::isfinite(double(values[i])) ||
          double(values[i]) < 0 || double(values[i]) > 86400)
        return false;
      *fields[i] = values[i];
    }
  }
  return core.configure_player({id, uint32_t(life)}, c);
}

bool FPSAuthority::configure_spawn(int team, const Vector3 &p) {
  return on_owner() && !advancing && core.configure_spawn(team, cv(p));
}

bool FPSAuthority::request_restart() {
  if (!on_owner() || advancing)
    return false;
  core.request_restart();
  return true;
}

bool FPSAuthority::configure_stress(int64_t id, bool enabled) {
  auto *p = core.find(id);
  return on_owner() && !advancing && p &&
         core.configure_stress(p->handle, enabled);
}

bool FPSAuthority::stage_player(int64_t id) {
  if (!on_owner() || advancing) return false;
  auto *p = core.find(id);
  if (!p || p->last_seq >= 0 || p->count) return false;
  p->staging = true;
  seat(p->handle, p->position, true);
  return true;
}

Dictionary FPSAuthority::squad_roster() const {
 Dictionary result;if(!on_owner())return result;
 for(const auto &p:core.players())if(p.active)result[p.handle.id]=p.squad<0?-1:p.team*4+p.squad;
 return result;
}
