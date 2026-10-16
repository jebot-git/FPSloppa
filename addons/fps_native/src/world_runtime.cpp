#include "world_runtime.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/plane.hpp>
#include <limits>
#include <unordered_set>
using namespace godot;
namespace {
constexpr int caps[] = {600, 400, 600, 84, 56, 84, 42, 28, 42, 42, 28, 42};
double unit(double v) { return v - std::floor(v); }
bool outside(AABB b, const Array &planes) {
  Vector3 center = b.get_center(), half = b.size * .5;
  for (int i = 0; i < planes.size(); ++i) {
    Plane p = planes[i];
    if (p.distance_to(center) > p.normal.abs().dot(half))
      return true;
  }
  return false;
}
void write_transform(float *dst, const Transform3D &t) {
  for (int r = 0; r < 3; ++r) {
    for (int c = 0; c < 3; ++c)
      dst[r * 4 + c] = t.basis.get_column(c)[r];
    dst[r * 4 + 3] = t.origin[r];
  }
}
PackedFloat32Array buffer(int count, int stride = 12) {
  PackedFloat32Array b;
  b.resize(count * stride);
  b.fill(0);
  return b;
}
} // namespace
uint64_t FPSWorld::key(Vector2i p) {
  return (uint64_t(uint32_t(p.x)) << 32) | uint32_t(p.y);
}
Vector2i FPSWorld::bin(double x, double z) const {
  return {int(std::floor((x + extent * .5) / tile)),
          int(std::floor((z + extent * .5) / tile))};
}
void FPSWorld::grass_load(Vector2i coord, const PackedVector4Array &rows,
                          const PackedByteArray &kinds, AABB bounds) {
  if (rows.size() != kinds.size())
    return;
  GrassTile t;
  t.bounds = bounds;
  t.rows.reserve(rows.size());
  for (int i = 0; i < rows.size(); ++i) {
    Vector4 r = rows[i];
    if (kinds[i] > 3)
      continue;
    t.audio_cells[key({int(std::floor(r.x / 2)), int(std::floor(r.z / 2))})]
        .push_back({r.x, r.y, r.z});
    double scale =
        .90 + .20 * (.5 + .5 * std::sin(double(r.x) * 3.1 + double(r.z) * 2.7));
    t.rows.push_back(
        {{r.x, r.y, r.z},
         Basis(Vector3(0, 1, 0), r.w).scaled(Vector3(scale, scale, scale)),
         unit(std::sin(double(r.x) * 39.3 + double(r.z) * 7.1) * 12345.67),
         int(unit(std::sin(double(r.x) * 11.71 + double(r.z) * 47.37) *
                  19873.11) *
             2147483647.),
         int(kinds[i])});
  }
  grass[key(coord)] = std::move(t);
}
void FPSWorld::grass_evict(Vector2i coord) { grass.erase(key(coord)); }
Dictionary FPSWorld::grass_select(Vector3 position, double distance,
                                  double tile_side, double world_extent) {
  distance = std::clamp(distance, 24., 160.);
  int limit = int(std::ceil(distance));
  for (auto &b : buckets)
    b.clear();
  int candidates = 0;
  Vector2i center(
      int(std::floor((position.x + world_extent * .5) / tile_side)),
      int(std::floor((position.z + world_extent * .5) / tile_side)));
  int radius = int(std::ceil((distance + 2) / tile_side));
  double d2 = distance * distance;
  for (int z = center.y - radius; z <= center.y + radius; ++z)
    for (int x = center.x - radius; x <= center.x + radius; ++x) {
      auto it = grass.find(key({x, z}));
      if (it == grass.end())
        continue;
      auto &t = it->second;
      if (position.clamp(t.bounds.position, t.bounds.get_end())
              .distance_squared_to(position) > d2)
        continue;
      for (auto &r : t.rows) {
        if (std::abs(position.y - r.p.y) > 8)
          continue;
        double sq = position.distance_squared_to(r.p);
        if (sq >= d2)
          continue;
        ++candidates;
        buckets[int(std::sqrt(sq)) * 4 + r.kind].push_back(&r);
      }
    }
  Array buffers;
  PackedInt32Array counts;
  counts.resize(12);
  int visible = 0;
  double maximum = 0;
  for (int group = 0; group < 12; ++group) {
    int kind = group / 3, lod = group % 3,
        start = lod == 0   ? 0
                : lod == 1 ? 16
                           : 36,
        end = std::min(limit, lod == 0   ? 16
                              : lod == 1 ? 36
                                         : limit);
    std::vector<const GrassRow *> selected;
    selected.reserve(caps[group]);
    far_rows.clear();
    uint32_t ordinal = 0;
    for (int d = start; d < end; ++d)
      for (auto *r : buckets[d * 4 + kind]) {
        if (lod == 2) {
          if (r->thinning > std::pow(36. / std::max(d, 36), 2))
            continue;
          far_rows.push_back(
              {(uint64_t(uint32_t(r->priority)) << 32) | ordinal++, r});
        } else if (int(selected.size()) < caps[group])
          selected.push_back(r);
      }
    if (lod == 2) {
      size_t n = std::min(far_rows.size(), size_t(caps[group]));
      std::partial_sort(
          far_rows.begin(), far_rows.begin() + n, far_rows.end(),
          [](const auto &a, const auto &b) { return a.first < b.first; });
      for (size_t i = 0; i < n; ++i)
        selected.push_back(far_rows[i].second);
    }
    auto b = buffer(caps[group]);
    float *dst = b.ptrw();
    for (auto *r : selected) {
      double d = position.distance_to(r->p),
             u = std::clamp((d - (distance - 8)) / 8, 0., 1.);
      Basis basis = r->basis;
      basis.set_column(1, basis.get_column(1) * (1 - u * u * (3 - 2 * u)));
      write_transform(dst + counts[group] * 12, {basis, r->p});
      ++counts[group];
      ++visible;
      maximum = std::max(maximum, d);
    }
    buffers.append(b);
  }
  Dictionary result;
  result["buffers"] = buffers;
  result["counts"] = counts;
  result["candidates"] = candidates;
  result["visible"] = visible;
  result["maximum"] = maximum;
  return result;
}
void FPSWorld::trees_load(Vector2i coord, const Array &rows, AABB bounds,
                          const Array &mesh_bounds) {
  auto k = key(coord);
  if (!trees.count(k))
    tree_order.push_back(k);
  TreeTile t;
  t.bounds = bounds;
  t.rows.reserve(rows.size());
  for (int i = 0; i < rows.size(); ++i) {
    Dictionary r = rows[i];
    int kind = r["kind"];
    if (kind < 0 || kind >= mesh_bounds.size())
      continue;
    Transform3D transform(Basis(Vector3(0, 1, 0), double(r["angle"]))
                              .scaled(Vector3(1, 1, 1) * double(r["scale"])),
                          r["position"]);
    t.rows.push_back({transform, transform.xform(AABB(mesh_bounds[kind])), kind,
                      int(r.get("lod", 2))});
  }
  trees[k] = std::move(t);
}
void FPSWorld::trees_evict(Vector2i coord) {
  auto k = key(coord);
  trees.erase(k);
  tree_order.erase(std::remove(tree_order.begin(), tree_order.end(), k),
                   tree_order.end());
}
Dictionary FPSWorld::trees_select(Vector3 position, const Array &planes,
                                  bool culling, bool force_near, int capacity,
                                  double distance,
                                  const PackedInt32Array &allocated) {
  capacity = std::clamp(capacity, 1, 16384);
  std::array<std::vector<const Transform3D *>, 9> selected;
  PackedInt32Array counts;
  counts.resize(9);
  counts.fill(0);
  for (auto k : tree_order) {
    auto &t = trees.at(k);
    if (culling && outside(t.bounds, planes))
      continue;
    for (auto &r : t.rows) {
      Vector3 delta = position - r.transform.origin;
      if (double(delta.x) * delta.x + double(delta.z) * delta.z >
          distance * distance)
        continue;
      if (culling && outside(r.bounds, planes))
        continue;
      double d = delta.length();
      if (force_near || d < 42)
        r.lod = 0;
      else if (d > 130)
        r.lod = 2;
      else if (r.lod == 0 && d > 55)
        r.lod = 1;
      else if (r.lod == 2 && d < 110)
        r.lod = 1;
      int group = r.kind * 3 + r.lod;
      if (counts[group] >= capacity)
        continue;
      selected[group].push_back(&r.transform);
      ++counts[group];
    }
  }
  Array buffers;
  PackedInt32Array capacities;
  capacities.resize(9);
  for (int group = 0; group < 9; ++group) {
    int size = allocated.size() == 9
                   ? std::clamp(int(allocated[group]), 1, capacity)
                   : std::min(64, capacity);
    while (size < counts[group])
      size = std::min(capacity, size * 2);
    capacities[group] = size;
    auto b = buffer(size);
    auto *dst = b.ptrw();
    for (size_t i = 0; i < selected[group].size(); ++i)
      write_transform(dst + i * 12, *selected[group][i]);
    buffers.append(b);
  }
  Dictionary result;
  result["buffers"] = buffers;
  result["counts"] = counts;
  result["capacities"] = capacities;
  return result;
}
Dictionary FPSWorld::terrain_select(const Array &coords, const Array &bounds,
                                    const PackedInt32Array &slots,
                                    Vector3 position, const Array &planes,
                                    bool culling, bool force_fine,
                                    double tile_side, double world_extent,
                                    int capacity) {
  capacity = std::clamp(capacity, 1, 16384);
  std::array<PackedFloat32Array, 4> data;
  std::array<float *, 4> ptr;
  for (int i = 0; i < 4; ++i) {
    data[i] = buffer(capacity, 16);
    ptr[i] = data[i].ptrw();
  }
  PackedInt32Array counts;
  counts.resize(4);
  counts.fill(0);
  if (coords.size() == bounds.size() && coords.size() == slots.size())
    for (int i = 0; i < coords.size(); ++i) {
      if (culling && outside(bounds[i], planes))
        continue;
      Vector2i k = coords[i];
      Vector3 origin(k.x * tile_side - world_extent * .5, 0,
                     k.y * tile_side - world_extent * .5);
      Vector3 nearest(
          std::clamp(position.x, origin.x, real_t(origin.x + tile_side)),
          position.y,
          std::clamp(position.z, origin.z, real_t(origin.z + tile_side)));
      double d = position.distance_to(nearest);
      int group = force_fine || d < 48 ? 0 : d < 112 ? 1 : d < 208 ? 2 : 3;
      if (counts[group] >= capacity)
        continue;
      float *dst = ptr[group] + counts[group] * 16;
      write_transform(dst, {Basis(), origin});
      dst[12] = slots[i];
      ++counts[group];
    }
  Array buffers;
  for (auto &b : data)
    buffers.append(b);
  Dictionary result;
  result["buffers"] = buffers;
  result["counts"] = counts;
  return result;
}
Dictionary FPSWorld::terrain_plan(Vector3 position, const Array &resident,
                                  const Array &running, double tile_side,
                                  double world_extent, int grid,
                                  bool analytic) const {
  Dictionary result;
  Array desired, queue, evict;
  int candidates = 0;
  std::unordered_set<uint64_t> have, pending;
  for (int i = 0; i < resident.size(); ++i)
    have.insert(key(resident[i]));
  for (int i = 0; i < running.size(); ++i)
    pending.insert(key(running[i]));
  Vector2i cell(int(std::floor((position.x + world_extent * .5) / tile_side)),
                int(std::floor((position.z + world_extent * .5) / tile_side)));
  int span = int(std::ceil((256 + tile_side * .7072) / tile_side));
  std::vector<std::pair<double, Vector2i>> ordered;
  auto distance = [&](Vector2i k) {
    double dx = (k.x + .5) * tile_side - world_extent * .5 - position.x,
           dz = (k.y + .5) * tile_side - world_extent * .5 - position.z;
    return dx * dx + dz * dz;
  };
  for (int z = std::max(0, cell.y - span);
       z < std::min(grid, cell.y + span + 1); ++z)
    for (int x = std::max(0, cell.x - span);
         x < std::min(grid, cell.x + span + 1); ++x) {
      ++candidates;
      Vector2i k(x, z);
      double d = distance(k);
      if (d > std::pow(256 + tile_side * .7072, 2))
        continue;
      desired.append(k);
      if (!analytic && !have.count(key(k)) && !pending.count(key(k)))
        ordered.push_back({d, k});
    }
  std::stable_sort(ordered.begin(), ordered.end(),
                   [](auto a, auto b) { return a.first < b.first; });
  for (auto &row : ordered)
    queue.append(row.second);
  for (int i = 0; i < resident.size(); ++i)
    if (distance(resident[i]) > std::pow(320 + tile_side * .7072, 2))
      evict.append(resident[i]);
  result["desired"] = desired;
  result["queue"] = queue;
  result["evict"] = evict;
  result["candidates"] = candidates;
  return result;
}
bool FPSWorld::grass_contains(Vector3 point, double tile_side,
                              double world_extent) const {
  if (tile_side <= 0)
    return false;
  Vector2i center(int(std::floor((point.x + world_extent * .5) / tile_side)),
                  int(std::floor((point.z + world_extent * .5) / tile_side)));
  int cx = int(std::floor(point.x / 2)), cz = int(std::floor(point.z / 2));
  for (int z = center.y - 1; z <= center.y + 1; ++z)
    for (int x = center.x - 1; x <= center.x + 1; ++x) {
      auto tile = grass.find(key({x, z}));
      if (tile == grass.end())
        continue;
      for (int az = cz - 1; az <= cz + 1; ++az)
        for (int ax = cx - 1; ax <= cx + 1; ++ax) {
          auto cell = tile->second.audio_cells.find(key({ax, az}));
          if (cell == tile->second.audio_cells.end())
            continue;
          for (auto row : cell->second)
            if (std::abs(point.y - row.y) < 1.5 &&
                Vector2(point.x - row.x, point.z - row.z).length_squared() <
                    1.21)
              return true;
        }
    }
  return false;
}
void FPSWorld::buildings_configure(const Array &sites, const Array &bounds,
                                   const Array &triangles,
                                   double factory_offset) {
  buildings.clear();
  building_triangles.clear();
  building_triangles.resize(triangles.size());
  for (int i = 0; i < triangles.size(); ++i) {
    Array levels = triangles[i];
    for (int j = 0; j < levels.size(); ++j)
      building_triangles[i].push_back(int(levels[j]));
  }
  for (int i = 0; i < sites.size(); ++i) {
    Dictionary site = sites[i];
    int kind = site.get("kind", -1);
    if (kind < 0 || kind >= bounds.size() ||
        kind >= int(building_triangles.size()) ||
        building_triangles[kind].size() != 3)
      continue;
    Vector3 origin = site["position"];
    if (kind == 1)
      origin.y -= factory_offset;
    AABB b = bounds[kind];
    b.position += origin;
    buildings.push_back({origin, b, kind, 2});
  }
}
void FPSWorld::buildings_refresh(const Array &bounds, const Array &triangles) {
  if (triangles.size() != int(building_triangles.size()) ||
      bounds.size() != triangles.size())
    return;
  for (int i = 0; i < triangles.size(); ++i) {
    Array levels = triangles[i];
    if (levels.size() != 3)
      return;
    for (int lod = 0; lod < 3; ++lod)
      building_triangles[i][lod] = levels[lod];
  }
  for (auto &site : buildings) {
    site.bounds = bounds[site.kind];
    site.bounds.position += site.origin;
  }
}
void FPSWorld::buildings_reset_lods() {
  for (auto &site : buildings)
    site.lod = 2;
}
Dictionary FPSWorld::buildings_select(Vector3 position, const Array &planes,
                                      bool culling, bool force_near,
                                      double distance) {
  std::vector<std::vector<Transform3D>> selected(building_triangles.size() * 3);
  int visible = 0, triangles = 0;
  for (auto &site : buildings) {
    double d = position.distance_to(
        position.clamp(site.bounds.position, site.bounds.get_end()));
    if (d > distance || (culling && outside(site.bounds, planes)))
      continue;
    if (force_near || d < 65)
      site.lod = 0;
    else if (d > 180)
      site.lod = 2;
    else if (site.lod == 0 && d > 85)
      site.lod = 1;
    else if (site.lod == 2 && d < 150)
      site.lod = 1;
    selected[site.kind * 3 + site.lod].push_back(
        Transform3D(Basis(), site.origin));
    ++visible;
    triangles += building_triangles[site.kind][site.lod];
  }
  Array buffers, counts;
  for (size_t kind = 0; kind < building_triangles.size(); ++kind) {
    Array bs, cs;
    for (int lod = 0; lod < 3; ++lod) {
      auto &rows = selected[kind * 3 + lod];
      auto packed = buffer(buildings.size());
      auto *dst = packed.ptrw();
      for (size_t i = 0; i < rows.size(); ++i)
        write_transform(dst + i * 12, rows[i]);
      bs.append(packed);
      cs.append(int(rows.size()));
    }
    buffers.append(bs);
    counts.append(cs);
  }
  Dictionary result;
  result["buffers"] = buffers;
  result["counts"] = counts;
  result["visible_sites"] = visible;
  result["triangles"] = triangles;
  return result;
}
void FPSWorld::_bind_methods() {
  ClassDB::bind_method(
      D_METHOD("grass_contains", "point", "tile_side", "world_extent"),
      &FPSWorld::grass_contains);
  ClassDB::bind_method(D_METHOD("buildings_configure", "sites", "bounds",
                                "triangles", "factory_offset"),
                       &FPSWorld::buildings_configure);
  ClassDB::bind_method(D_METHOD("buildings_refresh", "bounds", "triangles"),
                       &FPSWorld::buildings_refresh);
  ClassDB::bind_method(D_METHOD("buildings_reset_lods"),
                       &FPSWorld::buildings_reset_lods);
  ClassDB::bind_method(D_METHOD("buildings_select", "position", "planes",
                                "culling", "force_near", "distance"),
                       &FPSWorld::buildings_select);
  ClassDB::bind_method(D_METHOD("vegetation_trees", "coord"),
                       &FPSWorld::vegetation_trees);
  ClassDB::bind_method(D_METHOD("vegetation_grass", "coord", "heights"),
                       &FPSWorld::vegetation_grass);

  ClassDB::bind_method(
      D_METHOD("grass_load", "coord", "rows", "kinds", "bounds"),
      &FPSWorld::grass_load);
  ClassDB::bind_method(D_METHOD("grass_evict", "coord"),
                       &FPSWorld::grass_evict);
  ClassDB::bind_method(
      D_METHOD("grass_select", "position", "distance", "tile_side", "extent"),
      &FPSWorld::grass_select);
  ClassDB::bind_method(
      D_METHOD("trees_load", "coord", "rows", "bounds", "mesh_bounds"),
      &FPSWorld::trees_load);
  ClassDB::bind_method(D_METHOD("trees_evict", "coord"),
                       &FPSWorld::trees_evict);
  ClassDB::bind_method(D_METHOD("trees_select", "position", "planes", "culling",
                                "force_near", "capacity", "distance",
                                "allocated"),
                       &FPSWorld::trees_select, DEFVAL(PackedInt32Array()));
  ClassDB::bind_method(D_METHOD("terrain_select", "coords", "bounds", "slots",
                                "position", "planes", "culling", "force_fine",
                                "tile_side", "extent", "capacity"),
                       &FPSWorld::terrain_select);
  ClassDB::bind_method(D_METHOD("terrain_plan", "position", "resident",
                                "running", "tile_side", "extent", "grid",
                                "analytic"),
                       &FPSWorld::terrain_plan);
  ClassDB::bind_method(D_METHOD("terrain_configure", "config"),
                       &FPSWorld::terrain_configure);
  ClassDB::bind_method(D_METHOD("terrain_tile", "coord"),
                       &FPSWorld::terrain_tile);
  ClassDB::bind_method(D_METHOD("terrain_samples", "coord", "samples"),
                       &FPSWorld::terrain_samples);
  ClassDB::bind_method(D_METHOD("terrain_surface", "x", "z"),
                       &FPSWorld::terrain_surface);
}
