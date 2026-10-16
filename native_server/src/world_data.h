#pragma once
#include "common.h"
namespace cqserver {
struct WorldData {
 std::filesystem::path directory;
 Json metadata;
 std::vector<uint8_t> geometry;
 explicit WorldData(const std::filesystem::path&);
 std::vector<float> floats(const Json &descriptor)const;
 cqauthority::Terrain terrain()const;
};
}
