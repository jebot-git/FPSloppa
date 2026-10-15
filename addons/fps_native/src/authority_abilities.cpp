#include "authority_core.h"
namespace cqauthority {
void Core::emit(EventKind kind, Handle actor, V at, V direction, int detail,
                double value, uint64_t entity) {
  if(cq.squads&&(kind==EventKind::SHOT||kind==EventKind::MELEE||kind==EventKind::AIRSTRIKE))if(auto *p=resolve(actor))p->combat_until=time_+8.;
  events_[event_next_] = {next_event_++, kind,  actor, entity, at,
                          direction,     time_, value, detail};
  event_next_ = (event_next_ + 1) % events_.size();
  event_count_ = std::min(event_count_ + 1, events_.size());
}
namespace {
struct Route {
  bool valid = false;
  V start, direction;
  double length = 0;
};
Route route(V from, V look, double limit) {
  V d = V{look.x, 0, look.z}.unit();
  if (d.length2() < .1 || std::abs(from.x) > limit || std::abs(from.z) > limit)
    return {};
  double lo = -infinity, hi = infinity;
  for (auto pair : {std::pair<double, double>{from.x, d.x}, {from.z, d.z}}) {
    if (std::abs(pair.second) < 1e-6)
      continue;
    double a = (-limit - pair.first) / pair.second,
           b = (limit - pair.first) / pair.second;
    lo = std::max(lo, std::min(a, b));
    hi = std::min(hi, std::max(a, b));
  }
  V start = from + d * lo;
  start.y = 0;
  return {hi - lo >= 1, start, d, hi - lo};
}
double ceiling(Host &host, V start, V d, double length) {
  double height = -infinity;
  for (int i = 0; i <= int(std::ceil(length / 16)); ++i) {
    V p = start + d * std::min(length, i * 16.);
    height = std::max(height, host.ground_height(p.x, p.z));
  }
  return height;
}
} // namespace
bool Core::recon(Player &p, Host &host) {
  if (!alive(p) || p.vehicle >= 0 || p.classes.role != Role::SCOUT ||
      !p.classes.equipped_t2 || p.classes.xp[1] < 7500 ||
      p.classes.drone_ready > time_)
    return false;
  V look = eye_pose(p).basis.z * -1;
  if (look.x * look.x + look.z * look.z < 1e-6)
    look = B::yaw(p.yaw).apply({0, 0, -1});
  auto path = route(p.position, look, cq.map_limit);
  if (!path.valid)
    return false;
  for (auto &f : flights_)
    if (!f.active) {
      f = Flight{};
      f.active = true;
      f.key = next_entity_++;
      f.owner = session(p);
      f.caller = p.handle;
      f.team = p.team;
      f.start = path.start;
      f.direction = path.direction;
      f.length = path.length;
      f.start.y = ceiling(host, f.start, f.direction, f.length) + 60;
      f.at = f.last_scan = time_;
      f.until = time_ + f.length / 120;
      p.classes.drone_ready = time_ + 120;
      p.classes.cloak_until = 0;
      return true;
    }
  return false;
}
bool Core::airstrike(Player &p, Host &host) {
  auto &d = p.designation;
  if (!alive(p) || !stationary(p) || p.classes.role != Role::SHOCKTROOP ||
      !p.classes.equipped_t2 || p.classes.xp[0] < 7500 ||
      p.classes.strike_ready > time_ || !d.locking)
    return false;
  auto path = route(d.lock_position, d.lock_direction, cq.map_limit);
  if (!path.valid)
    return false;
  for (auto &f : flights_)
    if (!f.active) {
      f = Flight{};
      f.active = f.strike = true;
      f.key = next_entity_++;
      f.owner = session(p);
      f.caller = p.handle;
      f.team = p.team;
      f.direction = path.direction;
      f.step = std::min(18., path.length / 11);
      double along = (d.lock_position - path.start).dot(path.direction),
             first = std::clamp(along - f.step * 5.5, 0.,
                                std::max(0., path.length - f.step * 11));
      f.target = path.start + path.direction * first;
      f.start = f.target - f.direction * 180;
      f.length = 180 + f.step * 11 + 240;
      f.start.y = ceiling(host, f.start, f.direction, f.length) + 80;
      f.at = time_;
      f.impact_at = time_ + 5;
      f.until = time_ + f.length / 60 + 2;
      p.classes.strike_ready = time_ + 300;
      d.locking = false;
      return true;
    }
  return false;
}
void Core::tick_flights(Host &host) {
  for (auto &p : players_)
    if (p.active && p.designation.locking &&
        (!alive(p) || p.weapon != 8 || !p.input.fire || !stationary(p) ||
         p.input.blocked || p.designation.until < time_))
      p.designation.locking = false;
  for (auto &f : flights_)
    if (f.active) {
      if (f.strike) {
        while (f.delivered < 12 &&
               time_ + 1e-5 >= f.impact_at + f.step / 60 * f.delivered) {
          V point = f.target + f.direction * (f.step * f.delivered++);
          double ground = host.ground_height(point.x, point.z);
          auto hit = host.entity_ray({point.x, f.start.y, point.z},
                                     {point.x, ground - 10, point.z}, 0);
          V where = hit.blocked ? hit.position : V{point.x, ground, point.z};
          Projectile blast;
          blast.owner = f.caller;
          blast.credit = f.owner;
          blast.effect = 1;
          blast.team = f.team;
          blast.weapon = 11;
          blast.splash = 300;
          blast.radius = 35;
          blast.damage = 300;
          impact(blast, {true, {}, where + V{0, .08, 0}}, host);
          emit(EventKind::AIRSTRIKE, f.caller, where, {}, f.delivered, 35,
               f.key);
        }
      } else if (tick_ % 3 == 0) {
        V a = f.start + f.direction * std::clamp((f.last_scan - f.at) * 120, 0.,
                                                 f.length),
          b = f.start +
              f.direction * std::clamp((time_ - f.at) * 120, 0., f.length);
        a.y = b.y = 0;
        for (size_t i = 0; i < MAX_PLAYERS; ++i) {
          auto &p = players_[i];
          if (!p.active || p.dead || p.staging || p.team == f.team)
            continue;
          V point = p.position;
          point.y = 0;
          if ((point - closest(point, a, b)).length2() > 10000)
            continue;
          p.spotted[f.team] = time_ + 10;
          if (f.seen_lives[i] != p.handle.life) {
            f.seen_lives[i] = p.handle.life;
            emit(EventKind::RECON_ALERT, p.handle, p.position, {}, f.team, 10,
                 f.key);
          }
        }
        f.last_scan = time_;
      }
      if (f.until <= time_)
        f.active = false;
    }
}
bool Core::deploy_turret(Player &p, V at, Host &host) {
  if (p.classes.role != Role::TECHNICIAN || !p.classes.equipped_t2 ||
      p.classes.turret_ready > time_ || p.classes.xp[3] < 7500 ||
      host.water(at))
    return false;
  for (V offset : {V{}, V{1, 0, 0}, V{-1, 0, 0}, V{0, 0, 1}, V{0, 0, -1}}) {
    auto hit = host.world_trace(at + offset + V{0, .35, 0},
                                at + offset - V{0, .35, 0}, p.handle);
    if (!hit.blocked || hit.normal.y < std::cos(8 * 3.141592653589793 / 180) ||
        (hit.position - at - offset).length() > .12)
      return false;
  }
  Turret *slot = nullptr;
  for (auto &t : turrets_)
    if (t.active && t.owner == session(p)) {
      slot = &t;
      break;
    }
  if (!slot)
    for (auto &t : turrets_)
      if (!t.active) {
        slot = &t;
        break;
      }
  if (!slot)
    return false;
  *slot = Turret{};
  slot->active = true;
  slot->key = next_entity_++;
  slot->owner = session(p);
  slot->gunner = p.handle;
  slot->team = p.team;
  slot->position = at;
  slot->fire_at = time_ + 1.5;
  slot->direction = B::yaw(p.yaw).apply({0, 0, -1});
  p.classes.turret_ready = time_ + 120;
  return true;
}
void Core::tick_turrets(Host &host) {
  for (auto &t : turrets_)
    if (t.active) {
      if (t.hp <= 0 || t.ammo <= 0 || !owner(t.owner)) {
        t.active = false;
        continue;
      }
      if (time_ < t.fire_at)
        continue;
      V origin = t.position + V{0, 1.15, 0}, target;
      double nearest = 150 * 150;
      uint64_t vehicle = 0;
      Handle player;
      for (auto &v : vehicles_)
        if (v.active && v.hp > 0 && v.team != t.team) {
          V p = v.position + V{0, .8, 0};
          double distance = (p - origin).length2();
          if (distance < nearest &&
              !host.entity_ray(origin, p, v.key).blocked) {
            nearest = distance;
            target = p;
            vehicle = v.key;
          }
        }
      if (!vehicle)
        for (auto &p : players_)
          if (alive(p) && p.team != t.team && p.vehicle < 0 &&
              p.classes.cloak_until <= time_) {
            V at = p.position + V{0, p.height * .5, 0};
            double distance = (at - origin).length2();
            double radius = 150 * detection_scale(p);
            if (distance <= radius * radius && distance < nearest &&
                !host.world_trace(origin, at, p.handle).blocked) {
              nearest = distance;
              target = at;
              player = p.handle;
            }
          }
      if (!vehicle && !player.id)
        continue;
      V direction = (target - origin).unit();
      if (host.entity_ray(origin, origin + direction * .6, t.key).blocked)
        continue;
      if (launch_external(t.gunner, t.team, 11, origin + direction * .6,
                          direction * 40, 100, 120, 5, 0, 4, .025, t.key, 0,
                          t.owner)) {
        t.direction = direction;
        t.target_vehicle = vehicle;
        t.target_player = player;
        t.fire_at = time_ + 1.5;
        t.shot_at = time_;
        --t.ammo;
        emit(EventKind::SHOT, t.gunner, origin, direction, 11, 0, t.key);
        if (!t.ammo)
          t.active = false;
      }
    }
}
void Core::repair(Player &p, Host &host) {
  if (p.classes.role != Role::TECHNICIAN || p.classes.replaces_box() || p.weapon != 7 || !p.input.fire ||
      p.input.blocked || time_-p.last_input>.35 || (p.input.vr && (!p.pose.tracked || !p.input.weapon_held)))
    return;
  // Cabin passenger may service only their own transport, never fire a gun.
  if(p.vehicle>=0 && (p.vehicle_seat!=7 || vehicles_[size_t(p.vehicle)].kind!=VehicleKind::TRANSPORT))return;
  auto pose = weapon_pose(p);
  V tip = pose.apply({0, 0, -.12});
  for (auto &v : vehicles_)
    if (v.active && v.hp > 0 && v.team == p.team &&
        (p.vehicle<0 || &v==&vehicles_[size_t(p.vehicle)]) && v.hp < vehicle_profile(v.kind).hp) {
      V local = B::yaw(v.yaw).inverse(tip - v.position);
      V half = vehicle_profile(v.kind).size * .5;
      V nearest{std::clamp(local.x, -half.x, half.x),
                std::clamp(local.y, 0., half.y * 2),
                std::clamp(local.z, -half.z, half.z)};
      V at = v.position + B::yaw(v.yaw).apply(nearest);
      if ((at - tip).length() > 1.5 || host.entity_ray(tip, at, v.key).blocked)
        continue;
      double amount = std::min(30 * step_, vehicle_profile(v.kind).hp - v.hp);
      v.hp += amount;
      p.repair_credit += amount;
      int xp = int(p.repair_credit / 10);
      p.repair_credit -= xp * 10;
      p.classes.award(xp);
      break;
    }
}
void Core::tick_locks(Host &host) {
  for (auto &p : players_)
    if (p.active) {
      if (!alive(p) || p.weapon != 11 || p.vehicle >= 0 || p.input.blocked ||
          time_ - p.last_input > .35) {
        p.lock_vehicle = 0;
        p.lock_elapsed = 0;
        continue;
      }
      auto pose = weapon_pose(p);
      V forward = pose.basis.z * -1;
      double score = std::cos(6 * 3.141592653589793 / 180);
      uint64_t best = 0;
      for (auto &v : vehicles_)
        if (v.active && v.hp > 0 && v.team >= 0 && v.team != p.team) {
          V target = v.position + V{0, .8, 0}, delta = target - pose.origin;
          double alignment = forward.dot(delta.unit());
          if (delta.length() > 500 || alignment <= score ||
              host.entity_ray(pose.origin, target, v.key).blocked)
            continue;
          score = alignment;
          best = v.key;
        }
      p.lock_elapsed =
          best ? (best == p.lock_vehicle ? std::min(1.5, p.lock_elapsed + step_)
                                         : step_)
               : 0;
      p.lock_vehicle = best;
    }
}

} // namespace cqauthority
