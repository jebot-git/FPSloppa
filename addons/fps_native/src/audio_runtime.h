#pragma once
#include "world_runtime.h"
#include <godot_cpp/classes/audio_stream_player3d.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <thread>
#include <unordered_map>
namespace godot {
class FPSAudio : public RefCounted {
  GDCLASS(FPSAudio, RefCounted)
  struct Walker {
    Vector3 previous;
    double distance = 0, next_at = 0;
  };
  std::unordered_map<int64_t, Walker> walkers;
  int64_t source_updates = 0;
  const std::thread::id owner_thread = std::this_thread::get_id();

protected:
  static void _bind_methods();

public:
  PackedInt32Array grass_step(FPSWorld *world, const PackedInt64Array &ids,
                              const PackedVector3Array &positions,
                              const PackedByteArray &flags, Vector3 listener,
                              double interval, double clock, double tile_side,
                              double extent);
  void grass_clear() {
    if (std::this_thread::get_id() == owner_thread)
      walkers.clear();
  }
  bool occluded(const Ref<World3D> &world, Vector3 from, Vector3 to) const;
  void update_source(const Ref<World3D> &world, Vector3 listener,
                     AudioStreamPlayer3D *player, double dry_db);
  Array spatial_step(const Array &sources, const Ref<World3D> &world,
                     Vector3 listener, double clock);
  double room_target(const Ref<World3D> &world, Vector3 listener) const;
  int64_t get_source_updates() const { return source_updates; }
};
} // namespace godot
