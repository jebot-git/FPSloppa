#pragma once
#include "world.h"
#include <set>
#include <map>
namespace cqserver {
class Destruction {
 World&world_;cqauthority::Core&core_;bool enabled_;V last_impact_;
 std::vector<int>cell_building_;
 std::map<int,std::vector<size_t>>wall_bodies_;
 std::map<int,std::vector<uint32_t>>wall_cells_;
 std::vector<std::vector<size_t>>building_bodies_;
 std::vector<std::vector<uint32_t>>rubble_;
 std::set<int>broken_,collapsed_;
 std::set<int>changed_walls_;
 uint32_t revision_=0,epoch_=1;
 bool failed(int)const;
 void rebuild_wall(int);
public:
 Destruction(World&,cqauthority::Core&,bool);
 bool impact(V,double,double);
 void reset(uint32_t);
 Json state()const;
 size_t broken_count()const{return broken_.size();}
 size_t collapsed_count()const{return collapsed_.size();}
};
}
