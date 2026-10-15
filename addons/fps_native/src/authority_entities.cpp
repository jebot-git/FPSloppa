#include "authority_core.h"
#include "authority_wire.h"
namespace cqauthority {
void Core::snapshot_entities() {
  using namespace wire;
  {
    Section section(frame_, 9);
    uint16_t count = 0;
    for (auto &v : vehicles_)
      count += v.active;
    append(frame_, count);
    for (size_t i = 0; i < vehicles_.size(); ++i) {
      auto &v = vehicles_[i];
      if (!v.active)
        continue;
      append(frame_, v.key);
      append(frame_, uint8_t(i));
      append(frame_, uint8_t(v.kind));
      append(frame_, int8_t(v.team));
      append(frame_, uint8_t(v.grounded));
      append(frame_, v.pilot.id);
      append(frame_, v.pilot.life);
      vec(frame_, v.position);
      vec(frame_, v.velocity);
      vec(frame_, v.direction);
      vec(frame_, v.normal);
      for (double n : {v.yaw, v.hp, v.visual_y, v.reload_at, v.next, v.shot_at})
        real(frame_, n);
      append(frame_, uint8_t(v.rounds));
      append(frame_, uint8_t(v.remaining));
    }
  }
  {
    Section section(frame_, 10);
    uint16_t count = 0;
    for (auto &t : turrets_)
      count += t.active;
    append(frame_, count);
    for (auto &t : turrets_)
      if (t.active) {
        append(frame_, t.key);
        append(frame_, t.owner.id);
        append(frame_, t.owner.token);
        append(frame_, int8_t(t.team));
        vec(frame_, t.position);
        vec(frame_, t.direction);
        real(frame_, t.hp);
        append(frame_, uint8_t(t.ammo));
        real(frame_, t.shot_at);
        append(frame_, t.target_vehicle);
        append(frame_, t.target_player.id);
        append(frame_, t.target_player.life);
      }
  }
  {
    Section section(frame_, 11);
    uint16_t count = 0;
    for (auto &f : flights_)
      count += f.active;
    append(frame_, count);
    for (auto &f : flights_)
      if (f.active) {
        append(frame_, f.key);
        append(frame_, uint8_t(f.strike));
        append(frame_, f.owner.id);
        append(frame_, f.owner.token);
        append(frame_, int8_t(f.team));
        vec(frame_, f.start);
        vec(frame_, f.direction);
        vec(frame_, f.target);
        for (double n : {f.length, f.at, f.until, f.impact_at, f.step})
          real(frame_, n);
        append(frame_, uint8_t(f.delivered));
      }
  }
  {
    Section section(frame_, 12);
    uint16_t count = 0;
    for (auto &g : grenades_)
      count += g.active;
    append(frame_, count);
    for (auto &g : grenades_)
      if (g.active) {
        append(frame_, g.key);
        append(frame_, g.owner.id);
        append(frame_, g.owner.token);
        append(frame_, g.life);
        append(frame_, int8_t(g.team));
        append(frame_, uint8_t(g.kind));
        vec(frame_, g.position);
        vec(frame_, g.velocity);
        real(frame_, g.age);
      }
  }
  {
    Section section(frame_, 13);
    uint16_t count = 0;
    for (size_t i = 0; i < event_count_; ++i)
      count +=
          time_ - events_[(event_next_ + events_.size() - event_count_ + i) %
                          events_.size()]
                      .at <=
          1;
    append(frame_, count);
    for (size_t i = 0; i < event_count_; ++i) {
      auto &e = events_[(event_next_ + events_.size() - event_count_ + i) %
                        events_.size()];
      if (time_ - e.at > 1)
        continue;
      append(frame_, e.seq);
      append(frame_, uint8_t(e.kind));
      append(frame_, e.actor.id);
      append(frame_, e.actor.life);
      append(frame_, e.entity);
      vec(frame_, e.position);
      vec(frame_, e.direction);
      real(frame_, e.at);
      real(frame_, e.value);
      append(frame_, int16_t(e.detail));
    }
  }
  {
    Section section(frame_, 14);
    uint16_t count = 0;
    for (auto &p : players_)
      count += p.active;
    append(frame_, count);
    for (auto &p : players_)
      if (p.active) {
        append(frame_, p.handle.id);
        append(frame_, p.handle.life);
        append(frame_, p.owned);
        for (double n : {p.cooldown, p.invulnerable, p.respawn_at, p.stamina})
          real(frame_, n);
        append(frame_, p.lock_vehicle);
        real(frame_, p.lock_elapsed);
        real(frame_, p.melee_ready);
        append(frame_, uint8_t(p.grenade_primed | (p.grenade_selected << 1) |
                               (p.grenade_offhand << 2)));
        real(frame_, p.grenade_ready);
        real(frame_, p.grenade_until);
        append(frame_, int8_t(p.reloading));
        real(frame_, p.reload_at);
        append(frame_, int8_t(p.cycling));
        real(frame_, p.cycle_at);
        real(frame_, p.charge_at);
        append(frame_, uint8_t(p.salvo_left));
        append(frame_, uint8_t(p.burst_left));
        append(frame_, p.jump_ack);
        append(frame_, p.jetpack_ack);
        append(frame_, p.fire_ack);
      }
  }
}
} // namespace cqauthority
