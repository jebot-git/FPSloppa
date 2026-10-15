#include "authority_core.h"
#include "authority_protocol.h"
#include "authority_transport_geometry.h"
#include <memory>
using namespace cqauthority;
extern void check(bool,const char*);
namespace {
struct SquadWorld:Host {
 bool blocked=false;
 Moved move(const Motion &m,double) override {V p=m.position;p.y=0;return {p,{},m.height,true};}
 Hit trace(V a,V b,Handle) override {return world_trace(a,b,{});}
 Hit world_trace(V a,V b,Handle) override {if(a.y>=0&&b.y<0)return {true,{},a+(b-a)*(a.y/(a.y-b.y)),{0,1,0}};return {};}
 bool clear_exit(Handle,V,uint64_t) override {return !blocked;}
 VehicleMoved move_vehicle(const Vehicle &v,V,double) override {return {v.position,{}, {0,1,0},v.position.y,true,true};}
};
int sequence=0;
void action(Core &c,Handle h,ActionKind kind,int a=0,int b=0,int d=0){Action op;op.seq=++sequence;op.kind=kind;op.a=a;op.b=b;op.c=d;check(c.queue_action(h,op),"squad action queued with current life");}
void deploy(Core &c,Handle h,SquadWorld &w,int kind=0,int target=0,int life=0){action(c,h,ActionKind::SPAWN,kind,target,life);c.advance(w);}
std::unique_ptr<Core> core(){auto c=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;cfg.squads=true;check(c->configure_cq(cfg),"native squads configured before admission");return c;}
Handle join(Core &c,int id,int team=0){auto h=c.join(id,team,{},1<<2,{100,100,100,100});check(h.id==id,"squad player admitted");return h;}
}
void squad_tests(){
 SquadWorld w;
 {auto hit=ballistic({0,2.3,0},{5000,0,0},ROCKET_TANK_SPEED,20);check(hit.valid&&hit.time<ROCKET_TANK_FUSE,"rocket tank can solve a five kilometre hit within projectile lifetime");V end=V{0,2.3,0}+hit.velocity*hit.time-V{0,10*hit.time*hit.time,0};check((end-V{5000,0,0}).length()<.001,"five kilometre ballistic solution reaches target");check(!ballistic({},{5010,0,0},ROCKET_TANK_SPEED,20).valid,"stationary level-ground rocket range bounded at five kilometres");}

 {Points p;p.count=1;std::array<std::array<bool,2>,MAX_ZONES> presence{};std::array<std::array<int,2>,MAX_ZONES> counts{};presence[0][0]=true;counts[0][0]=4;p.advance(2.49,presence,counts);check(p.zones[0].owner==-1,"four players do not capture before 2.5 seconds");p.advance(.01,presence,counts);check(p.zones[0].owner==0&&p.scores[0]==0,"four players capture in 2.5 seconds without retroactive income");}

 {
  auto a=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;cfg.auto_respawn=false;a->configure_cq(cfg);
  a->configure_zone({},10);a->configure_zone({},10);
  std::array<Handle,4> h;
  for(int r=0;r<4;++r){h[r]=a->join(r+1,0,{},1<<2,{100,100,100,100});ClassState cs;cs.role=cs.next=Role(r);check(a->configure_player(h[r],cs),"armour class fixture configured");check(a->resolve(h[r])->armor==cs.armor_limit(),"class spawns with full class armour");a->resolve(h[r])->armor=0;}
  a->points.zones[0].owner=a->points.zones[1].owner=0;
  for(int i=0;i<30;++i)a->advance(w);
  check(a->resolve(h[0])->armor==2&&a->resolve(h[2])->armor==2&&a->resolve(h[3])->armor==2,"owned POI recharges two armour per second without overlap stacking");
  check(a->resolve(h[1])->armor==0,"scout never gains armour");
  auto enemy=a->join(10,1,{},1<<2,{100,100,100,100});a->resolve(enemy)->armor=0;
  for(int i=0;i<30;++i)a->advance(w);
  check(a->resolve(h[0])->armor==2&&a->resolve(enemy)->armor==0,"contested POI stops recharge for both teams immediately");
  a->resolve(enemy)->position={100,0,100};
  for(int i=0;i<30;++i)a->advance(w);
  check(a->resolve(h[0])->armor==4,"recharge resumes when POI uncontested");
  a->resolve(h[2])->position={100,0,100};a->resolve(h[3])->dead=true;
  for(int i=0;i<30;++i)a->advance(w);
  check(a->resolve(h[2])->armor==4&&a->resolve(h[3])->armor==4,"outside and dead players do not recharge");
  for(int i=0;i<1600;++i)a->advance(w);
  check(a->resolve(h[0])->armor==100,"shocktroop recharge capped at one hundred");
  a->resolve(h[2])->position={};for(int i=0;i<800;++i)a->advance(w);
  check(a->resolve(h[2])->armor==50,"medic recharge capped at fifty");
  a->choose_class(h[0],int(Role::SCOUT));a->resolve(h[0])->dead=true;auto fresh=a->respawn(h[0],{});
  check(a->resolve(fresh)->armor==0&&a->resolve(fresh)->armor_credit==0,"class change resets armour and fractional recharge");
 }
 auto c=core();c->configure_zone({100,0,100});
 std::array<Handle,64> members;
 for(int i=0;i<64;++i){members[i]=join(*c,i+1,i/32);check(c->resolve(members[i])->staging,"new humans are staged");check(c->join_squad(members[i],(i%32)/8),"four eight-slot squads fill independently per team");}
 check(!c->join(100,0,{},1<<2,{1,1,1,1}).id,"team admission rejects thirty-third player");
 check(!c->join_squad(members[8],0),"full squad refuses ninth member");
 for(int i=0;i<64;++i)deploy(*c,members[i],w);
 check(c->resolve(members[0])->position.x<0&&c->resolve(members[32])->position.x>0,"team insertion sectors are opposite");
 check(std::abs(c->resolve(members[0])->position.z-c->resolve(members[24])->position.z)>200,"same-team squads have separated insertion positions");
 check(!c->join_squad(members[0],1),"living player cannot switch squad outside deployment");
 auto h=members[0];c->resolve(h)->invulnerable=0;
 check(c->damage(h,members[32],1,DamageKind::BULLET),"hostile damage accepted");
 check(c->resolve(h)->combat_until>c->time()&&c->resolve(members[32])->combat_until>c->time(),"damage locks victim and attacker out of squad spawning");
 check(c->damage(h,h,10000,DamageKind::VEHICLE_DESTROYED),"death begins deployment wait");
 for(int i=0;i<300;++i)c->advance(w);
 check(c->resolve(h)&&c->resolve(h)->dead,"human death never auto respawns around deployment map");
 deploy(*c,h,w,1,0);check(c->resolve(h)->dead,"enemy or neutral POI cannot spawn player");
 c->points.zones[0].owner=0;c->points.zones[0].contested=true;
 deploy(*c,h,w,1,0);check(c->resolve(h)->dead,"contested POI blocks deployment");
 c->points.zones[0].contested=false;w.blocked=true;
 deploy(*c,h,w,1,0);check(c->resolve(h)->dead,"obstructed POI refuses deployment");w.blocked=false;
 deploy(*c,h,w,1,0);auto fresh=c->find(h.id);
 check(fresh&&!fresh->dead&&fresh->handle!=h&&fresh->squad==0,"controlled POI spawns a new life while preserving squad");
 check((fresh->position-V{100,0,100}).length()<5,"controlled POI spawn remains near its capture site");
 check(!c->queue_action(h,Action{}),"old life cannot request another deployment");
 check(validate_frame(c->frame().data(),c->frame().size()),"squad section round trips bounded native wire validation");

 auto t=core();int transport=t->add_vehicle(VehicleKind::TRANSPORT,{},0,0);int tank=t->add_vehicle(VehicleKind::ROCKET,{30,0,0});
 std::array<Handle,8> squad;
 for(int i=0;i<8;++i){squad[i]=join(*t,i+1);t->join_squad(squad[i],0);}
 deploy(*t,squad[0],w);auto *driver=t->resolve(squad[0]);driver->position=transport_pods[6].entry;
 Command cmd;cmd.life=squad[0].life;cmd.seq=1;cmd.weapon=driver->weapon;t->submit(squad[0],cmd);action(*t,squad[0],ActionKind::USE);t->advance(w);
 check(driver->vehicle==transport&&driver->vehicle_seat==6,"squad driver boards dedicated cockpit");
 driver->combat_until=t->time()+8.;deploy(*t,squad[1],w,2,1,squad[0].life);check(t->resolve(squad[1])->staging,"combat blocks transport passenger spawn");driver->combat_until=0;
 for(int i=1;i<8;++i){deploy(*t,squad[i],w,2,1,squad[0].life);auto *p=t->resolve(squad[i]);check(!p->staging&&p->vehicle==transport&&p->vehicle_seat!=6,"entire eight-player squad deploys into seven free passenger seats");}
 check(t->vehicles()[transport].pilot==squad[0],"passenger spawns preserve driver");
 auto outsider=join(*t,20);t->join_squad(outsider,1);deploy(*t,outsider,w,2,1,squad[0].life);check(t->resolve(outsider)->staging,"different squad cannot use buddy");
 auto *pending=t->resolve(squad[7]);pending->staging=true;t->advance(w);
 auto extra=join(*t,30);t->join_squad(extra,1);deploy(*t,extra,w);auto *occupant=t->resolve(extra);occupant->position=transport_pods[7].entry;
 Command fill;fill.life=extra.life;fill.seq=1;fill.weapon=occupant->weapon;t->submit(extra,fill);action(*t,extra,ActionKind::USE);t->advance(w);check(occupant->vehicle==transport,"another allied squad can occupy the last passenger seat");

 deploy(*t,squad[7],w,2,1,squad[0].life+1);check(pending->staging,"stale buddy life rejected");
 deploy(*t,squad[7],w,2,1,squad[0].life);check(pending->staging,"full transport rejects pending spawn");
 auto &v=const_cast<Vehicle&>(t->vehicles()[tank]);v.pilot=squad[0];v.team=0;driver->vehicle=tank;driver->vehicle_seat=-1;
 deploy(*t,squad[7],w,2,1,squad[0].life);check(pending->staging,"tank driver cannot be buddy spawn");
}
