#include "authority_melee.h"
namespace cqauthority {
namespace {
struct Q {
  double x = 0, y = 0, z = 0, w = 1;
  Q operator*(double k) const { return {x * k, y * k, z * k, w * k}; }
  Q operator+(Q b) const { return {x + b.x, y + b.y, z + b.z, w + b.w}; }
  double dot(Q b) const { return x * b.x + y * b.y + z * b.z + w * b.w; }
  Q unit() const { return *this * (1 / std::sqrt(dot(*this))); }
};
Q quaternion(B b) {
  b.x = b.x.unit();
  b.y = (b.y - b.x * b.x.dot(b.y)).unit();
  b.z = b.x.cross(b.y);
  double trace = b.x.x + b.y.y + b.z.z;
  Q q;
  if (trace > 0) {
    double s = std::sqrt(trace + 1) * 2;
    q = {(b.y.z - b.z.y) / s, (b.z.x - b.x.z) / s, (b.x.y - b.y.x) / s,
         .25 * s};
  } else if (b.x.x > b.y.y && b.x.x > b.z.z) {
    double s = std::sqrt(1 + b.x.x - b.y.y - b.z.z) * 2;
    q = {.25 * s, (b.y.x + b.x.y) / s, (b.z.x + b.x.z) / s,
         (b.y.z - b.z.y) / s};
  } else if (b.y.y > b.z.z) {
    double s = std::sqrt(1 + b.y.y - b.x.x - b.z.z) * 2;
    q = {(b.y.x + b.x.y) / s, .25 * s, (b.z.y + b.y.z) / s,
         (b.z.x - b.x.z) / s};
  } else {
    double s = std::sqrt(1 + b.z.z - b.x.x - b.y.y) * 2;
    q = {(b.z.x + b.x.z) / s, (b.z.y + b.y.z) / s, .25 * s,
         (b.x.y - b.y.x) / s};
  }
  return q.unit();
}
T interpolate(T a, T b, double t) {
  Q x = quaternion(a.basis), y = quaternion(b.basis);
  double dot = x.dot(y);
  if (dot < 0) {
    y = y * -1;
    dot = -dot;
  }
  Q q;
  if (1 - dot > 1e-6) {
    double angle = std::acos(std::clamp(dot, -1., 1.));
    q = x * (std::sin((1 - t) * angle) / std::sin(angle)) +
        y * (std::sin(t * angle) / std::sin(angle));
  } else
    q = (x * (1 - t) + y * t).unit();
  B basis{{1 - 2 * (q.y * q.y + q.z * q.z), 2 * (q.x * q.y + q.w * q.z),
           2 * (q.x * q.z - q.w * q.y)},
          {2 * (q.x * q.y - q.w * q.z), 1 - 2 * (q.x * q.x + q.z * q.z),
           2 * (q.y * q.z + q.w * q.x)},
          {2 * (q.x * q.z + q.w * q.y), 2 * (q.y * q.z - q.w * q.x),
           1 - 2 * (q.x * q.x + q.y * q.y)}};
  basis.x = basis.x * (a.basis.x.length() * (1 - t) + b.basis.x.length() * t);
  basis.y = basis.y * (a.basis.y.length() * (1 - t) + b.basis.y.length() * t);
  basis.z = basis.z * (a.basis.z.length() * (1 - t) + b.basis.z.length() * t);
  return {basis, a.origin + (b.origin - a.origin) * t};
}
} // namespace
MeleeSample MeleeState::sample(const Pose &p, double now, int current_weapon) {
  T current = p.weapon;
  current.origin = current.origin - p.head.origin;
  T before = previous ? pose : current;
  double dt = previous ? now - time : 0;
  bool changed =
      previous && (weapon != current_weapon || left != p.left_handed);
  pose = current;
  time = now;
  weapon = current_weapon;
  left = p.left_handed;
  previous = true;
  V tip{0, 0, -.5};
  double distance = std::max((before.origin - current.origin).length(),
                             (before.apply(tip) - current.apply(tip)).length());
  if (dt < .005 || dt > .15 || changed || distance > .65) {
    armed = true;
    swing_until = 0;
    return {};
  }
  double speed = distance / dt;
  if (speed < .35)
    armed = true;
  MeleeSample out;
  if (speed >= 1 && distance >= .025 && armed && now >= ready_at) {
    armed = false;
    ready_at = now + MELEE_COOLDOWN;
    swing_until = now + .22;
    hit = false;
    out.started = true;
  }
  if (hit || now >= swing_until || speed < .35)
    return {};
  out.active = true;
  size_t i = 0;
  for (int step = 0; step < 4; ++step) {
    T a = interpolate(before, current, step / 4.),
      b = interpolate(before, current, (step + 1) / 4.);
    for (double reach : {0., .5, 1.})
      out.segments[i++] = {a.apply(tip * reach), b.apply(tip * reach)};
    out.segments[i++] = {b.origin, b.apply(tip)};
  }
  return out;
}
} // namespace cqauthority
