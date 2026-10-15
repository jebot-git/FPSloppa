#pragma once
#include "authority_math.h"
#include <cstdint>
#include <unordered_map>
#include <vector>
namespace cqauthority {
struct TerrainRoad {
  V a, b;
  double width = 1;
};
struct TerrainPad {
  V center;
  double radius = 1;
};
struct River {
  V a, b;
  double width = 1, depth = 1;
};
class Terrain {
public:
  bool configured = false;
  double extent = 2828.4271247461903, tile = 2828.4271247461903 / 89;
  V port;
  std::unordered_map<uint64_t, std::vector<TerrainRoad>> main, access;
  std::vector<TerrainPad> pads;
  std::vector<River> rivers;
  static uint64_t key(int32_t x, int32_t z) {
    return (uint64_t(uint32_t(x)) << 32) | uint32_t(z);
  }
  V water_sample(double x, double z) const;
  bool road(V position) const;
};
} // namespace cqauthority
