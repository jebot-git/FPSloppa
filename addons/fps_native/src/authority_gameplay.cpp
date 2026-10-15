#include "authority_core.h"
namespace cqauthority {
int Core::collapse_region(V lo, V hi, Host &host) {
  if (!cq.enabled || points.winner != -2 || !lo.finite() || !hi.finite() ||
      lo.x >= hi.x || lo.y >= hi.y || lo.z >= hi.z)
    return 0;
  auto inside = [&](V p) {
    return p.x >= lo.x && p.x <= hi.x && p.y >= lo.y && p.y <= hi.y &&
           p.z >= lo.z && p.z <= hi.z;
  };
  int affected = 0;
  // Fixed actor/entity arrays stay valid during an ordnance host callback.
  // Membership is evaluated before releasing seats or changing collision.
  for (auto &p : players_)
    if (p.active && !p.dead && !p.staging && inside(p.position)) {
      V position = p.position;
      if (p.vehicle >= 0) {
        vehicle_leave(p, host, true);
        p.position = position;
        host.teleport(p.handle, position);
      }
      if (damage(p.handle, {}, 10000, DamageKind::COLLAPSE)) ++affected;
    }
  for (auto &v : vehicles_)
    if (v.active && v.hp > 0 && inside(v.position))
      if (damage_vehicle(v.key, -1, 100, DamageKind::ORDNANCE, {}, host) > 0)
        ++affected;
  return affected;
}
Session Core::session(const Player &p) const {
  return {p.handle.id, p.session_token};
}
Player *Core::owner(Session s) {
  auto *p = find(s.id);
  return p && p->session_token == s.token ? p : nullptr;
}
bool Core::alive(const Player &p) const {
  return p.active && !p.dead && !p.incapacitated && !p.staging;
}
bool Core::same_team(const Player &a, const Player &b) const {
  return a.team == b.team && (cq.enabled || a.team != 0);
}
bool Core::configure_cq(const CqConfig &config) {
  if ((config.team_limit != 32 && config.team_limit != 64) || tick_ || !std::isfinite(config.map_limit) || config.map_limit <= 0 ||
      !std::isfinite(config.fall_limit) || !std::isfinite(config.water_level) ||
      !std::isfinite(config.light_fraction) || config.light_fraction < 0 ||
      config.light_fraction > 1 || !std::isfinite(config.cycle_seconds) ||
      config.cycle_seconds <= 0 || !std::isfinite(config.cycle_offset) ||
      !std::isfinite(config.round_seconds) || config.round_seconds < 0 ||
      !std::isfinite(config.intermission_seconds) ||
      config.intermission_seconds < 0)
    return false;
  for (auto &p : players_)
    if (p.active)
      return false;
  cq = config;
  extended_frames = config.enabled;
  return true;
}
bool Core::configure_zone(V at, double radius) {
  if (tick_ || points.count == MAX_ZONES || !at.finite() ||
      !std::isfinite(radius) || radius <= 0)
    return false;
  auto &z = points.zones[points.count++];
  z.position = at;
  z.radius = radius;
  return true;
}
bool Core::configure_player(Handle h, const ClassState &state) {
  auto *p = resolve(h);
  if (!cq.enabled || !p || p->profile_loaded || p->last_seq >= 0 || p->count ||
      size_t(state.role) > 3 || size_t(state.next) > 3)
    return false;
  for (size_t i = 0; i < 4; ++i)
    if (state.xp[i] < 0 || (state.primary_t2[i] && state.xp[i] < 2500) ||
        (state.secondary_t2[i] && state.xp[i] < 5000) ||
        (state.utility_t2[i] && state.xp[i] < 7500))
      return false;
  p->classes = state;
  p->classes.next = state.role;
  spawn_class(*p);
  p->classes.next = state.next;
  p->profile_loaded = true;
  return true;
}
bool Core::configure_stress(Handle h, bool enabled) {
  auto *p = resolve(h);
  if (!p || p->last_seq >= 0 || p->count)
    return false;
  p->stress = enabled;
  return true;
}
bool Core::choose_class(Handle h, int role) {
  auto *p = resolve(h);
  if (!cq.enabled || !p || role < 0 || role > 3)
    return false;
  p->classes.next = Role(role);
  return true;
}
bool Core::choose_gear(Handle h, int role, int slot, int value) {
  auto *p = resolve(h);
  return cq.enabled && p && p->classes.choose(role, slot, value);
}
void Core::spawn_class(Player &p) {
  auto &c = p.classes;
  c.role = c.next;
  c.cloak_until = 0;
  c.equipped_t2 = c.utility_t2[size_t(c.role)];
  c.nvg = false;
  c.blind_until = 0;
  p.incapacitated = false;
  p.bleed_remaining = 0;
  p.inject_progress = 0;
  p.injector = {};
  p.injury_source = {};
  p.injury_credit = {};
  p.injury_weapon = -1;
  p.death_gibbed = false;
  p.armor = c.armor_limit();
  p.armor_credit = 0;
  p.jetpack = {};
  p.jetpack_enabled = c.role == Role::SHOCKTROOP;
  p.invulnerable = time_ + 1.5;
  p.respawn_at = 0;
  p.vehicle = -1;p.vehicle_seat=-1;
  p.grenade_count = c.role == Role::MEDIC && c.equipped_t2         ? 3
                    : c.role == Role::SHOCKTROOP && !c.equipped_t2 ? 1
                                                                   : 0;
  p.grenade_primed = false;
  p.designation = {};
  int primary = c.weapon(false), secondary = c.weapon(true);
  p.owned = uint16_t((1 << primary) | (1 << secondary));
  if (c.role == Role::MEDIC || c.role == Role::TECHNICIAN) {
    p.owned |= 1 << 7;
    if (c.role == Role::TECHNICIAN || !c.replaces_box())
      p.owned |= 1 << 6;
  }
  if (c.role == Role::SHOCKTROOP && c.equipped_t2)
    p.owned |= 1 << 8;
  p.ammo = {};
  p.clips = {};
  p.physical = {};
  for (int w = 0; w < 12; ++w)
    if (p.owned & (1 << w)) {
      auto &d = weapons()[w];
      if (d.ammo < 0)
        continue;
      int spare = w == 5 || w == 11 ? 2 : w == 9 ? 5 : w == 2 || w == 0 ? 1 : 3;
      p.ammo[d.ammo] += d.mag * (spare + 1);
      p.clips[w] = d.mag;
    }
  p.spawn_ammo = p.ammo;
  p.weapon = primary;
  p.input.weapon = primary;
  trim_boxes(session(p), c.replaces_box() ? 0 : c.box_limit());
}
void Core::trim_boxes(Session who, int limit) {
  int count = 0;
  for (auto &b : boxes_)
    count += b.active && b.owner == who;
  while (count > limit) {
    Box *oldest = nullptr;
    for (auto &b : boxes_)
      if (b.active && b.owner == who && (!oldest || b.key < oldest->key))
        oldest = &b;
    if (!oldest)
      break;
    oldest->active = false;
    --count;
  }
}
bool Core::deploy_box(Handle h, V at) {
  auto *p = resolve(h);
  if (!cq.enabled || !p || !alive(*p) || p->input.blocked || p->vehicle >= 0 ||
      !at.finite() || (at - p->position).length() > 2.8 ||
      p->classes.box_ready > time_ ||
      (p->classes.role != Role::MEDIC && p->classes.role != Role::TECHNICIAN) ||
      p->classes.replaces_box())
    return false;
  Box *slot = nullptr;
  for (auto &b : boxes_)
    if (!b.active) {
      slot = &b;
      break;
    }
  if (!slot)
    for (auto &b : boxes_)
      if (b.owner == session(*p) && (!slot || b.key < slot->key))
        slot = &b;
  if (!slot)
    return false;
  trim_boxes(session(*p), p->classes.box_limit() - 1);
  *slot = Box{};
  slot->active = true;
  slot->key = next_entity_++;
  slot->owner = session(*p);
  slot->team = p->team;
  slot->health = p->classes.role == Role::MEDIC;
  slot->position = at;
  p->classes.box_ready = time_ + 30;
  return true;
}
int Core::supply(Box &box, Player &p, int requested) {
  if (!alive(p) || p.team != box.team || requested <= 0 || !box.active)
    return 0;
  int amount = std::min(requested, box.remaining);
  if (box.health) {
    amount = std::min(amount, int(100 - p.hp));
    p.hp += amount;
  } else {
    int spent = 0;
    for (int i = 0; i < 4; ++i) {
      int missing = std::max(0, p.spawn_ammo[i] - p.ammo[i]);
      if (i == 2) {
        int packs = std::min((amount - spent) / 300, missing / 3);
        p.ammo[i] += packs * 3;
        spent += packs * 300;
      } else {
        int n = std::min(amount - spent, missing);
        p.ammo[i] += n;
        spent += n;
      }
    }
    int limit = p.classes.role == Role::MEDIC && p.classes.equipped_t2 ? 3
                : p.classes.role == Role::SHOCKTROOP && !p.classes.equipped_t2
                    ? 1
                    : 0;
    if (amount - spent >= 100 && p.grenade_count < limit) {
      int n = std::min(limit - p.grenade_count, (amount - spent) / 100);
      p.grenade_count += n;
      spent += n * 100;
    }
    amount = spent;
  }
  box.remaining -= amount;
  if (box.remaining <= 0)
    box.active = false;
  if (amount > 0 && session(p) != box.owner) {
    box.xp_credit += amount;
    int xp = int(box.xp_credit / 10);
    box.xp_credit -= xp * 10;
    if (auto *source = owner(box.owner))
      source->classes.award(xp);
  }
  return amount;
}
bool Core::inject(Handle medic, Handle victim, double delta) {
  auto *a = resolve(medic);
  auto *b = resolve(victim);
  if (!cq.enabled || !a || !b || !alive(*a) || a->classes.role != Role::MEDIC ||
      !b->incapacitated || !same_team(*a, *b) || !std::isfinite(delta) ||
      delta <= 0 || delta > step_ + 1e-9)
    return false;
  if (b->injector.id && b->injector != medic)
    return false;
  b->injector = medic;
  b->inject_progress += delta;
  b->inject_touched = tick_;
  if (b->inject_progress + 1e-5 < 3)
    return true;
  b->incapacitated = false;
  b->bleed_remaining = 0;
  b->hp = 35;
  b->injector = {};
  b->inject_progress = 0;
  a->classes.award(75);
  return true;
}
T Core::weapon_pose(const Player &p, bool offhand) const {
  B body = B::yaw(p.yaw);
  if (p.pose.tracked) {
    T local = cq.enabled ? (offhand ? p.pose.offhand : p.pose.weapon) : p.reach.weapon_pose(p.pose, offhand);
    return {body.product(local.basis), p.position + body.apply(local.origin)};
  }
  return {body.product(B::euler({p.pitch, 0, 0})),
          p.position + V{0, std::min(1.45, p.height - .17), 0}};
}
bool Core::stationary(const Player &p) const {
  return p.input.x * p.input.x + p.input.z * p.input.z <= .0009 &&
         p.velocity.x * p.velocity.x + p.velocity.z * p.velocity.z <= .0225 &&
         std::abs(p.velocity.y) <= .5 && !p.input.jump;
}
bool Core::toggle_nvg(Handle h) {
  auto *p = resolve(h);
  if (!cq.enabled || !p || !alive(*p) || p->input.blocked ||
      p->classes.nvg_ready > time_ || time_ - p->last_input > .35)
    return false;
  if (p->input.vr) {
    if (!p->pose.tracked)
      return false;
    bool near = false;
    for (auto hand : {p->pose.left, p->pose.right}) {
      V relative = p->pose.head.inverse(hand.origin);
      near |= std::abs(relative.x) < .28 && relative.y > -.02 && relative.y < .45 &&
              relative.z > -.38 && relative.z < .18;
    }
    if (!near) return false;
  }
  p->classes.nvg = !p->classes.nvg;
  p->classes.nvg_ready = time_ + .35;
  return true;
}
T Core::eye_pose(const Player &p) const {
  if (p.pose.tracked) {
    auto t = p.pose.head;
    B body = B::yaw(p.yaw);
    return {body.product(t.basis), p.position + body.apply(t.origin)};
  }
  return {B::yaw(p.yaw).product(B::euler({p.pitch, 0, 0})),
          p.position + V{0, std::min(1.48, p.height - .17), 0}};
}
double Core::spot_range(const Player &p) const {
  bool scout = p.classes.role == Role::SCOUT;
  if (p.classes.nvg && p.classes.blind_until > time_)
    return 0;
  double minimum = p.classes.nvg ? (scout ? 100 : 50) : (scout ? 25 : 15);
  return minimum +
         ((scout ? 150 : 75) - minimum) * std::clamp(cq.light_fraction, 0., 1.);
}
void Core::tick_classes(Host &host) {
  for (auto &box : boxes_)
    if (box.active) {
      for (size_t i = 0; i < MAX_PLAYERS; ++i) {
        auto &p = players_[i];
        V chest = p.position + V{0, .9, 0};
        if (!alive(p) || p.team != box.team ||
            (chest - box.position).length() > 4 ||
            host.world_trace(box.position + V{0, .15, 0}, chest, p.handle)
                .blocked) {
          box.credit[i] = 0;
          continue;
        }
        bool needs = box.health ? p.hp < 100 : false;
        if (!box.health) {
          for (int a = 0; a < 4; ++a)
            needs |= p.spawn_ammo[a] - p.ammo[a] >= (a == 2 ? 3 : 1);
          int limit =
              p.classes.role == Role::MEDIC && p.classes.equipped_t2 ? 3
              : p.classes.role == Role::SHOCKTROOP && !p.classes.equipped_t2
                  ? 1
                  : 0;
          needs |= p.grenade_count < limit;
        }
        if (!needs) {
          box.credit[i] = 0;
          continue;
        }
        if (box.lives[i] != p.handle.life) {
          box.credit[i] = 0;
          box.lives[i] = p.handle.life;
        }
        box.credit[i] = std::min(300., box.credit[i] + step_ * 20);
        box.credit[i] -= supply(box, p, int(box.credit[i]));
        if (!box.active)
          break;
      }
    }
  for (auto &p : players_)
    if (alive(p) && p.vehicle < 0 && !p.input.blocked)
      repair(p, host);
  for (auto &a : players_)
    if (alive(a) && a.vehicle < 0 && !a.input.blocked && a.weapon == 7 &&
        a.input.fire && a.classes.role == Role::MEDIC) {
      V tip = weapon_pose(a).apply({0, 0, -.12});
      for (auto &b : players_)
        if (b.active && b.incapacitated && same_team(a, b)) {
          V chest = b.position + V{0, .35, 0};
          if ((tip - chest).length() <= .25 &&
              !host.world_trace(tip, chest, a.handle).blocked) {
            inject(a.handle, b.handle, step_);
            break;
          }
        }
    }
  for (auto &p : players_)
    if (p.active && p.incapacitated) {
      if (p.injury_tick == tick_)
        continue;
      auto *medic = resolve(p.injector);
      if (p.inject_touched == tick_ && medic && alive(*medic))
        continue;
      p.injector = {};
      p.inject_progress = 0;
      p.bleed_remaining = std::max(0., p.bleed_remaining - step_);
      if (p.bleed_remaining <= 1e-9)
        damage(p.handle, p.injury_source, 1, DamageKind::BLEEDOUT, false,
               p.injury_credit, p.injury_weapon);
    }
  if (tick_ % 3 == 0) {
    for (auto &a : players_)
      if (alive(a) && a.team >= 0 && a.team <= 1) {
        double radius = spot_range(a);
        if (radius <= 0)
          continue;
        V origin = a.position + V{0, std::min(1.48, a.height - .17), 0};
        for (auto &b : players_)
          if (b.active && !b.dead && !b.staging && b.team != a.team &&
              b.classes.cloak_until <= time_ &&
              b.spotted[a.team] <= time_ + 9.8 &&
              (b.position - a.position).length2() <= radius * radius * detection_scale(b) * detection_scale(b)) {
            for (double h : {std::min(1.48, b.height - .17),
                             std::min(1.48, b.height - .17) * .55})
              if (!host.world_trace(origin, b.position + V{0, h, 0}, a.handle)
                       .blocked) {
                b.spotted[a.team] = time_ + 10;
                break;
              }
          }
      }
  }
  std::array<std::array<bool, 2>, MAX_ZONES> presence{};
  std::array<std::array<int, 2>, MAX_ZONES> counts{};
  for (auto &p : players_)
    if (alive(p) && p.vehicle < 0 && p.team >= 0 && p.team <= 1)
      for (size_t i = 0; i < points.count; ++i) {
        auto &z = points.zones[i];
        V offset = p.position - z.position;
        if (std::abs(offset.y) <= 1.8 &&
            std::hypot(offset.x, offset.z) <= z.radius &&
            !host.world_trace(p.position + V{0, .8, 0},
                              z.position + V{0, .8, 0}, p.handle)
                 .blocked)
          {presence[i][p.team] = true;++counts[i][p.team];}
      }
  points.advance(step_, presence, counts);
  // Two armour points per second; overlapping POIs never multiply the rate.
  for (auto &p : players_) {
    bool recharge = false;
    if (alive(p) && p.armor < p.classes.armor_limit() && points.winner == -2)
      for (size_t i = 0; i < points.count; ++i) {
        const auto &z = points.zones[i];
        V offset = p.position - z.position;
        if (z.owner == p.team && !z.contested && std::abs(offset.y) <= 1.8 &&
            std::hypot(offset.x, offset.z) <= z.radius &&
            !host.world_trace(p.position + V{0, .8, 0},
                              z.position + V{0, .8, 0}, p.handle).blocked) {
          recharge = true;
          break;
        }
      }
    if (!recharge) { p.armor_credit = 0; continue; }
    p.armor_credit += step_ * 2;
    int gain = int(p.armor_credit + 1e-9);
    p.armor = std::min(p.classes.armor_limit(), p.armor + gain);
    p.armor_credit -= gain;
  }

  for (auto &p : players_)
    if (alive(p) && p.vehicle < 0 && !p.input.blocked) {
      drag(p, host);
      melee(p, host);
    }
}
} // namespace cqauthority

namespace cqauthority {
void Core::utility(Player &p, Host &host) {
  if (!alive(p) || p.vehicle >= 0 || p.input.blocked || !p.input.fire ||
      p.cooldown > 0)
    return;
  if (p.weapon == 6) {
    auto pose = weapon_pose(p);
    V start = p.position + V{0, .6, 0};
    V at = pose.origin - pose.basis.z;
    if (host.world_trace(start, at, p.handle).blocked)
      return;
    auto hit = host.world_trace(at + V{0, .4, 0}, at - V{0, 2, 0}, p.handle);
    if (hit.blocked && hit.normal.y >= .7 &&
        (hit.position - start).length() <= 2.5 &&
        (p.classes.role == Role::TECHNICIAN && p.classes.equipped_t2
             ? deploy_turret(p, hit.position, host)
             : deploy_box(p.handle, hit.position + V{0, .005, 0})))
      p.cooldown = .2;
  } else if (p.weapon == 8) {
    if (!stationary(p) ||
        (p.classes.role != Role::SCOUT &&
         !(p.classes.role == Role::SHOCKTROOP && p.classes.equipped_t2))) {
      p.designation.active = false;
      p.designation.locking = false;
      return;
    }
    auto pose = weapon_pose(p);
    V direction = pose.basis.z * -1;
    auto hit =
        trace_hit(host, pose.origin, pose.origin + direction * 200, p.handle);
    p.cooldown = .1;
    if (hit.blocked) {
      p.designation.active = true;
      p.designation.start = pose.origin;
      p.designation.position = hit.position;
      p.designation.direction = direction;
      p.designation.until = time_ + .45;
      if (p.classes.role == Role::SHOCKTROOP && p.classes.equipped_t2 &&
          p.classes.strike_ready <= time_) {
        auto &d = p.designation;
        if (!d.locking) {
          d.locking = true;
          d.target_at = time_;
          d.lock_position = hit.position;
          d.lock_direction = direction;
        } else if ((d.lock_position - hit.position).length() > 8)
          d.locking = false;
        else if (time_ - d.target_at + 1e-5 >= 5)
          airstrike(p, host);
      }
    } else {
      p.designation.active = false;
      p.designation.locking = false;
    }
  }
}
} // namespace cqauthority
