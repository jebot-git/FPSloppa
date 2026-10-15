#include "authority_core.h"
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
