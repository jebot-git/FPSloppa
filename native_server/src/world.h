#pragma once
#include "world_data.h"
#include "navigation.h"
#include "terrain.h"
#include <memory>
#include <functional>
namespace cqserver {
class World final:public cqauthority::Host {
 struct Impl;std::unique_ptr<Impl>p_;
 cqauthority::Core &core_;
public:
 Surface surface;
 Navigation navigation;
 std::function<void(V,double,double)>on_impact;
 World(const WorldData&,cqauthority::Core&);
 ~World();
 void add_actor(cqauthority::Handle,V);
 void remove_actor(int64_t);
 void sync(double);
 void set_body(size_t,bool);
 bool body_active(size_t)const;
 bool wall_visible(V,V,int)const;
 std::vector<uint32_t>add_boxes(const Json&,bool enabled,int wall=-1);
 void set_extra_body(uint32_t,bool);
 const WorldData &data()const;
 bool edge(const cqauthority::Motion&)override;
 double posture(cqauthority::Handle,double)override;
 cqauthority::Moved move(const cqauthority::Motion&,double)override;
 cqauthority::Hit trace(V,V,cqauthority::Handle)override;
 cqauthority::Hit world_trace(V,V,cqauthority::Handle)override;
 cqauthority::Hit sweep_world(V,V,double,cqauthority::Handle,uint64_t)override;
 double world_fraction(V,V,double,cqauthority::Handle)override;
 double ground_height(double,double)override;
 std::vector<V>navigate(V a,V b)override{return navigation.path(a,b);}
 cqauthority::Hit entity_ray(V,V,uint64_t)override;
 bool clear_exit(cqauthority::Handle,V,uint64_t)override;
 void seat(cqauthority::Handle,V,bool)override;
 void sync_vehicle(const cqauthority::Vehicle&)override;
 void ordnance_impact(V p,double d,double r)override{if(on_impact)on_impact(p,d,r);}
 cqauthority::VehicleMoved move_vehicle(const cqauthority::Vehicle&,V,double)override;
 void teleport(cqauthority::Handle,V)override;
 bool water(V p)override{return core_.terrain.water_sample(p.x,p.z).x>.5;}
 bool grass_cover(V p)override{return surface.grass(p);}
 V room_move(cqauthority::Handle,V,double)override;
};
}
