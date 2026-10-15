#include "authority_core.h"
#include "authority_tick.h"
#include <cstring>
#include <iostream>
#include <limits>
#include <memory>
#include <random>
#include <stdexcept>
using namespace cqauthority;
int checks = 0;
void check(bool b, const char *message) {
  ++checks;
  if (!b)
    throw std::runtime_error(message);
}
struct Flat : Host {
  Handle target{};
  bool hit = false, edge_value = false;
  int rays = 0, moves = 0;
  bool edge(const Motion &) override { return edge_value; }
  Moved move(const Motion &m, double dt) override {
    ++moves;
    V p = m.position + m.velocity * dt, v = m.velocity;
    bool floor = p.y <= 0;
    if (floor) {
      p.y = 0;
      v.y = 0;
    }
    return {p, v, m.height, floor};
  }
  Hit trace(V, V to, Handle) override {
    ++rays;
    return {hit, target, to};
  }
};
Handle add(Core &c, int64_t id = 1, int team = 1, int weapon = 2) {
  return c.join(id, team, {double(id * 4), 0, 0}, 1 << weapon,
                {1000, 1000, 1000, 1000});
}
Command cmd(Handle h, int seq = 0, int w = 2) {
  Command c;
  c.life = h.life;
  c.seq = seq;
  c.weapon = w;
  return c;
}
void inputs() {
  auto c = std::make_unique<Core>();
  Flat host;
  auto h = add(*c);
  check(h.id == 1, "join");
  check(!add(*c).id, "duplicate id");
  auto a = cmd(h);
  a.x = 3;
  a.z = 4;
  check(c->submit(h, a), "input valid");
  check(!c->submit(h, a), "duplicate sequence");
  c->advance(host);
  check(std::abs(c->find(1)->input.x - .6) < 1e-12, "normalised input");
  auto old = c->find(1)->last_seq;
  a.seq = 1;
  a.yaw = std::numeric_limits<double>::quiet_NaN();
  check(!c->submit(h, a) && c->find(1)->last_seq == old,
        "nonfinite transactional reject");
  a = cmd(h, 1);
  a.weapon = 4;
  check(!c->submit(h, a), "unowned weapon");
  a = cmd(h, 1);
  a.life++;
  check(!c->submit(h, a), "wrong life");
  for (int i = 1; i <= 32; ++i)
    check(c->submit(h, cmd(h, i)), "queue fill");
  check(!c->submit(h, cmd(h, 33)), "bounded queue reject");
  check(c->find(1)->last_seq == 32, "overflow doesn't poison sequence");
  c->advance(host);
  check(c->submit(h, cmd(h, 33)), "overflow recovery");
  for (int i = 0; i < 20; ++i)
    c->advance(host);
  check(c->find(1)->input.blocked && !c->find(1)->input.fire,
        "stale input timeout");
  check(c->leave(h), "leave");
  auto next = add(*c);
  check(next.life != h.life, "life generation unique");
  check(!c->submit(h, cmd(h, 1000)), "stale session input reject");
  check(!c->damage(h, next, 100), "stale victim reject");
  check(!c->leave(h) && c->find(1),
        "stale disconnect cannot remove replacement");
}
void wire() {
  auto core = std::make_unique<Core>();
  auto h = add(*core);
  std::array<uint8_t, 30> bytes{};
  bytes[0] = 'C';
  bytes[1] = 'Q';
  bytes[2] = 'I';
  bytes[3] = '1';
  bytes[4] = uint8_t(h.life);
  bytes[28] = 2;
  check(core->submit_packet(1, bytes.data(), bytes.size()),
        "packed input accepted");
  for (size_t size = 0; size < 31; ++size)
    if (size != 30)
      check(!core->submit_packet(1, bytes.data(), size),
            "truncated/oversized packet rejected before read");
  std::mt19937 rng(123);
  for (int trial = 0; trial < 10000; ++trial) {
    for (auto &byte : bytes)
      byte = rng() % 256;
    check(!core->submit_packet(1, bytes.data(), bytes.size()),
          "random corrupt packet rejected");
  }
  bytes.fill(0);
  bytes[0] = 'C';
  bytes[1] = 'Q';
  bytes[2] = 'I';
  bytes[3] = '1';
  bytes[4] = uint8_t(h.life);
  bytes[8] = 1;
  bytes[28] = 2;
  bytes[29] = 128;
  check(!core->submit_packet(1, bytes.data(), 30), "reserved flag rejected");
  bytes[29] = 0;
  bytes[22] = 0xc0;
  bytes[23] = 0x7f;
  check(!core->submit_packet(1, bytes.data(), 30), "packed NaN rejected");
  bytes[22] = 0;
  bytes[23] = 0;
  check(core->submit_packet(1, bytes.data(), 30),
        "invalid packed input did not poison sequence");
}
void movement() {
  auto c = std::make_unique<Core>();
  Flat host;
  auto h = add(*c);
  c->advance(host);
  auto a = cmd(h);
  a.x = 1;
  check(c->submit(h, a), "movement input");
  c->advance(host);
  check(std::abs(c->find(1)->velocity.x - (250. / 32) * 5 * DT) < 1e-10,
        "CS ground acceleration");
  a.seq++;
  a.x = 0;
  a.jump = true;
  c->submit(h, a);
  c->advance(host);
  check(c->find(1)->position.y > 0 && c->find(1)->velocity.y > 0, "jump");
  double highest = 0;
  for (int i = 0; i < 150; ++i) {
    a.seq++;
    c->submit(h, a);
    c->advance(host);
    highest = std::max(highest, c->find(1)->position.y);
  }
  check(highest > 1 && c->find(1)->grounded,
        "jump lands with held button no autojump");
  a.seq++;
  a.jump = false;
  a.prone = true;
  c->submit(h, a);
  c->advance(host);
  check(c->find(1)->height == .65, "prone");
  // Release within a tick must not discard a short jump press.
  a.prone = false;
  a.seq++;
  a.jump = true;
  c->submit(h, a);
  a.seq++;
  a.jump = false;
  c->submit(h, a);
  c->advance(host);
  check(c->find(1)->velocity.y > 0, "queued short jump survives release");
}
void combat() {
  auto c = std::make_unique<Core>();
  Flat host;
  auto a = add(*c), b = add(*c, 2, 2);
  host.hit = true;
  host.target = b;
  auto input = cmd(a);
  input.fire = true;
  c->submit(a, input);
  input.seq++;
  input.fire = false;
  c->submit(a, input);
  c->advance(host);
  check(c->find(1)->shots == 1 && c->find(2)->hp == 75,
        "short trigger and hitscan damage");
  check(!c->damage(b, a, -1) &&
            !c->damage(b, a, std::numeric_limits<double>::infinity()),
        "invalid damage");
  auto friend_h = add(*c, 3, 1);
  check(!c->damage(friend_h, a, 100), "friendly fire gate");
  check(c->damage(b, a, 100) && c->find(2)->dead && c->find(1)->kills == 1,
        "death attribution");
  check(!c->damage(b, a, 100) && c->find(1)->kills == 1, "death once");
  auto new_b = c->respawn(b, {8, 0, 0});
  check(new_b.id && new_b.life != b.life && c->find(2)->hp == 100, "respawn");
  check(!c->damage(b, a, 100), "delayed damage cannot affect respawn");
  // Reload has resident magazine state, never fabricates reserve ammunition.
  auto *p = c->resolve(a);
  p->clips[2] = 0;
  p->ammo[0] = 5;
  host.hit = false;
  input = cmd(a, 2);
  c->submit(a, input);
  for (int i = 0; i < 12; ++i) {
    input.seq++;
    c->submit(a, input);
    c->advance(host);
  }
  check(p->reloading == 2, "auto reload");
  for (int i = 0; i < 68; ++i) {
    input.seq++;
    c->submit(a, input);
    c->advance(host);
  }
  check(p->reloading == -1 && p->clips[2] == 5 && p->ammo[0] == 5,
        "reload completion bounded by total ammo");
  input.seq++;
  input.reload = true;
  c->submit(a, input);
  c->advance(host);
  check(p->reloading == -1, "full partial reserve cannot reload forever");
}
void projectiles() {
  auto c = std::make_unique<Core>();
  Flat host;
  auto a = add(*c, 1, 1, 5), b = add(*c, 2, 2);
  auto input = cmd(a, 0, 5);
  input.fire = true;
  for (int i = 0; i < 26; ++i) {
    input.seq = i;
    c->submit(a, input);
    c->advance(host);
  }
  check(c->find(1)->shots == 3, "charged three-round salvo");
  check(c->find(1)->ammo[2] == 997 && c->find(1)->clips[5] == 0,
        "salvo pays once");
  auto rocket = std::make_unique<Core>();
  auto owner = add(*rocket, 1, 1, 4), friend_h = add(*rocket, 2, 1);
  auto shot = cmd(owner, 0, 4);
  shot.fire = true;
  rocket->submit(owner, shot);
  rocket->advance(host);
  rocket->leave(owner);
  host.hit = true;
  host.target = friend_h;
  rocket->advance(host);
  check(rocket->find(2)->hp == 100,
        "projectile preserves team after owner disconnect");
  // Recycled IDs cannot inherit kill credit from an earlier life.
  auto k = std::make_unique<Core>();
  Flat kh;
  auto old = add(*k, 1, 1, 4), victim = add(*k, 2, 2);
  auto trigger = cmd(old, 0, 4);
  trigger.fire = true;
  k->submit(old, trigger);
  k->advance(kh);
  k->leave(old);
  auto replacement = add(*k, 1, 1, 4);
  kh.hit = true;
  kh.target = victim;
  k->resolve(victim)->hp = 1;
  k->advance(kh);
  check(k->resolve(replacement)->kills == 0,
        "projectile credit life isolation");
}
void tick_rate_tests() {
  for (int hz : {30, 60}) {
    auto c = std::make_unique<Core>(); Flat host;
    check(c->tick_rate() == 30 && c->step_seconds() == DT, "default rate remains 30 Hz");
    check(!c->configure_tick_rate(0) && !c->configure_tick_rate(59) && !c->configure_tick_rate(120), "unsupported rates rejected");
    check(c->configure_tick_rate(hz), "configure supported tick rate before use");
    auto h = c->join(1, 1, {0, 50, 0}, 1 << 4, {100,100,100,100});
    check(!c->configure_tick_rate(hz), "cannot change rate after admission");
    c->resolve(h)->cooldown = 1.;
    int publications = 0; uint64_t previous_frame_tick = 0;
    for (int n=0; n<hz/2; ++n) {
      auto input = cmd(h,n,4); check(c->submit(h,input), "rated input accepted");
      c->advance(host);
      const auto &frame = c->frame(); uint64_t frame_tick = 0;
      if (frame.size() >= 12) for (int b=0;b<8;++b) frame_tick |= uint64_t(frame[4+b]) << (8*b);
      if (frame_tick != previous_frame_tick) { ++publications; previous_frame_tick = frame_tick; }
    }
    check(publications == 10, "snapshot construction stays at 20 Hz at either rate");
    check(std::abs(c->time()-.5)<1e-12, "native clock matches real half-second");
    check(std::abs(c->resolve(h)->cooldown-.5)<1e-9, "cooldown uses configured seconds");
    check(std::abs(c->resolve(h)->position.y-46.875)<1e-8, "gravity integrates the same wall duration");
    for (int n=hz/2;n<hz;++n) { auto input=cmd(h,n,4); c->submit(h,input); c->advance(host); }
    check(c->tick()==uint64_t(hz) && std::abs(c->time()-1.)<1e-12, "one-second tick count and clock match");
    check(!c->configure_tick_rate(30), "cannot retime a running authority");
  }
}
void adaptive_tick_tests() {
  TickGovernor governor;
  check(!governor.observe(1000,1./60),"governor is opt-in");governor.enable();
  check(!governor.observe(NAN,1./60) && !governor.observe(1,-1),"invalid governor samples rejected");
  auto feed=[&](int ticks,double work,double wall) {for(int i=0;i<ticks;++i)check(governor.observe(work,wall),"valid load observation");};
  feed(1200,14500,1./60);check(governor.pending==60,"below-budget 64-player-like work retains 60 Hz");
  feed(121,15500,1./60);check(governor.pending==60,"one marginal pressure window does not flap");
  feed(121,15500,1./60);check(governor.pending==30,"sustained callback pressure requests fallback");
  check(!governor.commit(60) && governor.commit(30),"only pending transition commits");
  feed(600,5000,1./30);check(governor.pending==30,"recovery respects 30-second minimum residence");
  feed(310,5000,1./30);check(governor.pending==60 && governor.commit(60),"sustained headroom permits recovery");
  feed(230,1000,.025);check(governor.pending==30,"slow scheduling triggers fallback even with cheap callbacks");
  check(governor.fallbacks==1 && governor.recoveries==1,"transition counters track commits only");
  TickGovernor emergency;emergency.enable();
  for(int i=0;i<16;++i)emergency.observe(18000,1./60);
  check(emergency.pending==60,"short severe spike does not instantly change rate");
  for(int i=0;i<16;++i)emergency.observe(18000,1./60);
  check(emergency.pending==30,"sustained over-budget work gets emergency half-second fallback");
  auto c=std::make_unique<Core>();Flat host;c->configure_tick_rate(60);
  auto h=c->join(1,1,{0,50,0},1<<4,{100,100,100,100});c->resolve(h)->cooldown=2.;
  int snapshots=0;uint64_t previous=0;double previous_time=0.;
  for(int phase=0;phase<3;++phase) {
    int hz=phase==1?30:60;check(c->transition_tick_rate(hz),"running core accepts supported transition");
    for(int i=0;i<hz/2;++i) {
      c->advance(host);check(c->time()>previous_time,"clock never rewinds across transitions");previous_time=c->time();
      if(c->snapshot_tick()!=previous){++snapshots;previous=c->snapshot_tick();}
    }
    check(std::abs(c->time()-(phase+1)*.5)<1e-12,"mixed-rate clock preserves elapsed seconds");
    check(std::abs(c->resolve(h)->cooldown-(1.5-phase*.5))<1e-9,"cooldown survives live transitions");
  }
  check(snapshots==30,"20 Hz snapshots survive 60/30/60 transitions");
  check(std::abs(c->resolve(h)->position.y-21.875)<1e-8,"mixed-rate gravity preserves trajectory");
  check(!c->transition_tick_rate(45),"unsupported running rate rejected");
  auto irregular=std::make_unique<Core>();snapshots=0;previous=0;
  for(auto schedule : {std::pair<int,int>{60,17},{30,11},{60,19}}) {
    irregular->transition_tick_rate(schedule.first);
    for(int i=0;i<schedule.second;++i) {
      irregular->advance(host);
      if(irregular->snapshot_tick()!=previous){++snapshots;previous=irregular->snapshot_tick();}
    }
  }
  check(std::abs(irregular->time()-58./60)<1e-12 && snapshots==19,"off-boundary transitions retain clock and snapshot phase");
  auto admission=std::make_unique<Core>();admission->configure_tick_rate(60);
  admission->join(1,1,{0,50,0},1<<4,{100,100,100,100});
  for(int i=0;i<3;++i)admission->advance(host);
  admission->join(2,1,{4,50,0},1<<4,{100,100,100,100});admission->advance(host);
  check(admission->snapshot_tick()!=admission->tick() && admission->frame()[12]==1,"admission can leave a pre-barrier snapshot pending");
  admission->advance(host);admission->advance(host);
  check(admission->snapshot_tick()==admission->tick() && admission->frame()[12]==2,"fresh publication contains the complete admitted roster");
}
void experimental_team_limit_tests() {
  auto c=std::make_unique<Core>(); CqConfig config;config.enabled=true;config.squads=true;
  check(config.team_limit==32 && config.squad_limit()==8,"production team and squad caps unchanged");
  config.team_limit=63;check(!c->configure_cq(config),"unsupported team capacity rejected");
  config.team_limit=64;check(c->configure_cq(config),"experimental 64-per-team configuration accepted");
  for(int i=0;i<128;++i) {
    auto h=c->join(i+1,i%2,{double(i*4),0,0},1<<4,{100,100,100,100});
    check(h.id!=0,"experimental admission reaches 128 actors");
    check(c->join_squad(h,-1),"every experimental actor receives a squad");
  }
  for(int team=0;team<2;++team)for(int squad=0;squad<4;++squad)
    check(c->squad_size(team,squad)==16,"experimental squads contain 16 members");
  check(!c->join(129,0,{0,0,0},1<<4,{100,100,100,100}).id,"experimental capacity remains bounded at 128");
}
void snapshots_and_replay() {
  auto a = std::make_unique<Core>(), b = std::make_unique<Core>();
  Flat ha, hb;
  std::vector<Handle> aa, bb;
  for (int i = 0; i < 64; ++i) {
    aa.push_back(add(*a, i + 1, i % 2 + 1, 4));
    bb.push_back(add(*b, i + 1, i % 2 + 1, 4));
  }
  std::mt19937 rng(176041);
  std::vector<uint8_t> saved;
  int published = 0;
  for (int tick = 0; tick < 3600; ++tick) {
    for (int j = 0; j < 64; ++j) {
      Command c = cmd(aa[j], tick, 4);
      c.x = double(int(rng() % 200) - 100) / 100;
      c.z = double(int(rng() % 200) - 100) / 100;
      c.yaw = double(rng() % 628) / 100;
      c.fire = tick % 90 < 30;
      c.reload = tick % 120 == 60;
      c.jump = tick % 200 == 0;
      c.crouch = tick % 100 > 60;
      c.prone = tick % 400 > 350;
      check(a->submit(aa[j], c) == b->submit(bb[j], c), "replay ingress");
    }
    a->advance(ha);
    b->advance(hb);
    check(a->frame() == b->frame(), "deterministic replay frames");
    if ((tick + 1) * 2 / 3 != tick * 2 / 3) {
      ++published;
      check(a->frame().size() == 14 + 64 * 104, "fixed bounded wire rows");
      check(a->frame()[0] == 'C' && a->frame()[3] == '1', "versioned wire");
    }
    if (tick == 100)
      saved = a->frame();
    if (tick == 101)
      check(saved != a->frame(), "detached immutable frame copy");
  }
  check(published == 2400, "exact 20 Hz snapshot cadence");
  check(ha.moves == 64 * 3600,
        "one host movement commit per living player per tick");
  auto full = std::make_unique<Core>();
  for (int i = 1; i <= 128; ++i)
    check(add(*full, i).id == i, "capacity admission");
  check(!add(*full, 129).id, "capacity enforced");
}
void cq_rules_tests();
void vr_port_tests();
void transport_tests();
void squad_tests();
void entity_tests();
void protocol_tests();
void reference_tests(const std::string &);
extern int collision_legacy_misses, collision_legacy_late;
int main(int argc, char **argv) {
  try {
    if (argc == 2)
      reference_tests(argv[1]);
    vr_port_tests();
    transport_tests();
    squad_tests();
    cq_rules_tests();
    entity_tests();
    protocol_tests();
    tick_rate_tests();
    adaptive_tick_tests();
    experimental_team_limit_tests();
    inputs();
    wire();
    movement();
    combat();
    projectiles();
    snapshots_and_replay();
    std::cout << "{\"checks\":" << checks
              << ",\"ok\":true,\"collision_legacy_misses\":"
              << collision_legacy_misses
              << ",\"collision_legacy_late\":" << collision_legacy_late
              << ",\"replay_players\":64,\"replay_ticks\":3600}" << std::endl;
    return 0;
  } catch (const std::exception &e) {
    std::cerr << "FAIL " << checks << ": " << e.what() << std::endl;
    return 1;
  }
}
