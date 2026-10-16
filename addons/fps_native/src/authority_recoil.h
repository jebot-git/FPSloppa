#pragma once
#include "authority_math.h"
namespace cqauthority {
// CS recovery, movement bloom and unsupported-long-gun penalty in typed state.
struct RecoilState {
  double heat = 0, shot_at = -10, support_at = -10;
  V support_angles, step;
  double compensation(V axis, double stamp, bool supported) {
    if (!supported || axis.length() < .075 || axis.length() > 1.1) {
      support_at = -10;
      return 1;
    }
    V angles{std::atan2(axis.y, -axis.z), std::atan2(-axis.x, -axis.z), 0};
    double scale = 1;
    if (stamp > support_at && stamp - support_at <= .25) {
      V change{
          std::remainder(angles.x - support_angles.x, 2 * 3.141592653589793),
          std::remainder(angles.y - support_angles.y, 2 * 3.141592653589793),
          0};
      if (change.length() <= 20 * 3.141592653589793 / 180 &&
          step.length2() > 1e-12) {
        double counter = std::max(0., -change.dot(step.unit()) -
                                          .08 * 3.141592653589793 / 180);
        scale = 1 - .5 * std::clamp(counter /
                                        std::max(step.length(),
                                                 .25 * 3.141592653589793 / 180),
                                    0., 1.);
      }
    }
    if (stamp > support_at) {
      support_angles = angles;
      support_at = stamp;
    }
    return scale;
  }
  V shot(int slot, double now, double speed, bool ground, double height,
         bool vr, bool supported, double correction, double rx, double ry) {
    // Controller recoil is part of the transmitted weapon pose. Only running
    // adds random deviation; cadence, heat and grip never create a spray
    // pattern.
    (void)ground;
    (void)height;
    (void)vr;
    (void)supported;
    (void)correction;
    double cone = speed > 2.5 ? std::min(2.5, (speed - 2.5) * .35) : 0.;
    if (slot == 9 || slot == 10 || slot == 16)
      cone *= .6;
    V result{rx * std::tan(cone * 3.141592653589793 / 180),
             ry * std::tan(cone * 3.141592653589793 / 180), -1};
    heat = 0;
    step = {};
    shot_at = now;
    return result.unit();
  }
};
} // namespace cqauthority
