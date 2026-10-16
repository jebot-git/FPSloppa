#include "authority_core.h"
#include <memory>
using namespace cqauthority;
extern void check(bool, const char *);
namespace {
struct World : Host {
  bool drowned = false, grass = false;
  bool grass_cover(V) override { return grass; }
  int seated = 0, breaches = 0;
  void ordnance_impact(V, double, double) override { ++breaches; }
  uint64_t hull_key = 0;
  V hull_at;
  Hit sweep_world(V a, V b, double, Handle h, uint64_t ignore) override {
    double face = hull_at.z + 2.4;
    if (hull_key && hull_key != ignore && a.z > face && b.z <= face) {
      double t = (face-a.z)/(b.z-a.z); V at = a+(b-a)*t;
      if (std::abs(at.x-hull_at.x) < 1.1 && at.y >= hull_at.y && at.y <= hull_at.y+2) {
        Hit hit{true, {}, at, {0,0,1}}; hit.entity = hull_key; hit.entity_kind = 1; return hit;
      }
    }
    return world_trace(a,b,h);
  }
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
  for (int hz : {30, 60}) {
    auto c = make(); World world; c->configure_tick_rate(hz);
    int vehicle = c->add_vehicle(VehicleKind::LIGHT, {}, 0, 0);
    int outside_vehicle = c->add_vehicle(VehicleKind::HEAVY, {100, 0, 0}, 0, 1);
    auto inside = add(*c, 1, 0, {0, 0, 0});
    auto upper = add(*c, 2, 1, {0, 4, 0});
    auto rider = add(*c, 3, 0, {3.5, 0, 0});
    auto outside = add(*c, 4, 1, {100, 0, 0});
    input(*c, rider, 0); use(*c, rider, 0); c->advance(world);
    check(c->resolve(rider)->vehicle == vehicle, "collapse fixture has seated occupant");
    auto *p = c->resolve(inside); p->invulnerable = 100; p->armor = 100; p->stress = true;
    auto *down = c->resolve(upper); down->hp = 1; down->incapacitated = true;
    double hp = c->vehicles()[vehicle].hp, other_hp = c->vehicles()[outside_vehicle].hp;
    int affected = c->collapse_region({-10, -.3, -10}, {10, 12, 10}, world);
    check(affected == 4, "collapse affects three occupants and one hull");
    for (auto h : {inside, upper, rider})
      check(c->resolve(h)->dead && c->resolve(h)->death_gibbed && !c->resolve(h)->incapacitated,
            "collapse gibs either team, downed/invulnerable/stress actors and seated occupants");
    check(c->resolve(rider)->vehicle < 0, "collapse releases killed vehicle occupant");
    check(c->vehicles()[vehicle].hp == hp - 100, "collapse applies exactly 100 hull damage");
    check(c->vehicles()[outside_vehicle].hp == other_hp && !c->resolve(outside)->dead,
          "collapse leaves outside actors and vehicles unaffected");
    check(c->resolve(inside)->kills == 0 && c->resolve(upper)->kills == 0,
          "environmental collapse awards no kills or XP");
    check(c->collapse_region({10, 0, 0}, {-10, 10, 10}, world) == 0,
          "collapse rejects invalid volume");
  }
  for (int hz : {30, 60}) {
    auto c = make(); World world;
    check(c->configure_tick_rate(hz), "ordnance fixture rate");
    int tank = c->add_vehicle(VehicleKind::ROCKET, {}, 0, 0);
    auto driver = add(*c, 1, 0, {3.5, 0, 0});
    auto ally = add(*c, 2, 0, {100, 0, 0});
    check(!c->damage(ally, driver, 10), "small arms retain allied protection");
    check(c->damage(ally, driver, 10, DamageKind::ORDNANCE), "ordnance hurts allies");
    check(c->damage(ally, driver, 10, DamageKind::GRENADE), "HE grenades hurt allies");
    check(c->resolve(ally)->hp == 80, "friendly ordnance preserves normal damage amount");
    int xp = c->resolve(driver)->classes.xp[0];
    c->damage(ally, driver, 1000, DamageKind::ORDNANCE);
    check(c->resolve(ally)->dead && c->resolve(driver)->kills == -1 &&
          c->resolve(driver)->classes.xp[0] == xp && c->points.scores[0] == 0,
          "collateral death penalizes kill count without XP or objective reward");
    input(*c, driver, 0); use(*c, driver, 0); c->advance(world);
    check(c->resolve(driver)->vehicle == tank, "barrage fixture boards rocket tank");
    bool inspected = false;
    for (int tick = 1; tick <= hz * 2; ++tick) {
      input(*c, driver, tick, -1, tick == 1); c->advance(world);
      for (const auto &shot : c->projectiles_state())
        if (shot.active) {
          inspected = true;
          check(shot.radius == 30 && shot.arm == 0 && shot.bounce == 0 && !shot.stuck,
                "barrage has 30m radius and first-impact fuse at both tick rates");
        }
    }
    check(inspected && world.breaches > 0, "rocket impact dispatches environmental damage immediately");
  }
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
    check(c->damage_vehicle(key, 0, 10, DamageKind::ORDNANCE, h, world) == 10,
          "allied ordnance damages tank");
    for (int i = 1; i < 31; ++i) {
      input(*c, h, i, -1, true, 0, -1);
      input(*c, enemy, i);
      c->advance(world);
    }
    check(c->vehicles()[tank].position.z < -.5,
          "tank motion joystick advances hull");
    check(c->vehicles()[tank].rounds == 4, "light tank single-shot cadence");
    for (auto &shot : c->projectiles_state())
      if (shot.active) check(shot.age + shot.remaining >= 7.5, "light tank projectile survives at least 300m flight");
    check(c->vehicles()[tank].visual_y - c->vehicles()[tank].position.y <= .5,
          "hover clearance at most half metre");
    check(c->resolve(h)->shots == 0,
          "mounted pilot does not fire infantry weapon");
    check(c->damage_vehicle(key, 1, 500, DamageKind::ORDNANCE, enemy, world) ==
              190,
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
    for (auto &shot : c->projectiles_state())
      if (shot.active) check(shot.age + shot.remaining >= 7.5, "heavy tank projectile survives at least 300m flight");
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
    auto target = add(*c, 2, 1, {80, 0, -1000});
    world.grass = true;
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
      Command prone; prone.life = target.life; prone.seq = i; prone.weapon = c->resolve(target)->weapon; prone.prone = true;
      check(c->submit(target, prone), "prone recon target input");
      c->advance(world);
    }
    check(c->resolve(target)->grass_concealed && Core::detection_scale(*c->resolve(target)) == .25, "recon target is concealed from ground detection");
    check(c->resolve(target)->spotted[0] > c->time(),
          "swept recon ignores grass concealment at 80m cross-track");
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
    auto target = add(*c, 2, 1, {0, 0, -149});
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
              "turret autonomously acquires infantry at 149m");
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
  for(double pitch : {-.003, -1.5707963267948966}) {
    World world;auto c=make();auto h=add(*c,1,0,{},Role::SHOCKTROOP,true);
    for(int tick=0;tick<180;++tick) {
      Command command;command.life=h.life;command.seq=tick;command.weapon=8;command.fire=true;command.pitch=pitch;
      check(c->submit(h,command),"distant/vertical airstrike designation accepted");c->advance(world);
    }
    check(c->resolve(h)->classes.strike_ready>c->time(),"distant or downward target launches airstrike after held lock");
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
    V first; double impact_at = 0;
    for (const auto &f : c->flights()) if (f.active && f.strike) { first = f.target; impact_at = f.impact_at; }
    auto friendly = add(*c, 2, 0, first + V{25, 0, 0});
    bool friendly_checked = false;
    for (int i = 175; i < 450; ++i) {
      if (!friendly_checked && c->time() >= impact_at) {
        check(c->resolve(friendly)->hp < 100, "airstrike damages allies 25m away beyond old radius");
        friendly_checked = true;
      }
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
  {
    World world; world.grass = true;
    auto c = make();
    auto tech = add(*c, 1, 0, {}, Role::TECHNICIAN, true);
    auto target = add(*c, 2, 1, {0, 0, -40});
    auto step = [&](int index) {
      input(*c, tech, index, 6, index < 20);
      Command cmd; cmd.life = target.life; cmd.seq = index; cmd.weapon = c->resolve(target)->weapon; cmd.prone = true;
      check(c->submit(target, cmd), "concealed turret target input"); c->advance(world);
    };
    for (int i = 0; i < 100; ++i) step(i);
    int turrets = 0;
    for (auto &t : c->turrets()) if (t.active) { ++turrets; check(t.ammo == 12, "turret cannot acquire prone grass target at 40m"); }
    check(turrets == 1, "concealment turret fixture deployed");
    c->resolve(target)->position.z = -35;
    for (int i = 100; i < 160; ++i) step(i);
    for (auto &t : c->turrets()) if (t.active) check(t.ammo < 12, "turret acquires prone grass target inside 37.5m");
  }
  {
    World world;
    auto c = make();
    auto tech = add(*c, 1, 0, {}, Role::TECHNICIAN);
    auto *p = c->resolve(tech); p->owned |= uint16_t(1 << 11); p->weapon = 11; p->clips[11] = 3;
    int tank = c->add_vehicle(VehicleKind::LIGHT, {0, 0, -499}, 0, 1);
    world.hull_key = c->vehicles()[tank].key; world.hull_at = c->vehicles()[tank].position;
    bool locked = false;
    for (int i = 0; i < 500; ++i) {
      Command cmd; cmd.life = tech.life; cmd.seq = i; cmd.weapon = 11; cmd.fire = i == 60;
      check(c->submit(tech, cmd), "long-range guided command"); c->advance(world);
      locked |= c->resolve(tech)->lock_elapsed >= 1.5;
    }
    check(locked && c->resolve(tech)->shots == 1, "guided launcher acquires and fires at 499m");
    check(c->vehicles()[tank].hp < 250, "guided missile reaches and damages hull near 500m");
  }

  {
    World world;
    auto c = make();
    auto tech = add(*c, 1, 0, {}, Role::TECHNICIAN);
    bool reached = false;
    for (int i = 0; i < 230; ++i) {
      Command cmd; cmd.life = tech.life; cmd.seq = i; cmd.weapon = 5;
      cmd.pitch = 3.141592653589793/4; cmd.fire = i < 20;
      check(c->submit(tech, cmd), "ballistic range input"); c->advance(world);
      for (auto &shot : c->projectiles_state())
        if (shot.active && shot.weapon == 5 && std::abs(shot.position.z) >= 200 && shot.position.y > 0) reached = true;
    }
    check(reached, "actual launcher projectile reaches 200m above level ground on an arc");
  }

}
