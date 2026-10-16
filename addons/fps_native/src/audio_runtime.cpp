#include "audio_runtime.h"
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
#include <unordered_set>
using namespace godot;
PackedInt32Array FPSAudio::grass_step(FPSWorld *world,
                                      const PackedInt64Array &ids,
                                      const PackedVector3Array &positions,
                                      const PackedByteArray &flags,
                                      Vector3 listener, double interval,
                                      double clock, double tile_side,
                                      double extent) {
  PackedInt32Array out;
  if (std::this_thread::get_id() != owner_thread || !world || interval <= 0 ||
      ids.size() != positions.size() || ids.size() != flags.size())
    return out;
  std::unordered_set<int64_t> live;
  for (int i = 0; i < ids.size(); ++i) {
    live.insert(ids[i]);
    auto it = walkers.find(ids[i]);
    if (it == walkers.end())
      it = walkers.emplace(ids[i], Walker{positions[i], 0, 0}).first;
    auto &w = it->second;
    auto p = positions[i];
    double travel = Vector2(p.x - w.previous.x, p.z - w.previous.z).length();
    w.previous = p;
    if (!(flags[i] & 1) || p.distance_squared_to(listener) > 144 ||
        travel / interval <= 2.5 || travel > 3 ||
        !world->grass_contains(p, tile_side, extent)) {
      w.distance = 0;
      continue;
    }
    w.distance += travel;
    if (w.distance < ((flags[i] & 2) ? .18 : .35) || clock < w.next_at)
      continue;
    w.distance = 0;
    w.next_at = clock + .32;
    out.append(i);
  }
  for (auto it = walkers.begin(); it != walkers.end();) {
    if (!live.count(it->first))
      it = walkers.erase(it);
    else
      ++it;
  }
  return out;
}
bool FPSAudio::occluded(const Ref<World3D> &world, Vector3 from,
                        Vector3 to) const {
  if (std::this_thread::get_id() != owner_thread || world.is_null() ||
      from.distance_squared_to(to) < .04)
    return false;
  auto query = PhysicsRayQueryParameters3D::create(from, to, 1);
  return !world->get_direct_space_state()->intersect_ray(query).is_empty();
}
void FPSAudio::update_source(const Ref<World3D> &world, Vector3 listener,
                             AudioStreamPlayer3D *player, double dry_db) {
  if (std::this_thread::get_id() != owner_thread || !player || world.is_null())
    return;
  ++source_updates;
  bool blocked = occluded(world, listener, player->get_global_position());
  player->set_volume_db(blocked ? dry_db - 10 : dry_db);
  player->set_attenuation_filter_cutoff_hz(blocked ? 1800 : 18000);
}
Array FPSAudio::spatial_step(const Array &sources, const Ref<World3D> &world,
                             Vector3 listener, double clock) {
  Array out;
  if (std::this_thread::get_id() != owner_thread)
    return out;
  for (int i = 0; i < sources.size(); ++i) {
    Variant value = sources[i];
    if (value.get_type() != Variant::OBJECT)
      continue;
    auto *player = Object::cast_to<AudioStreamPlayer3D>(
        ObjectDB::get_instance(ObjectID(value)));
    if (!player || player->is_queued_for_deletion())
      continue;
    if (clock > double(player->get_meta("expires", INFINITY))) {
      player->queue_free();
      continue;
    }
    update_source(world, listener, player, player->get_meta("dry_db", -8.));
    out.append(player);
  }
  return out;
}
double FPSAudio::room_target(const Ref<World3D> &world,
                             Vector3 listener) const {
  if (std::this_thread::get_id() != owner_thread)
    return .04;
  const Vector3 directions[] = {
      {0, 1, 0}, {-1, 0, 0}, {1, 0, 0}, {0, 0, -1}, {0, 0, 1}};
  int count = 0;
  for (auto d : directions)
    if (occluded(world, listener, listener + d * 12))
      ++count;
  return .04 + count * .032;
}
void FPSAudio::_bind_methods() {
  ClassDB::bind_method(D_METHOD("grass_step", "world", "ids", "positions",
                                "flags", "listener", "interval", "clock",
                                "tile_side", "extent"),
                       &FPSAudio::grass_step);
  ClassDB::bind_method(D_METHOD("grass_clear"), &FPSAudio::grass_clear);
  ClassDB::bind_method(D_METHOD("occluded", "world", "from", "to"),
                       &FPSAudio::occluded);
  ClassDB::bind_method(
      D_METHOD("update_source", "world", "listener", "player", "dry_db"),
      &FPSAudio::update_source);
  ClassDB::bind_method(
      D_METHOD("spatial_step", "sources", "world", "listener", "clock"),
      &FPSAudio::spatial_step);
  ClassDB::bind_method(D_METHOD("room_target", "world", "listener"),
                       &FPSAudio::room_target);
  ClassDB::bind_method(D_METHOD("get_source_updates"),
                       &FPSAudio::get_source_updates);
}
