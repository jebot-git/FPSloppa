#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector4_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <unordered_map>
#include <vector>
namespace godot {
class FPSWorld : public RefCounted {
  GDCLASS(FPSWorld, RefCounted)
  struct GrassRow {
    Vector3 p;
    Basis basis;
    double thinning;
    int priority, kind;
  };
  struct GrassTile {
    AABB bounds;
    std::vector<GrassRow> rows;
    std::unordered_map<uint64_t, std::vector<Vector3>> audio_cells;
  };
  struct Tree {
    Transform3D transform;
    AABB bounds;
    int kind, lod = 2;
  };
  struct TreeTile {
    AABB bounds;
    std::vector<Tree> rows;
  };
  std::unordered_map<uint64_t, GrassTile> grass;
  std::unordered_map<uint64_t, TreeTile> trees;
  std::vector<uint64_t> tree_order;
  std::vector<const GrassRow *> buckets[640];
  std::vector<std::pair<uint64_t, const GrassRow *>> far_rows;
  struct Road {
    double ax, az, ay, bx, bz, by, width, along, earthwork;
  };
  std::unordered_map<uint64_t, std::vector<Road>> roads, access, earthworks,
      rivers;
  std::vector<Vector4> pads, rocks, cover;
  double extent = 2828.4271247461903, tile = 2828.4271247461903 / 89;
  bool terrain_ready = false;
  static uint64_t key(Vector2i p);
  Vector2i bin(double x, double z) const;
  double natural(double x, double z) const;
  double rock_mask(double x, double z) const;
  Vector3 water(double x, double z) const;
  Vector4 surface(double x, double z) const;

  struct Building {
    Vector3 origin;
    AABB bounds;
    int kind, lod = 2;
  };
  std::vector<Building> buildings;
  std::vector<std::vector<int>> building_triangles;

protected:
  static void _bind_methods();

public:
  static Dictionary weather_sample(int64_t seed,double seconds);
  static Dictionary weather_lightning(int64_t seed,double seconds);
  void grass_load(Vector2i coord, const PackedVector4Array &rows,
                  const PackedByteArray &kinds, AABB bounds);
  void grass_evict(Vector2i coord);
  bool grass_contains(Vector3 point, double tile_side,
                      double world_extent) const;
  void buildings_configure(const Array &sites, const Array &bounds,
                           const Array &triangles, double factory_offset);
  void buildings_refresh(const Array &bounds, const Array &triangles);
  void buildings_reset_lods();
  Dictionary buildings_select(Vector3 position, const Array &planes,
                              bool culling, bool force_near, double distance);
  Array vegetation_trees(Vector2i coord) const;
  PackedVector4Array vegetation_grass(Vector2i coord,
                                      const PackedFloat32Array &heights) const;
  bool planting_allowed(Vector2 point) const;

  Dictionary grass_select(Vector3 position, double distance, double tile_side,
                          double world_extent);
  void trees_load(Vector2i coord, const Array &rows, AABB bounds,
                  const Array &mesh_bounds);
  void trees_evict(Vector2i coord);
  Dictionary trees_select(Vector3 position, const Array &planes, bool culling,
                          bool force_near, int capacity, double distance,
                          const PackedInt32Array &allocated);
  Dictionary terrain_select(const Array &coords, const Array &bounds,
                            const PackedInt32Array &slots, Vector3 position,
                            const Array &planes, bool culling, bool force_fine,
                            double tile_side, double world_extent,
                            int capacity);
  Dictionary terrain_plan(Vector3 position, const Array &resident,
                          const Array &running, double tile_side,
                          double world_extent, int grid, bool analytic) const;
  void terrain_configure(const Dictionary &config);
  Dictionary terrain_tile(Vector2i coord) const;
  PackedVector4Array terrain_samples(Vector2i coord, int samples) const;
  Vector4 terrain_surface(double x, double z) const { return surface(x, z); }
};
} // namespace godot
