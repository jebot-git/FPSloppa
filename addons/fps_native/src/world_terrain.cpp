#include "world_runtime.h"
#include <algorithm>
#include <cmath>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <limits>
using namespace godot;
namespace {
double mix(double a, double b, double t) { return a + (b - a) * t; }
double smooth(double a, double b, double x) {
  double t = std::clamp((x - a) / (b - a), 0., 1.);
  return t * t * (3 - 2 * t);
}
Vector3 color(double r, double g, double b) { return Vector3(r, g, b); }
} // namespace
void FPSWorld::terrain_configure(const Dictionary &config) {
  // Configure once, before worker tasks. Everything sampled thereafter is
  // native and immutable.
  roads.clear();
  access.clear();
  earthworks.clear();
  rivers.clear();
  pads.clear();
  rocks.clear();
  cover.clear();
  extent = config.get("extent", extent);
  tile = config.get("tile", tile);
  auto load = [&](const char *name, auto &out, bool river = false) {
    Dictionary bins = config.get(name, Dictionary());
    Array keys = bins.keys();
    for (int i = 0; i < keys.size(); ++i) {
      Vector2i coord = keys[i];
      Array rows = bins[keys[i]];
      auto &dest = out[key(coord)];
      for (int j = 0; j < rows.size(); ++j) {
        Dictionary r = rows[j];
        Vector3 a = r["a"], b = r["b"];
        dest.push_back({a.x, a.z, a.y, b.x, b.z, b.y, double(r["width"]),
                        double(r.get("along", 0.)),
                        double(r.get(river ? "depth" : "earthwork", 0.))});
      }
    }
  };
  load("roads", roads);
  load("access", access);
  load("earthworks", earthworks);
  load("rivers", rivers, true);
  Array centers = config["centers"], radii = config["radii"];
  for (int i = 0; i < centers.size(); ++i) {
    Vector3 p = centers[i];
    pads.emplace_back(p.x, p.y, p.z, double(radii[i]));
  }
  Array rs = config["rocks"], cs = config["cover"];
  for (int i = 0; i < rs.size(); ++i)
    rocks.push_back(rs[i]);
  for (int i = 0; i < cs.size(); ++i)
    cover.push_back(cs[i]);
  terrain_ready = true;
}
double FPSWorld::rock_mask(double x, double z) const {
  double value = 0;
  for (auto r : rocks)
    value =
        std::max(value, 1 - smooth(.35, 1, std::hypot(x - r.x, z - r.y) / r.z));
  return value;
}
double FPSWorld::natural(double x, double z) const {
  double h = 85 + std::sin(x * .0032) * std::cos(z * .003) * 32 +
             std::sin(x * .011 + z * .008) * 8;
  const double peaks[][4] = {{-300, -1130, 380, 310},
                             {1030, -1040, 350, 390},
                             {1110, 120, 290, 205},
                             {-1150, 100, 300, 145},
                             {160, 530, 310, 85}};
  for (auto &p : peaks) {
    double d = std::hypot(x - p[0], z - p[1]) / p[2];
    h += p[3] * std::exp(-d * d * 2.3);
  }
  double canyon =
      (1 - smooth(28, 125, std::abs(x - (-470 + std::sin(z * .003) * 95)))) *
      (1 - smooth(650, 1050, std::abs(z)));
  h = mix(h, 22 + std::sin(z * .009) * 5, canyon);
  double second =
      (1 - smooth(22, 105, std::abs(z - (-800 + std::sin(x * .003) * 70)))) *
      smooth(50, 260, x) * (1 - smooth(850, 1250, x));
  h = mix(h, 46 + std::sin(x * .006) * 7, second);
  for (auto r : rocks) {
    double d = std::hypot(x - r.x, z - r.y) / r.z;
    h += r.w * (1 - smooth(.2, 1, d)) *
         (.82 + .18 * std::sin(x * .09 + z * .07));
  }
  for (auto c : cover) {
    double d = std::hypot(x - c.x, z - c.y);
    if (d < c.z)
      h += c.w * (1 - smooth(0, c.z, d));
  }
  return h;
}
Vector3 FPSWorld::water(double x, double z) const {
  Vector3 result;
  auto it =
      rivers.find(key({int(std::floor(x / 128)), int(std::floor(z / 128))}));
  if (it != rivers.end())
    for (auto &r : it->second) {
      double dx = r.bx - r.ax, dz = r.bz - r.az,
             t = std::clamp(((x - r.ax) * dx + (z - r.az) * dz) /
                                (dx * dx + dz * dz),
                            0., 1.);
      double mask =
          1 - smooth(r.width, r.width + 12,
                     std::hypot(x - (r.ax + dx * t), z - (r.az + dz * t)));
      if (mask > result.x)
        result = {real_t(mask), real_t(mix(r.ay, r.by, t)),
                  real_t(r.earthwork)};
    }
  for (auto p : pads)
    result.x *= smooth(p.w + 4, p.w + 16,
                       std::max(std::abs(x - p.x), std::abs(z - p.z)));
  if (pads.size() > 2) {
    auto p = pads[2];
    double south = z - p.z, d = std::max(0., south - 68),
           center = p.x + std::sin(d * .003) * 28, width = 63 + d * .24;
    double sea = (1 - smooth(width, width + 11, std::abs(x - center))) *
                 smooth(57, 68, south);
    if (sea > result.x)
      return {real_t(sea), 0, 8};
  }
  return result;
}
Vector4 FPSWorld::surface(double x, double z) const {
  if (!terrain_ready)
    return {};
  double h = natural(x, z),
         shade = .5 + .5 * std::sin(x * .065 + std::sin(z * .07) * 2),
         forest =
             .45 + .55 * smooth(-.5, .6,
                                std::sin(x * .021 + std::sin(z * .012) * 2) *
                                        std::cos(z * .017) +
                                    std::sin((x + z) * .009) * .4);
  // Color uses float channels in Godot's Color, matching the atlas source.
  Vector3 c = color(.24, .36, .18).lerp(color(.12, .25, .12), forest);
  c = c.lerp(color(.49, .46, .36), shade * .20);
  double gravel =
      smooth(.72, .95, .5 + .5 * std::sin(x * .33) * std::sin(z * .27)) *
      (1 - forest);
  c = c.lerp(color(.48, .47, .40), gravel * .35);
  c = c.lerp(color(.42, .43, .38),
             std::max(rock_mask(x, z), smooth(220, 390, h)) * .85);
  auto k = key(bin(x, z));
  auto foundation = earthworks.find(k);
  double strongest = 0, target = h;
  auto projection = [&](const Road &r) {
    double dx = r.bx - r.ax, dz = r.bz - r.az,
           t = std::clamp(((x - r.ax) * dx + (z - r.az) * dz) /
                              (dx * dx + dz * dz),
                          0., 1.);
    return std::pair<double, double>(
        t, std::hypot(x - (r.ax + dx * t), z - (r.az + dz * t)));
  };
  if (foundation != earthworks.end())
    for (auto &r : foundation->second) {
      auto p = projection(r);
      double influence = 1 - smooth(r.width + 3, r.earthwork, p.second);
      if (influence > strongest) {
        strongest = influence;
        target = mix(r.ay, r.by, p.first);
      }
    }
  h = mix(h, target, strongest);
  for (size_t i = 5; i < pads.size(); ++i) {
    auto p = pads[i];
    double weight = 1 - smooth(p.w, p.w + 16,
                               std::max(std::abs(x - p.x), std::abs(z - p.z)));
    h = mix(h, p.y, weight);
    c = c.lerp(color(.36, .39, .23), weight * .75);
  }
  for (size_t i = 0; i < std::min(size_t(5), pads.size()); ++i) {
    auto p = pads[i];
    double weight = 1 - smooth(p.w, p.w + (i == 4 ? 8 : 28),
                               std::max(std::abs(x - p.x), std::abs(z - p.z)));
    h = mix(h, p.y, weight);
    c = c.lerp(color(.38, .39, .29), weight * .6);
  }
  auto nearest = [&](const auto &bins)
      -> std::pair<const Road *, std::pair<double, double>> {
    const Road *row = nullptr;
    std::pair<double, double> best{0, std::numeric_limits<double>::infinity()};
    auto found = bins.find(k);
    if (found != bins.end())
      for (auto &r : found->second) {
        auto p = projection(r);
        if (p.second < best.second) {
          best = p;
          row = &r;
        }
      }
    return {row, best};
  };
  auto lane = nearest(access);
  if (lane.first && lane.second.second < .9)
    c = color(.53, .50, .40);
  auto road = nearest(roads);
  if (road.first) {
    auto &r = *road.first;
    auto p = road.second;
    h = mix(h, mix(r.ay, r.by, p.first),
            1 - smooth(r.width, r.width + 5, p.second));
    if (p.second < r.width) {
      c = color(.24, .25, .23);
      if (p.second < .16 &&
          std::fmod(r.along + p.first * std::hypot(r.bx - r.ax, r.bz - r.az),
                    10) < 5)
        c = color(.78, .72, .49);
    }
  }
  for (size_t i = 5; i < pads.size(); ++i) {
    auto p = pads[i];
    if (std::max(std::abs(x - p.x), std::abs(z - p.z)) <= p.w)
      h = p.y;
  }
  Vector3 w = water(x, z);
  h = mix(h, std::min(h, double(w.y - w.z)), w.x);
  c = c.lerp(color(.28, .30, .23), w.x);
  return {real_t(h), c.x, c.y, c.z};
}
PackedVector4Array FPSWorld::terrain_samples(Vector2i coord,
                                             int samples) const {
  PackedVector4Array out;
  if (!terrain_ready || samples < 2 || samples > 257)
    return out;
  out.resize(samples * samples);
  auto *dst = out.ptrw();
  double ox = coord.x * tile - extent * .5, oz = coord.y * tile - extent * .5;
  for (int z = 0; z < samples; ++z)
    for (int x = 0; x < samples; ++x)
      dst[z * samples + x] =
          surface(ox + x * tile / (samples - 1), oz + z * tile / (samples - 1));
  return out;
}

Dictionary FPSWorld::terrain_tile(Vector2i coord) const {
  auto values = terrain_samples(coord, 65);
  PackedFloat32Array heights;
  heights.resize(values.size());
  PackedByteArray colors;
  colors.resize(values.size() * 4);
  auto *h = heights.ptrw();
  auto *c = colors.ptrw();
  for (int i = 0; i < values.size(); ++i) {
    Vector4 v = values[i];
    h[i] = v.x;
    c[i * 4] = uint8_t(std::round(v.y * 255.));
    c[i * 4 + 1] = uint8_t(std::round(v.z * 255.));
    c[i * 4 + 2] = uint8_t(std::round(v.w * 255.));
    c[i * 4 + 3] = 255;
  }
  double low = INFINITY, high = -INFINITY;
  for (int i = 0; i < heights.size(); ++i) {
    low = std::min(low, double(h[i]));
    high = std::max(high, double(h[i]));
  }
  Dictionary result;
  result["height_bounds"] = Vector2(low, high);
  result["coord"] = coord;
  result["heights"] = heights.to_byte_array();
  result["colors"] = colors;
  return result;
}

bool FPSWorld::planting_allowed(Vector2 p) const {
  if (!terrain_ready)
    return false;
  for (size_t i = 0; i < pads.size(); ++i) {
    auto c = pads[i];
    if (std::max(std::abs(double(p.x) - c.x), std::abs(double(p.y) - c.z)) <
        c.w + (i < 5 ? 16 : 8))
      return false;
  }
  auto found = roads.find(key(bin(p.x, p.y)));
  const Road *nearest = nullptr;
  double best = INFINITY;
  if (found != roads.end())
    for (auto &r : found->second) {
      double dx = r.bx - r.ax, dz = r.bz - r.az;
      double t = std::clamp(((p.x - r.ax) * dx + (p.y - r.az) * dz) /
                                (dx * dx + dz * dz),
                            0., 1.);
      double d = std::hypot(p.x - (r.ax + dx * t), p.y - (r.az + dz * t));
      if (d < best) {
        best = d;
        nearest = &r;
      }
    }
  return !(nearest && best < nearest->width + 4) && water(p.x, p.y).x <= .01;
}
Array FPSWorld::vegetation_trees(Vector2i coord) const {
  Array result;
  if (!terrain_ready)
    return result;
  Ref<RandomNumberGenerator> rng;
  rng.instantiate();
  rng->set_seed(uint64_t(int64_t(1977) + int64_t(coord.x) * 73856093 +
                         int64_t(coord.y) * 19349663));
  Vector2 origin = Vector2(coord) * tile - Vector2(1, 1) * extent * .5;
  for (int z = 0; z < 4; ++z)
    for (int x = 0; x < 4; ++x) {
      double rx = rng->randf(), rz = rng->randf();
      Vector2 p = origin + Vector2((x + .2 + rx * .6) * tile / 4,
                                   (z + .2 + rz * .6) * tile / 4);
      double choice = rng->randf(), scale = rng->randf_range(.75, 1.25),
             angle = rng->randf() * 6.283185307179586476925286766559;
      if (!planting_allowed(p))
        continue;
      double h = surface(p.x, p.y).x;
      if (h < 1)
        continue;
      double slope = Vector2(natural(p.x + 1, p.y) - natural(p.x - 1, p.y),
                             natural(p.x, p.y + 1) - natural(p.x, p.y - 1))
                         .length() *
                     .5;
      double forest =
          .45 + .55 * smooth(-.5, .6,
                             std::sin(p.x * .021 + std::sin(p.y * .012) * 2) *
                                     std::cos(p.y * .017) +
                                 std::sin((p.x + p.y) * .009) * .4);
      if (slope > .85 || rock_mask(p.x, p.y) > .65 || h > 360)
        continue;
      Dictionary row;
      row["kind"] = choice < forest * .72 ? 0 : choice < .88 && h < 180 ? 1 : 2;
      row["position"] = Vector3(p.x, h, p.y);
      row["scale"] = scale;
      row["angle"] = angle;
      result.append(row);
    }
  return result;
}
PackedVector4Array
FPSWorld::vegetation_grass(Vector2i coord,
                           const PackedFloat32Array &heights) const {
  PackedVector4Array rows;
  if (!terrain_ready || heights.size() != 65 * 65)
    return rows;
  Ref<RandomNumberGenerator> rng;
  rng.instantiate();
  rng->set_seed(uint64_t(int64_t(8137) + int64_t(coord.x) * 73856093 +
                         int64_t(coord.y) * 19349663));
  Vector2 origin = Vector2(coord) * tile - Vector2(1, 1) * extent * .5;
  for (int z = 0; z < 32; ++z)
    for (int x = 0; x < 32; ++x) {
      double fx = (x + .25 + rng->randf() * .5) * 2,
             fz = (z + .25 + rng->randf() * .5) * 2;
      double angle = rng->randf() * 6.283185307179586476925286766559;
      if (rng->randf() > .90)
        continue;
      Vector2 p = origin + Vector2(fx, fz) * tile / 64;
      if (!planting_allowed(p) || rock_mask(p.x, p.y) > .4)
        continue;
      int ix = int(std::floor(fx)), iz = int(std::floor(fz)), i = iz * 65 + ix;
      double a = heights[i], b = heights[i + 1], c = heights[i + 65],
             d = heights[i + 66];
      double h = mix(mix(a, b, fx - ix), mix(c, d, fx - ix), fz - iz);
      if (h < 1 || h > 330 ||
          Vector2(b - a, c - a).length() / (tile / 64) > .55)
        continue;
      rows.append(Vector4(p.x, h - .03, p.y, angle));
    }
  return rows;
}
