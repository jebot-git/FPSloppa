#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <unordered_map>
#include <vector>
namespace godot {
class FPSDestruction : public RefCounted {
  GDCLASS(FPSDestruction, RefCounted)
  struct Cell {
    Vector3 center, size, position;
    int wall, kind, building = -1;
  };
  struct Wall {
    Vector3 center, size;
    int kind, building = -1;
    std::vector<int> cells;
    std::vector<int> triangles[2], samples[2];
  };
  struct Column {
    int side;
    double weight;
    std::vector<int> cells;
  };
  struct Building {
    int kind;
    Vector3 center;
    AABB bounds;
    std::vector<AABB> attachments;
    std::vector<std::vector<Column>> stories;
    std::vector<int> triangles[2];
  };
  std::vector<Cell> cells;
  std::unordered_map<int, Wall> walls;
  std::vector<int> wall_order;
  std::vector<Building> buildings;
  std::unordered_map<uint64_t, std::vector<int>> bins;
  bool baked = false, building_baked = false;
  static uint64_t key(int x, int z);

protected:
  static void _bind_methods();

public:
  void configure(const Array &cell_rows, const Dictionary &wall_rows,
                 const Array &building_rows, const Dictionary &cell_building,
                 const Dictionary &wall_building, const Dictionary &topology,
                 const Dictionary &building_topology);
  PackedInt32Array candidates(Vector3 position, double damage, double radius,
                              const PackedInt32Array &broken,
                              const PackedInt32Array &collapsed) const;
  Dictionary status(int id, const PackedInt32Array &broken) const;
  Array patch(const Array &source, int kind, int lod,
              const PackedInt32Array &broken,
              const PackedInt32Array &collapsed) const;
};
} // namespace godot
