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
 check(transport.forward==rocket.forward*1.2&&transport.reverse==rocket.reverse*1.2&&transport.turn==rocket.turn&&transport.acceleration==rocket.acceleration,"transport is 20 percent faster while retaining rocket steering and acceleration");
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
 check(c->damage_vehicle(key,1,20,DamageKind::BULLET,enemy,world)==0,"transport immune to infantry bullets");check(c->damage_vehicle(key,0,20,DamageKind::ORDNANCE,riders[6],world)==20,"allied ordnance damages transport");
 check(c->damage_vehicle(key,1,20,DamageKind::GRENADE,enemy,world)==10&&c->vehicles()[index].hp==70,"half grenade damage retained");check(c->damage_vehicle(key,1,20,DamageKind::ORDNANCE,enemy,world)==20&&c->vehicles()[index].hp==50,"full hostile ordnance damage retained");
 c->damage_vehicle(key,1,10000,DamageKind::ORDNANCE,enemy,world);
 for(int i:{0,1,2,4,5,7})check(c->resolve(riders[i])->dead&&c->resolve(riders[i])->vehicle<0,"wreck releases every remaining occupant");
 c->request_restart();c->advance(world);check(c->vehicles()[index].hp==100&&!c->vehicles()[index].pilot.id,"round reset restores full transport");for(auto seat:c->vehicles()[index].seats)check(!seat.id,"reset clears every seat generation");
 // Headlights are server-owned, driver-only and toggled once per release/press.
 {
  TransportWorld w;auto lights=std::make_unique<Core>();lights->configure_cq(cfg);
  int vi=lights->add_vehicle(VehicleKind::TRANSPORT,{},0,0);
  auto driver=lights->join(301,0,transport_pods[6].entry,1<<4,{100,100,100,100});
  auto passenger=lights->join(302,0,transport_pods[0].entry,1<<4,{100,100,100,100});
  input(*lights,driver,0);use(*lights,driver);lights->advance(w);
  input(*lights,passenger,0);use(*lights,passenger);lights->advance(w);
  int seq=1;
  auto trigger=[&](Handle h,bool down,bool blocked=false){Command cmd;cmd.life=h.life;cmd.seq=seq++;cmd.weapon=4;cmd.offhand_fire=down;cmd.blocked=blocked;check(lights->submit(h,cmd),"headlight input admitted");lights->advance(w);};
  trigger(passenger,true);check(!lights->vehicles()[vi].headlights,"passenger cannot toggle headlights");
  trigger(driver,true);check(lights->vehicles()[vi].headlights,"driver press enables headlights");
  trigger(driver,true);check(lights->vehicles()[vi].headlights,"held trigger does not repeatedly toggle");
  check(validate_frame(lights->frame().data(),lights->frame().size()),"lit vehicle flags pass wire validation");
  trigger(driver,false);trigger(driver,true);check(!lights->vehicles()[vi].headlights,"release then press disables headlights");
  trigger(driver,false);trigger(driver,true,true);check(!lights->vehicles()[vi].headlights,"blocked trigger cannot toggle");
  trigger(driver,true);check(!lights->vehicles()[vi].headlights,"focus recovery with held trigger requires release");
  trigger(driver,false);trigger(driver,true);check(lights->vehicles()[vi].headlights,"fresh press after focus recovery works");
  lights->request_restart();lights->advance(w);check(!lights->vehicles()[vi].headlights,"round reset switches lights off");
 }
 // Reversing changes steering yaw on every hull, at both adaptive rates.
 for(int hz:{30,60}) for(int kind=0;kind<4;++kind) {
  TransportWorld w;auto drive=std::make_unique<Core>();check(drive->configure_tick_rate(hz),"steering test rate");drive->configure_cq(cfg);
  int vi=drive->add_vehicle(VehicleKind(kind),{},0,0);
  auto h=drive->join(401,0,kind==3?transport_pods[6].entry:V{3,0,0},1<<4,{100,100,100,100});
  input(*drive,h,0);use(*drive,h);drive->advance(w);check(drive->resolve(h)->vehicle==vi,"steering test driver boards");
  int seq=1;auto &v=const_cast<Vehicle&>(drive->vehicles()[vi]);
  for(int steering:{-1,1}) for(int travel:{-1,1}) {
   v.speed=travel*2.;v.yaw=0;Command cmd;cmd.life=h.life;cmd.seq=seq++;cmd.weapon=4;cmd.x=steering;cmd.z=-travel;check(drive->submit(h,cmd),"steering command admitted");drive->advance(w);
   check(v.yaw*steering*travel<0,"forward and reverse steering yaw follows travel direction");
  }
  v.speed=2.;v.yaw=0;Command braking;braking.life=h.life;braking.seq=seq++;braking.weapon=4;braking.x=1;braking.z=1;drive->submit(h,braking);drive->advance(w);
  check(v.speed>0&&v.yaw<0,"reverse throttle does not flip steering before forward motion stops");
  v.speed=-2.;v.yaw=0;braking.seq=seq++;braking.z=-1;drive->submit(h,braking);drive->advance(w);
  check(v.speed<0&&v.yaw>0,"forward throttle retains reverse steering until reverse motion stops");
 }
 // Wheel steering must not reduce the independent throttle axis.
 {
  TransportWorld w;auto wheel=std::make_unique<Core>();wheel->configure_cq(cfg);
  int vi=wheel->add_vehicle(VehicleKind::TRANSPORT,{},0,0);
  auto driver=wheel->join(501,0,transport_pods[6].entry,1<<4,{100,100,100,100});
  input(*wheel,driver,0);use(*wheel,driver);wheel->advance(w);
  Command cmd;cmd.life=driver.life;cmd.seq=1;cmd.weapon=4;cmd.x=1;cmd.z=-1;
  check(wheel->submit(driver,cmd),"independent full wheel and throttle admitted");wheel->advance(w);
  auto *p=wheel->resolve(driver);
  check(p->input.x==1&&p->input.z==-1,"full steering preserves full throttle for native transport driver");
  cmd.seq=2;cmd.x=8;cmd.z=-8;wheel->submit(driver,cmd);wheel->advance(w);
  check(p->input.x==1&&p->input.z==-1,"native wheel axes individually bounded");
  cmd.seq=3;cmd.blocked=true;wheel->submit(driver,cmd);double yaw=wheel->vehicles()[vi].yaw;wheel->advance(w);
  check(wheel->vehicles()[vi].yaw==yaw,"blocked driver cannot steer with wheel input");
  input(*wheel,driver,4,false,0,true);wheel->advance(w);
  cmd.seq=5;cmd.blocked=false;cmd.x=1;cmd.z=1;wheel->submit(driver,cmd);wheel->advance(w);
  check(std::hypot(p->input.x,p->input.z)<=1.000001,"dismounted player returns to circular foot-movement bound");
 }
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
