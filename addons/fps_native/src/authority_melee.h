#pragma once
#include "authority_vr.h"
#include <array>
namespace cqauthority {
struct MeleeSample {
  bool active = false, started = false;
  std::array<std::array<V, 2>, 16> segments{};
};
// FPSloppa deathmatch/melee.gd shared activation delay, including both hands.
constexpr double MELEE_COOLDOWN = .8;
struct MeleeState {
  bool previous = false, armed = true, hit = false, left = false;
  int weapon = 0;
  int64_t sequence = -1;
  T pose;
  double time = 0, ready_at = 0, swing_until = 0;
  void reset() {
    previous = false;
    armed = true;
    swing_until = 0;
  }
  MeleeSample sample(const Pose &, double, int);
};
} // namespace cqauthority
