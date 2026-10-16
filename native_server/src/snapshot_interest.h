#pragma once
#include "common.h"
#include <set>
namespace cqserver {
// Parse/validate the authority frame once, then reuse row locations for every peer.
struct SnapshotView {
 struct Player{int64_t id;V position;int weapon;};
 struct Row{size_t at,size;int player,weapon;};
 struct Section{uint16_t type;size_t at,end;std::vector<Row>rows;};
 const std::vector<uint8_t>&source;size_t head=0;std::vector<Player>players;std::vector<Section>sections;
 explicit SnapshotView(const std::vector<uint8_t>&);
};
struct SnapshotInterest {
 std::set<int64_t>near;
 // Retain coarse roster/tactical/long-range combat state. Only expensive avatar
 // and reload detail is filtered, with hysteresis at the distance boundary.
 std::vector<uint8_t>filter(const SnapshotView&,int64_t viewer);
};
}
