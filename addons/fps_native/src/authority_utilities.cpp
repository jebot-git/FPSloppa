#include "authority_core.h"
namespace cqauthority {
bool Core::queue_action(Handle h, const Action &a) {
  auto *p = resolve(h);
  if (!p || a.seq < 0 || a.seq > INT32_MAX || a.seq <= p->action_seq ||
      int(a.kind) > int(ActionKind::SPAWN) ||
      p->action_count == p->actions.size()) {
    ++counters.rejected;
    return false;
  }
  p->actions[(p->action_head + p->action_count) % p->actions.size()] = a;
  ++p->action_count;
  p->action_seq = a.seq;
  return true;
}
void Core::actions(Player &p, Host &host) {
  if (p.nvg_pending) {
    if(p.vehicle<0)toggle_nvg(p.handle);
    p.nvg_pending = false;
  }
  while (p.action_count) {
    Action a = p.actions[p.action_head];
    p.action_head = (p.action_head + 1) % p.actions.size();
    --p.action_count;
    if (a.kind == ActionKind::TEAM && cq.enabled && a.a >= 0 && a.a < 2 &&
        p.team != a.a) {
      if(cq.squads){int count=0;for(const auto &other:players_)count+=other.active&&other.team==a.a;if(count>=32)continue;}
      if (p.vehicle >= 0)
        vehicle_leave(p, host, true);
      Session who = session(p);
      Handle old = p.handle;
      for (auto &b : boxes_)
        if (b.owner == who)
          b.active = false;
      for (auto &t : turrets_)
        if (t.owner == who)
          t.active = false;
      for (auto &f : fields_)
        if (f.owner == who)
          f.active = false;
      for (auto &f : flights_)
        if (f.owner == who)
          f.active = false;
      for (auto &g : grenades_)
        if (g.owner == who)
          g.active = false;
      for (auto &s : projectiles_)
        if (s.owner == old)
          s.active = false;
      p.team = a.a;
      if(cq.squads){p.squad=-1;p.staging=!p.bot;}
      p.dead = true;
      auto fresh = respawn(old, spawn_site(p, host));
      if (fresh.id)
        host.teleport(fresh, p.position);
      continue;
    }
    if(a.kind==ActionKind::SQUAD){join_squad(p.handle,a.a);continue;}
    if(a.kind==ActionKind::SPAWN){if(squad_deploy(p,a.a,a.b,a.c,host))return;continue;}
    if (a.kind == ActionKind::DEPLOY && cq.enabled && !cq.squads && p.staging) {
      p.staging = false;
      spawn_class(p);
      p.hp = 100;
      p.position = spawn_site(p, host);
      p.velocity = {};
      host.teleport(p.handle, p.position);
      continue;
    }
    if (a.kind == ActionKind::CLASS) {
      choose_class(p.handle, a.a);
      continue;
    }
    if (a.kind == ActionKind::GEAR) {
      choose_gear(p.handle, a.a, a.b, a.c);
      continue;
    }
    // Menu actions remain valid while movement/fire input is blocked.
    if (a.kind == ActionKind::SUICIDE && cq.enabled &&
        points.winner == -2 && !p.staging) {
      if (!p.dead)
        damage(p.handle, p.handle, 10000, DamageKind::VEHICLE_DESTROYED);
      p.want_respawn = true;
      continue;
    }
    if (!cq.enabled || !alive(p) || p.input.blocked ||
        time_ - p.last_input > .35 || points.winner != -2)
      continue;
    switch (a.kind) {
    case ActionKind::NVG:
      toggle_nvg(p.handle);
      break;
    case ActionKind::CANCEL:
      p.grenade_selected = p.grenade_offhand = p.grenade_trigger = false;
      p.grenade_primed = false;
      break;
    case ActionKind::SUICIDE:
      damage(p.handle, p.handle, 10000, DamageKind::VEHICLE_DESTROYED);
      break;
    case ActionKind::USE:
      if (a.a == 6 && p.vehicle < 0 && (p.owned & (1 << 6))) {
        if(a.b==1 || a.b==2) {drop_box(p,a.b-1,host);break;}
        if(a.b!=0)break;
        const int weapon = p.weapon; const bool fire = p.input.fire;
        const double cooldown=p.cooldown;
        p.weapon = 6; p.input.fire = true; p.cooldown=0; utility(p, host);
        p.cooldown=std::max(cooldown,p.cooldown);p.weapon = weapon; p.input.fire = fire; break;
      }
      if (vehicle_use(p, host))
        break;
      if (p.vehicle >= 0)
        break;
      if (p.classes.role == Role::SCOUT && p.classes.equipped_t2) {
        recon(p, host);
        break;
      }
      if (p.classes.role == Role::SCOUT && !p.classes.equipped_t2 &&
          p.classes.cloak_ready <= time_ && !p.input.fire &&
          !p.input.offhand_fire) {
        p.classes.cloak_until = time_ + 10;
        p.classes.cloak_ready = time_ + 30;
      } else if (p.weapon == 6) {
        bool fire = p.input.fire;
        p.input.fire = true;
        utility(p, host);
        p.input.fire = fire;
      }
      break;
    case ActionKind::GRENADE_EQUIP:
      if (p.vehicle < 0 && p.grenade_count > 0 && p.grenade_ready <= time_) {
        p.grenade_selected = !p.grenade_selected;
        p.grenade_offhand = p.grenade_trigger = p.grenade_primed = false;
      }
      break;
    case ActionKind::GRENADE_ARM:
      if (p.grenade_count > 0 && p.grenade_ready <= time_ && p.vehicle < 0 &&
          !p.grenade_primed) {
        p.grenade_hand = a.a >= 2 && a.a <= 3 ? a.a-2 :
            (a.a == 1 ? (p.pose.left_handed ? 0 : 1) : (p.pose.left_handed ? 1 : 0));
        p.grenade_selected = true;p.grenade_offhand = p.grenade_hand != (p.pose.left_handed ? 0 : 1);
        p.throw_peak_velocity = {}; p.throw_peak_until = 0;
        p.grenade_primed = true;
        p.grenade_until = time_ + 10;
      }
      break;
    case ActionKind::GRENADE_THROW:
      throw_grenade(p, host);
      break;
    default:
      break;
    }
  }
  if (p.grenade_primed &&
      (p.grenade_until < time_ || p.input.blocked || !alive(p))) {
    p.grenade_primed = false;
    p.grenade_selected = p.grenade_offhand = p.grenade_trigger = false;
  }
}
bool Core::throw_grenade(Player &p, Host &host) {
  if (!p.grenade_primed || p.grenade_count <= 0 || p.grenade_ready > time_ ||
      p.vehicle >= 0 || p.grenade_until < time_)
    return false;
  Grenade *slot = nullptr;
  for (auto &g : grenades_)
    if (!g.active) {
      slot = &g;
      break;
    }
  if (!slot)
    return false;
  V from, velocity, direction;
  if (p.input.vr) {
    if (!p.pose.tracked || time_ - p.pose_stamp > .16)
      return false;
    const bool left = p.grenade_hand >= 0 ? p.grenade_hand == 0 :
        (p.grenade_offhand ? !p.pose.left_handed : p.pose.left_handed);
    V local = (left ? p.pose.left : p.pose.right).origin;
    from = p.position + B::yaw(p.yaw).apply(local);
    V bounded = (time_ <= p.throw_peak_until ? p.throw_peak_velocity : p.throw_velocity).limited(12);
    double gain = 1 + 3.8 * std::clamp((bounded.length() - .65) / 1.35, 0., 1.);
    velocity = (bounded * gain).limited(40);
    const B &free_aim = left == p.pose.left_handed && p.pose.has_offhand ? p.pose.offhand.basis : p.pose.weapon.basis;
    if (velocity.length() >= .8) velocity = free_aim.z.unit() * -velocity.length();
    velocity = B::yaw(p.yaw).apply(velocity);
    direction =
        velocity.length() > .1 ? velocity.unit() : weapon_pose(p).basis.z * -1;
  } else {
    auto pose = eye_pose(p);
    from = pose.origin;
    double pitch = std::clamp(p.pitch + .17, -1.5, 1.5);
    direction = B::yaw(p.yaw).apply({0, std::sin(pitch), -std::cos(pitch)});
    velocity = direction * std::min(23.4375, 18.75 + pitch * 10) +
               p.velocity.limited(9);
    velocity = velocity.limited(28);
  }
  V chest = p.position + V{0, std::min(1.48, p.height - .17), 0};
  if (host.world_trace(chest, from, p.handle).blocked)
    return false;
  auto wall = host.world_trace(from, from + direction * .25, p.handle);
  V position =
      wall.blocked ? wall.position + wall.normal * .07 : from + direction * .18;
  if(cq.squads)p.combat_until=time_+8.;
  *slot = Grenade{};
  slot->active = true;
  slot->key = next_entity_++;
  slot->owner = session(p);
  slot->life = p.handle.life;
  slot->team = p.team;
  slot->kind = p.classes.role == Role::MEDIC && p.classes.equipped_t2 ? 3 : 0;
  slot->position = position;
  slot->velocity = velocity;
  p.grenade_primed = false;
  p.grenade_selected = p.grenade_offhand = p.grenade_trigger = false;
  --p.grenade_count;
  p.grenade_ready = time_ + .6;
  p.classes.cloak_until = 0;
  p.invulnerable = 0;
  return true;
}
void Core::tick_grenades(Host &host) {
  for (auto &g : grenades_)
    if (g.active) {
      g.age += step_;
      if (!g.ground) {
        int steps = std::max(1, int(std::ceil(g.velocity.length() * step_ / .08)));
        double dt = step_ / steps;
        for (int i = 0; i < std::min(steps, 32); ++i) {
          g.velocity.y -= 12.5 * dt;
          V end = g.position + g.velocity * dt;
          auto hit =
              host.world_trace(g.position, end + g.velocity.unit() * .06, {});
          if (hit.blocked) {
            g.position = hit.position + hit.normal * .065;
            g.velocity =
                (g.velocity - hit.normal * (2 * g.velocity.dot(hit.normal))) *
                .45;
            if (hit.normal.y > .65 && g.velocity.length() < 1) {
              g.velocity = {};
              g.ground = true;
              break;
            }
          } else
            g.position = end;
        }
      }
      if (g.position.y < cq.fall_limit - 2 || g.age > 12) {
        g.active = false;
        continue;
      }
      if (g.age < 1.5)
        continue;
      g.active = false;
      if (g.kind == 3) {
        activate_field(g.owner, g.team, g.position);
        continue;
      }
      for (auto &p : players_)
        if (alive(p)) {
          V target = p.position + V{0, .9, 0};
          double distance = (target - g.position).length();
          double radius = 350. / 32;
          if (distance >= radius ||
              host.world_trace(g.position, target, p.handle).blocked)
            continue;
          damage(p.handle, {g.owner.id, g.life},
                 std::round(100 * (1 - distance / radius)), DamageKind::GRENADE,
                 false, g.owner);
        }
      for (auto &v : vehicles_)
        if (v.active && v.hp > 0) {
          double d = (v.position - g.position).length();
          double radius = 350. / 32;
          if (d < radius &&
              !host.entity_ray(g.position, v.position + V{0, .5, 0}, v.key)
                   .blocked)
            damage_vehicle(v.key, g.team, std::round(100 * (1 - d / radius)),
                           DamageKind::GRENADE, {g.owner.id, g.life}, host,
                           g.owner);
        }
      for (auto &t : turrets_)
        if (t.active) {
          double d = (t.position - g.position).length(), radius = 350. / 32;
          if (d < radius && !host.entity_ray(g.position, t.position + V{0, .5, 0}, t.key).blocked) {
            t.hp -= std::round(100 * (1 - d / radius));
            if (t.hp <= 0) t.active = false;
          }
        }
      host.ordnance_impact(g.position, 100, 350. / 32);
      emit(EventKind::GRENADE, {g.owner.id, g.life}, g.position, {}, g.kind,
           350. / 32, g.key);
    }
}
bool Core::activate_field(Session source, int team, V at) {
  if (!at.finite() || team < 0 || team > 1)
    return false;
  for (auto &f : fields_)
    if (!f.active) {
      f = Field{};
      f.active = true;
      f.key = next_entity_++;
      f.owner = source;
      f.team = team;
      f.position = at + V{0, .1, 0};
      f.until = time_ + 10;
      return true;
    }
  return false;
}
void Core::tick_fields(Host &host) {
  bool any = false;
  for (auto &f : fields_)
    if (f.active) {
      if (f.until <= time_ || f.energy <= 0)
        f.active = false;
      else
        any = true;
    }
  if (!any) {
    field_delta_ = 0;
    return;
  }
  field_delta_ += step_;
  if (tick_ % 3)
    return;
  double elapsed = field_delta_;
  field_delta_ = 0;
  for (auto &f : fields_)
    if (f.active && f.health > 0) {
      for (size_t order = 0; order < MAX_PLAYERS; ++order) {
        size_t i = (order + field_cursor_) % MAX_PLAYERS;
        auto &p = players_[i];
        V chest = p.position + V{0, std::min(.8, p.height * .5), 0};
        if (!alive(p) || p.team != f.team || p.hp >= 100 ||
            (chest - f.position).length2() > 25 ||
            host.world_trace(f.position, chest, p.handle).blocked) {
          f.credit[i] = 0;
          continue;
        }
        if (f.lives[i] != p.handle.life) {
          f.lives[i] = p.handle.life;
          f.credit[i] = 0;
        }
        f.credit[i] = std::min(100., f.credit[i] + elapsed * 10);
        int amount = std::min({int(f.credit[i]), f.health, int(100 - p.hp)});
        if (amount <= 0)
          continue;
        p.hp += amount;
        f.health -= amount;
        f.credit[i] -= amount;
        if (session(p) != f.owner) {
          f.xp_credit += amount;
          int xp = int(f.xp_credit / 10);
          f.xp_credit -= xp * 10;
          if (auto *owner_player = owner(f.owner);
              owner_player && owner_player->classes.role == Role::MEDIC)
            owner_player->classes.award(xp);
        }
      }
    }
  ++field_cursor_;
}
double Core::energy_intercept(int team, V from, V end, double damage, V &stop) {
  struct Entry {
    double t;
    size_t i;
  };
  std::array<Entry, MAX_FIELDS> entries{};
  size_t count = 0;
  V d = end - from;
  double a = d.length2();
  stop = end;
  if (a < .000001 || damage <= 0)
    return damage;
  for (size_t i = 0; i < MAX_FIELDS; ++i) {
    auto &f = fields_[i];
    if (!f.active || f.until <= time_ || f.energy <= 0 ||
        (team == f.team && (from - f.position).length2() <= 25))
      continue;
    V offset = from - f.position;
    double b = 2 * offset.dot(d), c = offset.length2() - 25,
           disc = b * b - 4 * a * c;
    if (disc < 0)
      continue;
    double near = (-b - std::sqrt(disc)) / (2 * a),
           far = (-b + std::sqrt(disc)) / (2 * a), t = near >= 0 ? near : far;
    if (t >= 0 && t <= 1)
      entries[count++] = {t, i};
  }
  std::sort(entries.begin(), entries.begin() + count, [](auto a, auto b) {
    return a.t < b.t || (a.t == b.t && a.i < b.i);
  });
  for (size_t n = 0; n < count; ++n) {
    auto &f = fields_[entries[n].i];
    double absorbed = std::min(damage, f.energy);
    f.energy -= absorbed;
    f.hit_at = time_;
    damage -= absorbed;
    if (f.energy <= 0)
      f.active = false;
    if (damage <= 0) {
      stop = from + d * entries[n].t;
      break;
    }
  }
  return damage;
}
} // namespace cqauthority
