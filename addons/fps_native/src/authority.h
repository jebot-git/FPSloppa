#pragma once
#include "authority_core.h"
#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/physics_shape_query_parameters3d.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <thread>
#include <unordered_map>
namespace godot {
class FPSAuthority : public RefCounted, private cqauthority::Host {
  GDCLASS(FPSAuthority, RefCounted)
  struct Actor {
    ObjectID body, shape;
    cqauthority::Handle handle;
  };
  cqauthority::Core core;
  std::unordered_map<int64_t, Actor> actors;
  std::unordered_map<uint64_t, cqauthority::Handle> identities;
  std::unordered_map<uint64_t, ObjectID> entity_bodies;
  std::unordered_map<uint64_t, uint64_t> entity_identities;
  ObjectID world_node;
  Node3D *world() const;
  cqauthority::Hit contact(const Dictionary &) const;
  uint64_t excluded_entity = 0;
  cqauthority::Hit entity_ray(cqauthority::V, cqauthority::V,
                              uint64_t) override;
  bool clear_exit(cqauthority::Handle, cqauthority::V, uint64_t) override;
  void seat(cqauthority::Handle, cqauthority::V, bool) override;
  void sync_vehicle(const cqauthority::Vehicle &) override;
  cqauthority::VehicleMoved move_vehicle(const cqauthority::Vehicle &,
                                         cqauthority::V, double) override;
  double ground_height(double, double) override;
  std::vector<cqauthority::V> navigate(cqauthority::V, cqauthority::V) override;
  void sync_turrets();
  Ref<PhysicsRayQueryParameters3D> ray;
  Ref<PhysicsShapeQueryParameters3D> posture_query;
  Ref<CapsuleShape3D> upper;
  Ref<SphereShape3D> sweep_shape;
  Ref<PhysicsShapeQueryParameters3D> sweep_query;
  bool advancing = false;
  uint64_t last_physics_frame = UINT64_MAX;
  const std::thread::id owner_thread = std::this_thread::get_id();
  bool on_owner() const {
    auto *os = OS::get_singleton();
    return os && std::this_thread::get_id() == owner_thread &&
           os->get_thread_caller_id() == os->get_main_thread_id();
  }
  CharacterBody3D *body(int64_t) const;
  bool edge(const cqauthority::Motion &) override;
  double posture(cqauthority::Handle, double) override;
  cqauthority::Moved move(const cqauthority::Motion &, double) override;
  cqauthority::Hit sweep_world(cqauthority::V, cqauthority::V, double,
                               cqauthority::Handle, uint64_t) override;
  double world_fraction(cqauthority::V, cqauthority::V, double,
                        cqauthority::Handle) override;
  bool request_action(int64_t, int64_t, int64_t, int, int, int, int);
  cqauthority::V room_move(cqauthority::Handle, cqauthority::V,
                           double) override;
  cqauthority::Hit world_trace(cqauthority::V, cqauthority::V,
                               cqauthority::Handle) override;
  cqauthority::Hit cast_ray(cqauthority::V, cqauthority::V, cqauthority::Handle,
                            uint32_t);
  cqauthority::Hit trace(cqauthority::V, cqauthority::V,
                         cqauthority::Handle) override;

protected:
  static void _bind_methods();

public:
  FPSAuthority();
  ~FPSAuthority();
  bool request_restart();
  bool configure_world(Node3D *);
  bool configure_tick_rate(int hz);
  Dictionary terrain_sample(const Vector3 &) const;
  bool configure_lamps(const PackedVector3Array &);
  int attach_vehicle(int, CharacterBody3D *, double, int);

  int64_t attach_actor(int64_t, CharacterBody3D *, CollisionShape3D *, int, int,
                       const PackedInt32Array &);
  bool detach_actor(int64_t, int64_t);
  bool submit(int64_t, const Dictionary &);
  bool submit_packet(int64_t, const PackedByteArray &);
  bool configure_jetpack(int64_t, bool);
  bool validate_pose(const Variant &) const;
  bool configure_frames(bool);
  bool configure_reach(int64_t, const Dictionary &);
  bool configure_cq(const Dictionary &);
  bool configure_player(int64_t, int64_t, const Dictionary &);
  bool stage_player(int64_t id);
  bool configure_stress(int64_t, bool);
  bool configure_terrain(const Dictionary &);
  bool water(cqauthority::V) override;
  bool configure_zone(const Vector3 &, double);
  bool configure_spawn(int, const Vector3 &);
  bool choose_class(int64_t, int64_t, int);
  bool choose_gear(int64_t, int64_t, int, int, int);
  void teleport(cqauthority::Handle, cqauthority::V) override;

  bool advance();
  PackedByteArray snapshot() const;
  Dictionary inspect(int64_t) const;
  Dictionary squad_roster() const;
  Dictionary metrics() const;
};
} // namespace godot
