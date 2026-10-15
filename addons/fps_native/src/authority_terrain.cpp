#include "authority_terrain.h"
namespace cqauthority {
namespace {
double smooth(double a, double b, double x) {
  double t = std::clamp((x - a) / (b - a), 0., 1.);
  return t * t * (3 - 2 * t);
}
double distance(V p, const TerrainRoad &r, double &t) {
  V a{r.a.x, 0, r.a.z}, b{r.b.x, 0, r.b.z}, d = b - a;
  t = std::clamp((p - a).dot(d) / d.length2(), 0., 1.);
  return (p - a - d * t).length();
}
} // namespace
V Terrain::water_sample(double x, double z) const {
  if (!configured)
    return {};
  V result{};
  V p{x, 0, z};
  for (auto &row : rivers) {
    V d{row.b.x - row.a.x, 0, row.b.z - row.a.z};
    double t =
        std::clamp((p - V{row.a.x, 0, row.a.z}).dot(d) / d.length2(), 0., 1.);
    double gap = (p - V{row.a.x, 0, row.a.z} - d * t).length();
    double mask = 1 - smooth(row.width, row.width + 12, gap);
    if (mask > result.x)
      result = {mask, row.a.y + (row.b.y - row.a.y) * t, row.depth};
  }
  for (auto &pad : pads) {
    double d = std::max(std::abs(x - pad.center.x), std::abs(z - pad.center.z));
    result.x *= smooth(pad.radius + 4, pad.radius + 16, d);
  }
  double south = z - port.z, distance = std::max(0., south - 68),
         center = port.x + std::sin(distance * .003) * 28,
         width = 63 + distance * .24;
  double sea = (1 - smooth(width, width + 11, std::abs(x - center))) *
               smooth(57, 68, south);
  return sea > result.x ? V{sea, 0, 8} : result;
}
bool Terrain::road(V position) const {
  if (!configured)
    return false;
  auto cell = key(int32_t(std::floor((position.x + extent * .5) / tile)),
                  int32_t(std::floor((position.z + extent * .5) / tile)));
  V p{position.x, 0, position.z};
  for (auto *bins : {&main, &access}) {
    auto it = bins->find(cell);
    if (it == bins->end())
      continue;
    double nearest = 1e30, height = 0, width = 0;
    for (auto &r : it->second) {
      double t = 0, d = distance(p, r, t);
      if (d < nearest) {
        nearest = d;
        height = r.a.y + (r.b.y - r.a.y) * t;
        width = r.width;
      }
    }
    if (nearest < width && std::abs(position.y - height) < 1)
      return true;
  }
  return false;
}
} // namespace cqauthority
