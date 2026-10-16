#include "movement_runtime.h"
#include "authority_movement.h"
#include "authority_vr.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <godot_cpp/classes/kinematic_collision3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/core/class_db.hpp>
using namespace godot;
namespace {
cqauthority::V cv(Vector3 v) { return {v.x, v.y, v.z}; }
Vector3 gv(cqauthority::V v) { return {real_t(v.x), real_t(v.y), real_t(v.z)}; }
Dictionary ray(CharacterBody3D *actor, Vector3 from, Vector3 to, int mask,
               bool exclude) {
  auto query = PhysicsRayQueryParameters3D::create(from, to, mask);
  if (exclude) {
    Array excluded;
    excluded.append(actor->get_rid());
    query->set_exclude(excluded);
  }
  return actor->get_world_3d()->get_direct_space_state()->intersect_ray(query);
}
} // namespace
bool godot::movement_step(CharacterBody3D *actor, Vector3 travel, double height,
                          uint32_t edge_mask) {
  if (!actor || travel.length() < .001)
    return false;
  Ref<KinematicCollision3D> obstacle;
  obstacle.instantiate();
  auto before = actor->get_global_transform();
  if (!actor->test_move(before, travel, obstacle, actor->get_safe_margin(),
                        true, 4))
    return false;
  bool blocked = false;
  for (int i = 0; i < obstacle->get_collision_count(); ++i)
    if (obstacle->get_normal(i).dot(travel) < -.0000001) {
      blocked = true;
      break;
    }
  if (!blocked)
    return false;
  Ref<KinematicCollision3D> ceiling;
  ceiling.instantiate();
  if (actor->test_move(before, Vector3(0, height, 0), ceiling))
    height = std::max(0., double(ceiling->get_travel().y));
  if (height < .001)
    return false;
  auto raised = before;
  raised.origin.y += height;
  if (actor->test_move(raised, travel))
    return false;
  raised.origin += travel;
  Ref<KinematicCollision3D> landing;
  landing.instantiate();
  if (!actor->test_move(raised, Vector3(0, -height - .05, 0), landing))
    return false;
  if (Object::cast_to<CharacterBody3D>(landing->get_collider()))
    return false;
  double tread = landing->get_position().y;
  if (landing->get_normal().dot(Vector3(0, 1, 0)) <
      std::cos(actor->get_floor_max_angle())) {
    auto into = -landing->get_normal().slide(Vector3(0, 1, 0)).normalized();
    auto edge = landing->get_position() + into * .02;
    auto support = ray(actor, edge + Vector3(0, .05, 0),
                       edge - Vector3(0, .1, 0), edge_mask, true);
    if (support.is_empty() ||
        Vector3(support["normal"]).y < std::cos(actor->get_floor_max_angle()))
      return false;
    tread = Vector3(support["position"]).y;
  }
  if (tread - before.origin.y - .005 > height + .001)
    return false;
  Vector3 target = raised.origin + landing->get_travel();
  double rise = target.y - before.origin.y;
  if (rise <= .00001 || rise > height + .001)
    return false;
  actor->set_global_position(target);
  Vector3 velocity = actor->get_velocity();
  velocity.y = 0;
  actor->set_velocity(velocity);
  return true;
}
Vector2 FPSMovement::horizontal(Vector2 velocity, Vector2 wish, double speed,
                                bool grounded, double delta, double stamina,
                                bool edge) const {
  auto result = cqauthority::cs_horizontal({velocity.x, 0, velocity.y},
                                           {wish.x, 0, wish.y}, speed, grounded,
                                           delta, stamina, edge);
  return {real_t(result.x), real_t(result.z)};
}
Dictionary FPSMovement::simulate_cs(CharacterBody3D *actor, Vector3 direction,
                                    Vector3 swim,
                                    const PackedFloat64Array &state,
                                    double delta, bool slow, bool jump,
                                    bool in_water, bool supported) const {
  (void)slow;
  Dictionary out;
  if (!actor || !actor->is_inside_tree() || state.size() != 5 ||
      !std::isfinite(delta) || delta <= 0 || delta > .25 ||
      !direction.is_finite())
    return out;
  // state: max speed, effective movement speed, stamina, jump held, view
  // offset.
  double stamina = std::max(0., state[2] - delta);
  bool grounded = supported && actor->get_velocity().y <= 0,
       jumping = grounded && jump && !bool(state[3]) && !in_water;
  double before = actor->get_position().y;
  Vector3 velocity = actor->get_velocity();
  Vector3 flat(velocity.x, 0, velocity.z);
  if (in_water) {
    Vector3 stroke = swim.is_finite()
                         ? actor->get_basis().xform(swim.limit_length(1))
                         : Vector3();
    velocity = gv(cqauthority::cs_water(
        cv(velocity), cv((direction + stroke).limit_length(1)), state[1], delta,
        jump));
  } else {
    if (jumping) {
      flat = gv(cqauthority::cs_jump_limit(cv(flat), state[0]));
      velocity.y = 268.3281573 / 32 * std::max(0., 1 - .19 * stamina);
      stamina = 1.315789429;
    }
    bool walking = grounded && !jumping, edge = false;
    if (walking && !flat.is_zero_approx()) {
      Vector3 offset = flat.normalized() * .5;
      double rise = 0;
      if (actor->is_on_floor()) {
        auto normal = actor->get_floor_normal();
        if (normal.y > .7)
          rise = std::max(0., double(-normal.dot(offset) / normal.y));
      }
      Vector3 ahead =
          actor->get_global_position() + offset + Vector3(0, rise + .02, 0);
      edge = ray(actor, ahead, ahead - Vector3(0, 34. / 32, 0), 3, true)
                 .is_empty();
    }
    flat = gv(
        cqauthority::cs_horizontal(cv(flat), cv({direction.x, 0, direction.z}),
                                   state[1], walking, delta, stamina, edge));
    velocity = {
        flat.x,
        real_t(walking ? -.2
                       : std::max(-62.5, double(velocity.y) - 25 * delta * .5)),
        flat.z};
  }
  velocity =
      velocity.clamp(Vector3(-62.5, -62.5, -62.5), Vector3(62.5, 62.5, 62.5));
  actor->set_velocity(velocity);
  bool stepping = grounded && !jumping && !in_water,
       stepped =
           stepping &&
           movement_step(actor, Vector3(velocity.x, 0, velocity.z) * delta,
                         18. / 32);
  double impact = actor->get_velocity().y;
  auto slide_start = std::chrono::steady_clock::now();
  if (!stepped)
    actor->move_and_slide();
  double slide_us = std::chrono::duration<double, std::micro>(
                        std::chrono::steady_clock::now() - slide_start)
                        .count();
  bool on_floor = actor->is_on_floor() || stepped;
  if (stepping && !on_floor) {
    actor->apply_floor_snap();
    on_floor = actor->is_on_floor() || stepped;
  }
  velocity = actor->get_velocity();
  if (!in_water)
    velocity.y = on_floor && (!jumping || velocity.y <= 0)
                     ? 0
                     : std::max(-62.5, double(velocity.y) - 25 * delta * .5);
  actor->set_velocity(velocity);
  double view = state[4];
  if (stepping && on_floor &&
      std::abs(actor->get_position().y - before) <= 18. / 32 + .05)
    view = std::clamp(view + before - actor->get_position().y, -18. / 32,
                      18. / 32);
  out["slide_usec"] = stepped ? -1. : slide_us;
  out["stamina"] = stamina;
  out["jump_held"] = jump;
  out["stepped"] = stepped;
  out["view_offset"] = view;
  out["sound"] = jumping && velocity.y > 0 ? 1
                 : !grounded && on_floor && impact < -250. / 32 && !in_water
                     ? 2
                     : 0;
  return out;
}
Vector3 FPSMovement::correct_prediction(CharacterBody3D *actor,
                                        Vector3 requested) const {
  if (!actor || !requested.is_finite())
    return {};
  Vector3 before = actor->get_position(), remaining = requested;
  for (int i = 0; i < 3; ++i) {
    auto hit = actor->move_and_collide(remaining);
    if (hit.is_null())
      break;
    remaining = hit->get_remainder().slide(hit->get_normal());
    if (remaining.length_squared() < .000001)
      break;
  }
  return actor->get_position() - before;
}
Dictionary FPSMovement::vehicles(const PackedInt64Array &ids,
                                 const Array &previous, const Array &current,
                                 const PackedFloat64Array &timing, double now,
                                 double physics_fraction) const {
  Dictionary out;
  if (previous.size() != ids.size() || current.size() != ids.size() ||
      timing.size() != ids.size() * 5)
    return out;
  for (int i = 0; i < ids.size(); ++i) {
    Array old = previous[i], next = current[i];
    if (old.size() != 3 || next.size() != 3)
      continue;
    Transform3D a = old[0], b = next[0];
    double alpha = timing[i * 5] < 0 ? physics_fraction
                                     : (now - timing[i * 5]) /
                                           std::max(.001, timing[i * 5 + 1]);
    alpha = std::clamp(alpha, 0., 1.);
    bool compatible = timing[i * 5 + 2] == timing[i * 5 + 3] &&
                      a.origin.distance_to(b.origin) < 20;
    auto pose = compatible ? a.interpolate_with(b, alpha) : b;
    Vector3 direction = next[1];
    double yaw = next[2];
    if (compatible) {
      direction = Vector3(old[1]).slerp(direction, alpha).normalized();
      double from = old[2],
             angle = std::fmod(yaw - from, 6.28318530717958647692);
      double distance = std::fmod(2 * angle, 6.28318530717958647692) - angle;
      yaw = from + distance * alpha;
    }
    out[ids[i]] = Array::make(pose, direction, yaw);
  }
  return out;
}
namespace {
cqauthority::Jetpack read_jetpack(const Dictionary &s) {
  cqauthority::Jetpack j;
  j.mode = s.get("mode", 0);
  j.age = s.get("age", 0.);
  j.cooldown = s.get("cooldown", 0.);
  j.tap = s.get("tap", 0.);
  j.distance = s.get("distance", 0.);
  j.time = s.get("time", 0.);
  j.activation = int64_t(s.get("activation", 0));
  Vector2 heading = s.get("heading", Vector2());
  j.heading = {heading.x, 0, heading.y};
  return j;
}
void write_jetpack(const Dictionary &state, const cqauthority::Jetpack &j) {
  Dictionary s = state;
  s["mode"] = j.mode;
  s["age"] = j.age;
  s["cooldown"] = j.cooldown;
  s["tap"] = j.tap;
  s["distance"] = j.distance;
  s["time"] = j.time;
  s["activation"] = int64_t(j.activation);
  s["heading"] = Vector2(j.heading.x, j.heading.z);
}
} // namespace
Dictionary FPSMovement::jetpack_tick(const Dictionary &state, Vector3 velocity,
                                     Vector3 direction, double delta, bool jump,
                                     bool jump_held, bool requested,
                                     bool blocked, bool cancel,
                                     bool prone) const {
  Dictionary out;
  if (!std::isfinite(delta) || delta <= 0 || delta > .25)
    return out;
  auto j = read_jetpack(state);
  auto before = j.activation;
  if (cancel)
    j.mode = 0;
  auto v = cv(velocity);
  bool active = j.tick(v, cv(direction), delta, jump, jump_held, requested,
                       true, blocked || cancel, prone);
  write_jetpack(state, j);
  out["active"] = active;
  out["velocity"] = gv(v);
  out["activated"] = j.activation != before;
  return out;
}
Vector3 FPSMovement::jetpack_moved(const Dictionary &state, Vector3 velocity,
                                   Vector3 before, Vector3 after, bool floor,
                                   bool ceiling) const {
  auto j = read_jetpack(state);
  auto v = cv(velocity);
  j.moved(v, cv(before), cv(after), floor, ceiling);
  write_jetpack(state, j);
  return gv(v);
}
void FPSMovement::prediction_clear() {
  history.clear();
  history_index.clear();
  acknowledged = -1;
}
void FPSMovement::prediction_remember(int64_t sequence, Vector3 position,
                                      Vector3 velocity, double height,
                                      const Dictionary &jetpack,
                                      double stamina) {
  Sample sample{sequence, position, velocity,
                height,   stamina,  jetpack.duplicate(true)};
  auto found = history_index.find(sequence);
  if (found != history_index.end())
    *found->second = sample;
  else {
    history.push_back(sample);
    history_index[sequence] = std::prev(history.end());
  }
  while (history.size() > 180) {
    history_index.erase(history.front().sequence);
    history.pop_front();
  }
}
Dictionary FPSMovement::prediction_samples() const {
  Dictionary out;
  for (const auto &s : history) {
    Dictionary row;
    row["position"] = s.position;
    row["velocity"] = s.velocity;
    row["height"] = s.height;
    row["stamina"] = s.stamina;
    row["jetpack"] = s.jetpack.duplicate(true);
    out[s.sequence] = row;
  }
  return out;
}
void FPSMovement::prediction_set_stats(const Dictionary &stats) {
  corrections = stats.get("corrections", 0);
  resets = stats.get("resets", 0);
  max_error = stats.get("max_error", 0.);
}
Dictionary FPSMovement::prediction_stats() const {
  Dictionary out;
  out["corrections"] = corrections;
  out["resets"] = resets;
  out["max_error"] = max_error;
  return out;
}
Dictionary FPSMovement::prediction_begin(CharacterBody3D *actor,
                                         int64_t sequence, Vector3 position,
                                         Vector3 velocity, bool grounded) {
  Dictionary out;
  if (!actor || sequence <= acknowledged)
    return out;
  acknowledged = sequence;
  auto found = history_index.find(sequence);
  if (found == history_index.end()) {
    out["missing"] = true;
    out["reset"] = actor->get_position().distance_to(position) > 2.5;
    return out;
  }
  const auto &s = *found->second;
  out["height"] = s.height;
  out["stamina"] = s.stamina;
  out["jetpack"] = s.jetpack.duplicate(true);
  Vector3 error = position - s.position, velocity_error = velocity - s.velocity;
  double length = error.length();
  max_error = std::max(max_error, length);
  if (length > .20)
    ++corrections;
  if (length > 2.5) {
    ++resets;
    out["reset"] = true;
    return out;
  }
  Vector3 correction = length > .20 ? error * .35 : Vector3(), impulse;
  for (int axis = 0; axis < 3; ++axis)
    if (std::abs(velocity_error[axis]) > .8)
      impulse[axis] = velocity_error[axis];
  if (grounded && std::abs(velocity.y) < .8 && s.velocity.y < 0)
    impulse.y = 0;
  for (int index = 0; index < actor->get_slide_collision_count(); ++index) {
    auto collision = actor->get_slide_collision(index);
    for (int contact = 0; contact < collision->get_collision_count();
         ++contact) {
      auto normal = collision->get_normal(contact);
      if (s.velocity.dot(normal) < -.8 && std::abs(velocity.dot(normal)) < .8 &&
          impulse.dot(normal) > 0)
        impulse -= normal * impulse.dot(normal);
    }
  }
  out["correction"] = correction;
  out["impulse"] = impulse;
  return out;
}
void FPSMovement::prediction_finish(int64_t sequence, Vector3 correction,
                                    Vector3 impulse) {
  for (auto it = history.begin(); it != history.end();) {
    if (it->sequence <= sequence) {
      history_index.erase(it->sequence);
      it = history.erase(it);
    } else {
      it->position += correction;
      it->velocity += impulse;
      ++it;
    }
  }
}
void FPSMovement::_bind_methods() {
  ClassDB::bind_method(D_METHOD("prediction_clear"),
                       &FPSMovement::prediction_clear);
  ClassDB::bind_method(D_METHOD("prediction_remember", "sequence", "position",
                                "velocity", "height", "jetpack", "stamina"),
                       &FPSMovement::prediction_remember);
  ClassDB::bind_method(D_METHOD("prediction_begin", "actor", "sequence",
                                "position", "velocity", "grounded"),
                       &FPSMovement::prediction_begin);
  ClassDB::bind_method(
      D_METHOD("prediction_finish", "sequence", "correction", "impulse"),
      &FPSMovement::prediction_finish);
  ClassDB::bind_method(D_METHOD("prediction_samples"),
                       &FPSMovement::prediction_samples);
  ClassDB::bind_method(D_METHOD("prediction_set_stats", "stats"),
                       &FPSMovement::prediction_set_stats);
  ClassDB::bind_method(D_METHOD("prediction_stats"),
                       &FPSMovement::prediction_stats);
  ClassDB::bind_method(D_METHOD("prediction_acknowledged"),
                       &FPSMovement::prediction_acknowledged);
  ClassDB::bind_method(D_METHOD("prediction_size"),
                       &FPSMovement::prediction_size);

  ClassDB::bind_method(D_METHOD("jetpack_tick", "state", "velocity",
                                "direction", "delta", "jump", "jump_held",
                                "requested", "blocked", "cancel", "prone"),
                       &FPSMovement::jetpack_tick);
  ClassDB::bind_method(D_METHOD("jetpack_moved", "state", "velocity", "before",
                                "after", "floor", "ceiling"),
                       &FPSMovement::jetpack_moved);
  ClassDB::bind_method(D_METHOD("horizontal", "velocity", "wish", "speed",
                                "grounded", "delta", "stamina", "edge"),
                       &FPSMovement::horizontal);
  ClassDB::bind_method(D_METHOD("simulate_cs", "actor", "direction", "swim",
                                "state", "delta", "slow", "jump", "in_water",
                                "supported"),
                       &FPSMovement::simulate_cs);
  ClassDB::bind_method(D_METHOD("correct_prediction", "actor", "requested"),
                       &FPSMovement::correct_prediction);
  ClassDB::bind_method(D_METHOD("vehicles", "ids", "previous", "current",
                                "timing", "now", "physics_fraction"),
                       &FPSMovement::vehicles);
}
