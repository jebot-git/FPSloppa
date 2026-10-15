#include "authority_core.h"
#include "authority_weapon_geometry.h"
#include "authority_wire.h"
#include <chrono>
#include <cstring>
#include <type_traits>
namespace cqauthority {
const std::array<Weapon, 12> &weapons() {
  // CQ armory numerical values. Utility slots intentionally have no firearm
  // definition.
  static const std::array<Weapon, 12> w = {
      {{3, 18, .36, 14, 75, 0, 90, 0, .025, 2.2, 3},
       {1, 36, .075, 16, 90, 0, 180, 0, .035},
       {0, 7, .35, 25, 0, 0, 100},
       {1, 40, .06, 12, 150, 0, 60, 0, .015},
       {1, 30, .12, 18, 70, 0, 160, 0, .035},
       {2, 3, 1, 100, 55, 12, 825, 120, 5, 6.6, 1, 3, .35},
       {},
       {},
       {},
       {0, 7, .6, 40, 0, 0, 200},
       {1, 10, .8, 55, 0, 0, 250},
       {2, 3, 1, 100, 40, 0, 600, 120, 5, 6.6}}};
  return w;
}
Core::Core() { frame_.reserve(512 * 1024); }
bool Core::configure_tick_rate(int hz) {
  if ((hz != 30 && hz != 60) || tick_ != 0 ||
      std::any_of(players_.begin(), players_.end(), [](const Player &p) { return p.active; }))
    return false;
  return transition_tick_rate(hz);
}
bool Core::transition_tick_rate(int hz) {
  if (hz != 30 && hz != 60) return false;
  tick_hz_ = hz; step_ = 1.0 / double(hz); return true;
}
Player *Core::find(int64_t id) {
  for (auto &p : players_)
    if (p.active && p.handle.id == id)
      return &p;
  return nullptr;
}
const Player *Core::find(int64_t id) const {
  for (auto &p : players_)
    if (p.active && p.handle.id == id)
      return &p;
  return nullptr;
}
Player *Core::resolve(Handle h) {
  auto *p = find(h.id);
  return p && p->handle == h ? p : nullptr;
}
Handle Core::join(int64_t id, int team, V position, uint16_t owned,
                  std::array<int, 4> ammo) {
  if (id == 0 || (!cq.enabled && id < 0) || find(id) || !position.finite() ||
      team < 0 || team > (cq.enabled ? 1 : 2) || (owned & ~uint16_t(0xfff)) ||
      !owned || !next_life_)
    return {};
  if (cq.squads) { int count=0;for (const auto &p:players_) count+=p.active&&p.team==team;if(count>=cq.team_limit)return {}; }
  for (int n : ammo)
    if (n < 0 || n > 10000)
      return {};
  // Utilities require the CQ feature adapter and are not accepted by this
  // infantry fixture.
  for (int i = 0; i < 12; ++i)
    if (!cq.enabled && (owned & (1 << i)) && weapons()[i].ammo < 0)
      return {};
  for (auto &p : players_)
    if (!p.active) {
      p = Player{};
      p.active = true;
      p.bot = cq.enabled && id < 0;
      p.handle = {id, next_life_++};
      p.session_token = p.handle.life;
      p.team = team;
      p.position = position;
      p.spawn_position = position;
      p.previous_position = position;
      p.owned = owned;
      p.ammo = ammo;
      p.spawn_ammo = ammo;
      for (int i = 0; i < 12; ++i)
        if (owned & (1 << i)) {
          if (weapons()[i].ammo >= 0)
            p.clips[i] = std::min(weapons()[i].mag, ammo[weapons()[i].ammo]);
          p.weapon = i;
        }
      if (cq.enabled)
        spawn_class(p);
      if(cq.squads) { p.staging=!p.bot;if(p.bot){int best=0;for(int s=1;s<4;++s)if(squad_size(team,s)<squad_size(team,best))best=s;p.squad=best;} }
      p.input.life = p.handle.life;
      p.input.weapon = p.weapon;
      return p.handle;
    }
  return {};
}
bool Core::leave(Handle h) {
  auto *p = resolve(h);
  if (!p)
    return false;
  if (cq.enabled) {
    if (p->vehicle >= 0) {
      auto &v = vehicles_[p->vehicle];
      for(auto &seat:v.seats) if(seat==h) seat={};
      if(v.pilot==h) {
        v.pilot={};
        for(auto seat:v.seats) if(seat.id){v.pilot=seat;break;}
        v.remaining=0;v.speed=0;
      }
    }
    auto who = session(*p);
    for (auto &b : boxes_)
      if (b.owner == who)
        b.active = false;
  }
  p->active = false;
  return true;
}
Handle Core::respawn(Handle h, V at) {
  auto *p = resolve(h);
  if (!p || !p->dead || !at.finite())
    return {};
  auto id = p->handle.id;
  auto team = p->team;
  auto owned = p->owned;
  auto ammo = p->spawn_ammo;
  auto reach = p->reach;
  auto classes = p->classes;
  bool profile_loaded = p->profile_loaded, stress = p->stress, staging = p->staging;
  int squad=p->squad;auto base=p->spawn_position;
  auto token = p->session_token;
  auto kills = p->kills;
  auto deaths = p->deaths;
  auto weapon = p->weapon;
  p->active = false;
  auto next = join(id, team, at, owned, ammo);
  if (auto *fresh = resolve(next)) {
    fresh->squad=squad;fresh->spawn_position=base;
    fresh->reach = reach;
    fresh->classes = classes;
    fresh->profile_loaded = profile_loaded;
    fresh->stress = stress;
    fresh->staging = staging;
    fresh->session_token = token;
    if (cq.enabled)
      spawn_class(*fresh);
    fresh->kills = kills;
    fresh->deaths = deaths;
    if (!cq.enabled) {
      fresh->weapon = weapon;
      fresh->input.weapon = weapon;
    }
  }
  return next;
}
bool Core::submit(Handle h, const Command &c) {
  auto *p = resolve(h);
  if (!p || c.jump_event > INT32_MAX || c.jetpack_event > INT32_MAX ||
      c.fire_event > INT32_MAX || c.fire_mask > 7 ||
      (c.fire_event && c.fire_weapon != c.weapon) || c.jump_seq > c.seq ||
      c.jump_seq < -1 || !std::isfinite(c.view_time) || c.life != h.life ||
      c.seq < 0 || c.seq > 2147483647 || c.seq <= p->last_seq ||
      !std::isfinite(c.x) || !std::isfinite(c.z) || !std::isfinite(c.yaw) ||
      !std::isfinite(c.pitch) || std::abs(c.yaw) > 1e6 ||
      std::abs(c.pitch) > 1.570797 || c.weapon < 0 || c.weapon >= 12 ||
      !(p->owned & (1 << c.weapon)) || !c.pose.valid() || !c.room.finite()) {
    ++counters.rejected;
    return false;
  }
  if (p->count == INPUT_DEPTH) {
    ++counters.overflow;
    ++counters.rejected;
    return false;
  }
  Command safe = c;
  safe.stamp = time_;
  safe.pitch = std::clamp(safe.pitch, -1.5707963267948966, 1.5707963267948966);
  if (safe.pose.tracked && safe.pose.has_height)
    safe.pose.height = std::clamp(safe.pose.height, .80, 1.65);
  safe.room = validate_room(safe.room, safe.pose);
  safe.vr = safe.vr || safe.pose.tracked;
  if (safe.vr && !safe.pose.tracked)
    safe.blocked = true;
  double n = std::hypot(c.x, c.z);
  if (!std::isfinite(n)) {
    ++counters.rejected;
    return false;
  }
  if (n > 1) {
    safe.x /= n;
    safe.z /= n;
  }
  p->queue[(p->head + p->count) % INPUT_DEPTH] = safe;
  ++p->count;
  p->last_seq = c.seq;
  p->last_input = time_;
  ++counters.accepted;
  return true;
}
bool Core::submit_packet(int64_t peer_id, const uint8_t *data, size_t size) {
  auto *p = find(peer_id);
  if (!p || !data || size < 30 || data[0] != 'C' || data[1] != 'Q' ||
      data[2] != 'I' || (data[3] != '1' && data[3] != '2') ||
      (data[29] & 128) || (data[3] == '1' && size != 30) ||
      (data[3] == '2' && (size < 48 || size > 310))) {
    ++counters.rejected;
    return false;
  }
  auto u32 = [&](size_t offset) {
    uint32_t value = 0;
    for (size_t i = 0; i < 4; ++i)
      value |= uint32_t(data[offset + i]) << (8 * i);
    return value;
  };
  auto scalar = [&](size_t offset) {
    uint32_t bits = u32(offset);
    float value;
    std::memcpy(&value, &bits, 4);
    return double(value);
  };
  Command c;
  c.life = u32(4);
  c.seq = u32(8);
  c.x = scalar(12);
  c.z = scalar(16);
  c.yaw = scalar(20);
  c.pitch = scalar(24);
  c.weapon = data[28];
  uint8_t bits = data[29];
  c.fire = bits & 1;
  c.jump = bits & 2;
  c.reload = bits & 4;
  c.slow = bits & 8;
  c.crouch = bits & 16;
  c.prone = bits & 32;
  c.blocked = bits & 64;
  if (data[3] == '2') {
    uint16_t flags = uint16_t(data[30]) | uint16_t(data[31]) << 8;
    if (((flags & 16384) && !(flags & 8192))) {
      ++counters.rejected;
      return false;
    }
    c.weapon_held = !(flags & 8192) || (flags & 16384);
    c.drag = flags & 512;
    c.melee = flags & 1024;
    c.respawn = flags & 2048;
    c.vr = flags & 1;
    c.pose.tracked = flags & 2;
    c.pose.has_offhand = flags & 4;
    c.pose.left_handed = flags & 8;
    c.pose.has_height = flags & 16;
    c.reload_grip = flags & 32;
    c.reload_trigger = flags & 32768;
    c.jetpack = flags & 64;
    c.offhand_fire = flags & 128;
    size_t base = c.pose.tracked ? (c.pose.has_offhand ? 288 : 240) : 48;
    if (size != base + ((flags & 256) ? 4 : 0) + ((flags & 4096) ? 18 : 0) ||
        (!c.pose.tracked && (flags & 28))) {
      ++counters.rejected;
      return false;
    }
    if (flags & 256)
      c.view_time = scalar(base);
    if (flags & 4096) {
      size_t at = base + ((flags & 256) ? 4 : 0);
      c.jump_event = u32(at);
      c.jump_seq = int32_t(u32(at + 4));
      c.jetpack_event = u32(at + 8);
      c.fire_event = u32(at + 12);
      c.fire_weapon = data[at + 16];
      c.fire_mask = data[at + 17];
    }
    c.room = {scalar(32), scalar(36), scalar(40)};
    c.pose.height = scalar(44);
    if (c.pose.tracked) {
      size_t at = 48;
      for (auto *t : {&c.pose.head, &c.pose.left, &c.pose.right, &c.pose.weapon,
                      &c.pose.offhand}) {
        if (t == &c.pose.offhand && !c.pose.has_offhand)
          break;
        for (auto *v : {&t->basis.x, &t->basis.y, &t->basis.z, &t->origin}) {
          *v = {scalar(at), scalar(at + 4), scalar(at + 8)};
          at += 12;
        }
      }
    }
  }
  return submit(p->handle, c);
}
void Core::consume(Player &p) {
  p.press_pending = false;
  p.jump_pending = false;
  while (p.count) {
    auto c = p.queue[p.head];
    p.head = (p.head + 1) % INPUT_DEPTH;
    --p.count;
    if (c.jump_event > p.jump_ack && c.jump_event - p.jump_ack <= 32) {
      p.jump_ack = c.jump_event;
      if (!p.dead && !p.incapacitated && !c.blocked)
        p.jump_pending = true;
    }
    if (c.jetpack_event > p.jetpack_ack &&
        c.jetpack_event - p.jetpack_ack <= 32) {
      p.jetpack_ack = c.jetpack_event;
      if (!p.dead && !p.incapacitated && !c.blocked)
        p.jet_event_pending = true;
    }
    if (c.fire_event > p.fire_ack && c.fire_event - p.fire_ack <= 32) {
      p.fire_ack = c.fire_event;
      if (!p.dead && !p.incapacitated && !c.blocked) {
        p.press_pending |= c.fire_mask & 1;
        p.nvg_pending |= c.fire_mask & 4;
      }
    }
    if (!c.blocked) {
      p.press_pending |= c.fire && !p.input.fire;
      p.jump_pending |= c.jump && !p.input.jump;
    }
    if (c.vr != p.input.vr)
      for (auto &physical : p.physical)
        if (physical.initialised)
          physical.interrupt();
    if (c.pose.tracked && p.pose.tracked &&
        c.pose.left_handed == p.pose.left_handed &&
        c.stamp - p.pose_stamp >= .008 && c.stamp - p.pose_stamp <= .16) {
      V before = ((p.grenade_primed && !p.grenade_offhand) ? (p.pose.left_handed ? p.pose.left : p.pose.right) : (p.pose.left_handed ? p.pose.right : p.pose.left)).origin -
                 p.pose.head.origin;
      V after = ((p.grenade_primed && !p.grenade_offhand) ? (c.pose.left_handed ? c.pose.left : c.pose.right) : (c.pose.left_handed ? c.pose.right : c.pose.left)).origin -
                c.pose.head.origin;
      p.throw_velocity =
          ((after - before) / (c.stamp - p.pose_stamp)).limited(12);
    } else if (c.stamp > p.pose_stamp)
      p.throw_velocity = {};
    if (c.offhand_fire && !p.input.offhand_fire)
      p.nvg_pending = true;
    p.pose = c.pose;
    p.room = c.room;
    p.pose_stamp = c.stamp;
    p.input = c;
  }
  if (p.incapacitated) {
    p.input.x = 0;
    p.input.z = 0;
    p.input.jump = false;
    p.input.prone = true;
    p.input.fire = false;
    p.input.offhand_fire = false;
    p.input.blocked = true;
    p.pose = {};
    p.room = {};
    p.jetpack = {};
  }
  if (time_ - p.last_input > .35 || p.input.blocked) {
    p.input.x = 0;
    p.input.z = 0;
    p.input.fire = false;
    p.input.jump = false;
    p.input.reload = false;
    p.press_pending = false;
    p.jump_pending = false;
    p.input.blocked = true;
    p.burst_left = 0;
    p.salvo_left = 0;
    p.charge_at = 0;
    p.reloading = -1;
    p.room = {};
    for (auto &physical : p.physical)
      if (physical.initialised)
        physical.interrupt();
  }
  if (p.input.weapon != p.weapon) {
    if (p.physical[p.weapon].initialised)
      p.physical[p.weapon].interrupt();
    p.grenade_selected = p.grenade_primed = p.grenade_offhand =
        p.grenade_trigger = false;
    p.weapon = p.input.weapon;
    p.recoil = {};
    p.cooldown = std::max(p.cooldown, .28);
    p.reloading = -1;
    p.charge_at = 0;
    p.burst_left = 0;
    p.salvo_left = 0;
  }
  p.yaw = p.input.yaw;
  p.pitch = p.input.pitch;
}
void Core::movement(Player &p, Host &host) {
  if (p.staging) { p.velocity = {}; host.seat(p.handle, p.position, true); return; }
  auto &c = p.input;
  double requested = c.prone ? .65 : c.crouch ? 1.05 : cq.enabled ? 1.70 : 1.65;
  if (p.pose.tracked) {
    requested = std::max(p.pose.has_height ? p.pose.height : 1.65,
                         std::clamp(p.pose.head.origin.y + .10, .80, 1.65));
    if (c.prone && p.pose.head.origin.y < .69)
      requested = std::clamp(p.pose.head.origin.y + .10, .65, .79);
  }
  double height = host.posture(p.handle, requested);
  if (!std::isfinite(height))
    return;
  p.height =
      std::clamp(height, .65, cq.enabled && !p.pose.tracked ? 1.70 : 1.65);
  if (p.pose.tracked) {
    p.pose.height = p.height;
    p.pose.has_height = true;
  }
  p.stamina = std::max(0., p.stamina - step_);
  bool ground = p.grounded && p.velocity.y <= 0;
  bool jumping =
      ground && p.height >= .8 && (p.jump_pending || (c.jump && !p.jump_held));
  V wish = B::yaw(p.yaw).apply({c.x, 0, c.z});
  double room_scale =
      1 - std::min(p.room.length() / step_ / ((c.slow ? 5.2 : 9.4)), 1.);
  wish = wish * room_scale;
  bool boosted = p.jetpack.tick(p.velocity, wish, step_, c.jump || p.jump_pending,
                                p.jump_held && !p.jump_pending,
                                c.jetpack || p.jet_event_pending,
                                p.jetpack_enabled, c.blocked, p.height < .8);
  p.input.jetpack = false;
  p.jet_event_pending = false;
  if (boosted) {
    V before = p.position;
    auto result = host.move(
        {p.handle, p.position, p.velocity, height, p.yaw, p.grounded, false},
        step_);
    if (result.position.finite() && result.velocity.finite()) {
      p.position = result.position;
      p.velocity = result.velocity;
      p.grounded = result.grounded;
      p.jetpack.moved(p.velocity, before, p.position, p.grounded,
                      result.ceiling);
    }
    p.jump_held = c.jump;
    if (p.pose.tracked && p.room.length2() > 0) {
      V applied = host.room_move(p.handle, p.room, p.yaw);
      if (applied.finite()) {
        p.position = p.position + applied;
        V shift = B::yaw(p.yaw).inverse(applied);
        p.room = p.room - shift;
        p.pose.rebase(shift);
      }
    }
    if (cq.enabled && host.water(p.position))
      damage(p.handle, {}, 10000, DamageKind::WATER);
    if (p.position.y < (cq.enabled ? cq.fall_limit : -200))
      damage(p.handle, {}, 10000, DamageKind::FALL);
    return;
  }
  p.jump_held = c.jump && p.height >= .8;
  double speed = 250. / 32 * (c.slow ? .52 : 1) *
                 (p.height < .8    ? .18
                  : p.height < 1.6 ? .333
                                   : 1);
  V horizontal{p.velocity.x, 0, p.velocity.z};
  if (jumping) {
    if (horizontal.length() > 250. / 32 * 1.2)
      horizontal = horizontal.unit() * (250. / 32 * 1.2 * .8);
    p.velocity.y = 268.3281573 / 32 * std::max(0., 1 - .19 * p.stamina);
    p.stamina = 1.315789429;
  }
  bool walk = ground && !jumping;

  double strength = wish.length();
  double current = horizontal.length();
  if (walk && current > 0) {
    double stop = strength > 0 && strength < 1
                      ? std::min(75. / 32, speed * strength)
                      : 75. / 32;
    Motion probe{p.handle, p.position, p.velocity, p.height,
                 p.yaw,    p.grounded, false};
    horizontal = horizontal *
                 (std::max(0., current - std::max(current, stop) * 4 *
                                             (host.edge(probe) ? 2 : 1) * step_) /
                  current) *
                 std::pow(std::max(0., 1 - .19 * p.stamina), step_ * 100);
  }
  if (strength > 0) {
    auto direction = wish.unit();
    double requested = speed * strength;
    double available = (walk ? requested : std::min(requested, 30. / 32)) -
                       horizontal.dot(direction);
    if (available > 0)
      horizontal =
          horizontal +
          direction * std::min(available, (walk ? 5 : 10) * requested * step_);
  }
  if (walk && horizontal.length() < 1. / 32)
    horizontal = {};
  p.velocity = {horizontal.x,
                walk ? -.2 : std::max(-62.5, p.velocity.y - 25 * step_ * .5),
                horizontal.z};
  for (auto *v : {&p.velocity.x, &p.velocity.y, &p.velocity.z})
    *v = std::clamp(*v, -62.5, 62.5);
  auto result = host.move(
      {p.handle, p.position, p.velocity, height, p.yaw, p.grounded, walk}, step_);
  // Host results are trusted collision results, but never admit NaNs into
  // resident state.
  if (!result.position.finite() || !result.velocity.finite() ||
      !std::isfinite(result.height))
    return;
  p.position = result.position;
  p.velocity = result.velocity;
  p.height = std::clamp(result.height, .65, 1.65);
  p.grounded = result.grounded;
  if (p.grounded && (!jumping || p.velocity.y <= 0))
    p.velocity.y = 0;
  else
    p.velocity.y = std::max(-62.5, p.velocity.y - 25 * step_ * .5);
  if (p.pose.tracked && p.room.length2() > 0) {
    V applied = host.room_move(p.handle, p.room, p.yaw);
    if (applied.finite()) {
      p.position = p.position + applied;
      V shift = B::yaw(p.yaw).inverse(applied);
      p.room = p.room - shift;
      p.pose.rebase(shift);
    }
  }
  if (cq.enabled && host.water(p.position))
    damage(p.handle, {}, 10000, DamageKind::WATER);
  if (p.position.y < (cq.enabled ? cq.fall_limit : -200))
    damage(p.handle, {}, 10000, DamageKind::FALL);
}
bool Core::damage(Handle victim, Handle source, double amount, DamageKind kind,
                  bool headshot, Session credit, int weapon) {
  auto *p = resolve(victim);
  auto *a = resolve(source);
  if (!a && credit.id == source.id)
    a = owner(credit);
  if (!p || p->staging || p->dead || !std::isfinite(amount) || amount <= 0)
    return false;
  bool bypass = kind == DamageKind::WATER || kind == DamageKind::FALL ||
                kind == DamageKind::BLEEDOUT ||
                kind == DamageKind::VEHICLE_DESTROYED ||
                kind == DamageKind::HEAVY_RUNOVER;
  if (p->stress && !bypass)
    return false;
  if (cq.enabled &&
      (points.winner != -2 || (p->invulnerable > time_ && !bypass) ||
       (p->vehicle >= 0 && !bypass)))
    return false;
  if (a && a != p && same_team(*a, *p))
    return false;
  double dealt = amount;
  if (cq.enabled && p->armor > 0 && !bypass) {
    int saved = std::min(p->armor, int(amount / (p->armor_tier == 2 ? 2 : 3)));
    p->armor -= saved;
    dealt -= saved;
  }
  auto feedback = [&](bool dead, bool gib) {
    if (cq.enabled) {
      bool blast = kind == DamageKind::ORDNANCE || kind == DamageKind::GRENADE;
      int flags = int(dead) | (int(gib) << 1) | (int(blast) << 2) |
                  (int(headshot) << 3) |
                  ((std::clamp(weapon, -1, 11) + 1) << 4) | (int(kind) << 8);
      V direction = a ? (p->position - a->position).unit() : V{0, 1, 0};
      emit(EventKind::HURT, p->handle,
           p->position + V{0, std::min(1., p->height * .6), 0}, direction,
           flags, dealt, a ? uint64_t(a->handle.id) : 0);
    }
  };
  if(cq.squads){p->combat_until=time_+8.;if(a&&a!=p)a->combat_until=time_+8.;}
  double old_hp = p->hp;
  p->hp = std::max(0., p->hp - dealt);
  ++counters.damage;
  if (!p->hp) {
    bool gibbed = bypass || headshot || dealt - old_hp >= 25;
    bool forced_down = kind == DamageKind::RUNOVER;
    if (cq.enabled && (forced_down || !gibbed)) {
      p->hp = 1;
      if (!p->incapacitated) {
        p->incapacitated = true;
        p->bleed_remaining = 10;
        p->injury_source = source;
        p->injury_credit = credit.id ? credit : a ? session(*a) : Session{};
        p->injury_weapon = weapon;
        p->injury_tick = tick_;
        p->classes.cloak_until = 0;
        p->input.fire = false;
        p->input.offhand_fire = false;
        p->room = {};
        p->jetpack = {};
      }
      feedback(false, false);
      return true;
    }
    p->death_gibbed = gibbed;
    feedback(true, gibbed);
    p->dead = true;
    p->incapacitated = false;
    p->pose = {};
    p->velocity = {};
    p->count = 0;
    p->input = {};
    p->burst_left = 0;
    p->salvo_left = 0;
    p->charge_at = 0;
    p->reloading = -1;
    p->respawn_at = time_ + 2;
    ++p->deaths;
    ++counters.deaths;
    if (a && a != p) {
      ++a->kills;
      if (cq.enabled) {
        a->classes.award(100);
        points.kill(a->team);
      }
    }
  } else
    feedback(false, false);
  return true;
}
bool Core::fire(Player &p, Host &host, bool paid) {
  if (cq.enabled && p.weapon == 11 && p.lock_elapsed < 1.5)
    return false;
  const auto &w = weapons()[p.weapon];
  if (p.staging || p.dead || p.incapacitated || p.vehicle >= 0 || p.input.blocked || (p.input.vr && !p.input.weapon_held) ||
      w.ammo < 0 || p.reloading >= 0 ||
      (!paid &&
       (p.cooldown > 1e-9 || p.clips[p.weapon] <= 0 || p.ammo[w.ammo] <= 0)))
    return false;
  Projectile *slot = nullptr;
  if (w.speed > 0) {
    for (auto &s : projectiles_)
      if (!s.active) {
        slot = &s;
        break;
      }
    if (!slot) {
      ++counters.projectile_full;
      return false;
    }
  }
  V origin = p.position + V{0, std::min(1.48, p.height - .17), 0};
  V direction{-std::sin(p.yaw) * std::cos(p.pitch), std::sin(p.pitch),
              -std::cos(p.yaw) * std::cos(p.pitch)};
  if (p.pose.tracked) {
    B body = B::yaw(p.yaw);
    auto held = cq.enabled ? p.pose.weapon : p.reach.weapon_pose(p.pose);
    V hand = p.position + body.apply(held.origin);
    origin = p.position + body.apply(held.apply((cq.enabled ? cq_geometry(p.weapon).muzzle : V{0, .12, -.35}) * .65));
    direction = body.apply(held.basis.z * -1).unit();
    V chest =
        p.position + V{0, std::max(.25, std::min(1.25, p.height - .40)), 0};
    if (host.world_trace(chest, hand, p.handle).blocked)
      return false;
    auto backoff = [](V a, V b, double fraction) {
      if (!std::isfinite(fraction))
        return b;
      return a + (b - a) *
                     std::max(0., fraction -
                                      .01 / std::max((b - a).length(), .0001));
    };
    double radius = w.splash > 0 ? .025 : std::max(.025, w.radius);
    double fraction = host.world_fraction(chest, hand, radius, p.handle);
    if (fraction == 0)
      return false;
    V anchor = backoff(chest, hand, fraction);
    fraction = host.world_fraction(anchor, origin, radius, p.handle);
    if (fraction == 0)
      return false;
    origin = backoff(anchor, origin, fraction);
  }

  if (cq.enabled && p.weapon != 5 && p.weapon != 11) {
    B basis = weapon_pose(p).basis;
    bool supported = !p.pose.tracked;
    V axis;
    if(p.pose.tracked && p.pose.has_offhand && p.input.reload_grip &&
       p.physical[p.weapon].grab==Grab::NONE && p.physical[p.weapon].carry==0) {
      auto hand=p.pose.left_handed?p.pose.right:p.pose.left;
      auto primary=p.pose.left_handed?p.pose.left:p.pose.right;
      axis=primary.basis.unapply(hand.origin-primary.origin);
      supported=(hand.origin-p.pose.weapon.apply(cq_geometry(p.weapon).support*.65)).length()<.16;
    }
    double correction=p.recoil.compensation(axis,p.pose_stamp,supported);
    V offset=p.recoil.shot(p.weapon,time_,std::hypot(p.velocity.x,p.velocity.z),p.grounded,p.height,p.pose.tracked,supported,correction,random_unit()*2-1,random_unit()*2-1);
    // Use the actual tracked/desktop sight basis; palm position never recoils.
    B sight=p.pose.tracked?B::yaw(p.yaw).product(p.pose.weapon.basis):basis;
    direction=sight.apply(offset).unit();
  }
  if (!paid) {
    consume_ammo(p, 1);
    --p.ammo[w.ammo];
  }
  p.invulnerable = 0;
  p.classes.cloak_until = 0;
  p.cooldown = w.cycle;
  if (!cq.enabled || !paid)
    ++p.shots;
  if(cq.squads)p.combat_until=time_+8.;
  ++counters.shots;
  if (cq.enabled)
    emit(EventKind::SHOT, p.handle, origin, direction, p.weapon);
  if (slot) {
    *slot = {true,     p.handle, p.team,   origin,    direction * w.speed,
             w.damage, w.splash, w.radius, w.gravity, w.range / w.speed};
    slot->credit = session(p);
    slot->key = next_projectile_++;
    slot->weapon = p.weapon;
    slot->sweep_radius = w.splash > 0 ? .025 : w.radius;
    slot->quake = p.weapon == 5 || p.weapon == 11;
    slot->direct_random = p.weapon == 5 ? 20 : 0;
    slot->target_vehicle = p.weapon == 11 ? p.lock_vehicle : 0;
  } else {
    auto hit = trace_hit(host, origin, origin + direction * w.range, p.handle,
                         0, p.input.view_time);
    double amount = hit.headshot && p.weapon == 9    ? 100
                    : hit.headshot && p.weapon == 10 ? 110
                                                     : w.damage;
    V end = hit.blocked ? hit.position : origin + direction * w.range;
    if (cq.enabled && p.weapon == 10) {
      V stop;
      amount = energy_intercept(p.team, origin, end, w.damage, stop) *
               (hit.headshot ? 2 : 1);
      end = stop;
    }
    if (hit.blocked && hit.actor.id && amount > 0)
      damage(hit.actor, p.handle, amount,
             p.weapon == 10 ? DamageKind::ENERGY : DamageKind::BULLET,
             hit.headshot, {}, p.weapon);
    if (cq.enabled) {
      emit(EventKind::RAY, p.handle, origin, direction, p.weapon,
           (end - origin).length(), uint64_t(p.team));
    }
  }
  return true;
}
void Core::consume_ammo(Player &p, int count) {
  p.clips[p.weapon] = std::max(0, p.clips[p.weapon] - count);
  if (p.weapon == 11 && p.clips[11] > 0) {
    p.cycling = 11;
    p.cycle_at = time_ + 2.7;
  }
  auto &physical = p.physical[p.weapon];
  if (physical.initialised && (p.clips[p.weapon] == 0 || p.weapon == 11)) {
    physical.ready = false;
    physical.locked = p.clips[p.weapon] == 0;
  }
}
bool Core::magazines(Player &p) {
  int w = p.weapon;
  const auto &spec = weapons()[w];
  if (spec.ammo < 0)
    return true;
  int &clip = p.clips[w];
  clip = std::min(clip, p.ammo[spec.ammo]);
  auto &state = p.physical[w];
  bool pack = w == 5 || w == 11;
  if (w == 11 && p.cycling == 11) {
    if (time_ < p.cycle_at)
      return false;
    p.cycling = -1;
    if (state.initialised)
      state.chamber(clip);
  }
  if (!p.input.vr && pack && state.pack_until > time_) {
    p.reloading = w;
    p.reload_at = state.pack_until;
    return false;
  }
  if (p.input.vr) {
    p.reloading = -1;
    if (!state.initialised)
      state.init(clip);
    state.cq_weapon = cq.enabled ? w : -1;
    bool previous_mag = state.mag;
    int before = clip;
    clip =
        state.sample(pack                           ? 12
                     : (w == 2 || w == 9 || w == 3) ? 2
                                                    : 7,
                     clip, p.ammo[spec.ammo], spec.mag, p.pose,
                     p.input.reload_grip, p.input.reload, time_, p.pose_stamp, p.input.reload_trigger, cq.enabled);
    if (pack) {
      state.pack_delay(previous_mag, before, clip, time_, spec.reload);
      if (state.pack_until > 0) {
        p.reloading = w;
        p.reload_at = state.pack_until;
      }
    }
    return clip > 0 && state.can_fire(pack);
  }
  if (p.reloading >= 0 && time_ + 1e-9 >= p.reload_at) {
    clip = std::min(spec.mag, p.ammo[spec.ammo]);
    p.reloading = -1;
    if (pack && state.initialised) {
      state.mag = true;
      state.pack_until = 0;
      state.chamber(clip);
    }
  }
  if (p.reloading < 0 && (clip == 0 || (p.input.reload && !p.reload_held)) &&
      clip < std::min(spec.mag, p.ammo[spec.ammo]) &&
      (p.cooldown <= 1e-9 || (pack && clip == 0))) {
    p.reloading = w;
    p.reload_at = time_ + spec.reload;
    p.charge_at = 0;
    p.burst_left = 0;
  }
  p.reload_held = p.input.reload;
  return p.reloading < 0 && clip > 0;
}
void Core::combat(Player &p, Host &host) {
  if (p.staging || p.dead || p.incapacitated || p.vehicle >= 0)
    return;
  p.cooldown = std::max(0., p.cooldown - step_);
  if (cq.enabled && p.grenade_selected) {
    if (!p.grenade_offhand && !p.input.vr && !p.input.blocked) {
      bool pressed = p.input.fire || p.press_pending;
      if (pressed && !p.grenade_trigger && !p.grenade_primed &&
          p.grenade_ready <= time_ && p.grenade_count > 0) {
        p.grenade_primed = true;
        p.grenade_pin_at = time_ + .5;
        p.grenade_until = time_ + 10;
      }
      if (!pressed && p.grenade_primed && time_ >= p.grenade_pin_at)
        throw_grenade(p, host);
      p.grenade_trigger = pressed;
    }
    return;
  }
  if (p.input.vr && !p.input.weapon_held) {
    for(auto &reload:p.physical) if(reload.initialised) reload.interrupt();
    p.burst_left=0; p.charge_at=0; p.salvo_left=0; return;
  }
  const auto &w = weapons()[p.weapon];
  if (w.ammo < 0) {
    if (cq.enabled)
      utility(p, host);
    return;
  }
  if (p.input.blocked)
    return;
  if (p.salvo_left) {
    if (time_ + 1e-9 >= p.next_shot && fire(p, host, true)) {
      --p.salvo_left;
      p.next_shot = time_ + .15;
    }
    return;
  }
  if (!magazines(p))
    return;
  if (cq.enabled && !p.input.fire)
    p.burst_held = false;
  if (p.burst_left) {
    if (!p.input.fire && !cq.enabled) {
      p.burst_left = 0;
      return;
    }
    if (time_ + 1e-9 >= p.next_shot) {
      p.cooldown = 0;
      if (fire(p, host)) {
        --p.burst_left;
        p.next_shot = time_ + .065;
        if (!p.burst_left)
          p.cooldown = .23;
      } else
        p.burst_left = 0;
    }
    return;
  }
  if (w.salvo > 1) {
    if (!p.input.fire) {
      p.charge_at = 0;
      return;
    }
    if (p.cooldown > 1e-9 || p.clips[p.weapon] < w.salvo ||
        p.ammo[w.ammo] < w.salvo)
      return;
    if (!p.charge_at) {
      p.charge_at = time_ + w.charge;
      return;
    }
    if (time_ + 1e-9 >= p.charge_at && fire(p, host)) {
      consume_ammo(p, w.salvo - 1);
      p.ammo[w.ammo] -= w.salvo - 1;
      p.salvo_left = w.salvo - 1;
      p.next_shot = time_ + .15;
      p.charge_at = 0;
    }
    return;
  }
  if (cq.enabled && (p.weapon==2 || p.weapon==9 || p.weapon==10) && !p.press_pending) return;
  if (w.burst > 1 && cq.enabled && p.burst_held)
    return;
  if ((p.input.fire || p.press_pending) && fire(p, host) && w.burst > 1) {
    p.burst_held = true;
    p.burst_left = w.burst - 1;
    p.next_shot = time_ + .065;
  }
}
void Core::impact(const Projectile &s, const Hit &hit, Host &host) {
  const bool ordnance = s.splash > 0;
  const DamageKind kind = ordnance ? DamageKind::ORDNANCE : DamageKind::BULLET;
  if (cq.enabled) {
    if (!s.effect)
      emit(ordnance ? EventKind::EXPLOSION : EventKind::IMPACT, s.owner,
           hit.position, hit.normal, s.weapon, s.radius, s.key);
  }
  if (hit.entity)
    damage_vehicle(hit.entity, s.team, s.damage, kind, s.owner, host, s.credit);
  for (auto &t : turrets_)
    if (t.active && t.key == hit.entity && t.team != s.team) {
      t.hp -= s.damage;
      if (t.hp <= 0)
        t.active = false;
    }

  if (hit.actor.id) {
    auto *target = resolve(hit.actor);
    if (target && (!(cq.enabled || s.team) || target->team != s.team ||
                   target->handle == s.owner ||
                   (s.credit.id && session(*target) == s.credit)))
      damage(hit.actor, s.owner,
             s.damage + (s.direct_random
                             ? int(random_unit() * (s.direct_random + 1))
                             : 0),
             kind, hit.headshot, s.credit, s.weapon);
  }
  if (s.splash <= 0)
    return;
  for (auto &p : players_)
    if (p.active && !p.dead && !p.staging && p.handle != hit.actor) {
      if ((cq.enabled || s.team) && p.team == s.team && p.handle != s.owner &&
          (!s.credit.id || session(p) != s.credit))
        continue;
      auto center =
          p.position +
          V{0, cq.enabled ? std::min(.8, p.height * .5) : p.height * .5, 0};
      double distance = std::max(0., (center - hit.position).length() -
                                         (cq.enabled ? .3 : 0));
      if (distance >= s.radius)
        continue;
      if (p.vehicle >= 0)
        continue;
      auto obstruction = cq.enabled
                             ? host.world_trace(hit.position, center, s.owner)
                             : host.trace(hit.position, center, s.owner);
      if (!obstruction.blocked || obstruction.actor == p.handle) {
        double amount = cq.enabled && s.quake
                            ? std::max(0., s.splash - distance * 16)
                            : s.splash * (1 - distance / s.radius);
        if (cq.enabled)
          p.velocity = p.velocity + (center - hit.position).unit() *
                                        std::min(24., amount * .15);
        damage(p.handle, s.owner,
               cq.enabled
                   ? std::max(1., std::round(
                                      amount *
                                      ((p.handle == s.owner ||
                                        (s.credit.id && session(p) == s.credit))
                                           ? .5
                                           : 1)))
                   : amount,
               kind, false, s.credit, s.weapon);
      }
    }
  if (cq.enabled) {
    for (auto &v : vehicles_)
      if (v.active && v.hp > 0 && v.key != hit.entity && v.team != s.team) {
        V center = v.position + V{0, .5, 0};
        double distance = std::max(0., (center - hit.position).length() -
                                           (cq.enabled ? .3 : 0));
        if (distance < s.radius &&
            !host.entity_ray(hit.position, center, v.key).blocked)
          damage_vehicle(v.key, s.team, s.splash * (1 - distance / s.radius),
                         kind, s.owner, host, s.credit);
      }
    for (auto &t : turrets_)
      if (t.active && t.key != hit.entity && t.team != s.team) {
        double d = (t.position - hit.position).length();
        if (d < s.radius &&
            !host.entity_ray(hit.position, t.position + V{0, .5, 0}, t.key)
                 .blocked) {
          t.hp -= s.splash * (1 - d / s.radius);
          if (t.hp <= 0)
            t.active = false;
        }
      }
  }
}
void Core::projectiles(Host &host) {
  for (auto &s : projectiles_)
    if (s.active) {
      if (s.stuck) {
        s.age += step_;
        s.remaining -= step_;
        if (s.age >= s.arm || s.remaining <= 0) {
          s.active = false;
          impact(s, {true, {}, s.position}, host);
        }
        continue;
      }
      if (cq.enabled && s.weapon == 5 && s.arm == 0) {
        const Designation *best = nullptr;
        double alignment = std::cos(12 * 3.141592653589793 / 180);
        for (auto &p : players_)
          if (alive(p) && p.team == s.team && p.weapon == 8 && p.input.fire &&
              !p.input.blocked && p.designation.active &&
              p.designation.until > time_) {
            V d = (p.designation.position - s.position).unit();
            double score = s.velocity.unit().dot(d);
            if (score > alignment) {
              alignment = score;
              best = &p.designation;
            }
          }
        if (best) {
          V desired =
              (best->position - s.position).unit() * s.velocity.length();
          s.velocity =
              s.velocity +
              (desired - s.velocity).limited(s.velocity.length() * .08 * step_);
        }
      }
      if (s.target_vehicle)
        for (auto &v : vehicles_)
          if (v.active && v.key == s.target_vehicle && v.hp > 0 &&
              v.team != s.team) {
            V desired = (v.position + V{0, .8, 0} - s.position).unit(),
              current = s.velocity.unit();
            double angle = std::acos(std::clamp(current.dot(desired), -1., 1.)),
                   step = std::min(angle, 2.0943951023931953 * step_);
            if (angle > 1e-6) {
              V tangent = (desired - current * std::cos(angle)).unit();
              if (tangent.length2() < .1)
                tangent = current.cross({0, 1, 0}).unit();
              s.velocity =
                  (current * std::cos(step) + tangent * std::sin(step)) *
                  s.velocity.length();
            }
            break;
          }
      V next =
          s.position + s.velocity * step_ + V{0, -.5 * s.gravity * step_ * step_, 0};
      auto hit = trace_hit(host, s.position, next, s.owner, s.sweep_radius, -1,
                           !s.fresh, s.ignore_entity);
      s.fresh = false;
      s.age += step_;
      s.remaining -= step_;
      if (hit.blocked) {
        if (s.age < s.arm && s.bounce > 0) {
          s.position = hit.position + hit.normal * (s.sweep_radius + .005);
          s.velocity =
              (s.velocity - hit.normal * (2 * s.velocity.dot(hit.normal))) *
              s.bounce;
          if (s.velocity.length() < 1) {
            s.stuck = true;
            s.velocity = {};
          }
          continue;
        }
        s.active = false;
        impact(s, hit, host);
      } else if (s.remaining <= 0) {
        s.active = false;
        if (cq.enabled && s.splash > 0)
          impact(s, {true, {}, next}, host);
      } else {
        s.position = next;
        s.velocity.y -= s.gravity * step_;
      }
    }
}
using wire::append;
using wire::real;
void Core::snapshot() {
  snapshot_tick_ = tick_;
  frame_.clear();
  for (uint8_t c : {'C', 'Q', 'A', '1'})
    frame_.push_back(c);
  append(frame_, tick_);
  uint16_t count = 0;
  for (auto &p : players_)
    count += p.active;
  append(frame_, count);
  for (auto &p : players_)
    if (p.active) {
      append(frame_, p.handle.id);
      append(frame_, p.handle.life);
      append(frame_, uint8_t(p.team));
      append(frame_, uint8_t(p.dead));
      append(frame_, uint8_t(p.weapon));
      append(frame_, uint8_t(p.grounded));
      for (double v :
           {p.position.x, p.position.y, p.position.z, p.velocity.x,
            p.velocity.y, p.velocity.z, p.yaw, p.pitch, p.height, p.hp})
        real(frame_, v);
      append(frame_, p.last_seq);
      append(frame_, p.shots);
      for (int n : p.ammo)
        append(frame_, uint16_t(n));
      for (int n : p.clips)
        append(frame_, uint16_t(n));
    }
  if (extended_frames)
    snapshot_extended();
}
void Core::advance(Host &host) {
  using Clock = std::chrono::steady_clock;
  auto a = Clock::now();
  ++tick_;
  const uint64_t previous_clock_units = clock_units_;
  clock_units_ += 60 / tick_hz_;
  time_ = double(clock_units_) * (1.0 / 60.0);
  if (cq.enabled) {
    round_state(host);
    tick_lighting(host);
  }
  auto after_mode = Clock::now();
  const bool running = !cq.enabled || points.winner == -2;
  if (cq.enabled && running)
    tick_bots(host);
  auto after_ai = Clock::now();
  for (auto &p : players_)
    if (p.active && p.dead && cq.enabled && points.winner == -2) {
      consume(p);
      if (cq.auto_respawn && (!cq.squads || p.bot || p.stress) && time_ >= p.respawn_at &&
          (p.input.respawn || p.want_respawn || time_ >= p.respawn_at + 3)) {
        auto next = respawn(p.handle, spawn_site(p, host));
        if (next.id) {
          host.teleport(next, p.position);
        }
      }
    }
  for (auto &p : players_)
    if (p.active && !p.dead) {
      if (p.stress) {
        p.ammo = {10000, 10000, 10000, 10000};
        p.grenade_count =
            p.classes.role == Role::MEDIC && p.classes.equipped_t2         ? 3
            : p.classes.role == Role::SHOCKTROOP && !p.classes.equipped_t2 ? 1
                                                                           : 0;
      }
      p.previous_position = p.position;
      consume(p);
      if (running && p.vehicle < 0)
        movement(p, host);
      else
        p.jetpack.cooldown = std::max(0., p.jetpack.cooldown - step_);
    }
  if (cq.enabled)
    record_history();
  // Ground concealment is host-derived at 10 Hz, independent of simulation Hz.
  if (cq.enabled && clock_units_ / 6 != previous_clock_units / 6)
    for (auto &p : players_)
      if (p.active)
        p.grass_concealed = !p.dead && p.vehicle < 0 && p.height <= .7 && host.grass_cover(p.position);
  auto b = Clock::now();
  if (cq.enabled && points.winner == -2)
    tick_locks(host);
  for (auto &p : players_)
    if (p.active) {
      actions(p, host);
      if (running && !p.dead)
        combat(p, host);
    }
  if (running)
    projectiles(host);
  if (cq.enabled && points.winner == -2) {
    tick_vehicles(host);
    tick_turrets(host);
    tick_flights(host);
    tick_grenades(host);
    tick_fields(host);
    tick_classes(host);
  }
  auto c = Clock::now();
  // Keep snapshot construction at 20 Hz for either supported simulation rate.
  if (clock_units_ / 3 != previous_clock_units / 3)
    snapshot();
  auto d = Clock::now();
  timings = {
      std::chrono::duration<double, std::micro>(b - after_ai).count(),
      std::chrono::duration<double, std::micro>(c - b).count(),
      std::chrono::duration<double, std::micro>(d - c).count(),
      std::chrono::duration<double, std::micro>(after_ai - after_mode).count(),
      std::chrono::duration<double, std::micro>(after_mode - a).count()};
}
} // namespace cqauthority
