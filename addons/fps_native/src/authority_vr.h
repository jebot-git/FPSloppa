#pragma once
#include "authority_math.h"
#include <cstdint>
namespace cqauthority {
struct Pose {
  bool tracked = false, left_handed = false, has_offhand = false,
       has_height = false;
  T head, left, right, weapon, offhand;
  double height = 1.65;
  bool valid() const;
  void rebase(V shift);
};
struct ReachProfile {
  bool enabled = false;
  V neck, head, eye, left_shoulder, right_shoulder, neck_socket;
  B correction;
  V left_rest[3], right_rest[3];
  T weapon_pose(const Pose &, bool offhand = false) const;
};
V room_request(V head);
V validate_room(V requested, const Pose &);
T hip_frame(const Pose &);
bool pouch_contains(const Pose &, V);
struct MotionHistory {
  bool present = false;
  double time = 0;
  V hand, weapon, support, raw_weapon, raw_support;
  B basis, head_basis;
};
struct HandMotion {
  bool valid = false, duplicate = false;
  double dt = 0;
  V hand_step, weapon_step, body_step, support_step;
};
HandMotion sample_motion(MotionHistory &, const Pose &, double stamp);
enum class Grab : uint8_t { NONE, MAGAZINE, AMMO, RACK };
struct Reload {
  bool initialised = false, mag = true, ready = false, locked = false,
       grip = true, trigger = true, eject = true, pulled = false, left_pouch = false;
  int side = -1, carry = 0, carried_rounds = 0, cq_weapon = -1;
  uint32_t event = 0;
  Grab grab = Grab::NONE;
  double stroke = 0, started = 0, removed_depth = 0, pack_until = 0;
  V anchor;
  MotionHistory motion;
  void init(int clip);
  void interrupt();
  void chamber(int clip);
  void eject_mag(bool pack);
  bool can_fire(bool pack) const;
  int sample(int geometry, int clip, int total, int capacity, const Pose &,
             bool grip, bool eject, double now, double stamp,
             bool magazine_trigger = false, bool separate_trigger = false);
  void pack_delay(bool previous_mag, int previous_clip, int clip, double now,
                  double duration);
};
struct Jetpack {
  int mode = 0;
  double age = 0, cooldown = 0, tap = 0, distance = 0, time = 0;
  uint32_t activation = 0;
  V heading;
  bool tick(V &velocity, V direction, double dt, bool jump, bool jump_held,
            bool requested, bool enabled, bool blocked, bool prone);
  void moved(V &velocity, V before, V after, bool floor, bool ceiling);
};
} // namespace cqauthority
