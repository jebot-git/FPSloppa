#include "authority_core.h"
#include "authority_protocol.h"
#include "authority_weapon_geometry.h"
#include <memory>
using namespace cqauthority;
extern void check(bool, const char *);
namespace {
struct World : Host {
  Moved move(const Motion &m, double) override {
    return {m.position, {}, m.height, true};
  }
  Hit trace(V, V to, Handle) override { return {false, {}, to}; }
};
} // namespace
void weapon_tier_tests() {
  const int primary[4][3] = {{4, 1, 14}, {9, 10, 16}, {3, 12, 13}, {5, 11, 15}};
  for (int role = 0; role < 4; ++role) {
    ClassState state;
    state.role = Role(role);
    check(state.weapon(false) == primary[role][0], "T1 class mapping");
    check(!state.choose(role, 0, primary[role][1]) &&
              !state.choose(role, 0, primary[role][2]),
          "unearned tier rejected");
    state.xp[role] = 2500;
    check(state.choose(role, 0, primary[role][1]) &&
              state.weapon(false) == primary[role][1],
          "T2 level-five selection");
    check(!state.choose(role, 0, primary[role][2]),
          "T3 remains locked at level five");
    state.xp[role] = 5000;
    check(state.choose(role, 0, primary[role][2]) &&
              state.weapon(false) == primary[role][2],
          "T3 level-ten selection");
    check(state.choose(role, 0, primary[role][0]) &&
              state.weapon(false) == primary[role][0],
          "downgrade clears higher tier selection");
  }
  for (int w : {0, 1, 2, 3, 4, 9, 10, 12, 13, 14, 15, 16}) {
    RecoilState recoil;
    for (int i = 0; i < 50; ++i)
      check((recoil.shot(w, i * .045, 0, true, 1.65, true, i % 2, 1, .8, .7) -
             V{0, 0, -1})
                    .length() < 1e-12,
            "stationary sustained fire never acquires a spray pattern");
    check(std::abs(recoil.shot(w, 3, 6, true, 1.65, true, true, 1, 1, 1).x) > 0,
          "running adds spread deviation");
  }
  auto core = std::make_unique<Core>();
  CqConfig cfg;
  cfg.enabled = true;
  cfg.auto_respawn = false;
  core->configure_cq(cfg);
  World world;
  auto h = core->join(1, 0, {}, uint32_t(1) << 14, {100, 100, 100, 100});
  check(h.id != 0, "expanded weapon bitset accepts T3");
  ClassState profile;
  profile.xp[0] = 5000;
  profile.primary_t3[0] = true;
  check(core->configure_player(h, profile), "T3 authority profile accepted");
  Command c;
  c.life = h.life;
  c.weapon = 14;
  c.fire = true;
  for (int i = 0; i < 15; ++i) {
    c.seq = i;
    check(core->submit(h, c), "T3 input accepted");
    core->advance(world);
  }
  check(core->resolve(h)->shots == 3,
        "T3 rifle emits one three-shot burst per trigger press");
  check(validate_frame(core->frame().data(), core->frame().size(), 1),
        "CQ3 expanded loadout frame validates");
  const auto &g = cq_geometry(14);
  V start = g.muzzle * .65 + V{0, 1.45, 0},
    zero = (g.sight * .65 + V{0, 0, -g.zero_distance} - g.muzzle * .65).unit();
  int shots = 0;
  for (const auto &event : core->events())
    if (event.seq && event.kind == EventKind::SHOT) {
      ++shots;
      check((event.position - start).length() < 1e-6,
            "shot starts at modeled barrel");
      check((event.direction - zero).length() < 1e-6,
            "stationary burst targets authored optic zero");
    }
  check(shots >= 3, "burst shot events recorded");
  // Held automatic fire pays for every shot, including after the initial edge.
  for(int weapon : {0,11}) {
    auto fixture=std::make_unique<Core>();fixture->configure_cq(cfg);
    auto life=fixture->join(1,0,{},1u<<weapon,{100,100,100,100});
    ClassState loadout;loadout.role=weapon==11?Role::TECHNICIAN:Role::SHOCKTROOP;
    loadout.xp.fill(7500);loadout.primary_t2[3]=true;loadout.secondary_t2[0]=true;
    check(fixture->configure_player(life,loadout),"automatic/dumb-fire fixture profile");
    auto *player=fixture->resolve(life);int ammo=player->ammo[weapons()[weapon].ammo];
    for(int tick=0;tick<45;++tick) {
      Command command;command.life=life.life;command.seq=tick;command.weapon=weapon;command.fire=true;
      check(fixture->submit(life,command),"held fire command");fixture->advance(world);
    }
    player=fixture->resolve(life);
    check(player->shots>=(weapon==0?3:1),"automatic pistol repeats and launcher fires without lock");
    if(weapon==11)for(const auto &shot:fixture->projectiles_state())if(shot.active)check(shot.target_vehicle==0,"unlocked launcher round is unguided");
    check(ammo-player->ammo[weapons()[weapon].ammo]==int(player->shots),"each automatic shot consumes ammunition");

  }
  Reload pack;pack.init(0);pack.mag=false;pack.pack_delay(true,0,0,1,6.6);
  pack.mag=true;pack.pack_delay(false,0,120,2,6.6);
  check(!pack.can_fire(true),"minigun pack cannot skip arming delay");
  pack.pack_delay(true,120,120,7.6,6.6);
  check(pack.can_fire(true),"minigun pack arms without a charging handle");

}
