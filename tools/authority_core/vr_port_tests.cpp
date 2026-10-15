#include "authority_core.h"
#include "authority_weapon_geometry.h"
#include "authority_protocol.h"
#include "authority_nvg.h"
#include <memory>
using namespace cqauthority;
extern void check(bool,const char *);
namespace { struct World:Host {
 Moved move(const Motion &m,double dt) override {return {m.position+m.velocity*dt,m.velocity,m.height,true};}
 Hit trace(V,V,Handle) override {return {};}
 void seat(Handle,V,bool) override {}
}; }
void vr_port_tests() {
 {
  auto c=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;c->configure_cq(cfg);
  auto h=c->join(88,0,{},1<<4,{100,100,100,100});auto *p=c->resolve(h);p->last_input=0;p->input.vr=true;p->pose.tracked=true;p->pose.head.origin={0,1.65,0};
  p->pose.left.origin={0,1.65,-.18};p->pose.right.origin={.3,1.0,-.3};
  check(c->toggle_nvg(h)&&p->classes.nvg,"either-hand visor touch accepts natural forehead height");
  p->classes.nvg_ready=0;p->pose.left.origin={-.3,1.,-.3};p->pose.right.origin={0,1.7,-.18};
  check(!c->toggle_nvg(h),"occupied weapon hand cannot toggle visor");
  p->input.weapon_held=false;
  check(c->toggle_nvg(h)&&!p->classes.nvg,"empty weapon hand can also toggle visor");
  p->classes.nvg_ready=0;p->pose.right.origin={.3,1.,-.3};
  check(!c->toggle_nvg(h),"remote hand positions cannot toggle visor");
  p->pose.left.origin={0,1.65,-.18};p->physical[p->weapon].carry=1;
  check(!c->toggle_nvg(h),"hand carrying reload ammunition cannot toggle visor");
  p->physical[p->weapon].carry=0;p->physical[p->weapon].grab=Grab::RACK;
  check(!c->toggle_nvg(h),"hand cocking a weapon cannot toggle visor");
  p->physical[p->weapon].grab=Grab::NONE;p->grenade_primed=true;p->grenade_hand=0;
  check(!c->toggle_nvg(h),"hand holding an armed grenade cannot toggle visor");
 }
 check(nvg_direct({0,0,-1},{0,0,-8}),"direct lamp look causes NVG glare");
 check(!nvg_direct({0,0,-1},{.7,0,-8}),"peripheral lamp cannot white out NVG");
 check(!nvg_direct({0,0,-1},{0,0,8}),"light behind wearer cannot white out NVG");
 check(nvg_direct({0,0,-1},{0,0,-1},true)&&!nvg_direct({0,0,-1},{.04,0,-1},true),"sun requires one-degree direct gaze");
 {
  auto light=std::make_unique<Core>();CqConfig config;config.enabled=true;config.day_cycle=false;light->configure_cq(config);
  light->configure_lamps({{0,1.48,-8}});auto who=light->join(80,0,{},1<<4,{100,100,100,100});light->resolve(who)->classes.nvg=true;World world;
  for(int i=0;i<3;++i){Command c;c.life=who.life;c.seq=i;c.weapon=4;light->submit(who,c);light->advance(world);}
  check(light->resolve(who)->classes.blind_until>light->time(),"native direct fixture gaze blinds spotting");
  for(int i=3;i<6;++i){Command c;c.life=who.life;c.seq=i;c.weapon=4;c.yaw=.1;light->submit(who,c);light->advance(world);}
  check(light->resolve(who)->classes.blind_until<=light->time(),"native look-away clears fixture glare at next scan");
 }
 {
  auto flashes=std::make_unique<Core>();CqConfig config;config.enabled=true;flashes->configure_cq(config);
  auto who=flashes->join(81,0,{},1<<4,{1000,1000,1000,1000});flashes->resolve(who)->classes.nvg=true;World world;
  for(int i=0;i<40;++i){Command c;c.life=who.life;c.seq=i;c.weapon=4;c.fire=true;flashes->submit(who,c);flashes->advance(world);}
  check(flashes->counters.shots>0&&flashes->resolve(who)->classes.blind_until==0,"muzzle fire never sets native full-screen NVG blindness");
 }
 RecoilState state;
 auto first=state.shot(4,0,0,true,1.65,true,true,1,.8,.7);
 check((first-V{0,0,-1}).length()<1e-12,"recovered braced first shot follows sight");
 auto follow=state.shot(4,.12,0,true,1.65,true,true,1,.8,.7);
 check(follow.y>first.y,"sustained CS fire adds bloom and climb");
 auto recovered=state.shot(4,3,0,true,1.65,true,true,1,.8,.7);
 check((recovered-first).length()<1e-12,"CS recoil recovers after pause");
 RecoilState single,braced;
 auto a=single.shot(4,0,0,true,1.65,true,false,1,.8,.7);
 auto b=braced.shot(4,0,0,true,1.65,true,true,1,.8,.7);
 check(std::abs(a.x)>std::abs(b.x),"unsupported VR long gun has accuracy penalty");
 auto core=std::make_unique<Core>();CqConfig config;config.enabled=true;config.auto_respawn=false;
 check(core->configure_cq(config),"prepare CQ staging test");
 auto h=core->join(1,0,{0,0,0},1<<4,{1000,1000,1000,1000});auto *p=core->resolve(h);p->staging=true;
 core->configure_zone({0,0,0},3);World world;
 for(int i=0;i<90;++i){Command c;c.life=h.life;c.seq=i;c.weapon=4;c.x=1;c.fire=true;core->submit(h,c);core->advance(world);}
 check(p->position.length()<1e-9&&core->counters.shots==0,"staging actor neither moves nor fires");
 check(core->points.zones[0].owner!=0,"staging actor cannot capture");
 Action choose;choose.kind=ActionKind::CLASS;choose.seq=0;choose.a=int(Role::MEDIC);check(core->queue_action(h,choose),"choose class during staging");core->advance(world);
 Action deploy;deploy.kind=ActionKind::DEPLOY;deploy.seq=1;check(core->queue_action(h,deploy),"queue explicit deployment");core->advance(world);
 check(!p->staging&&p->classes.role==Role::MEDIC,"deployment applies staged class choice");
 {
  auto semi=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;cfg.auto_respawn=false;semi->configure_cq(cfg);
  auto who=semi->join(2,0,{0,0,0},1<<2,{1000,1000,1000,1000});
  for(int i=0;i<42;++i){Command c;c.life=who.life;c.seq=i;c.weapon=2;c.fire=i>=12;semi->submit(who,c);semi->advance(world);}
  check(semi->counters.shots==1,"CQ semi-auto pistol requires trigger release");
  Command release;release.life=who.life;release.seq=42;release.weapon=2;semi->submit(who,release);semi->advance(world);
  release.seq=43;release.fire=true;semi->submit(who,release);semi->advance(world);
  check(semi->counters.shots==2,"second trigger press fires after release");
 }
 {
  auto owned=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;cfg.auto_respawn=false;owned->configure_cq(cfg);
  auto who=owned->join(3,0,{0,0,0},1<<4,{1000,1000,1000,1000});
  for(int i=0;i<20;++i){Command c;c.life=who.life;c.seq=i;c.weapon=4;c.fire=true;c.vr=true;c.weapon_held=false;c.pose.tracked=true;c.pose.head.origin={0,1.65,0};owned->submit(who,c);owned->advance(world);}
  check(owned->counters.shots==0,"released VR weapon cannot fire through native input");
  auto frame=owned->frame();
  check(validate_frame(frame.data(),frame.size()),"holstered flag survives bounded native frame validation");
  std::array<uint8_t,48> packet{};packet[0]='C';packet[1]='Q';packet[2]='I';packet[3]='2';
  for(int i=0;i<4;++i){packet[4+i]=uint8_t(who.life>>(8*i));packet[8+i]=uint8_t(20u>>(8*i));}
  packet[28]=4;packet[30]=1;packet[31]=32;
  check(owned->submit_packet(who.id,packet.data(),packet.size()),"holstered grip flag accepted from CQI2 wire");owned->advance(world);
  check(!owned->resolve(who)->input.weapon_held,"released grip survives packet decoding");
  packet[8]=21;packet[31]=96;
  check(owned->submit_packet(who.id,packet.data(),packet.size()),"drawn grip flag accepted from CQI2 wire");owned->advance(world);
  check(owned->resolve(who)->input.weapon_held,"drawn grip survives packet decoding");
  packet[8]=22;packet[31]=64;
  check(!owned->submit_packet(who.id,packet.data(),packet.size()),"grip value without presence flag rejected");
 }
 RecoilState compensation;compensation.step={.02,0,0};
 compensation.compensation({0,0,-.3},1,true);
 check(compensation.compensation({0,-.015,-.3},1.1,true)<1,"active support correction reduces bloom");
 check(compensation.compensation({0,-.015,-.3},1.1,true)==1,"duplicate controller sample cannot compensate twice");
 for(int w:{0,2,9,10}) {
  Reload r;r.init(7);r.cq_weapon=w;Pose p;p.tracked=true;p.has_offhand=true;p.head.origin={0,1.65,0};p.weapon.origin={0,1.1,-.3};p.left.origin=p.weapon.apply(cq_geometry(w).support*.65);p.offhand=p.left;
  r.sample(2,7,100,7,p,false,false,0,0,false,true);r.sample(2,7,100,7,p,true,false,.033,.033,false,true);
  check(r.grab==Grab::NONE,"pistol support contact does not accidentally grab the slide");
 }
 for(int w:{0,1,2,3,4,9,10})for(bool left:{false,true})for(bool use_trigger:{false,true}) {
  Reload r;r.init(7);r.cq_weapon=w;r.ready=false;
  Pose pose;pose.tracked=true;pose.has_offhand=true;pose.left_handed=left;pose.head.origin={0,1.65,0};pose.weapon.origin={0,1.1,-.3};
  auto &hand=left?pose.right:pose.left;hand.origin=pose.weapon.apply(cq_geometry(w).rack*.65);pose.offhand=hand;
  int geometry=(w==2||w==9||w==3)?2:7;
  r.sample(geometry,7,100,7,pose,false,false,0,0,false,true);
  r.sample(geometry,7,100,7,pose,!use_trigger,false,.033,.033,use_trigger,true);
  check(r.grab==Grab::RACK,"CQ slide/charging handle accepts grip or offhand trigger in either handedness");
  for(int i=1;i<=5;++i){hand.origin.z+=.012;r.sample(geometry,7,100,7,pose,!use_trigger,false,.033+i*.033,.033+i*.033,use_trigger,true);}
  check(r.pulled&&r.stroke>.9&&!r.ready,"held trigger or grip physically retracts bolt without premature chambering");
  r.sample(geometry,7,100,7,pose,false,false,.25,.25,false,true);
  check(r.ready&&r.grab==Grab::NONE&&r.mag,"releasing cocking control chambers the gun without extracting its magazine");
 }
 for(int w:{0,1,2,3,4,9,10})for(bool left:{false,true}) {
  Reload r;r.init(7);r.cq_weapon=w;Pose p;p.tracked=true;p.has_offhand=true;p.left_handed=left;p.head.origin={0,1.65,0};p.weapon.origin={0,1.1,-.3};auto &hand=left?p.right:p.left;hand.origin=p.weapon.apply(cq_geometry(w).magazine*.65);p.offhand=hand;
  r.sample(2,7,100,7,p,false,false,0,0,false,true);
  r.sample(2,7,100,7,p,true,false,.033,.033,false,true);
  check(r.grab!=Grab::MAGAZINE,"support grip alone cannot accidentally pull CQ magazine");
  r.interrupt();r.sample(2,7,100,7,p,false,false,.066,.066,false,true);
  r.sample(2,7,100,7,p,false,false,.1,.1,true,true);
  check(r.grab==Grab::MAGAZINE,"support trigger grips authored CQ magazine with either hand");
  int clip=7;for(int i=1;i<=5;++i){hand.origin.y-=.02;clip=r.sample(2,clip,100,7,p,false,false,.1+i*.033,.1+i*.033,true,true);}
  check(!r.mag&&r.carry==4&&r.carried_rounds==6,"trigger draw retains exact magazine rounds and chamber");
  for(int i=1;i<=5;++i){hand.origin.y+=.02;clip=r.sample(2,clip,100,7,p,false,false,.265+i*.033,.265+i*.033,true,true);}
  check(r.mag&&clip==7&&r.carry==0,"same physical magazine reinserts with preserved rounds");
 }
 for(int w:{0,1,2,3,4,9,10})for(bool left:{false,true}) {
  Reload reload;reload.init(7);reload.cq_weapon=w;Pose pose;pose.tracked=true;pose.has_offhand=true;pose.left_handed=left;pose.head.origin={0,1.65,0};pose.weapon.origin={left?-.3:.3,1.1,-.3};
  auto &hand=left?pose.right:pose.left;hand.origin=pose.weapon.apply(cq_geometry(w).magazine*.65);pose.offhand=hand;
  reload.sample(2,7,100,7,pose,false,false,0,0);
  reload.sample(2,7,100,7,pose,true,false,1./30,1./30);
  check(reload.grab==Grab::MAGAZINE,"actual authored magazine is grabbable both handednesses");
  int clip=7;
  for(int i=2;i<=5;++i){hand.origin.y-=.02;clip=reload.sample(2,clip,100,7,pose,true,false,double(i)/30,double(i)/30);}
  check(!reload.mag&&reload.carry==4&&clip==1,"tracked pull removes magazine and preserves chambered round");
 }
}
