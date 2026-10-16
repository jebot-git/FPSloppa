#include "authority_core.h"
#include "authority_wire.h"
namespace cqauthority {
void Core::snapshot_extended() {
  using namespace wire;
  frame_[3] = cq.enabled ? '3':'2';
  {
    Section section(frame_, 1);
    uint16_t count = 0;
    for (auto &p : players_)
      count += p.active && p.pose.tracked;
    append(frame_, count);
    for (auto &p : players_)
      if (p.active && p.pose.tracked) {
        append(frame_, p.handle.id);
        append(frame_, p.handle.life);
        append(frame_, uint8_t((p.pose.left_handed ? 1 : 0) |
                               (p.pose.has_offhand ? 2 : 0)));
        real(frame_, p.pose.height);
        for (auto *t :
             {&p.pose.head, &p.pose.left, &p.pose.right, &p.pose.weapon})
          transform(frame_, *t);
        if (p.pose.has_offhand)
          transform(frame_, p.pose.offhand);
      }
  }
  {
    Section section(frame_, 2);
    uint16_t count = 0;
    for (auto &p : players_)
      if (p.active)
        for (auto &r : p.physical)
          count += r.initialised;
    append(frame_, count);
    for (auto &p : players_)
      if (p.active)
        for (int w = 0; w < int(WEAPON_COUNT); ++w) {
          auto &r = p.physical[w];
          if (!r.initialised)
            continue;
          append(frame_, p.handle.id);
          append(frame_, p.handle.life);
          append(frame_, uint8_t(w));
          append(frame_, uint16_t(p.clips[w]));
          uint16_t flags = 1 | (r.mag ? 2 : 0) | (r.ready ? 4 : 0) |
                           (r.grab == Grab::RACK ? 8 : 0) |
                           (r.locked ? 32 : 0) |
                           (r.grab == Grab::MAGAZINE ? 1024 : 0);
          append(frame_, flags);
          real(frame_, r.stroke);
          append(frame_, uint8_t(r.carry));
          append(frame_, int8_t(p.reloading));
          real(frame_, p.reload_at);
          append(frame_, int8_t(p.cycling));
          real(frame_, p.cycle_at);
          real(frame_, r.pack_until);
          append(frame_, uint16_t(r.carried_rounds));
          append(frame_, r.event);
        }
  }
  {
    Section section(frame_, 3);
    uint16_t count = 0;
    for (auto &s : projectiles_)
      count += s.active;
    append(frame_, count);
    for (auto &s : projectiles_)
      if (s.active) {
        append(frame_, s.key);
        append(frame_, s.owner.id);
        append(frame_, s.owner.life);
        append(frame_, int8_t(s.team));
        append(frame_, uint8_t(s.weapon));
        vec(frame_, s.position);
        vec(frame_, s.velocity);
        real(frame_, s.remaining);
        append(frame_, uint8_t(s.stuck | (s.quake << 1)));
        for (double n : {s.gravity, s.arm, s.sweep_radius, s.age})
          real(frame_, n);
      }
  }
  {
    Section section(frame_, 4);
    uint16_t count = 0;
    for (auto &p : players_)
      count += p.active;
    append(frame_, count);
    for (auto &p : players_)
      if (p.active) {
        append(frame_, p.handle.id);
        append(frame_, p.handle.life);
        append(frame_, uint8_t(p.jetpack.mode));
        for (double n :
             {p.jetpack.age, p.jetpack.cooldown, p.jetpack.tap,
              p.jetpack.distance, p.jetpack.heading.x, p.jetpack.heading.z})
          real(frame_, n);
        append(frame_, p.jetpack.activation);
      }
  }
  if (cq.enabled)
    snapshot_cq();
}
} // namespace cqauthority
