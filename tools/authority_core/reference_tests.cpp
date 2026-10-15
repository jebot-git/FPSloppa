#include "authority_core.h"
#include <cstring>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
using namespace cqauthority;
extern void check(bool, const char *);
namespace {
struct Reader {
  std::ifstream stream;
  Reader(const std::string &file, const char *magic)
      : stream(file, std::ios::binary) {
    char got[4];
    stream.read(got, 4);
    check(stream.good() && std::memcmp(got, magic, 4) == 0,
          "reference file version");
  }
  uint64_t integer(size_t count) {
    uint64_t v = 0;
    for (size_t i = 0; i < count; ++i) {
      char byte;
      if (!stream.get(byte))
        throw std::runtime_error("truncated reference file");
      v |= uint64_t(uint8_t(byte)) << (8 * i);
    }
    return v;
  }
  double real() {
    uint64_t bits = integer(8);
    double value;
    std::memcpy(&value, &bits, 8);
    return value;
  }
  V vec() {
    double x = real(), y = real(), z = real();
    return {x, y, z};
  }
};
} // namespace
int collision_legacy_misses = 0, collision_legacy_late = 0;
namespace {
double oracle_box(V a, V b, V half, double radius) {
  V d = b - a;
  auto distance = [&](double t) {
    V p = a + d * t;
    double x = std::max(0., std::abs(p.x) - half.x),
           y = std::max(0., std::abs(p.y) - half.y),
           z = std::max(0., std::abs(p.z) - half.z);
    return x * x + y * y + z * z;
  };
  double lo = 0, hi = 1;
  for (int i = 0; i < 100; ++i) {
    double one = (lo * 2 + hi) / 3, two = (lo + hi * 2) / 3;
    if (distance(one) <= distance(two))
      hi = two;
    else
      lo = one;
  }
  double minimum = (lo + hi) * .5;
  double threshold = radius * radius + 1e-12;
  if (distance(minimum) > threshold)
    return infinity;
  if (distance(0) <= threshold)
    return 0;
  lo = 0;
  hi = minimum;
  for (int i = 0; i < 100; ++i) {
    double middle = (lo + hi) * .5;
    if (distance(middle) <= threshold)
      hi = middle;
    else
      lo = middle;
  }
  return hi;
}
double oracle_body(V from, V to, double height, double yaw, double radius) {
  from = B::yaw(yaw).inverse(from);
  to = B::yaw(yaw).inverse(to);
  double first = infinity;
  for (auto &part : body_geometry(height))
    first =
        std::min(first, oracle_box(part.pose.inverse(from),
                                   part.pose.inverse(to), part.half, radius));
  return first;
}
} // namespace
void reference_tests(const std::string &folder) {
  {
    Reader r(folder + "/points.bin", "CQP1");
    size_t rows = r.integer(4);
    check(rows == 12000, "point reference workload count");
    Points p;
    for (size_t row = 0; row < rows; ++row) {
      bool reset = r.integer(1);
      size_t count = r.integer(1);
      check(count > 0 && count <= MAX_ZONES, "reference zone bound");
      if (reset) {
        p = Points{};
        p.count = count;
      }
      double dt = r.real();
      int killer = int8_t(r.integer(1));
      std::array<std::array<bool, 2>, MAX_ZONES> presence{};
      for (size_t i = 0; i < count; ++i) {
        auto bits = r.integer(1);
        presence[i] = {bool(bits & 1), bool(bits & 2)};
      }
      p.advance(dt, presence);
      if (r.integer(1))
        p.kill(killer);
      check(p.scores[0] == int(r.integer(2)), "GDScript CQ score red parity");
      check(p.scores[1] == int(r.integer(2)), "GDScript CQ score blue parity");
      check(p.winner == int8_t(r.integer(1)), "GDScript CQ winner parity");
      for (size_t i = 0; i < count; ++i) {
        auto &z = p.zones[i];
        check(z.owner == int8_t(r.integer(1)), "GDScript CQ owner parity");
        check(std::abs(z.progress[0] - r.real()) < 1e-8,
              "GDScript CQ progress red parity");
        check(std::abs(z.progress[1] - r.real()) < 1e-8,
              "GDScript CQ progress blue parity");
        check(std::abs(z.credit - r.real()) < 1e-8,
              "GDScript CQ income credit parity");
        check(z.contested == bool(r.integer(1)),
              "GDScript CQ contention parity");
      }
    }
    check(r.stream.peek() == std::char_traits<char>::eof(),
          "no extra point reference bytes");
  }
  {
    Reader r(folder + "/jetpack.bin", "CQJ1");
    size_t rows = r.integer(4);
    check(rows == 16000, "jetpack reference workload count");
    Jetpack jet;
    for (size_t row = 0; row < rows; ++row) {
      uint8_t flags = r.integer(1);
      if (flags & 1)
        jet = {};
      double dt = r.real();
      V direction = r.vec(), before = r.vec(), velocity = r.vec();
      bool active = jet.tick(velocity, direction, dt, flags & 16, flags & 32,
                             flags & 64, flags & 2, flags & 4, flags & 8);
      V after = before + velocity * dt;
      if (after.y < 0) {
        after.y = 0;
        velocity.y = 0;
      }
      if (active)
        jet.moved(velocity, before, after, after.y <= 0, flags & 128);
      check(active == bool(r.integer(1)), "GDScript jetpack activation parity");
      check((velocity - r.vec()).length() < .001,
            "GDScript jetpack velocity parity");
      check((after - r.vec()).length() < .001,
            "GDScript jetpack position parity");
      check(jet.mode == int(r.integer(1)), "GDScript jetpack mode parity");
      for (double value :
           {jet.age, jet.cooldown, jet.tap, jet.distance, jet.time})
        check(std::abs(value - r.real()) < .001,
              "GDScript jetpack state parity");
      V heading{r.real(), 0, r.real()};
      check((jet.heading - heading).length() < .0001,
            "GDScript jetpack steering parity");
      check(jet.activation == r.integer(4),
            "GDScript jetpack activation serial parity");
    }
    check(r.stream.peek() == std::char_traits<char>::eof(),
          "no extra jetpack reference bytes");
  }
  {
    Reader r(folder + "/anatomy.bin", "CQA0");
    check(r.integer(4) == 101, "anatomy reference height count");
    for (int key = 65; key <= 165; ++key)
      for (auto &part : body_geometry(key * .01))
        for (V vector : {part.pose.basis.x, part.pose.basis.y,
                         part.pose.basis.z, part.pose.origin, part.half})
          check((vector - r.vec()).length() < .00001,
                "GDScript anatomy dimensions/orientation parity");
  }
  {
    Reader r(folder + "/bodies.bin", "CQB1");
    size_t rows = r.integer(4);
    check(rows == 18000, "body reference workload count");
    for (size_t row = 0; row < rows; ++row) {
      V from = r.vec(), to = r.vec();
      double height = r.real(), yaw = r.real(), radius = r.real(),
             legacy = r.real();
      bool head = r.integer(1);
      auto hit = body_fraction(from, to, height, yaw, radius);
      double expected = oracle_body(from, to, height, yaw, radius);
      if (std::isfinite(hit.fraction) != std::isfinite(expected))
        std::cerr << "body oracle mismatch row=" << row
                  << " native=" << hit.fraction << " oracle=" << expected
                  << std::endl;
      check(std::isfinite(hit.fraction) == std::isfinite(expected),
            "independent convex-distance body sweep verdict");
      if (std::isfinite(expected)) {
        check(std::abs(hit.fraction - expected) < .00001,
              "independent convex-distance body sweep fraction");
        if (!std::isfinite(legacy))
          ++collision_legacy_misses;
        else if (std::abs(hit.fraction - legacy) > .0001)
          ++collision_legacy_late;
        if (radius == 0 && std::isfinite(legacy) &&
            std::abs(hit.fraction - legacy) < .00001)
          check(head == hit.head, "GDScript hitscan headshot parity");
      } else
        check(!std::isfinite(legacy), "native must not lose a legacy hit");
    }
    check(r.stream.peek() == std::char_traits<char>::eof(),
          "no extra body reference bytes");
  }
  {
    Reader r(folder + "/melee.bin", "CQM1");
    size_t count = r.integer(4);
    MeleeState state;
    for (size_t i = 0; i < count; ++i) {
      bool reset = r.integer(1);
      if (reset)
        state = MeleeState{};
      double now = r.real();
      int weapon = r.integer(1);
      Pose pose;
      pose.left_handed = r.integer(1);
      pose.head.origin = r.vec();
      pose.weapon.basis = {r.vec(), r.vec(), r.vec()};
      pose.weapon.origin = r.vec();
      bool active = r.integer(1), started = r.integer(1);
      auto result = state.sample(pose, now, weapon);
      check(result.active == active && result.started == started,
            "tracked melee sample state GDScript parity");
      if (active)
        for (auto segment : result.segments) {
          V a = r.vec(), b = r.vec();
          check((segment[0] - a).length() < .00001 &&
                    (segment[1] - b).length() < .00001,
                "tracked melee rotational sweep GDScript parity");
        }
    }
    check(r.stream.peek() == std::char_traits<char>::eof(),
          "no extra melee reference bytes");
  }
}
