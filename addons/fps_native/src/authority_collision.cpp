#include "authority_collision.h"
#include <vector>
namespace cqauthority {
namespace {
double axis(V v, int i) { return i == 0 ? v.x : i == 1 ? v.y : v.z; }
V clamp_box(V p, V half) {
  return {std::clamp(p.x, -half.x, half.x), std::clamp(p.y, -half.y, half.y),
          std::clamp(p.z, -half.z, half.z)};
}
B align_up(V direction) {
  V a{0, 1, 0}, b = direction.unit(), cross = a.cross(b);
  double c = a.dot(b), s = cross.length();
  if (s < 1e-10)
    return c > 0 ? B{} : B::euler({3.141592653589793, 0, 0});
  V n = cross / s;
  auto rotate = [&](V v) {
    return v * c + n.cross(v) * s + n * n.dot(v) * (1 - c);
  };
  return {rotate({1, 0, 0}), rotate({0, 1, 0}), rotate({0, 0, 1})};
}
BodyGeometry generate(int key, bool seated=false) {
  BodyGeometry parts;
  bool prone = key < 80;
  V pelvis =
      prone ? V{0, .32, .30} : V{0, std::max(.30, .78 - (1.65 - key * .01)), 0};
  T upper{B::euler({prone ? -77 * 3.141592653589793 / 180 : 0, 0, 0}), pelvis};
  size_t at = 0;
  parts[at++] = {{upper.basis, upper.apply({0, .24, 0})},
                 V{.55, .58, .32} * .5};
  parts[at++] = {{B{}, upper.apply({0, .70, 0}) + V{0, 0, -.0125}},
                 V{.35, .34, .365} * .5};
  for (double side : {-1., 1.}) {
    parts[at++] = {{upper.basis, upper.apply({side * .38, .32, 0})},
                   V{.22, .36, .30} * .5};
    parts[at++] = {{upper.basis, upper.apply({side * .38, .12, -.16})},
                   V{.16, .23, .37} * .5};
    V hip = pelvis + V{side * .18, 0, 0},
      foot=seated ? V{side*.33,.32,-.28} : V{side * (prone ? .28 : .18), .10, prone ? 1.15 : 0};
    V axis = (foot - hip).unit();
    double distance = std::clamp((hip - foot).length(), .02, .719);
    foot = hip + axis * distance;
    V pole = prone ? V{0, -1, 0} : V{0, 0, -1};
    V bend = (pole - axis * pole.dot(axis)).unit();
    if (bend.length2() < .1)
      bend = {0, 0, -1};
    V knee =
        (hip + foot) * .5 +
        bend * std::sqrt(std::max(0., .36 * .36 - distance * distance * .25));
    for (auto ends :
         {std::array<V, 2>{hip, knee}, std::array<V, 2>{knee, foot}}) {
      V from = ends[0], to = ends[1];
      parts[at++] = {{align_up(to - from), (from + to) * .5},
                     V{.21, (from - to).length(), .24} * .5};
    }
    parts[at++] = {{B{}, foot + V{0, -.01, -.05}}, V{.24, .18, .37} * .5};
  }
  return parts;
}
} // namespace
const BodyGeometry &body_geometry(double height, bool seated) {
  if(seated) { static const auto bike=generate(165,true);return bike; }
  static const auto table = []() {
    std::vector<BodyGeometry> result;
    result.reserve(101);
    for (int key = 65; key <= 165; ++key)
      result.push_back(generate(key));
    return result;
  }();
  return table[size_t(std::clamp(int(std::round(height * 100)), 65, 165) - 65)];
}
double box_fraction(V start, V end, V half, double radius) {
  V motion = end - start;
  double enter = 0, leave = 1;
  for (int i = 0; i < 3; ++i) {
    double extent = axis(half, i) + radius + .000001, p = axis(start, i),
           d = axis(motion, i);
    if (std::abs(d) < 1e-10) {
      if (std::abs(p) > extent)
        return infinity;
    } else {
      double a = (-extent - p) / d, b = (extent - p) / d;
      enter = std::max(enter, std::min(a, b));
      leave = std::min(leave, std::max(a, b));
      if (enter > leave)
        return infinity;
    }
  }
  if (radius <= 0)
    return enter;
  std::array<double, 8> cuts{};
  size_t count = 0;
  cuts[count++] = enter;
  cuts[count++] = leave;
  for (int i = 0; i < 3; ++i) {
    double d = axis(motion, i);
    if (std::abs(d) < 1e-10)
      continue;
    for (double sign : {-1., 1.}) {
      double t = (sign * axis(half, i) - axis(start, i)) / d;
      if (t > enter && t < leave)
        cuts[count++] = t;
    }
  }
  // At most eight cuts. Insertion sorting avoids libstdc++ introsort
  // speculatively instantiating its sixteen-element insertion threshold.
  for (size_t i = 1; i < count; ++i) {
    double value = cuts[i];
    size_t j = i;
    while (j && cuts[j - 1] > value) {
      cuts[j] = cuts[j - 1];
      --j;
    }
    cuts[j] = value;
  }
  V first = start + motion * enter;
  if ((first - clamp_box(first, half)).length2() <= radius * radius + 1e-10)
    return enter;
  for (size_t i = 0; i + 1 < count; ++i) {
    double low = cuts[i], high = cuts[i + 1];
    V mid = start + motion * ((low + high) * .5), offset{}, velocity{};
    for (int j = 0; j < 3; ++j) {
      double m = axis(mid, j);
      if (std::abs(m) <= axis(half, j))
        continue;
      double o = axis(start, j) - std::copysign(axis(half, j), m),
             v = axis(motion, j);
      if (j == 0) {
        offset.x = o;
        velocity.x = v;
      } else if (j == 1) {
        offset.y = o;
        velocity.y = v;
      } else {
        offset.z = o;
        velocity.z = v;
      }
    }
    double a = velocity.length2(), b = offset.dot(velocity),
           c = offset.length2() - radius * radius;
    if (a < 1e-12)
      continue;
    double disc = b * b - a * c;
    if (disc < 0)
      continue;
    double contact = (-b - std::sqrt(disc)) / a;
    if (contact >= low - 1e-7 && contact <= high + 1e-7)
      return std::clamp(contact, low, high);
  }
  return infinity;
}
BodyHit body_fraction(V from, V to, double height, double yaw, double radius, bool seated) {
  B basis = B::yaw(yaw);
  from = basis.inverse(from);
  to = basis.inverse(to);
  if (!std::isfinite(box_fraction(from - V{0, .8, 0}, to - V{0, .8, 0},
                                  {1.5, .9, 1.5}, radius)))
    return {};
  BodyHit first;
  const auto &parts = body_geometry(height,seated);
  for (size_t i = 0; i < parts.size(); ++i) {
    const auto &p = parts[i];
    double t =
        box_fraction(p.pose.inverse(from), p.pose.inverse(to), p.half, radius);
    if (t < first.fraction) {
      first.fraction = t;
      first.axis = {0, p.pose.origin.y, 0};
    }
  }
  if (std::isfinite(first.fraction)) {
    V point = from + (to - from) * first.fraction;
    V head = parts[1].pose.inverse(point);
    first.head = (head - clamp_box(head, parts[1].half)).length2() <=
                 radius * radius + 1e-8;
  }
  return first;
}
} // namespace cqauthority
