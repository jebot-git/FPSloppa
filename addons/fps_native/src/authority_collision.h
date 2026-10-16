#pragma once
#include "authority_math.h"
#include <array>
#include <limits>
namespace cqauthority {
constexpr double infinity = std::numeric_limits<double>::infinity();
struct BodyPart {
  T pose;
  V half;
};
using BodyGeometry = std::array<BodyPart, 12>;
const BodyGeometry &body_geometry(double height, bool seated = false);
double box_fraction(V from, V to, V half, double radius = 0);
struct BodyHit {
  double fraction = infinity;
  bool head = false;
  V axis;
};
BodyHit body_fraction(V from, V to, double height, double yaw,
                      double radius = 0, bool seated = false);
} // namespace cqauthority
