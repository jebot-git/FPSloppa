#include "authority_core.h"
#include "authority_protocol.h"
#include <cstring>
#include <memory>
using namespace cqauthority;
extern void check(bool, const char *);
namespace {
struct World : Host {
  Moved move(const Motion &m, double dt) override {
    V p = m.position + m.velocity * dt, v = m.velocity;
    if (p.y < 0) {
      p.y = 0;
      v.y = 0;
    }
    return {p, v, m.height, p.y <= 0};
  }
  Hit trace(V, V, Handle) override { return {}; }
};
std::unique_ptr<Core> game() {
  auto c = std::make_unique<Core>();
  CqConfig cfg;
  cfg.enabled = true;
  cfg.auto_respawn = false;
  check(c->configure_cq(cfg), "protocol CQ setup");
  return c;
}
void command(Core &c, Handle h, int seq, int weapon, bool fire = false,
             uint32_t event = 0) {
  Command x;
  x.life = h.life;
  x.seq = seq;
  x.weapon = weapon;
  x.fire = fire;
  x.fire_event = event;
  x.fire_weapon = weapon;
  x.fire_mask = event ? 1 : 0;
  check(c.submit(h, x), "protocol event accepted");
}
} // namespace
void protocol_tests() {
  World world;
  {
    auto c = game();
    for (int i = 1; i <= 64; ++i)
      c->join(i, i % 2, {double(i * 3), 0, 0}, 1 << 2, {100, 100, 100, 100});
    c->advance(world);
    c->advance(world);
    auto frame = c->frame();
    check(validate_frame(frame.data(), frame.size(), 64, 2),
          "bounded native CQA2 validation");
    check(!validate_frame(frame.data(), frame.size(), 32, 2) &&
              !validate_frame(frame.data(), frame.size(), 64, 3),
          "frame count/tick enforced");
    for (size_t i = 0; i < 14 + 64 * 104; ++i)
      check(!validate_frame(frame.data(), i),
            "truncated mandatory frame rejected");
    auto corrupt = frame;
    for (size_t i = 22; i < 26; ++i)
      corrupt.at(i) = 0;
    check(!validate_frame(corrupt.data(), corrupt.size()),
          "zero player life rejected");
    corrupt = frame;
    uint32_t nan = 0x7fc00000;
    std::memcpy(corrupt.data() + 30, &nan, 4);
    check(!validate_frame(corrupt.data(), corrupt.size()),
          "NaN player position rejected");
    size_t at = 14 + 64 * 104;
    bool found = false;
    while (at < frame.size()) {
      uint16_t type = frame[at] | uint16_t(frame[at + 1]) << 8;
      uint32_t n = 0;
      for (int j = 0; j < 4; ++j)
        n |= uint32_t(frame[at + 2 + j]) << (8 * j);
      if (type == 14) {
        corrupt = frame;
        std::memcpy(corrupt.data() + at + 8 + 14, &nan, 4);
        check(!validate_frame(corrupt.data(), corrupt.size()),
              "NaN CQ cooldown rejected");
        found = true;
      }
      at += 6 + n;
    }
    check(found, "native full player section present");
    uint32_t seed = 0x1234abcd;
    for (int i = 0; i < 12000; ++i) {
      corrupt = frame;
      seed = seed * 1664525 + 1013904223;
      size_t at = seed % corrupt.size();
      seed = seed * 1664525 + 1013904223;
      corrupt[at] ^= uint8_t(1 << (seed % 8));
      (void)validate_frame(corrupt.data(), corrupt.size());
    }
    check(true, "bounded frame mutation corpus completes");
  }
  {
    auto c = game();
    auto h = c->join(1, 0, {}, 1 << 2, {100, 100, 100, 100});
    for (int i = 0; i < 12; ++i) {
      command(*c, h, i, 2);
      c->advance(world);
    }
    command(*c, h, 12, 2, false, 1);
    c->advance(world);
    check(c->resolve(h)->shots == 1 && c->resolve(h)->fire_ack == 1,
          "lost trigger press recovered from repeated event");
    for (int i = 13; i < 40; ++i) {
      command(*c, h, i, 2, false, 1);
      c->advance(world);
    }
    check(c->resolve(h)->shots == 1,
          "trigger retransmission cannot double fire");
    Command x;
    x.life = h.life;
    x.seq = 40;
    x.weapon = 2;
    x.blocked = true;
    x.fire_event = 2;
    x.fire_weapon = 2;
    x.fire_mask = 1;
    check(c->submit(h, x), "blocked event queued");
    c->advance(world);
    check(c->resolve(h)->shots == 1 && c->resolve(h)->fire_ack == 2,
          "blocked trigger acknowledged without delayed shot");
    x.seq = 41;
    x.fire_event = 100;
    x.blocked = false;
    check(c->submit(h, x), "large event jump packet accepted");
    c->advance(world);
    check(c->resolve(h)->fire_ack == 2,
          "event counter cannot jump beyond bounded window");
    x.seq = 42;
    x.fire_event = 0;
    x.jump_event = 1;
    x.jump_seq = 41;
    check(c->submit(h, x), "repeated jump edge queued");
    c->advance(world);
    check(c->resolve(h)->jump_ack == 1 && c->resolve(h)->position.y > 0,
          "short jump survives lost held packet");
  }
  {
    auto c = game();
    auto h = c->join(1, 0, {}, 1 << 2, {100, 100, 100, 100});
    ClassState profile;
    profile.xp[0] = 5000;
    profile.primary_t3[0] = true;
    check(c->configure_player(h, profile), "cold T3 primary profile");
    check(!c->configure_player(h, profile),
          "profile cannot be reapplied to refill ammunition");
    for (int i = 0; i < 12; ++i) {
      command(*c, h, i, 14);
      c->advance(world);
    }
    command(*c, h, 12, 14, true);
    c->advance(world);
    for (int i = 13; i < 36; ++i) {
      command(*c, h, i, 14);
      c->advance(world);
    }
    check(c->resolve(h)->shots == 3,
          "CQ burst completes after trigger release");
    for (int i = 36; i < 70; ++i) {
      command(*c, h, i, 14, true);
      c->advance(world);
    }
    check(c->resolve(h)->shots == 6,
          "holding trigger cannot repeat a CQ burst");
  }
  {
    auto c = game();
    check(c->configure_zone({0, 0, -30}), "native AI capture goal");
    auto bot = c->join(-1000, 0, {}, 1 << 2, {100, 100, 100, 100});
    auto enemy = c->join(2, 1, {0, 0, -20}, 1 << 2, {100, 100, 100, 100});
    check(bot.id == -1000 && c->resolve(bot)->bot,
          "native bot signed identity admitted");
    for (int i = 0; i < 180; ++i)
      c->advance(world);
    check(c->resolve(bot)->last_seq >= 179 && c->resolve(bot)->shots > 0,
          "native bot perception emits ordinary weapon inputs");
    check(c->resolve(enemy)->hp < 100 || c->resolve(enemy)->incapacitated ||
              c->resolve(enemy)->dead,
          "native bot damages through authoritative projectiles");
    check(c->resolve(bot)->position.length() > .1,
          "native bot follows navigation output");
    check(validate_frame(c->frame().data(), c->frame().size(), 2),
          "negative bot IDs survive bounded frame protocol");
  }
  {
    auto c = game();
    auto h = c->join(1, 0, {}, 1 << 2, {100, 100, 100, 100});
    command(*c, h, 0, 4);
    c->advance(world);
    Action a;
    a.seq = 0;
    a.kind = ActionKind::GRENADE_EQUIP;
    check(c->queue_action(h, a), "desktop grenade selection action");
    command(*c, h, 1, 4);
    c->advance(world);
    check(c->resolve(h)->grenade_selected,
          "grenade selected without changing firearm ID");
    for (int i = 2; i < 20; ++i) {
      command(*c, h, i, 4, true);
      c->advance(world);
    }
    check(c->resolve(h)->shots == 0 && c->resolve(h)->grenade_primed,
          "holding grenade pin suppresses firearm");
    command(*c, h, 20, 4);
    c->advance(world);
    check(c->resolve(h)->grenade_count == 2 && !c->resolve(h)->grenade_selected,
          "desktop release throws once and restores firearm");
    int count = 0;
    for (auto &g : c->grenades())
      count += g.active;
    check(count == 1, "one native grenade spawned on release");
    c->resolve(h)->classes.xp[0] = 3000;
    a.seq = 1;
    a.kind = ActionKind::TEAM;
    a.a = 1;
    check(c->queue_action(h, a), "team change control action");
    command(*c, h, 21, 4);
    c->advance(world);
    auto *p = c->find(1);
    check(p->team == 1 && p->handle != h && p->classes.xp[0] == 3000,
          "team change binds a new life and preserves progression");
    auto previous = p->handle;
    c->request_restart();
    c->advance(world);
    p = c->find(1);
    check(p->handle != previous && p->classes.xp[0] == 3000 &&
              c->round_epoch() == 2,
          "administrative restart preserves XP without end-round award");
    count = 0;
    for (auto &g : c->grenades())
      count += g.active;
    check(count == 0, "administrative restart clears in-flight ordnance");
  }
  {
    auto c = game();
    auto attacker = c->join(1, 0, {}, 1 << 2, {100, 100, 100, 100});
    auto victim = c->join(2, 1, {0, 0, -4}, 1 << 2, {100, 100, 100, 100});
    Session credit{1, c->resolve(attacker)->session_token};
    c->resolve(attacker)->dead = true;
    auto fresh = c->respawn(attacker, {});
    c->resolve(victim)->invulnerable = 0;
    check(c->damage(victim, attacker, 1000, DamageKind::BULLET, false, credit),
          "in-flight damage carries stable session credit");
    check(c->resolve(fresh)->kills == 1 &&
              c->resolve(fresh)->classes.xp[0] == 100,
          "kill credit survives owner respawn");
    auto next = c->respawn(victim, {0, 0, -4});
    c->resolve(next)->invulnerable = 0;
    c->leave(fresh);
    auto reconnect = c->join(1, 0, {}, 1 << 2, {100, 100, 100, 100});
    c->damage(next, attacker, 1000, DamageKind::BULLET, false, credit);
    check(c->resolve(reconnect)->kills == 0 &&
              c->resolve(reconnect)->classes.xp[0] == 0,
          "disconnected session cannot credit a reused peer ID");
  }
  {
    auto c = game();
    auto a = c->join(1, 0, {}, 1 << 2, {100, 100, 100, 100}),
         v = c->join(2, 1, {0, 0, -4}, 1 << 2, {100, 100, 100, 100});
    c->resolve(v)->invulnerable = 0;
    c->resolve(v)->armor = 0; // Attribution fixture starts with bare health.
    c->damage(v, a, 100);
    check(c->resolve(v)->incapacitated,
          "bleed attribution fixture incapacitated");
    c->resolve(a)->dead = true;
    auto fresh = c->respawn(a, {});
    for (int i = 0; i < 310; ++i)
      c->advance(world);
    check(c->resolve(v)->dead && c->resolve(fresh)->kills == 1,
          "bleedout kill credit survives attacker respawn");
    bool hurt = false;
    for (auto &e : c->events())
      hurt |= e.seq && e.kind == EventKind::HURT && (e.detail & 1);
    check(hurt, "native death feedback event emitted");
  }
}
