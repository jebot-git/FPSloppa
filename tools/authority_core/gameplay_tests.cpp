#include "authority_core.h"
#include "authority_transport_geometry.h"
#include <memory>
#include <cstring>
using namespace cqauthority;
extern void check(bool, const char *);
namespace {
struct World : Host {
  Handle target{};
  V target_position;
  bool actor_hit = false, grass = false;
  bool grass_cover(V) override { return grass; }
  Moved move(const Motion &m, double dt) override {
    V position = m.position + m.velocity * dt, velocity = m.velocity;
    bool floor = position.y <= 0;
    if (floor) {
      position.y = 0;
      velocity.y = 0;
    }
    return {position, velocity, m.height, floor};
  }
  Hit trace(V, V end, Handle) override {
    return {actor_hit, target, actor_hit ? target_position : end};
  }
  Hit world_trace(V from, V to, Handle) override {
    if (from.y >= 0 && to.y < 0) {
      double t = from.y / (from.y - to.y);
      return {true, {}, from + (to - from) * t, {0, 1, 0}};
    }
    return {};
  }
};
std::unique_ptr<Core> game() {
  auto c = std::make_unique<Core>();
  CqConfig config;
  config.enabled = true;
  config.auto_respawn = false;
  check(c->configure_cq(config), "CQ config before admission");
  return c;
}
Handle join(Core &c, int id, int team) {
  auto h = c.join(id, team, {double(id * 8), 0, 0}, 1 << 2,
                {1000, 1000, 1000, 1000});
  c.resolve(h)->armor = 0; // Existing damage fixtures exercise bare health.
  return h;
}
Handle role(Core &c, Handle h, Role r, bool t2 = false) {
  auto *p = c.resolve(h);
  p->classes.next = r;
  if (t2) {
    p->classes.xp[size_t(r)] = 7500;
    check(c.choose_gear(h, int(r), 2, 2), "T2 utility choice with level 15");
  }
  p->dead = true;
  auto next = c.respawn(h, p->position);
  check(next.id != 0, "class applied on respawn");
  c.resolve(next)->invulnerable = 0;
  c.resolve(next)->armor = 0; // Existing damage/utility fixtures exercise bare health.
  return next;
}
void tick(Core &c, World &world, int &seq, bool fire = false, int weapon = -1,
          bool prone = false) {
  for (auto &p : c.players())
    if (p.active && !p.dead) {
      Command input;
      input.life = p.handle.life;
      input.seq = seq;
      input.weapon =
          weapon >= 0 && p.classes.role == Role::MEDIC ? weapon : p.weapon;
      input.fire = fire && p.classes.role == Role::MEDIC;
      input.prone = prone && p.classes.role == Role::MEDIC;
      c.submit(p.handle, input);
    }
  ++seq;
  c.advance(world);
}
} // namespace
void cq_rules_tests() {
  // Physical injector: contact, latched drift, release and native revival.
  {
    auto c=game();World world;
    auto medic=role(*c,join(*c,1,0),Role::MEDIC), victim=join(*c,2,0), enemy=join(*c,3,1);
    auto *m=c->resolve(medic), *v=c->resolve(victim);m->position={0,0,-.35};v->position={};v->invulnerable=0;c->damage(victim,enemy,100);
    Command cmd;cmd.life=medic.life;cmd.weapon=7;cmd.fire=true;cmd.weapon_held=true;cmd.pose.tracked=true;
    cmd.pose.head.origin={0,1.65,0};cmd.pose.left.origin={-.3,1,-.2};cmd.pose.right.origin={0,.35,-.756375};cmd.pose.weapon.origin=cmd.pose.right.origin;cmd.pose.weapon.basis=B::yaw(3.141592653589793);
    for(int i=0;i<40;++i){cmd.seq=i;c->submit(medic,cmd);c->advance(world);}
    check(v->inject_progress>1,"tracked authored injector tip starts revival");
    cmd.pose.right.origin.x=.5;cmd.pose.weapon.origin=cmd.pose.right.origin;
    for(int i=40;i<50;++i){cmd.seq=i;c->submit(medic,cmd);c->advance(world);}
    check(v->inject_progress>1.5,"latched injection tolerates wrist drift");
    cmd.seq=50;cmd.fire=false;c->submit(medic,cmd);c->advance(world);check(v->inject_progress==0,"trigger release cancels injection latch");
    cmd.pose.right.origin.x=0;cmd.pose.weapon.origin=cmd.pose.right.origin;cmd.fire=true;
    for(int i=51;i<145;++i){cmd.seq=i;c->submit(medic,cmd);c->advance(world);}
    check(!v->incapacitated && v->hp==35 && m->classes.xp[2]==75,"tracked injector revives once after three seconds");
  }
  // Native dragging retains a life-bound patient while either hand pulls.
  for(bool right:{false,true}) {
    auto c=game();World world;
    auto medic=role(*c,join(*c,1,0),Role::MEDIC), victim=join(*c,2,0), enemy=join(*c,3,1);
    auto *m=c->resolve(medic), *v=c->resolve(victim);m->position={0,0,-.35};v->position={};v->invulnerable=0;c->damage(victim,enemy,100);
    Command cmd;cmd.life=medic.life;cmd.weapon=3;cmd.drag=true;cmd.pose.tracked=true;cmd.pose.left_handed=right;cmd.pose.head.origin={0,1.65,0};cmd.pose.left.origin={-.3,1,-.2};cmd.pose.right.origin={.3,1,-.2};
    auto &hand=right?cmd.pose.right:cmd.pose.left;hand.origin={0,.35,-.65};cmd.pose.weapon=right?cmd.pose.left:cmd.pose.right;
    cmd.seq=0;c->submit(medic,cmd);c->advance(world);check(m->drag_target==victim,"physical hand contact latches allied patient");
    check(v->position.length()<.001,"gripping visible prone torso does not yank body origin");
    hand.origin.z=.15;
    for(int i=1;i<=15;++i){cmd.seq=i;c->submit(medic,cmd);c->advance(world);}
    check(v->position.z>.5,"latched drag follows beyond initial contact radius");
    double at=v->position.z;cmd.seq=16;cmd.drag=false;c->submit(medic,cmd);c->advance(world);check(!m->drag_target.id&&v->position.z==at,"release stops native drag");
  }
  // Native cabin repair is restricted to a technician in the front passenger seat.
  {
    struct CabinWorld:World {
      VehicleMoved move_vehicle(const Vehicle &v,V velocity,double dt)override {
        V at=v.position+velocity*dt;at.y=std::max(0.,at.y);velocity.y=0;
        return {at,velocity,{0,1,0},at.y,true,true};
      }
    } world;
    auto c=game();auto h=role(*c,join(*c,1,0),Role::TECHNICIAN);auto *p=c->resolve(h);
    int index=c->add_vehicle(VehicleKind::TRANSPORT,{},0,0);
    auto &v=const_cast<Vehicle&>(c->vehicles()[size_t(index)]);v.hp=40;p->position=transport_pods[7].entry;
    Command cmd;cmd.life=h.life;cmd.seq=0;cmd.weapon=7;cmd.vr=true;cmd.weapon_held=true;cmd.pose.tracked=true;cmd.pose.head.origin={0,1.65,0};cmd.pose.left.origin={-.3,1,-.3};cmd.pose.right.origin={.3,1,-.3};cmd.pose.weapon=cmd.pose.right;
    c->submit(h,cmd);Action board;board.seq=0;c->queue_action(h,board);c->advance(world);
    check(p->vehicle==index && p->vehicle_seat==7,"technician boards front cabin passenger seat");
    cmd.fire=true;for(int i=1;i<=30;++i){cmd.seq=i;c->submit(h,cmd);c->advance(world);}
    check(std::abs(v.hp-(40+30*30*c->step_seconds()))<.01,"held repair tool repairs own cabin transport at thirty HP per second");
    check(p->classes.xp[3]==int(30*30*c->step_seconds()/10),"cabin repair awards actual restoration XP");
    cmd.seq=31;cmd.fire=false;c->submit(h,cmd);c->advance(world);double hp=v.hp;
    check(v.hp==hp,"released repair trigger stops cabin repair");
    v.seats[7]={};v.seats[0]=h;p->vehicle_seat=0;
    cmd.seq=32;cmd.fire=true;c->submit(h,cmd);c->advance(world);
    check(v.hp==hp,"side pod cannot repair from its seat");
    v.seats[0]={};v.seats[6]=h;v.pilot=h;p->vehicle_seat=6;
    cmd.seq=33;c->submit(h,cmd);c->advance(world);check(v.hp==hp,"driver cannot repair while driving");
  }
  // Both classes hide the carried box and permit a replacement after 15 seconds.
  for(Role r:{Role::MEDIC,Role::TECHNICIAN}) {
    auto c=game();World world;auto h=role(*c,join(*c,1,0),r);auto *p=c->resolve(h);p->position={};
    Command cmd;cmd.life=h.life;cmd.seq=0;cmd.weapon=6;cmd.pose.tracked=true;cmd.pose.head.origin={0,1.65,0};cmd.pose.left.origin={-.3,1,-.2};cmd.pose.right.origin={.3,1,-.2};cmd.pose.weapon=cmd.pose.right;
    c->submit(h,cmd);c->advance(world);
    Action a;a.seq=0;a.kind=ActionKind::USE;a.a=6;a.b=2;c->queue_action(h,a);c->advance(world);
    const Box *box=nullptr;for(auto &b:c->boxes())if(b.active)box=&b;
    check(box!=nullptr,"both class boxes drop from a tracked hand");
    if(!box)continue;
    auto key=box->key;double ready=p->classes.box_ready;
    check(std::abs(ready-c->time()-15.)<.001,"first physical drop starts fifteen-second cooldown");
    cmd.seq=1;cmd.pose.right.origin={.5,1,-.5};cmd.pose.weapon=cmd.pose.right;c->submit(h,cmd);c->advance(world);
    a.seq=1;c->queue_action(h,a);c->advance(world);
    check(box->key==key && p->classes.box_ready==ready,"cooldown rejects an immediate replacement");
    while(c->time()+c->step_seconds()<ready){++cmd.seq;c->submit(h,cmd);c->advance(world);}
    check(!c->deploy_box(h,{0,0,0}),"replacement remains locked until fifteen seconds");
    ++cmd.seq;c->submit(h,cmd);c->advance(world);
    a.seq=2;c->queue_action(h,a);c->advance(world);
    Box *replacement=nullptr;int count=0;for(auto &b:c->boxes())if(b.active){++count;replacement=const_cast<Box*>(&b);}
    check(count==1 && replacement && replacement->key!=key,"replacement after fifteen seconds retires original at one-box limit");
    if(!replacement)continue;
    // Force real health/ammunition consumption of the last supply unit.
    replacement->remaining=1;if(r==Role::MEDIC)p->hp=99;else p->ammo[0]=0;
    replacement->airborne=false;replacement->position=p->position;replacement->credit[0]=1.;replacement->lives[0]=p->handle.life;
    ++cmd.seq;c->submit(h,cmd);c->advance(world);
    check(!replacement->active,"depletion removes the deployed box");
    check(std::abs(p->classes.box_ready-c->time()-15.)<.001,"depletion starts fifteen-second replacement cooldown");
  }
  // A thrown box supplies only after landing, inside a three-metre ground radius.
  {
    struct SupplyWorld:World {Hit sweep_world(V a,V b,double,Handle h,uint64_t)override{return world_trace(a,b,h);}} world;
    auto c=game();auto medic=role(*c,join(*c,1,0),Role::MEDIC);auto *m=c->resolve(medic);m->position={};m->hp=35;
    Command cmd;cmd.life=medic.life;cmd.seq=0;cmd.weapon=6;cmd.pose.tracked=true;cmd.pose.left_handed=true;cmd.pose.head.origin={0,1.65,0};cmd.pose.left.origin={-.3,1,-.2};cmd.pose.right.origin={.3,1,-.2};cmd.pose.weapon=cmd.pose.left;
    c->submit(medic,cmd);c->advance(world);m->hand_velocity[0]={2,1,0};m->hand_peak_until[0]=0;
    Action release;release.kind=ActionKind::USE;release.seq=0;release.a=6;release.b=1;check(c->queue_action(medic,release),"physical box release admitted");c->advance(world);
    const Box *box=nullptr;for(auto &b:c->boxes())if(b.active){box=&b;break;}
    check(box&&box->airborne&&m->hp==35,"box cannot heal in hand or in flight");
    if(box) {
      V origin=box->position;
      for(int i=1;i<60&&box->airborne;++i){cmd.seq=i;cmd.weapon=3;c->submit(medic,cmd);c->advance(world);}
      check(box->active&&!box->airborne&&box->position.y<.05&&box->position.x>origin.x+.1,"thrown box lands on world geometry");
      auto near=join(*c,2,0),far=join(*c,3,0);c->resolve(near)->position=box->position+V{2.99,0,0};c->resolve(far)->position=box->position+V{3.01,0,0};c->resolve(near)->hp=35;c->resolve(far)->hp=35;
      for(int i=60;i<90;++i){cmd.seq=i;c->submit(medic,cmd);c->advance(world);}
      check(c->resolve(near)->hp>35&&c->resolve(far)->hp==35,"ground medical box heals inside three metres only");
      check(!c->queue_action(medic,release),"duplicate release cannot spawn another box");
    }
  }

  {
    auto c=game();World world;auto h=join(*c,913,0);
    std::array<uint8_t,60> packet{};packet[0]='C';packet[1]='Q';packet[2]='I';packet[3]='3';packet[28]=2;
    for(int i=0;i<4;++i){packet[4+i]=uint8_t(h.life>>(i*8));}
    float value=3.;std::memcpy(packet.data()+48,&value,4);
    check(c->submit_packet(h.id,packet.data(),packet.size()),"CQI3 swimming wire admitted");c->advance(world);
    check(c->resolve(h)->input.swim.length()==1.,"untrusted swim speed is bounded");
    packet[8]=1;value=std::numeric_limits<float>::quiet_NaN();std::memcpy(packet.data()+48,&value,4);
    check(!c->submit_packet(h.id,packet.data(),packet.size()),"nonfinite swim rejected transactionally");
    value=0.;std::memcpy(packet.data()+48,&value,4);
    check(!c->submit_packet(h.id,packet.data(),packet.size()-1),"truncated swim wire rejected");
    check(c->submit_packet(h.id,packet.data(),packet.size()),"bad swim cannot poison next sequence");
  }

  for (int hz : {30, 60}) {
    auto c = game(); World world;
    check(c->configure_tick_rate(hz), "menu suicide tick rate");
    auto h = join(*c, 901, 0);
    Command input; input.life = h.life; input.seq = 0; input.weapon = 2; input.blocked = true;
    check(c->submit(h, input), "menu-blocked input accepted");
    c->advance(world);
    Action action; action.kind = ActionKind::SUICIDE; action.seq = 0;
    c->resolve(h)->last_input=-10;
    check(c->queue_action(h, action), "suicide menu action accepted");
    c->advance(world);
    auto *p = c->resolve(h);
    check(p->dead && p->deaths == 1, "suicide works with menu-blocked input and spawn protection");
    check(p->respawn_at > c->time() && p->want_respawn, "suicide preserves normal respawn delay");
    check(!c->queue_action(h, action), "replayed suicide rejected");
    action.seq = 1; c->queue_action(h, action); c->advance(world);
    check(p->deaths == 1, "dead suicide cannot award another death");
  }

  for (int hz : {30,60}) {
    struct WaterWorld:World {bool wet=true;bool water(V at) override{return wet && at.y<4.;}} world;
    auto c=std::make_unique<Core>();CqConfig cfg;cfg.enabled=true;cfg.auto_respawn=false;cfg.water_level=4.;c->configure_cq(cfg);c->configure_tick_rate(hz);
    auto h=join(*c,910,0);c->resolve(h)->position={0,0,0};
    auto input=[&](int seq,V stroke=V{}){Command in;in.life=h.life;in.seq=seq;in.weapon=2;in.swim=stroke;check(c->submit(h,in),"swimming input accepted");c->advance(world);};
    for(int i=0;i<hz*10;++i)input(i);
    check(!c->resolve(h)->dead && c->resolve(h)->hp==100,"water grants a twelve-second breathing interval");
    for(int i=hz*10;i<hz*13;++i)input(i);
    check(!c->resolve(h)->dead && c->resolve(h)->hp<100,"prolonged submersion damages gradually rather than instant kill");
    world.wet=false;input(hz*13);
    check(c->resolve(h)->air_left==12.,"surfacing restores breathing time");
    world.wet=true;
    for(int i=hz*13+1;i<hz*14;++i)input(i,{0,0,-1});
    check(c->resolve(h)->position.z<-2. && c->resolve(h)->position.y>0.5,"swim stroke moves and buoys swimmer towards surface");
    const double hp=c->resolve(h)->hp;
    for(int i=hz*14;i<hz*15;++i)input(i,{0,0,-1});
    check(c->resolve(h)->hp==hp,"resurfacing avoids further drowning damage");
  }
  for (int hand : {0,1}) {
    auto c=game();World world;auto h=join(*c,911,0);auto *p=c->resolve(h);
    p->position={};p->pose.tracked=true;p->pose.has_offhand=true;p->pose.head.origin={0,1.65,0};
    p->pose.left.origin={-.3,1.2,-.3};p->pose.right.origin={.3,1.2,-.3};
    p->pose.weapon=p->pose.right;p->pose.offhand=p->pose.left;p->pose.offhand.basis=B::yaw(.5);
    Command in;in.life=h.life;in.seq=0;in.weapon=2;in.pose=p->pose;in.vr=true;in.weapon_held=false;
    c->submit(h,in);c->advance(world);
    Action arm;arm.kind=ActionKind::GRENADE_ARM;arm.seq=0;arm.a=2+hand;c->queue_action(h,arm);c->advance(world);
    check(p->grenade_primed && p->grenade_hand==hand,"grenade binds explicit physical hand");
    for(int i=1;i<=4;++i){in.seq=i;(hand==0?in.pose.left:in.pose.right).origin.y+=.05;c->submit(h,in);c->advance(world);}
    // Release can occur after the hand has stopped: retain recent bounded swing power.
    in.seq=5;c->submit(h,in);c->advance(world);
    Action release;release.kind=ActionKind::GRENADE_THROW;release.seq=1;c->queue_action(h,release);c->advance(world);
    bool launched=false;
    for(const auto &g:c->grenades())if(g.active){launched=g.velocity.length()>3.;check((g.velocity.unit()-B::yaw(hand==0?0.:.5).apply({0,0,-1})).length()<.3,"grenade follows the free hand's aim");}
    check(launched && !p->grenade_primed && p->grenade_count==2,"armed grenade launches once from either hand after release");
    int seq=6;int action_seq=2;
    auto sync_pose=[&](){in.pose.weapon.origin=in.pose.right.origin;in.pose.offhand.origin=in.pose.left.origin;};
    for(int remaining:{1,0}) {
      p->position.x+=100; // Keep earlier blasts away from the control fixture.
      for(int frame=0;frame<24;++frame){in.seq=seq++;c->submit(h,in);c->advance(world);}
      arm.seq=action_seq++;c->queue_action(h,arm);c->advance(world);
      check(p->grenade_primed,"each remaining loadout grenade arms after cooldown");
      for(int frame=0;frame<4;++frame){in.seq=seq++;(hand==0?in.pose.left:in.pose.right).origin.y+=.04;sync_pose();check(c->submit(h,in),"repeated throw keeps hand and aim origins coherent");c->advance(world);}
      release.seq=action_seq++;c->queue_action(h,release);c->advance(world);
      bool fresh=false;for(const auto &g:c->grenades())fresh|=g.active && g.age<.1 && g.velocity.length()>3.;
      check(fresh&&!p->grenade_primed&&p->grenade_count==remaining,"second and third grenades physically launch and consume exactly one charge");
    }
    arm.seq=action_seq++;c->queue_action(h,arm);c->advance(world);
    check(!p->grenade_primed&&p->grenade_count==0,"empty grenade inventory cannot arm a phantom fourth grenade");
    p->position.x+=100;
    auto technician=role(*c,join(*c,913,0),Role::TECHNICIAN);c->resolve(technician)->position=p->position+V{2,0,0};
    check(c->deploy_box(technician,p->position),"technician ammo box deployed for grenade resupply regression");
    for(int frame=0;frame<600 && p->grenade_count<3;++frame){in.seq=seq++;c->submit(h,in);c->advance(world);}
    check(p->grenade_count==3,"ammo box restores the three-grenade loadout");
    c->clear_supply(technician);arm.seq=action_seq++;c->queue_action(h,arm);c->advance(world);
    for(int frame=0;frame<4;++frame){in.seq=seq++;(hand==0?in.pose.left:in.pose.right).origin.y+=.04;sync_pose();check(c->submit(h,in),"repeated throw keeps hand and aim origins coherent");c->advance(world);}
    release.seq=action_seq++;c->queue_action(h,release);c->advance(world);
    check(p->grenade_count==2&&!p->grenade_primed,"resupplied grenade throws again with the same tracked hand");
  }
  for(Role role : {Role::MEDIC,Role::TECHNICIAN}) {
    auto c=game();World world;auto h=join(*c,912,0);auto *p=c->resolve(h);p->classes.next=role;p->dead=true;h=c->respawn(h,{0,0,0});p=c->resolve(h);
    Command input;input.life=h.life;input.seq=0;input.weapon=p->weapon;c->submit(h,input);c->advance(world);p->cooldown=.28;
    Action deploy;deploy.seq=0;deploy.kind=ActionKind::USE;deploy.a=6;c->queue_action(h,deploy);c->advance(world);
    bool box=false;for(const auto &b:c->boxes())box|=b.active && b.owner.id==h.id;
    check(box,"medic/technician explicit box action deploys from held primary");
  }
  // Exercise authority dispatch as well as the golden-reference swing sampler.
  for (int hz : {30, 60}) {
    auto c = game(); World world;
    check(c->configure_tick_rate(hz), "melee fixture tick rate");
    auto attacker = join(*c, 1, 0), victim = join(*c, 2, 1);
    auto *p = c->resolve(attacker);
    p->position = {}; p->weapon = 2;
    p->invulnerable = 0; c->resolve(victim)->invulnerable = 0;
    world.actor_hit = true; world.target = victim;
    world.target_position = {0, 1, -1};
    int seq = 0; bool offhand = false;
    auto step = [&](double x, bool held = true, bool vr = true, bool tracked = true) {
      Command cmd; cmd.life = attacker.life; cmd.seq = seq++;
      cmd.weapon = 2; cmd.melee = true; cmd.vr = vr; cmd.weapon_held = held;
      cmd.pose.tracked = vr && tracked; cmd.pose.has_offhand = offhand;
      cmd.pose.head.origin = {0, 1.65, 0};
      cmd.pose.weapon.origin = {x, 1.1, -.6};
      cmd.pose.offhand.origin = {-x, 1.1, -.6};
      cmd.pose.right = cmd.pose.weapon; cmd.pose.left = cmd.pose.offhand;
      check(c->submit(attacker, cmd), "melee fixture input accepted");
      c->advance(world);
    };
    step(-.8, false); step(-.65, false); step(-.45, false);
    check(p->melee_ready == 0 && c->resolve(victim)->hp == 100,
          "unheld tracked weapon cannot melee even with forged melee input");
    step(-.8); step(-.65); step(-.45);
    check(c->resolve(victim)->hp == 90, "held tracked weapon whip deals FPSloppa 10 damage once");
    double ready = p->melee_ready;
    check(std::abs(ready - (c->time() - 1. / hz + .8)) < 1e-9,
          "both hands share FPSloppa 0.8 second cooldown");
    for (int i = 0; i < hz; ++i) step(i % 2 ? -.45 : -.3);
    check(c->resolve(victim)->hp == 90 && p->melee_ready == ready,
          "continuous flailing cannot rearm after cooldown");
    step(-.45); // Stop moving to rearm before a deliberate second swing.
    step(-.3);
    check(c->resolve(victim)->hp == 80, "rested weapon can melee again after cooldown");
    ready = p->melee_ready; offhand = true;
    step(-.3, false); step(-.3); step(-.15);
    check(p->melee_ready == ready && c->resolve(victim)->hp == 80,
          "release, regrip and alternating hands cannot bypass activation delay");
    for (int i = 0; i < hz; ++i) step(-.3, true, true, false);
    check(c->resolve(victim)->hp == 80, "lost tracking cannot deal melee damage");
    step(-.3, true, false);
    ready = p->melee_ready;
    for (int i = 0; i < hz / 2; ++i) step(-.3, true, false);
    check(p->melee_ready == ready && c->resolve(victim)->hp == 70,
          "desktop melee also retains shared 0.8 second delay");
  }
  {
    ClassState state;
    for (int xp : {0, 499, 500, 2499, 2500, 4999, 5000, 7499, 7500, 20000}) {
      state.xp.fill(xp);
      state.role = Role::MEDIC;
      check(state.level() == xp / 500, "500 XP per level");
      check(state.box_limit() == std::clamp(xp / 2500, 1, 3),
            "box level thresholds");
      check(state.choose(2, 0, 12) == (xp >= 2500), "primary level 5 gate");
      check(state.choose(2, 1, 0) == (xp >= 5000), "secondary level 10 gate");
      check(state.choose(2, 2, 2) == (xp >= 7500), "utility level 15 gate");
    }
    check(!state.choose(4, 0, 1) && !state.choose(0, 4, 1) &&
              !state.choose(0, 0, 11),
          "role/slot/weapon validation");
    state.xp[2] = INT32_MAX - 1;
    state.award(100);
    check(state.xp[2] == INT32_MAX, "XP cannot overflow");
  }
  {
    Points p;
    p.count = 1;
    std::array<std::array<bool, 2>, MAX_ZONES> presence{};
    presence[0][0] = true;
    p.advance(9.99, presence);
    check(p.zones[0].owner == -1, "capture not early");
    p.advance(.01, presence);
    check(p.zones[0].owner == 0 && p.scores[0] == 0 && p.zones[0].credit == 0,
          "no retroactive capture income");
    p.advance(10, presence);
    check(p.scores[0] == 1, "one point per POI per ten seconds");
    presence[0][1] = true;
    p.advance(30, presence);
    check(p.zones[0].contested && p.scores[0] == 4,
          "contested capture stops progress but holding income continues");
    presence[0][0] = false;
    p.advance(10, presence);
    check(p.zones[0].owner == 1 && p.zones[0].credit == 0,
          "enemy capture resets income credit");
    Points q;
    q.count = 2;
    q.zones[0].owner = 0;
    q.zones[1].owner = 1;
    q.scores = {199, 199};
    q.advance(10, {});
    check(q.winner == -1 && q.scores[0] == 200 && q.scores[1] == 200,
          "simultaneous income draw");
    Points k;
    k.count = 3;
    k.zones[0].owner = 0;
    k.zones[1].owner = 0;
    k.zones[2].owner = 0;
    check(k.kill(0) == 3 && k.scores[0] == 3, "kill multiplied by held POIs");
    check(k.kill(1) == 0 && k.scores[1] == 0,
          "zero held POIs yields zero kill points");
    k.scores[0] = 199;
    k.kill(0);
    check(k.winner == 0 && k.scores[0] == 200, "score caps at winning 200");
  }
  {
    auto c = game();
    World world;
    auto a = join(*c, 1, 0), b = join(*c, 2, 1);
    check(c->resolve(a)->ammo[0] == 14 && c->resolve(a)->ammo[1] == 120 &&
              c->resolve(a)->weapon == 4,
          "native class loadout capacities");
    check(!c->damage(b, a, 100), "spawn invulnerability");
    c->resolve(b)->invulnerable = 0;
    c->points.count = 1;
    c->points.zones[0].owner = 0;
    check(c->damage(b, a, 100) && c->resolve(b)->incapacitated &&
              c->resolve(b)->hp == 1,
          "ordinary lethal damage incapacitates");
    check(c->resolve(a)->kills == 0, "incapacitation not a kill");
    c->damage(b, a, 18);
    check(c->resolve(b)->incapacitated && !c->resolve(b)->dead,
          "ordinary follow-up does not bypass revival window");
    c->damage(b, a, 1, DamageKind::BULLET, true);
    check(c->resolve(b)->dead && c->resolve(a)->kills == 1 &&
              c->points.scores[0] == 1 && c->resolve(a)->classes.xp[0] == 100,
          "headshot final death awards kill points and XP once");
    auto next = c->respawn(b, {0, 0, 0});
    c->resolve(next)->invulnerable = 0;
    c->resolve(next)->armor = 0;
    check(!c->damage(b, a, 1000), "old life cannot damage respawn");
    c->damage(next, a, 100);
    for (int i = 0; i < 301; ++i)
      c->advance(world);
    check(c->resolve(next)->dead, "ten second bleedout kills");
  }
  {
    auto c = game();
    World world;
    int seq = 0;
    auto medic = role(*c, join(*c, 1, 0), Role::MEDIC);
    auto victim = join(*c, 2, 0);
    auto enemy = join(*c, 3, 1);
    c->resolve(victim)->invulnerable = 0;
    c->resolve(victim)->position = {0, 0, 0};
    c->resolve(medic)->position = {0, 0, .15};
    c->damage(victim, enemy, 100);
    for (int i = 0; i < 40; ++i)
      tick(*c, world, seq, true, 7, true);
    check(c->resolve(victim)->inject_progress > 1 &&
              c->resolve(victim)->bleed_remaining > 9.9,
          "continuous medic contact pauses bleedout");
    tick(*c, world, seq, false, 7, true);
    check(c->resolve(victim)->inject_progress == 0,
          "broken injection resets progress");
    for (int i = 0; i < 92; ++i)
      tick(*c, world, seq, true, 7, true);
    check(!c->resolve(victim)->incapacitated && c->resolve(victim)->hp == 35 &&
              c->resolve(medic)->classes.xp[2] == 75,
          "three second injection revives at 35 HP and awards 75 XP");
  }
  {
    auto c = game();
    World world;
    int seq = 0;
    auto tech = role(*c, join(*c, 1, 0), Role::TECHNICIAN);
    c->resolve(tech)->classes.xp[3] = 7500;
    tick(*c, world, seq);
    check(c->deploy_box(tech, c->resolve(tech)->position), "first dispenser");
    check(!c->deploy_box(tech, c->resolve(tech)->position),
          "15 second dispenser cooldown");
    for (int n = 0; n < 3; ++n) {
      for (int i = 0; i < 901; ++i)
        tick(*c, world, seq);
      check(c->deploy_box(tech, c->resolve(tech)->position),
            "new box at cooldown boundary");
    }
    int count = 0;
    uint64_t oldest = UINT64_MAX;
    for (auto &b : c->boxes())
      if (b.active) {
        ++count;
        oldest = std::min(oldest, b.key);
      }
    check(count == 3 && oldest == 2,
          "fourth deployment retires oldest at level 15 limit");
    auto who = c->resolve(tech)->session_token;
    c->damage(tech, tech, 10000, DamageKind::VEHICLE_DESTROYED);
    auto respawn = c->respawn(tech, {0, 0, 0});
    check(c->resolve(respawn)->session_token == who,
          "respawn preserves deployment session owner");
    count = 0;
    for (auto &b : c->boxes())
      count += b.active;
    check(count == 3, "death does not erase valid owned boxes");
    c->leave(respawn);
    count = 0;
    for (auto &b : c->boxes())
      count += b.active;
    check(count == 0, "disconnect removes old-session dispensers");
  }
  {
    auto c = game();
    World world;
    int seq = 0;
    auto tech = role(*c, join(*c, 1, 0), Role::TECHNICIAN);
    auto target = role(*c, join(*c, 2, 0), Role::TECHNICIAN);
    c->resolve(tech)->position = {0, 0, 0};
    c->resolve(target)->position = {1, 0, 0};
    tick(*c, world, seq);
    check(c->deploy_box(tech, {0, 0, 0}), "ammo dispenser placed");
    c->resolve(target)->ammo[2] -= 3;
    for (int i = 0; i < 449; ++i)
      tick(*c, world, seq);
    check(c->resolve(target)->ammo[2] == 6,
          "launcher pack not partially supplied");
    for (int i = 0; i < 3; ++i)
      tick(*c, world, seq);
    check(c->resolve(target)->ammo[2] == 9,
          "launcher pack costs atomic 300 units");
    check(c->resolve(tech)->classes.xp[3] == 30,
          "weighted supply awards actual 300 cost XP");
  }
  {
    auto c = game();
    World world;
    int seq = 0;
    auto medic = role(*c, join(*c, 1, 0), Role::MEDIC, true);
    check(c->resolve(medic)->grenade_count == 3 &&
              !(c->resolve(medic)->owned & (1 << 6)),
          "medic T2 replaces box and carries three grenades");
    tick(*c, world, seq);
    Action action;
    action.seq = 0;
    action.kind = ActionKind::GRENADE_ARM;
    check(c->queue_action(medic, action), "reliable arm queued");
    action.seq = 1;
    action.kind = ActionKind::GRENADE_THROW;
    check(c->queue_action(medic, action), "reliable throw queued");
    tick(*c, world, seq);
    check(c->resolve(medic)->grenade_count == 2, "throw consumes one grenade");
    for (int i = 0; i < 48; ++i)
      tick(*c, world, seq);
    V at;
    bool found = false;
    for (auto &f : c->fields())
      if (f.active) {
        found = true;
        at = f.position;
      }
    check(found, "healing grenade activates field after fuse");
    for (int i = 2; i < 8; ++i) {
      auto h = join(*c, i, 0);
      c->resolve(h)->position = at;
      c->resolve(h)->hp = 1;
      c->resolve(h)->invulnerable = 0;
    }
    for (int i = 0; i < 257; ++i)
      tick(*c, world, seq);
    bool empty = false;
    for (auto &f : c->fields())
      if (f.active)
        empty = f.health == 0 && f.energy == 500;
    check(empty, "healing pool exhaustion leaves shield alive");
    for (int i = 0; i < 60; ++i)
      tick(*c, world, seq);
    found = false;
    for (auto &f : c->fields())
      found |= f.active;
    check(!found, "healing field expires at ten seconds");
  }
  {
    auto c = game();
    World world;
    int seq = 0;
    auto a = join(*c, 1, 0), b = join(*c, 2, 1);
    c->resolve(a)->classes.role = Role::SCOUT;
    c->cq.light_fraction = 0;
    check(c->spot_range(*c->resolve(a)) == 25 &&
              c->spot_range(*c->resolve(b)) == 15,
          "dark spotting range per class");
    c->resolve(a)->classes.nvg = true;
    c->resolve(b)->classes.nvg = true;
    check(c->spot_range(*c->resolve(a)) == 100 &&
              c->spot_range(*c->resolve(b)) == 50,
          "night vision spotting range");
    c->resolve(a)->classes.blind_until = 10;
    check(c->spot_range(*c->resolve(a)) == 0, "NVG glare blinds spotting");
    c->cq.light_fraction = 1;
    c->resolve(a)->classes.blind_until = 0;
    check(c->spot_range(*c->resolve(a)) == 150 &&
              c->spot_range(*c->resolve(b)) == 75,
          "day spotting range");
    tick(*c, world, seq);
    Action x;
    x.seq = 0;
    x.kind = ActionKind::NVG;
    check(c->queue_action(a, x), "NVG action queued");
    check(!c->queue_action(a, x), "duplicate reliable action rejected");
    tick(*c, world, seq);
    check(!c->resolve(a)->classes.nvg, "native NVG action toggles");
  }
  {
    auto c = game();
    World world;
    auto observer = join(*c, 1, 0), target = join(*c, 2, 1);
    c->resolve(observer)->position = {0, 0, 0};
    c->resolve(target)->position = {20, 0, 0};
    int seq = 0;
    auto advance = [&](bool prone, int count) {
      for (int n = 0; n < count; ++n) {
        for (auto handle : {observer, target}) {
          Command cmd; cmd.life = handle.life; cmd.seq = ++seq;
          cmd.weapon = c->resolve(handle)->weapon;
          cmd.prone = handle == target && prone;
          check(c->submit(handle, cmd), "concealment fixture input");
        }
        c->advance(world);
      }
    };
    advance(true, 3);
    check(c->resolve(target)->spotted[0] > c->time(), "prone on bare ground remains visible at 20m");
    world.grass = true; c->resolve(target)->spotted = {};
    advance(true, 3);
    check(c->resolve(target)->grass_concealed && Core::detection_scale(*c->resolve(target)) == .25,
          "native prone grass cover has 75 percent reduction");
    check(c->resolve(target)->spotted[0] == 0, "native 20m target exceeds 18.75m concealed range");
    c->resolve(target)->position.x = 10; advance(true, 3);
    check(c->resolve(target)->spotted[0] > c->time(), "native target inside concealed range is spotted");
    c->resolve(target)->position.x = 20; advance(true, 3);
    check(c->resolve(target)->spotted[0] > c->time(), "native concealment preserves existing memory");
    advance(true, 310);
    check(c->resolve(target)->spotted[0] <= c->time(), "native concealment prevents memory refresh outside range");
    advance(false, 3);
    check(c->resolve(target)->spotted[0] > c->time() && Core::detection_scale(*c->resolve(target)) == 1,
          "standing cancels concealment");
    check(weapons()[5].speed * weapons()[5].speed / weapons()[5].gravity >= 200,
          "native launcher ballistic envelope reaches 200m");
    check(weapons()[11].range >= 500, "native guided missile supports 500m travel");
  }

}
