#include "authority_core.h"
#include "authority_transport_geometry.h"
#include "authority_protocol.h"
#include <memory>
using namespace cqauthority;
extern void check(bool,const char*);
namespace {
struct TransportWorld:Host {
 bool blocked_exit=false,wet=false;
 Moved move(const Motion &m,double dt) override {V p=m.position+m.velocity*dt;p.y=std::max(0.,p.y);return {p,{},m.height,true};}
 Hit trace(V a,V b,Handle) override {return world_trace(a,b,{});}
 Hit world_trace(V a,V b,Handle) override {if(a.y>=0&&b.y<0)return {true,{},a+(b-a)*(a.y/(a.y-b.y)),{0,1,0}};return {};}
 bool clear_exit(Handle,V,uint64_t) override {return !blocked_exit;}
 bool water(V) override{return wet;}
 VehicleMoved move_vehicle(const Vehicle &v,V velocity,double dt) override {V p=v.position+velocity*dt;p.y=std::max(0.,p.y);velocity.y=0;return {p,velocity,{0,1,0},p.y,true,true};}
};
void input(Core &c,Handle h,int seq,bool fire=false,int drive=0,bool jump=false) {Command cmd;cmd.life=h.life;cmd.seq=seq;cmd.weapon=4;cmd.fire=fire;cmd.z=drive;cmd.jump=jump;check(c.submit(h,cmd),"transport input admitted");}
void use(Core &c,Handle h,int seq=0) {Action a;a.kind=ActionKind::USE;a.seq=seq;check(c.queue_action(h,a),"transport use action admitted");}
}
void transport_tests() {
 TransportWorld world;auto c=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;cfg.auto_respawn=false;c->configure_cq(cfg);
 check(c->add_vehicle(VehicleKind::TRANSPORT,{},0,-1)<0,"transport requires allied team");
 int index=c->add_vehicle(VehicleKind::TRANSPORT,{},0,0);
 const auto &rocket=vehicle_profile(VehicleKind::ROCKET),&transport=vehicle_profile(VehicleKind::TRANSPORT);
 check(transport.forward==rocket.forward&&transport.reverse==rocket.reverse&&transport.turn==rocket.turn&&transport.acceleration==rocket.acceleration,"transport mobility matches rocket tank");
 check(transport.capacity==0&&transport.pair==0&&transport.hp==100,"transport unarmed with battery damage profile and 100 HP");
 std::array<Handle,8> riders;
 for(int seat=0;seat<8;++seat){riders[seat]=c->join(seat+1,0,transport_pods[seat].entry,1<<4,{1000,1000,1000,1000});input(*c,riders[seat],0);use(*c,riders[seat]);c->advance(world);check(c->resolve(riders[seat])->vehicle==index&&c->resolve(riders[seat])->vehicle_seat==seat,"all eight authored seats board from their own entry");if(seat<6)check(!c->vehicles()[index].pilot.id,"side pod passenger never silently becomes driver");}
 check(c->vehicles()[index].pilot==riders[6],"cockpit driver owns movement controls");
 auto enemy=c->join(99,1,transport_pods[0].entry,1<<4,{100,100,100,100});input(*c,enemy,0);use(*c,enemy);c->advance(world);check(c->resolve(enemy)->vehicle<0,"enemy cannot board");
 auto extra=c->join(98,0,transport_pods[0].entry,1<<4,{100,100,100,100});input(*c,extra,0);use(*c,extra);c->advance(world);check(c->resolve(extra)->vehicle<0,"ninth occupant cannot overfill a full squad transport");
 for(int tick=1;tick<=30;++tick){for(int i=0;i<8;++i)input(*c,riders[i],tick,true,i==6?-1:1);c->advance(world);}
 check(c->counters.shots==0,"all eight occupants cannot fire");check(c->vehicles()[index].speed>3.9,"only cockpit driver moves the transport");
 for(int i=0;i<8;++i)check((c->resolve(riders[i])->position-transport_seat(c->vehicles()[index],i)).length()<1e-8,"every passenger follows its own seat");
 check(validate_frame(c->frame().data(),c->frame().size()),"all eight seat indices survive bounded wire validation");
 world.blocked_exit=true;input(*c,riders[3],31,false,0,true);c->advance(world);check(c->resolve(riders[3])->vehicle==index,"blocked jump retains passenger");
 world.blocked_exit=false;input(*c,riders[3],32);c->advance(world);input(*c,riders[3],33,false,0,true);c->advance(world);check(c->resolve(riders[3])->vehicle<0,"jump dismounts side passenger");
 input(*c,riders[6],31,false,0,true);c->advance(world);check(!c->vehicles()[index].pilot.id&&c->resolve(riders[6])->vehicle<0,"driver exit leaves dedicated seat vacant");
 input(*c,riders[2],31);use(*c,riders[2],1);c->advance(world);check(c->vehicles()[index].pilot==riders[2]&&c->resolve(riders[2])->vehicle_seat==6&&!c->vehicles()[index].seats[2].id,"passenger use moves into vacant driver cockpit");
 auto key=c->vehicles()[index].key;
 check(c->damage_vehicle(key,1,20,DamageKind::BULLET,enemy,world)==0,"transport immune to infantry bullets");check(c->damage_vehicle(key,0,20,DamageKind::ORDNANCE,riders[6],world)==0,"allied ordnance protection retained");
 check(c->damage_vehicle(key,1,20,DamageKind::GRENADE,enemy,world)==10&&c->vehicles()[index].hp==90,"half grenade damage retained");check(c->damage_vehicle(key,1,20,DamageKind::ORDNANCE,enemy,world)==20&&c->vehicles()[index].hp==70,"full hostile ordnance damage retained");
 c->damage_vehicle(key,1,10000,DamageKind::ORDNANCE,enemy,world);
 for(int i:{0,1,2,4,5,7})check(c->resolve(riders[i])->dead&&c->resolve(riders[i])->vehicle<0,"wreck releases every remaining occupant");
 c->request_restart();c->advance(world);check(c->vehicles()[index].hp==100&&!c->vehicles()[index].pilot.id,"round reset restores full transport");for(auto seat:c->vehicles()[index].seats)check(!seat.id,"reset clears every seat generation");
 // Every authored vehicle keeps its identity and placement across destruction.
 {
  TransportWorld w;auto timer=std::make_unique<Core>();timer->configure_cq(cfg);
  std::array<int,4> ids;
  for(int k=0;k<4;++k) {
   ids[k]=timer->add_vehicle(VehicleKind(k),{double(k)*20,0,5},.7,0);
   auto &v=const_cast<Vehicle&>(timer->vehicles()[ids[k]]);
   v.position={100.+k,0,40};v.yaw=2.;v.team=1;v.reload_at=999;
   timer->damage_vehicle(v.key,0,10000,DamageKind::ORDNANCE,{},w);
   check(v.hp==0&&v.respawn_at==(k==3?120.:180.),"vehicle destruction schedules class-specific respawn");
   timer->damage_vehicle(v.key,0,10000,DamageKind::ORDNANCE,{},w);
   check(v.respawn_at==(k==3?120.:180.),"wreck damage cannot restart respawn timer");
  }
  for(int tick=0;tick<3599;++tick)timer->advance(w);
  for(int id:ids)check(timer->vehicles()[id].hp==0,"no vehicle respawns before two minutes");
  timer->advance(w);
  check(timer->vehicles()[ids[3]].hp==100,"transport returns at exactly 120 seconds");
  for(int k=0;k<3;++k)check(timer->vehicles()[ids[k]].hp==0,"tanks remain destroyed at two minutes");
  for(int tick=3600;tick<5399;++tick)timer->advance(w);
  for(int k=0;k<3;++k)check(timer->vehicles()[ids[k]].hp==0,"tanks remain destroyed one tick before three minutes");
  timer->advance(w);
  for(int k=0;k<4;++k) {
   const auto &v=timer->vehicles()[ids[k]];
   check(v.hp==vehicle_profile(VehicleKind(k)).hp&&v.rounds==vehicle_profile(VehicleKind(k)).capacity,"respawn restores full health and ammunition");
   check((v.position-v.spawn).length()<1e-8&&v.yaw==.7&&v.team==0,"respawn restores authored location heading and team");
   check(!v.pilot.id&&v.respawn_at==0&&v.reload_at==0&&v.remaining==0,"respawn clears driver timer and volley state");
   for(auto seat:v.seats)check(!seat.id,"respawn has no stale occupants");
  }
  const auto &truck=timer->vehicles()[ids[3]];
  timer->damage_vehicle(truck.key,1,10000,DamageKind::ORDNANCE,{},w);
  check(timer->vehicles()[ids[3]].respawn_at==300.,"second transport destruction gets a fresh two-minute timer");
  timer->request_restart();timer->advance(w);
  check(timer->vehicles()[ids[3]].hp==100&&timer->vehicles()[ids[3]].respawn_at==0,"round restart cancels pending respawn");
 }
 {
  TransportWorld w;auto drowned=std::make_unique<Core>();drowned->configure_cq(cfg);
  int id=drowned->add_vehicle(VehicleKind::TRANSPORT,{},0,0);w.wet=true;drowned->advance(w);
  check(drowned->vehicles()[id].hp==0&&drowned->vehicles()[id].respawn_at>120.,"water destruction also schedules respawn");
  w.wet=false;for(int tick=0;tick<3600;++tick)drowned->advance(w);
  check(drowned->vehicles()[id].hp==100,"drowned transport respawns after two minutes");
 }

}
