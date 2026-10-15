#include "authority_core.h"
#include <memory>
using namespace cqauthority;
extern void check(bool, const char *);
namespace {
struct World : Host {
  bool drowned = false;
  int seated = 0;
  double floor = 0;
  Moved move(const Motion &m, double dt) override {
    V p = m.position + m.velocity * dt;
    V v = m.velocity;
    if (p.y <= floor) {
      p.y = floor;
      v.y = 0;
    }
    return {p, v, m.height, p.y <= floor};
  }
  Hit trace(V a, V b, Handle h) override { return world_trace(a, b, h); }
  Hit world_trace(V a, V b, Handle) override {
    if (a.y >= floor && b.y < floor) {
      double t = (a.y - floor) / (a.y - b.y);
      return {true, {}, a + (b - a) * t, {0, 1, 0}};
    }
    return {};
  }
  bool water(V) override { return drowned; }
  double ground_height(double, double) override { return floor; }
  void seat(Handle, V, bool in) override { seated += in ? 1 : -1; }
  VehicleMoved move_vehicle(const Vehicle &v, V velocity, double dt) override {
    V p = v.position + velocity * dt;
    p.y = std::max(floor, p.y);
    velocity.y = 0;
    return {p,         velocity,
            {0, 1, 0}, p.y + (v.kind == VehicleKind::ROCKET ? 0 : .25),
            true,      true};
  }
};
std::unique_ptr<Core> make() {
  auto c = std::make_unique<Core>();
  CqConfig cfg;
  cfg.enabled = true;
  cfg.auto_respawn = false;
  check(c->configure_cq(cfg), "entity fixture CQ");
  c->extended_frames = true;
  return c;
}
Handle add(Core &c, int id, int team, V at, Role role = Role::SHOCKTROOP,
           bool tier = false) {
  auto h = c.join(id, team, at, 1 << 2, {100, 100, 100, 100});
  auto *p = c.resolve(h);
  p->classes.next = role;
  if (tier) {
    p->classes.xp[size_t(role)] = 7500;
    check(c.choose_gear(h, int(role), 2, 2), "T2 entity utility unlock");
  }
  p->dead = true;
  h = c.respawn(h, at);
  c.resolve(h)->invulnerable = 0;
  c.resolve(h)->armor = 0; // Existing entity damage fixtures use bare health.
  return h;
}
void input(Core &c, Handle h, int seq, int weapon = -1, bool fire = false,
           double x = 0, double z = 0) {
  Command cmd;
  cmd.life = h.life;
  cmd.seq = seq;
  cmd.weapon = weapon < 0 ? c.resolve(h)->weapon : weapon;
  cmd.fire = fire;
  cmd.x = x;
  cmd.z = z;
  check(c.submit(h, cmd), "entity command accepted");
}
void use(Core &c, Handle h, int seq) {
  Action a;
  a.seq = seq;
  a.kind = ActionKind::USE;
  check(c.queue_action(h, a), "entity use queued");
}
} // namespace
void entity_tests() {
  {
    World world;
    auto c = make();
    int tank = c->add_vehicle(VehicleKind::LIGHT, {0, 0, 0});
    check(tank == 0, "cold light tank admitted");
    auto h = add(*c, 1, 0, {2, 0, 0});
    auto enemy = add(*c, 2, 1, {20, 0, 0});
    input(*c, h, 0);
    use(*c, h, 0);
    c->advance(world);
    check(c->resolve(h)->vehicle == tank, "native tank boarding");
    check(c->vehicles()[tank].pilot == h, "vehicle life-bound pilot");
    check(c->add_vehicle(VehicleKind::LIGHT, {}) < 0,
          "no runtime cold vehicle mutation");
    auto key = c->vehicles()[tank].key;
    check(!c->damage_vehicle(key, 1, 100, DamageKind::BULLET, enemy, world),
          "infantry cannot damage tanks");
    check(c->damage_vehicle(key, 1, 100, DamageKind::GRENADE, enemy, world) ==
              50,
          "tank grenade damage halved");
    check(!c->damage_vehicle(key, 0, 100, DamageKind::ORDNANCE, h, world),
          "allied ordnance does not damage tank");
    for (int i = 1; i < 31; ++i) {
      input(*c, h, i, -1, true, 0, -1);
      input(*c, enemy, i);
      c->advance(world);
    }
    check(c->vehicles()[tank].position.z < -.5,
          "tank motion joystick advances hull");
    check(c->vehicles()[tank].rounds == 4, "light tank single-shot cadence");
    check(c->vehicles()[tank].visual_y - c->vehicles()[tank].position.y <= .5,
          "hover clearance at most half metre");
    check(c->resolve(h)->shots == 0,
          "mounted pilot does not fire infantry weapon");
    check(c->damage_vehicle(key, 1, 500, DamageKind::ORDNANCE, enemy, world) ==
              200,
          "tank ordnance full remaining damage");
    check(c->resolve(h)->dead && !c->resolve(h)->incapacitated,
          "destroyed occupied tank gibs pilot");
    check(c->vehicles()[tank].pilot.id == 0, "destroyed tank releases pilot");
  }
  {
    World world;
    auto c = make();
    c->add_vehicle(VehicleKind::ROCKET, {});
    auto h = add(*c, 1, 0, {1, 0, 0});
    input(*c, h, 0);
    use(*c, h, 0);
    c->advance(world);
    world.drowned = true;
    input(*c, h, 1);
    c->advance(world);
    check(c->vehicles()[0].hp == 0 && c->resolve(h)->dead,
          "water destroys occupied tank and pilot");
  }
  {
    World world;
    auto c = make();
    c->add_vehicle(VehicleKind::HEAVY, {});
    auto h = add(*c, 1, 0, {1, 0, 0});
    input(*c, h, 0);
    use(*c, h, 0);
    c->advance(world);
    input(*c, h, 1, -1, true);
    c->advance(world);
    int count = 0;
    for (auto &s : c->projectiles_state())
      count += s.active;
    check(count == 2 && c->vehicles()[0].rounds == 3,
          "heavy tank consumes one volley for two barrel shots");
    check(c->leave(h), "disconnect mounted pilot");
    input(*c, add(*c, 2, 1, {100, 0, 0}), 2);
    c->advance(world);
    check(!c->vehicles()[0].pilot.id && c->vehicles()[0].remaining == 0,
          "disconnect clears mounted attack state");
  }
  {
    World world;
    auto c = make();
    auto scout = add(*c, 1, 0, {}, Role::SCOUT, true);
    auto target = add(*c, 2, 1, {0, 0, -1000});
    input(*c, scout, 0);
    input(*c, target, 0);
    use(*c, scout, 0);
    c->advance(world);
    int count = 0;
    for (auto &f : c->flights())
      if (f.active) {
        ++count;
        check(f.start.y == 60 && f.length > 2800,
              "recon full-map route with terrain clearance");
      }
    check(count == 1, "recon native flight created");
    double ready = c->resolve(scout)->classes.drone_ready;
    check(ready > 120, "recon two minute cooldown");
    for (int i = 1; i < 710; ++i) {
      input(*c, scout, i);
      input(*c, target, i);
      c->advance(world);
    }
    check(c->resolve(target)->spotted[0] > c->time(),
          "swept recon detects enemy along route");
    int alerts = 0;
    for (auto &e : c->events())
      alerts += e.seq && e.kind == EventKind::RECON_ALERT;
    check(alerts == 1, "recon alerts once per life per flight");
    check(c->resolve(scout)->classes.drone_ready == ready,
          "flight scan does not reset cooldown");
  }
  {
    World world;
    auto c = make();
    auto tech = add(*c, 1, 0, {}, Role::TECHNICIAN, true);
    auto target = add(*c, 2, 1, {0, 0, -30});
    for (int i = 0; i < 100; ++i) {
      input(*c, tech, i, 6, i < 20);
      input(*c, target, i);
      c->advance(world);
    }
    int count = 0;
    for (auto &t : c->turrets())
      if (t.active) {
        ++count;
        check(t.ammo < 12 && t.target_player == target,
              "turret autonomously acquires infantry and spends ammo");
      }
    check(count == 1, "T2 technician places one turret");
    check(c->resolve(tech)->classes.turret_ready > 120,
          "turret two minute cooldown");
  }
  {
    auto low = ballistic({0, 2, 0}, {100, 0, 0}, std::sqrt(5500.), 20),
         high =
             ballistic({0, 2, 0}, {100, 0, 0}, std::sqrt(5500.), 20, {}, true);
    check(low.valid && high.valid && high.time > low.time,
          "mortar two ballistic arcs");
    for (auto s : {low, high}) {
      V end = V{0, 2, 0} + s.velocity * s.time - V{0, 10 * s.time * s.time, 0};
      check((end - V{100, 0, 0}).length() < 1e-8,
            "ballistic endpoint accuracy");
      check(std::abs(s.velocity.length() - std::sqrt(5500.)) < 1e-5,
            "ballistic launch speed accuracy");
    }
  }
  {
    World world;
    auto c = make();
    auto h = add(*c, 1, 0, {}, Role::SHOCKTROOP, true);
    for (int i = 0; i < 175; ++i) {
      Command cmd;
      cmd.life = h.life;
      cmd.seq = i;
      cmd.weapon = 8;
      cmd.fire = true;
      cmd.pitch = -.25;
      check(c->submit(h, cmd), "airstrike designator input");
      c->advance(world);
    }
    int count = 0;
    for (auto &f : c->flights())
      if (f.active && f.strike) {
        ++count;
        check(f.delivered == 0 && f.impact_at > c->time(),
              "bomber flight precedes cluster impacts");
      }
    check(count == 1 && c->resolve(h)->classes.strike_ready > 300,
          "five second lock calls one bomber with five minute cooldown");
    for (int i = 175; i < 450; ++i) {
      if(!c->resolve(h)->dead) input(*c, h, i, 8);
      c->advance(world);
    }
    int impacts = 0;
    for (auto &e : c->events())
      impacts += e.seq && e.kind == EventKind::AIRSTRIKE;
    check(impacts == 12, "airstrike delivers twelve crawling impacts");
  }
  {
    World world;
    auto c = make();
    auto h = add(*c, 1, 0, {}, Role::SHOCKTROOP, true);
    for (int i = 0; i < 200; ++i) {
      Command cmd;
      cmd.life = h.life;
      cmd.seq = i;
      cmd.weapon = 8;
      cmd.fire = true;
      cmd.pitch = -.25;
      cmd.x = i % 60 < 5 ? .1 : 0;
      check(c->submit(h, cmd), "interrupted designator input");
      c->advance(world);
    }
    bool flight = false;
    for (auto &f : c->flights())
      flight |= f.active;
    check(!flight && c->resolve(h)->classes.strike_ready == 0,
          "movement breaks continuous airstrike lock");
  }
  {
    World world;
    auto c = make();
    auto h = add(*c, 1, 0, {});
    auto old = h;
    auto *p = c->resolve(h);
    p->classes.xp[0] = 1000;
    c->points.winner = 0;
    input(*c, h, 0, -1, true, 0, -1);
    c->advance(world);
    check(p->position.length() < 1e-8 && p->shots == 0,
          "intermission freezes movement and weapons");
    check(p->classes.xp[0] == 1150, "winner participation award once");
    for (int i = 1; i < 302; ++i)
      c->advance(world);
    p = c->find(1);
    check(p && p->handle != old && p->classes.xp[0] == 1150,
          "new round respawns and preserves class XP");
    check(c->points.winner == -2 && c->round_epoch() == 2,
          "round restart resets CQ score and advances epoch");
    Command stale;
    stale.life = old.life;
    stale.seq = 10000;
    stale.weapon = 4;
    check(!c->submit(old, stale), "old round life cannot control new round");
  }
  {
    World world;
    auto c = make();
    auto h = add(*c, 1, 0, {}, Role::SCOUT);
    c->cq.day_cycle = true;
    c->cq.cycle_offset = 600;
    c->advance(world);
    check(c->cq.light_fraction == 0 && c->spot_range(*c->resolve(h)) == 25,
          "night scout range 25 metres");
    c->cq.cycle_offset = 266;
    c->advance(world);
    check(c->cq.light_fraction > .999, "dusk still provides full mixed light");
    c->cq.cycle_offset = 319;
    c->advance(world);
    check(c->cq.light_fraction > 0 && c->cq.light_fraction < 1,
          "dusk progressively darkens");
    c->cq.cycle_offset = 886;
    c->advance(world);
    check(c->cq.light_fraction > 0 && c->cq.light_fraction < 1,
          "dawn progressively brightens");
  }
}
