#pragma once
#include "common.h"
#include <unordered_map>
namespace cqserver {
class Navigation {
 struct Point {float x,y,z;operator V()const{return {x,y,z};}};
 struct Poly {uint32_t first=0;uint16_t count=0;V center;};
 std::vector<Point>vertices_;
 std::vector<Poly>polygons_;
 std::vector<uint32_t>indices_;
 std::vector<std::vector<uint32_t>>adjacency_;
 std::unordered_map<uint64_t,std::vector<uint32_t>>bins_;
 std::vector<V>road_points_;
 std::vector<std::vector<uint32_t>>road_edges_;
 uint32_t nearest(V,double,V*)const;
 std::vector<V>local(V,V);
 void roads(const Json&);
public:
 uint64_t queries=0,failed=0,expanded=0,ambiguous_edges=0;
 Navigation(const std::filesystem::path&,const Json&,const Json&);
 std::vector<V>path(V,V);
 size_t polygon_count()const{return polygons_.size();}
};
}
