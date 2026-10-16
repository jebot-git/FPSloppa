#include "authority_core.h"
#include "authority_wire.h"
namespace cqauthority {
void Core::snapshot_cq() {
  using namespace wire;
  if(cq.squads){
    Section section(frame_,15);uint16_t count=0;for(const auto &p:players_)count+=p.active;append(frame_,count);
    for(const auto &p:players_)if(p.active){append(frame_,p.handle.id);append(frame_,p.handle.life);append(frame_,uint8_t(p.squad+1));real(frame_,p.combat_until);}
  }
  {
    Section section(frame_,16);uint16_t count=0;for(const auto &p:players_)count+=p.active;append(frame_,count);
    for(const auto &p:players_)if(p.active){
      append(frame_,p.handle.id);append(frame_,p.handle.life);append(frame_,p.owned);
      for(int w=12;w<int(WEAPON_COUNT);++w)append(frame_,uint16_t(p.clips[w]));
      uint8_t mask=0;for(int i=0;i<4;++i)mask|=p.classes.primary_t3[i]<<i;append(frame_,mask);
    }
  }
  {
    Section section(frame_, 5);
    uint16_t count = 0;
    for (auto &p : players_)
      count += p.active;
    append(frame_, count);
    for (auto &p : players_)
      if (p.active) {
        const auto &c = p.classes;
        append(frame_, p.handle.id);
        append(frame_, p.handle.life);
        append(frame_, uint8_t(c.role));
        append(frame_, uint8_t(c.next));
        append(frame_, uint8_t(c.equipped_t2 ? 2 : 1));
        append(frame_, uint8_t((p.incapacitated ? 1 : 0) | (c.nvg ? 2 : 0) |
                               (p.death_gibbed ? 4 : 0) | (p.staging ? 8 : 0) | (p.input.vr && !p.input.weapon_held ? 16 : 0)));
        for (int xp : c.xp)
          append(frame_, int32_t(xp));
        append(frame_, uint16_t(p.armor));
        append(frame_, uint8_t(p.armor_tier));
        append(frame_, uint8_t(p.grenade_count));
        append(frame_, int16_t(p.vehicle));
        append(frame_, int32_t(p.kills));
        append(frame_, int32_t(p.deaths));
        real(frame_, p.bleed_remaining);
        real(frame_, p.inject_progress);
        append(frame_, p.injector.id);
        append(frame_, p.injector.life);
        for (double t : {c.box_ready, c.cloak_until, c.cloak_ready,
                         c.drone_ready, c.strike_ready, c.turret_ready,
                         c.blind_until, p.spotted[0], p.spotted[1]})
          real(frame_, t);
        append(frame_, uint8_t(p.designation.active));
        vec(frame_, p.designation.start);
        vec(frame_, p.designation.position);
        vec(frame_, p.designation.direction);
        real(frame_, p.designation.until);
        for (auto *choices : {&c.primary_t2, &c.secondary_t2, &c.utility_t2}) {
          uint8_t mask = 0;
          for (int i = 0; i < 4; ++i)
            mask |= (*choices)[i] << i;
          append(frame_, mask);
        }
        append(frame_, int8_t(p.vehicle_seat));
      }
  }
  {
    Section section(frame_, 6);
    append(frame_, uint16_t(points.count));
    append(frame_, int8_t(points.winner));
    for (int n : points.scores)
      append(frame_, uint16_t(n));
    real(frame_, time_);
    real(frame_, cq.light_fraction);
    append(frame_, round_epoch_);
    real(frame_, intermission());
    real(frame_, time_ + cq.cycle_offset);
    real(frame_, round_remaining());
    for (size_t i = 0; i < points.count; ++i) {
      auto &z = points.zones[i];
      vec(frame_, z.position);
      real(frame_, z.radius);
      append(frame_, int8_t(z.owner));
      for (double n : z.progress)
        real(frame_, n);
      real(frame_, z.credit);
      append(frame_, uint8_t(z.contested));
    }
  }
  {
    Section section(frame_, 7);
    uint16_t count = 0;
    for (auto &b : boxes_)
      count += b.active;
    append(frame_, count);
    for (auto &b : boxes_)
      if (b.active) {
        append(frame_, b.key);
        append(frame_, b.owner.id);
        append(frame_, b.owner.token);
        append(frame_, int8_t(b.team));
        append(frame_, uint8_t(b.health));
        vec(frame_, b.position);
        append(frame_, uint16_t(b.remaining));
      }
  }
  {
    Section section(frame_, 8);
    uint16_t count = 0;
    for (auto &f : fields_)
      count += f.active;
    append(frame_, count);
    for (auto &f : fields_)
      if (f.active) {
        append(frame_, f.key);
        append(frame_, f.owner.id);
        append(frame_, f.owner.token);
        append(frame_, int8_t(f.team));
        vec(frame_, f.position);
        append(frame_, uint16_t(f.health));
        real(frame_, f.energy);
        real(frame_, f.until);
        real(frame_, f.hit_at);
      }
  }
  snapshot_entities();
}
} // namespace cqauthority
