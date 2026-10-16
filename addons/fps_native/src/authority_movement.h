#pragma once
#include "authority_math.h"
namespace cqauthority {
// Pure CS movement kernel, shared by authoritative simulation and client
// prediction.
inline V cs_horizontal(V velocity, V wish, double speed, bool grounded,
                       double dt, double stamina, bool edge) {
  double current = velocity.length(), strength = std::min(wish.length(), 1.);
  if (grounded && current > 0) {
    double stop = strength > 0 && strength < 1
                      ? std::min(75. / 32, speed * strength)
                      : 75. / 32;
    velocity = velocity * (std::max(0., current - std::max(current, stop) * 4 *
                                                      (edge ? 2 : 1) * dt) /
                           current);
    velocity = velocity * std::pow(std::max(0., 1 - .19 * stamina), dt * 100);
  }
  if (strength > 0) {
    V direction = wish.unit();
    double requested = speed * strength,
           available = (grounded ? requested : std::min(requested, 30. / 32)) -
                       velocity.dot(direction);
    if (available > 0)
      velocity =
          velocity +
          direction * std::min(available, (grounded ? 5 : 10) * requested * dt);
  }
  return grounded && velocity.length() < 1. / 32 ? V{} : velocity;
}
inline V cs_jump_limit(V velocity, double speed) {
  return velocity.length() > speed * 1.2 ? velocity.unit() * (speed * 1.2 * .8)
                                         : velocity;
}
inline V cs_water(V velocity, V wish, double speed, double dt, bool jump) {
  if (jump)
    velocity.y = 100. / 32;
  V requested = wish.limited(1) * speed;
  if (requested.length2() < 1e-12)
    requested.y = -60. / 32;
  velocity = velocity * std::max(0., 1 - 4 * dt);
  double length = requested.length() * .8,
         available = length - velocity.length();
  if (available > 0)
    velocity =
        velocity + requested.unit() * std::min(available, 5 * length * dt);
  return velocity;
}
} // namespace cqauthority
