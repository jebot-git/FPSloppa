#pragma once
#include "common.h"
#include <list>
#include <unordered_map>
namespace cqserver {
class Surface {
 struct Road {V a,b;double width,earthwork;};
 using Bins=std::unordered_map<uint64_t,std::vector<Road>>;
 Bins roads_,earthworks_,rivers_;
 std::vector<std::array<double,4>>pads_,rocks_,cover_;
 struct Tile {float ox=0,oz=0;std::array<V,1024>roots{};std::array<uint8_t,1024>states{};std::array<float,1024>px{},pz{};std::unordered_map<int,float>heights;uint64_t use=0;};
 std::unordered_map<uint64_t,Tile>tiles_;uint64_t use_=0;
 Tile&tile(int,int);
 V root(Tile&,int);
 double rock(double,double)const;
 double natural(double,double)const;
 V water(double,double)const;
 uint64_t bin(double x,double z)const;
public:
 double extent=0,tile_side=0;
 explicit Surface(const Json&);
 float height(double,double)const;
 bool planting(double,double)const;
 bool grass(V);
 size_t cached_tiles()const{return tiles_.size();}
};
}
