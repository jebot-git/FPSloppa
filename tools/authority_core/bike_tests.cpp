#include "authority_core.h"
#include "authority_bike_geometry.h"
#include "authority_protocol.h"
#include <memory>
using namespace cqauthority;
extern void check(bool,const char *);
namespace {
struct BikeWorld:Host {
 bool wet=false;
 Moved move(const Motion &m,double dt) override {return {m.position+m.velocity*dt,m.velocity,m.height,false};}
 Hit trace(V a,V b,Handle) override {return world_trace(a,b,{});}
 Hit world_trace(V a,V b,Handle) override {if(a.y>=0&&b.y<0)return {true,{},a+(b-a)*(a.y/(a.y-b.y)),{0,1,0}};return {};}
 bool water(V p) override{return wet&&p.y<4.;}
 VehicleMoved move_vehicle(const Vehicle &v,V velocity,double dt) override {V p=v.position+velocity*dt;p.y=0;return {p,{},V{0,1,0},0,true,true};}
};
}
void bike_tests() {
 for(int hz:{30,60}) {
  BikeWorld world;auto core=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;cfg.auto_respawn=false;core->configure_cq(cfg);core->configure_tick_rate(hz);
  int index=core->add_vehicle(VehicleKind::BIKE,{});auto rider=core->join(700,0,{1.5,0,0},1<<4,{100,100,100,100});
  int seq=0;auto drive=[&](double steer,double pedal,bool jump=false,bool fire=false){Command c;c.life=rider.life;c.seq=seq++;c.weapon=4;c.x=steer;c.z=pedal;c.jump=jump;c.fire=fire;check(core->submit(rider,c),"bike controls admitted");core->advance(world);};
  drive(0,0);Action use;use.kind=ActionKind::USE;use.seq=0;core->queue_action(rider,use);drive(0,0);
  check(core->resolve(rider)->vehicle==index,"neutral single-seat bike boards");
  check(core->vehicles()[index].hp==50&&vehicle_profile(VehicleKind::BIKE).reverse==0,"bike has 50HP and no reverse");
  check(!core->sheltered(*core->resolve(rider)),"bike rider is exposed");
  for(int i=0;i<hz*2;++i)drive(0,-1,false,true);
  check(core->vehicles()[index].speed>15. && core->counters.shots==0,"bike accelerates quickly without firing rider or vehicle weapons");
  double yaw=core->vehicles()[index].yaw;drive(1,-1);check(core->vehicles()[index].yaw<yaw,"handlebar input steers moving bike");
  check((core->resolve(rider)->position-bike_seat(core->vehicles()[index])).length()<1e-8,"rider remains on authored saddle socket");
  for(int i=0;i<hz*5;++i)drive(0,1);
  check(core->vehicles()[index].speed==0,"holding brake stops without reversing");
  yaw=core->vehicles()[index].yaw;drive(1,1);check(core->vehicles()[index].yaw==yaw,"stationary handlebar cannot pivot bike");
  check(validate_frame(core->frame().data(),core->frame().size()),"new bike kind survives native wire validation");
  auto *p=core->resolve(rider);p->invulnerable=0;p->armor=0;
  auto enemy=core->join(701,1,p->position+V{0,0,-8},1<<1,{100,100,100,100});
  ClassState profile;profile.xp[0]=2500;profile.primary_t2[0]=true;core->configure_player(enemy,profile);
  Command shot;shot.life=enemy.life;shot.seq=0;shot.weapon=1;shot.yaw=3.141592653589793;shot.fire=true;
  check(core->submit(enemy,shot),"enemy attack admitted");core->advance(world);
  for(int i=0;i<hz/5;++i)core->advance(world); // projectile travel time
  check(p->hp<100,"native bullet trace can hit exposed seated rider");
  auto key=core->vehicles()[index].key;
  check(core->damage_vehicle(key,1,20,DamageKind::BULLET,enemy,world)==0,"bike retains normal vehicle bullet immunity");
  check(core->damage_vehicle(key,1,20,DamageKind::GRENADE,enemy,world)==10,"bike takes ordinary half grenade damage");
  check(core->damage_vehicle(key,1,10,DamageKind::ORDNANCE,enemy,world)==10,"bike takes full ordnance damage");
  drive(0,0,true);check(p->vehicle<0,"jump dismounts bike");
  core->damage_vehicle(key,1,100,DamageKind::ORDNANCE,enemy,world);
  check(core->vehicles()[index].hp==0,"bike is destructible");
  const double due=core->vehicles()[index].respawn_at;
  check(std::abs(due-core->time()-120.)<1e-8,"bike uses transport two-minute respawn");
  for(int i=0;i<hz*120;++i)core->advance(world);
  check(core->vehicles()[index].hp==50&&!core->vehicles()[index].pilot.id&&(core->vehicles()[index].position-core->vehicles()[index].spawn).length()<1e-8,"destroyed bike returns to intended location empty");
 }
 for(int hz:{30,60}) {
  BikeWorld world;world.wet=true;auto core=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;cfg.auto_respawn=false;cfg.water_level=4.;core->configure_cq(cfg);core->configure_tick_rate(hz);
  auto swimmer=core->join(702,0,{},1<<2,{100,100,100,100});auto *p=core->resolve(swimmer);p->invulnerable=0;
  for(int i=0;i<hz;++i){Command c;c.life=swimmer.life;c.seq=i;c.weapon=2;c.jump=true;c.z=-1;check(core->submit(swimmer,c),"jump swim input admitted");core->advance(world);}
  check(p->position.y>3&&p->position.z<-2&&!p->dead,"jump plus locomotion swims up and forward without hand strokes");
 }
}
