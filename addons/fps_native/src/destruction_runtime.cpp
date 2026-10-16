#include "destruction_runtime.h"
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <unordered_set>
using namespace godot;
namespace {
std::vector<int> integers(const Variant &v) {
  std::vector<int> out;
  if (v.get_type() == Variant::ARRAY) {
    Array a = v;
    for (int i = 0; i < a.size(); ++i)
      out.push_back(a[i]);
  } else if (v.get_type() == Variant::PACKED_INT32_ARRAY) {
    PackedInt32Array a = v;
    for (int i = 0; i < a.size(); ++i)
      out.push_back(a[i]);
  }
  return out;
}
std::unordered_set<int> make_set(const PackedInt32Array &a) {
  std::unordered_set<int> out;
  for (int i = 0; i < a.size(); ++i)
    out.insert(a[i]);
  return out;
}
template <class T>
Variant extend(const Variant &original, const std::vector<int> &samples,
               int vertices) {
  T src = original, dst = src;
  int stride = vertices ? src.size() / vertices : 0;
  if (!stride)
    return dst;
  dst.resize(src.size() + samples.size() * stride);
  auto *p = dst.ptrw();
  for (size_t i = 0; i < samples.size(); ++i)
    for (int j = 0; j < stride; ++j)
      p[src.size() + i * stride + j] = src[samples[i] * stride + j];
  return dst;
}
Variant extend_channel(const Variant &src, const std::vector<int> &samples,
                       int vertices) {
  switch (src.get_type()) {
  case Variant::PACKED_VECTOR3_ARRAY:
    return extend<PackedVector3Array>(src, samples, vertices);
  case Variant::PACKED_VECTOR2_ARRAY:
    return extend<PackedVector2Array>(src, samples, vertices);
  case Variant::PACKED_COLOR_ARRAY:
    return extend<PackedColorArray>(src, samples, vertices);
  case Variant::PACKED_FLOAT32_ARRAY:
    return extend<PackedFloat32Array>(src, samples, vertices);
  case Variant::PACKED_FLOAT64_ARRAY:
    return extend<PackedFloat64Array>(src, samples, vertices);
  case Variant::PACKED_BYTE_ARRAY:
    return extend<PackedByteArray>(src, samples, vertices);
  case Variant::PACKED_INT32_ARRAY:
    return extend<PackedInt32Array>(src, samples, vertices);
  default:
    return src;
  }
}
} // namespace
uint64_t FPSDestruction::key(int x, int z) {
  return (uint64_t(uint32_t(x)) << 32) | uint32_t(z);
}
void FPSDestruction::configure(const Array &cell_rows,
                               const Dictionary &wall_rows,
                               const Array &building_rows,
                               const Dictionary &cell_building,
                               const Dictionary &wall_building,
                               const Dictionary &topology,
                               const Dictionary &building_topology) {
  cells.clear();
  walls.clear();
  wall_order.clear();
  buildings.clear();
  bins.clear();
  baked = !topology.is_empty();
  building_baked = !building_topology.is_empty();
  for (int i = 0; i < cell_rows.size(); ++i) {
    Dictionary r = cell_rows[i];
    Cell c{r["center"], r["size"], r["position"],
           r["wall"],   r["kind"], cell_building.get(i, -1)};
    cells.push_back(c);
    bins[key(int(std::floor(c.position.x / 16)),
             int(std::floor(c.position.z / 16)))]
        .push_back(i);
  }
  Array keys = wall_rows.keys();
  for (int i = 0; i < keys.size(); ++i) {
    int id = keys[i];
    Dictionary r = wall_rows[id];
    Wall w;
    w.center = r["center"];
    w.size = r["size"];
    w.kind = r["kind"];
    w.building = wall_building.get(id, -1);
    w.cells = integers(r["cells"]);
    Dictionary t = topology.get(id, Dictionary());
    for (int lod = 0; lod < 2; ++lod) {
      Dictionary d = t.get(lod, Dictionary());
      w.triangles[lod] = integers(d.get("triangles", PackedInt32Array()));
      w.samples[lod] = integers(d.get("vertices", PackedInt32Array()));
    }
    walls[id] = std::move(w);
    wall_order.push_back(id);
  }
  for (int i = 0; i < building_rows.size(); ++i) {
    Dictionary r = building_rows[i];
    Building b;
    b.kind = r["kind"];
    b.center = r["center"];
    b.bounds = r["bounds"];
    Array attachments = r["attachments"];
    for (int j = 0; j < attachments.size(); ++j)
      b.attachments.push_back(attachments[j]);
    Array stories = r["stories"];
    for (int f = 0; f < stories.size(); ++f) {
      std::vector<Column> columns;
      Array cols = stories[f];
      for (int j = 0; j < cols.size(); ++j) {
        Dictionary c = cols[j];
        columns.push_back({c["side"], c["weight"], integers(c["cells"])});
      }
      b.stories.push_back(std::move(columns));
    }
    Dictionary t = building_topology.get(i, Dictionary());
    for (int lod = 0; lod < 2; ++lod)
      b.triangles[lod] = integers(t.get(lod, PackedInt32Array()));
    buildings.push_back(std::move(b));
  }
}
PackedInt32Array
FPSDestruction::candidates(Vector3 at, double damage, double radius,
                           const PackedInt32Array &broken,
                           const PackedInt32Array &collapsed) const {
  PackedInt32Array out;
  if (damage < 60 || !at.is_finite() || !std::isfinite(radius) || radius <= 0)
    return out;
  auto gone = make_set(broken), fallen = make_set(collapsed);
  double reach = std::clamp(radius * .18, .75, 4.5);
  std::vector<std::pair<double, int>> near;
  int cx = int(std::floor(at.x / 16)), cz = int(std::floor(at.z / 16));
  for (int z = cz - 1; z <= cz + 1; ++z)
    for (int x = cx - 1; x <= cx + 1; ++x) {
      auto bin = bins.find(key(x, z));
      if (bin == bins.end())
        continue;
      for (int id : bin->second) {
        auto &c = cells[id];
        if (gone.count(id) || fallen.count(c.building) ||
            (!buildings.empty() && c.building < 0))
          continue;
        Vector3 nearest =
            at.clamp(c.position - c.size * .5, c.position + c.size * .5);
        double d = at.distance_to(nearest);
        if (d <= reach)
          near.push_back({d, id});
      }
    }
  // Approximate equality is not transitive. Use bounded insertion ordering,
  // rather than passing that relation to an STL sort requiring a strict order.
  auto before = [](auto a, auto b) {
    return Math::is_equal_approx(a.first, b.first) ? a.second < b.second
                                                   : a.first < b.first;
  };
  for (size_t i = 1; i < near.size(); ++i) {
    auto row = near[i];
    size_t j = i;
    while (j > 0 && before(row, near[j - 1])) {
      near[j] = near[j - 1];
      --j;
    }
    near[j] = row;
  }
  for (auto row : near)
    out.push_back(row.second);
  return out;
}
Dictionary FPSDestruction::status(int id,
                                  const PackedInt32Array &broken) const {
  Dictionary result;
  if (id < 0 || id >= int(buildings.size()))
    return result;
  auto gone = make_set(broken);
  auto &building = buildings[id];
  Array floors;
  int failed_floor = -1;
  double lowest = 1;
  for (size_t f = 0; f < building.stories.size(); ++f) {
    double total = 0, intact = 0, side_total[4] = {}, side_intact[4] = {};
    for (auto &c : building.stories[f]) {
      bool alive = true;
      for (int cell : c.cells)
        if (gone.count(cell)) {
          alive = false;
          break;
        }
      total += c.weight;
      side_total[c.side] += c.weight;
      if (alive) {
        intact += c.weight;
        side_intact[c.side] += c.weight;
      }
    }
    double ratio = total > 0 ? intact / total : 1;
    Array sides;
    for (int i = 0; i < 4; ++i)
      sides.append(side_total[i] > 0 ? side_intact[i] / side_total[i] : 1.);
    bool failed = ratio < .45;
    for (int a = 0; a < 2; ++a)
      for (int b = 2; b < 4; ++b)
        if (double(sides[a]) < .2 && double(sides[b]) < .2)
          failed = true;
    lowest = std::min(lowest, ratio);
    Dictionary row;
    row["remaining"] = ratio;
    row["sides"] = sides;
    row["failed"] = failed;
    floors.append(row);
    if (failed && failed_floor < 0)
      failed_floor = f;
  }
  result["remaining"] = lowest;
  result["failed_floor"] = failed_floor;
  result["stories"] = floors;
  return result;
}
Array FPSDestruction::patch(const Array &source, int kind, int lod,
                            const PackedInt32Array &broken,
                            const PackedInt32Array &collapsed) const {
  if (source.size() != 13 || lod < 0 || lod > 1)
    return {};
  Array out = source.duplicate();
  PackedVector3Array points = source[0];
  PackedInt32Array indices = source[12], kept;
  auto gone = make_set(broken), fallen = make_set(collapsed);
  std::unordered_set<int> removed;
  std::unordered_map<int, std::vector<int>> samples;
  std::vector<int> replacements;
  for (int id : wall_order) {
    auto &w = walls.at(id);
    if (w.kind != kind || fallen.count(w.building))
      continue;
    bool broken_wall = false;
    for (int cell : w.cells)
      if (gone.count(cell)) {
        broken_wall = true;
        break;
      }
    if (!broken_wall)
      continue;
    replacements.push_back(id);
    if (baked) {
      for (int i : w.triangles[lod])
        removed.insert(i);
      if (!w.samples[lod].empty())
        samples[id] = w.samples[lod];
    }
  }
  if (!baked)
    for (int i = 0; i + 2 < indices.size(); i += 3)
      for (int id : replacements) {
        auto &w = walls.at(id);
        AABB bounds(w.center - w.size * .5, w.size);
        bounds = bounds.grow(.002);
        if (bounds.has_point(points[indices[i]]) &&
            bounds.has_point(points[indices[i + 1]]) &&
            bounds.has_point(points[indices[i + 2]])) {
          auto &s = samples[id];
          for (int j = 0; j < 3; ++j)
            if (std::find(s.begin(), s.end(), indices[i + j]) == s.end())
              s.push_back(indices[i + j]);
          removed.insert(i);
          break;
        }
      }
  for (int id : fallen) {
    if (id < 0 || id >= int(buildings.size()))
      continue;
    auto &b = buildings[id];
    if (b.kind != kind)
      continue;
    if (building_baked) {
      for (int i : b.triangles[lod])
        removed.insert(i);
    } else
      for (int i = 0; i + 2 < indices.size(); i += 3) {
        bool upper = false;
        for (int j = 0; j < 3; ++j)
          upper |= points[indices[i + j]].y > b.center.y + .2;
        if (!upper)
          continue;
        auto inside = [&](AABB bounds) {
          return bounds.has_point(points[indices[i]]) &&
                 bounds.has_point(points[indices[i + 1]]) &&
                 bounds.has_point(points[indices[i + 2]]);
        };
        bool matches = inside(b.bounds);
        for (auto bounds : b.attachments)
          matches |= inside(bounds);
        if (matches)
          removed.insert(i);
      }
  }
  kept.resize(indices.size());
  int used = 0;
  for (int i = 0; i + 2 < indices.size(); i += 3)
    if (!removed.count(i))
      for (int j = 0; j < 3; ++j)
        kept[used++] = indices[i + j];
  kept.resize(used);
  PackedVector3Array vertices = points;
  std::vector<int> copied;
  const int faces[][4] = {{0, 2, 3, 1}, {4, 5, 7, 6}, {2, 6, 7, 3},
                          {0, 1, 5, 4}, {0, 4, 6, 2}, {1, 3, 7, 5}};
  for (int id : replacements) {
    auto found = samples.find(id);
    if (found == samples.end() || found->second.empty())
      continue;
    auto &w = walls.at(id);
    for (int cell : w.cells) {
      if (gone.count(cell))
        continue;
      auto &c = cells[cell];
      Vector3 corners[8];
      for (int i = 0; i < 8; ++i)
        corners[i] = c.center + Vector3(i & 1 ? .5 : -.5, i & 2 ? .5 : -.5,
                                        i & 4 ? .5 : -.5) *
                                    c.size;
      for (auto &face : faces) {
        int offset = vertices.size();
        for (int j : face) {
          Vector3 v = corners[j];
          int nearest = found->second[0];
          double distance = INFINITY;
          for (int sample : found->second) {
            double d = points[sample].distance_squared_to(v);
            if (d < distance) {
              distance = d;
              nearest = sample;
            }
          }
          vertices.push_back(v);
          copied.push_back(nearest);
        }
        for (int j : {0, 1, 2, 0, 2, 3})
          kept.push_back(offset + j);
      }
    }
  }
  out[0] = vertices;
  for (int channel = 1; channel < 12; ++channel)
    out[channel] = extend_channel(source[channel], copied, points.size());
  out[12] = kept;
  return out;
}
void FPSDestruction::_bind_methods() {
  ClassDB::bind_method(D_METHOD("configure", "cells", "walls", "buildings",
                                "cell_building", "wall_building", "topology",
                                "building_topology"),
                       &FPSDestruction::configure);
  ClassDB::bind_method(D_METHOD("candidates", "position", "damage", "radius",
                                "broken", "collapsed"),
                       &FPSDestruction::candidates);
  ClassDB::bind_method(D_METHOD("status", "building", "broken"),
                       &FPSDestruction::status);
  ClassDB::bind_method(
      D_METHOD("patch", "source", "kind", "lod", "broken", "collapsed"),
      &FPSDestruction::patch);
}
