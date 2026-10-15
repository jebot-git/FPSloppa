#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
namespace cqauthority {
struct Handle {
  int64_t id = 0;
  uint32_t life = 0;
  bool operator==(Handle b) const { return id == b.id && life == b.life; }
  bool operator!=(Handle b) const { return !(*this == b); }
};
struct V {
  double x = 0, y = 0, z = 0;
  V operator+(V b) const { return {x + b.x, y + b.y, z + b.z}; }
  V operator-(V b) const { return {x - b.x, y - b.y, z - b.z}; }
  V operator*(double k) const { return {x * k, y * k, z * k}; }
  V operator/(double k) const { return *this * (1 / k); }
  double dot(V b) const { return x * b.x + y * b.y + z * b.z; }
  V cross(V b) const {
    return {y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x};
  }
  double length2() const { return dot(*this); }
  double length() const { return std::sqrt(length2()); }
  bool finite() const {
    return std::isfinite(x) && std::isfinite(y) && std::isfinite(z);
  }
  V unit() const {
    double n = length();
    return n > 1e-12 ? *this / n : V{};
  }
  V limited(double n) const { return length() > n ? unit() * n : *this; }
};
struct B {
  V x{1, 0, 0}, y{0, 1, 0}, z{0, 0, 1};
  V apply(V v) const { return x * v.x + y * v.y + z * v.z; }
  V inverse(V v) const { return {v.dot(x), v.dot(y), v.dot(z)}; }
  static B yaw(double a) {
    return {{std::cos(a), 0, -std::sin(a)},
            {0, 1, 0},
            {std::sin(a), 0, std::cos(a)}};
  }
  B product(const B &b) const { return {apply(b.x), apply(b.y), apply(b.z)}; }
  static B euler(V angles) {
    double x = angles.x, y = angles.y, z = angles.z;
    double cx = std::cos(x), sx = std::sin(x), cy = std::cos(y),
           sy = std::sin(y), cz = std::cos(z), sz = std::sin(z);
    return {{cy * cz + sy * sx * sz, cx * sz, -sy * cz + cy * sx * sz},
            {-cy * sz + sy * sx * cz, cx * cz, sy * sz + cy * sx * cz},
            {sy * cx, -sx, cy * cx}};
  }
  V euler_angles() const {
    double sx = std::clamp(-z.y, -1., 1.);
    if (std::abs(sx) < .999999)
      return {std::asin(sx), std::atan2(z.x, z.z), std::atan2(x.y, y.y)};
    return {std::copysign(1.5707963267948966, sx), std::atan2(-x.z, x.x), 0};
  }
  bool valid() const {
    return x.finite() && y.finite() && z.finite() &&
           std::abs(x.dot(y.cross(z)) - 1) <= .05 &&
           std::abs(x.length() - 1) <= .02 && std::abs(y.length() - 1) <= .02 &&
           std::abs(z.length() - 1) <= .02 && std::abs(x.dot(y)) < .02 &&
           std::abs(x.dot(z)) < .02 && std::abs(y.dot(z)) < .02;
  }
  // Accepted network bases are near orthonormal, not necessarily exact. Use the
  // true inverse for reload gestures, matching Transform3D.affine_inverse().
  V unapply(V v) const {
    double d = x.dot(y.cross(z));
    return {v.dot(y.cross(z)) / d, v.dot(z.cross(x)) / d,
            v.dot(x.cross(y)) / d};
  }
};
struct T {
  B basis;
  V origin;
  V apply(V p) const { return origin + basis.apply(p); }
  V inverse(V p) const { return basis.unapply(p - origin); }
  bool valid() const { return origin.finite() && basis.valid(); }
};
inline V closest(V p, V a, V b) {
  V d = b - a;
  return a +
         d * std::clamp((p - a).dot(d) / std::max(1e-12, d.length2()), 0., 1.);
}
} // namespace cqauthority
