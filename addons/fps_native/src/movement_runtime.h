#pragma once
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <list>
#include <unordered_map>
namespace godot {
class FPSMovement : public RefCounted {
  GDCLASS(FPSMovement, RefCounted)
  struct Sample {
    int64_t sequence;
    Vector3 position, velocity;
    double height, stamina;
    Dictionary jetpack;
  };
  std::list<Sample> history;
  std::unordered_map<int64_t, std::list<Sample>::iterator> history_index;
  int64_t acknowledged = -1, corrections = 0, resets = 0;
  double max_error = 0;

protected:
  static void _bind_methods();

public:
  bool snapshot_apply_fields(const Array&,const Dictionary&,const Dictionary&,int64_t mine,double clock) const;
  void prediction_reconcile(CharacterBody3D*,int64_t sequence,Vector3 position,Vector3 velocity,double height,bool grounded,const Dictionary &jetpack,double stamina,double max_stamina);
  void prediction_clear();
  void prediction_remember(int64_t sequence, Vector3 position, Vector3 velocity,
                           double height, const Dictionary &jetpack,
                           double stamina);
  Dictionary prediction_begin(CharacterBody3D *actor, int64_t sequence,
                              Vector3 position, Vector3 velocity,
                              bool grounded);
  void prediction_finish(int64_t sequence, Vector3 correction, Vector3 impulse);
  Dictionary prediction_samples() const;
  Dictionary prediction_stats() const;
  void prediction_set_stats(const Dictionary &stats);
  int64_t prediction_acknowledged() const { return acknowledged; }
  int prediction_size() const { return int(history.size()); }
  Dictionary jetpack_tick(const Dictionary &state, Vector3 velocity,
                          Vector3 direction, double delta, bool jump,
                          bool jump_held, bool requested, bool blocked,
                          bool cancel, bool prone) const;
  Vector3 jetpack_moved(const Dictionary &state, Vector3 velocity,
                        Vector3 before, Vector3 after, bool floor,
                        bool ceiling) const;
  Vector2 horizontal(Vector2 velocity, Vector2 wish, double speed,
                     bool grounded, double delta, double stamina,
                     bool edge) const;
  Dictionary simulate_cs(CharacterBody3D *actor, Vector3 direction,
                         Vector3 swim, const PackedFloat64Array &state,
                         double delta, bool slow, bool jump, bool in_water,
                         bool supported) const;
  Dictionary vehicles(const PackedInt64Array &ids, const Array &previous,
                      const Array &current, const PackedFloat64Array &timing,
                      double now, double physics_fraction) const;
  Vector3 correct_prediction(CharacterBody3D *actor, Vector3 requested) const;
};
bool movement_step(CharacterBody3D *actor, Vector3 travel, double height,
                   uint32_t edge_mask = 1);
} // namespace godot
