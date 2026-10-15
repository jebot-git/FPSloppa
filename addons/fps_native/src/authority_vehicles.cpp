#include "authority_core.h"
#include "authority_transport_geometry.h"
namespace cqauthority {
double Core::random_unit() {
  random_state_ ^= random_state_ >> 12;
  random_state_ ^= random_state_ << 25;
  random_state_ ^= random_state_ >> 27;
  return ((random_state_ * 2685821657736338717ULL) >> 11) * 0x1.0p-53;
}

int Core::add_vehicle(VehicleKind kind, V at, double yaw, int team) {
  if (tick_ || !cq.enabled || !at.finite() || !std::isfinite(yaw) ||
      size_t(kind) > 3 || team < -1 || team > 1 ||
      (kind == VehicleKind::TRANSPORT && team < 0))
    return -1;
  for (size_t i = 0; i < MAX_VEHICLES; ++i)
    if (!vehicles_[i].active) {
      auto &v = vehicles_[i];
      v = Vehicle{};
      v.active = true;
      v.key = next_entity_++;
      v.kind = kind;
      v.team = v.spawn_team = team;
      v.spawn = v.position = at;
      v.spawn_yaw = v.yaw = yaw;
      v.hp = vehicle_profile(kind).hp;
      v.rounds = vehicle_profile(kind).capacity;
      v.direction = B::yaw(yaw).apply({0, 0, -1});
      v.visual_y = at.y + (kind == VehicleKind::ROCKET || kind == VehicleKind::TRANSPORT ? 0 : .25);
      return int(i);
    }
  return -1;
}
bool Core::vehicle_use(Player &p, Host &host) {
  if (!alive(p) || p.input.blocked || time_ - p.last_input > .35 ||
      p.use_ready > time_)
    return false;
  if (p.vehicle >= 0) {
    auto &v = vehicles_[size_t(p.vehicle)];
    if (v.kind == VehicleKind::TRANSPORT) {
      if (p.vehicle_seat != 6 && !v.seats[6].id) {
        v.seats[size_t(p.vehicle_seat)] = {};
        v.seats[6] = p.handle;v.pilot=p.handle;p.vehicle_seat=6;
        p.position=transport_seat(v,6);host.seat(p.handle,p.position,true);
        p.use_ready=time_+.5;return true;
      }
      return false; // Jump dismounts. Use never ejects the driver by accident.
    }
    return vehicle_leave(p, host);
  }
  double nearest = 4.5;
  int chosen = -1, chosen_seat = -1;
  for (size_t i = 0; i < MAX_VEHICLES; ++i) {
    auto &v = vehicles_[i];
    if (!v.active || v.hp <= 0)
      continue;
    if (v.kind == VehicleKind::TRANSPORT) {
      if (p.team != v.team) continue;
      for (size_t seat=0; seat<v.seats.size(); ++seat) {
        if (v.seats[seat].id) continue;
        V entry=v.position+B::yaw(v.yaw).apply(transport_pods[seat].entry);
        double distance=(p.position-entry).length();
        if(distance>transport_entry_radius || distance>nearest ||
           host.entity_ray(p.position+V{0,.8,0},entry+V{0,.8,0},v.key).blocked) continue;
        nearest=distance;chosen=int(i);chosen_seat=int(seat);
      }
      continue;
    }
    if (v.pilot.id) continue;
    double distance = (p.position - v.position).length();
    if (distance > nearest || host.entity_ray(p.position + V{0, .8, 0},
                                              v.position + V{0, 1, 0}, v.key)
                                  .blocked)
      continue;
    nearest = distance;
    chosen = int(i);chosen_seat=-1;
  }
  if (chosen < 0)
    return false;
  auto &v = vehicles_[chosen];
  if (v.kind == VehicleKind::TRANSPORT) {
    v.seats[size_t(chosen_seat)]=p.handle;
    if (chosen_seat==6) v.pilot=p.handle;
  } else {v.pilot=p.handle;v.team=p.team;}
  p.vehicle_seat=chosen_seat;
  p.vehicle = chosen;
  p.position = chosen_seat>=0 ? transport_seat(v,chosen_seat) : v.position;
  p.velocity = {};
  p.jetpack.mode = 0;
  p.jetpack.tap = 0;
  p.classes.cloak_until = 0;
  p.grenade_primed = false;
  p.burst_left = 0;
  p.salvo_left = 0;
  p.charge_at = 0;
  p.designation = {};
  p.use_ready = time_ + .5;
  host.seat(p.handle, p.position, true);
  return true;
}
bool Core::vehicle_leave(Player &p, Host &host, bool forced) {
  if (p.vehicle < 0)
    return false;
  auto &v = vehicles_[p.vehicle];
  V point{infinity, infinity, infinity};
  V door{3.2,0,0};
  if (v.kind==VehicleKind::TRANSPORT && p.vehicle_seat>=0 && p.vehicle_seat<8)
    door=transport_pods[size_t(p.vehicle_seat)].entry;
  std::array<V,8> exits{{door,door+V{door.x<0?-.8:.8,0,0},V{3.2,0,0},V{-3.2,0,0},V{0,0,5},V{0,0,-5},V{4.2,0,2},V{-4.2,0,2}}};
  for (V local : exits) { /* authored door first, then clear ground fallbacks */
    V at = v.position + B::yaw(v.yaw).apply(local);
    auto hit = host.entity_ray(at + V{0, 2, 0}, at - V{0, 3, 0}, v.key);
    if (!hit.blocked || hit.normal.y < .8) continue;
    at=hit.position+V{0,.08,0};
    if(host.water(at)||!host.clear_exit(p.handle,at,v.key)) continue;
    point=at;break;
  }
  if (!point.finite()) {
    if (!forced)
      return false;
    point = v.position + V{0, 2.5, 0};
  }
  if(v.kind==VehicleKind::TRANSPORT) {
    for(auto &seat:v.seats) if(seat==p.handle) seat={};
    if(v.pilot==p.handle) {
      v.pilot={};

    }
  } else v.pilot={};
  if(!v.pilot.id) {v.speed=0;v.velocity={};v.remaining=0;}
  p.vehicle = -1;p.vehicle_seat=-1;
  // The jump belongs to dismounting, not a second on-foot jump or queued boost.
  p.jump_held=p.input.jump;p.jump_pending=false;
  p.jet_event_pending=false;p.input.jetpack=false;
  p.position = point;
  p.velocity = {};
  p.use_ready = time_ + .5;
  host.seat(p.handle, point, false);
  return true;
}
void Core::destroy_vehicle(Vehicle &v, Handle attacker, Host &host, bool water,
                           Session credit) {
  if (v.respawn_at > 0) return;
  v.respawn_at = time_ + (v.kind == VehicleKind::TRANSPORT ? 120. : 180.);
  if(v.kind==VehicleKind::TRANSPORT) {
    auto occupants=v.seats;
    v.hp=0;v.remaining=0;v.rounds=0;v.speed=0;v.velocity={};host.sync_vehicle(v);
    for(auto occupant:occupants) if(auto *p=resolve(occupant)) {
      vehicle_leave(*p,host,true);
      damage(p->handle,attacker.id?attacker:p->handle,10000,water?DamageKind::WATER:DamageKind::VEHICLE_DESTROYED,false,credit);
    }
    return;
  }
  auto *pilot = resolve(v.pilot);
  v.hp = 0;
  v.remaining = 0;
  v.rounds = 0;
  v.speed = 0;
  v.velocity = {};
  host.sync_vehicle(v);
  if (pilot) {
    vehicle_leave(*pilot, host, true);
    pilot->position = v.position;
    host.teleport(pilot->handle, v.position);
    damage(pilot->handle, attacker.id ? attacker : pilot->handle, 10000,
           water ? DamageKind::WATER : DamageKind::VEHICLE_DESTROYED, false,
           credit);
  }
}
int Core::damage_vehicle(uint64_t key, int team, double amount, DamageKind kind,
                         Handle attacker, Host &host, Session credit) {
  if (!std::isfinite(amount) || amount <= 0 ||
      (kind != DamageKind::ORDNANCE && kind != DamageKind::GRENADE) ||
      points.winner != -2)
    return 0;
  for (auto &v : vehicles_)
    if (v.active && v.key == key) {
      if (v.hp <= 0 || team == v.team)
        return 0;
      int dealt = std::min(
          int(v.hp),
          int(std::round(amount * (kind == DamageKind::GRENADE ? .5 : 1))));
      if(cq.squads&&dealt>0){if(auto *a=resolve(attacker))a->combat_until=time_+8.;if(auto *driver=resolve(v.pilot))driver->combat_until=time_+8.;for(auto h:v.seats)if(auto *rider=resolve(h))rider->combat_until=time_+8.;}
      v.hp -= dealt;
      if (v.hp <= 0)
        destroy_vehicle(v, attacker, host, false, credit);
      return dealt;
    }
  return 0;
}
bool Core::launch_external(Handle h, int team, int weapon, V origin, V velocity,
                           double direct, double splash, double radius,
                           double gravity, double fuse, double sweep_radius,
                           uint64_t ignore, uint64_t target, Session credit) {
  for (auto &s : projectiles_)
    if (!s.active) {
      s = Projectile{};
      s.active = true;
      s.key = next_projectile_++;
      s.owner = h;
      auto *who = resolve(h);
      s.credit = credit.id ? credit : who ? session(*who) : Session{};
      s.team = team;
      s.weapon = weapon;
      s.position = origin;
      s.velocity = velocity;
      s.damage = direct;
      s.splash = splash;
      s.radius = radius;
      s.gravity = gravity;
      s.remaining = fuse;
      s.sweep_radius = sweep_radius;
      s.ignore_entity = ignore;
      s.target_vehicle = target;
      s.quake = weapon == 5 || weapon == 11;
      s.arm = weapon == 5 ? 2 : 0;
      s.bounce = weapon == 5 ? .1 : 0;
      return true;
    }
  ++counters.projectile_full;
  return false;
}
void Core::respawn_vehicle(Vehicle &v, Host &host) {
  const auto key = v.key;
  const auto kind = v.kind;
  const auto spawn = v.spawn;
  const auto yaw = v.spawn_yaw;
  const auto team = v.spawn_team;
  v = Vehicle{};
  v.active = true;
  v.key = key;
  v.kind = kind;
  v.team = v.spawn_team = team;
  v.position = v.spawn = spawn;
  v.yaw = v.spawn_yaw = yaw;
  v.hp = vehicle_profile(kind).hp;
  v.rounds = vehicle_profile(kind).capacity;
  v.visual_y = spawn.y + (kind == VehicleKind::ROCKET || kind == VehicleKind::TRANSPORT ? 0 : .25);
  v.direction = B::yaw(yaw).apply({0, 0, -1});
  host.sync_vehicle(v);
}
void Core::tick_vehicles(Host &host) {
  for (size_t index = 0; index < MAX_VEHICLES; ++index) {
    auto &v = vehicles_[index];
    if (!v.active) continue;
    if (v.hp <= 0) {
      if (v.respawn_at > 0 && time_ + 1e-9 >= v.respawn_at)
        respawn_vehicle(v, host);
      continue;
    }
    auto &profile = vehicle_profile(v.kind);
    if(v.kind==VehicleKind::TRANSPORT) {
      for(size_t seat=0;seat<v.seats.size();++seat) {
        auto h=v.seats[seat];if(!h.id)continue;auto *p=resolve(h);
        if(!p || !alive(*p) || p->vehicle!=int(index) || p->vehicle_seat!=int(seat) || p->team!=v.team) {
          if(p && p->vehicle==int(index)) vehicle_leave(*p,host,true);
          else {v.seats[seat]={};if(v.pilot==h)v.pilot={};}
        } else if(p->jump_pending && !p->input.blocked) vehicle_leave(*p,host);
      }
      v.pilot=v.seats[6];
    }
    auto *pilot = resolve(v.pilot);
    if (v.pilot.id && (!pilot || !alive(*pilot))) {
      if (pilot)
        vehicle_leave(*pilot, host, true);
      else {
        v.pilot = {};
        v.remaining = 0;
        v.speed = 0;
      }
      pilot = nullptr;
    }
    bool valid = pilot && !pilot->input.blocked &&
                 time_ - pilot->last_input <= .35 &&
                 (!pilot->input.vr || pilot->pose.tracked);
    double x = valid ? pilot->input.x : 0, z = valid ? pilot->input.z : 0;
    V old = v.position;
    double mobility = terrain.road(v.position) ? 1.25 : 1;
    double desired =
        -z * (z < 0 ? profile.forward : profile.reverse) * mobility;
    double delta = desired - v.speed;
    v.speed += std::clamp(delta, -DT * profile.acceleration * mobility,
                          DT * profile.acceleration * mobility);
    v.yaw -= x * profile.turn * mobility * DT;
    V horizontal = B::yaw(v.yaw).apply({0, 0, -v.speed});
    V next = v.position + horizontal * DT;
    if (std::abs(next.x) > cq.map_limit - 4 ||
        std::abs(next.z) > cq.map_limit - 4) {
      horizontal = {};
      v.speed = 0;
    }
    if (pilot || !v.grounded || !v.stable_ground || std::abs(v.speed) > .001) {
      v.fall_speed -= 20 * DT;
      auto result =
          host.move_vehicle(v, {horizontal.x, v.fall_speed, horizontal.z}, DT);
      if (result.position.finite() && result.velocity.finite()) {
        v.position = result.position;
        v.fall_speed = result.velocity.y;
        v.normal = result.normal;
        v.visual_y = result.visual_y;
        v.grounded = result.grounded;
        v.stable_ground = result.stable_ground;
      }
    }
    v.velocity = (v.position - old) / DT;
    host.sync_vehicle(v);
    bool drowned = false;
    for (V corner : {V{}, V{profile.size.x * .45, 0, profile.size.z * .4},
                     V{-profile.size.x * .45, 0, profile.size.z * .4},
                     V{profile.size.x * .45, 0, -profile.size.z * .4},
                     V{-profile.size.x * .45, 0, -profile.size.z * .4}})
      if (host.water(v.position + B::yaw(v.yaw).apply(corner))) {
        drowned = true;
        break;
      }
    if (drowned) {
      destroy_vehicle(v, pilot ? pilot->handle : Handle{}, host, true);
      continue;
    }
    if (pilot) {
      if (valid) {
        V raw = weapon_pose(*pilot).basis.z * -1;
        if (v.kind != VehicleKind::ROCKET) {
          B basis = vehicle_basis(v);
          raw = basis.inverse(raw);
          double pitch =
              std::clamp(std::asin(std::clamp(raw.y, -1., 1.)),
                         profile.pitch_min * 3.141592653589793 / 180,
                         profile.pitch_max * 3.141592653589793 / 180);
          V horizontal = V{raw.x, 0, raw.z}.unit();
          if (horizontal.length2() < .1)
            horizontal = {0, 0, -1};
          raw = basis.apply(horizontal * std::cos(pitch) +
                            V{0, std::sin(pitch), 0});
        }
        v.direction = raw.unit();
      }
      pilot->position = v.kind==VehicleKind::TRANSPORT ? transport_seat(v,pilot->vehicle_seat) : v.position;
      pilot->velocity = {};
      host.seat(pilot->handle, pilot->position, true);
      if (std::abs(v.speed) >= 1) {
        for (auto &target : players_)
          if (target.active && !target.dead && !target.staging && target.handle != pilot->handle &&
              target.vehicle < 0 && target.team != v.team &&
              target.invulnerable <= time_ &&
              (!target.incapacitated || v.kind == VehicleKind::HEAVY)) {
            V nearest = closest(target.position, old, v.position);
            V local = B::yaw(v.yaw).inverse(target.position - nearest);
            if (std::abs(local.x) > profile.size.x * .5 + .3 ||
                std::abs(local.z) > profile.size.z * .5 + .3 || local.y < -.4 ||
                local.y > 1.7 ||
                host.entity_ray(nearest + V{0, .8, 0},
                                target.position + V{0, .8, 0}, v.key)
                    .blocked)
              continue;
            damage(target.handle, pilot->handle, 10000,
                   v.kind == VehicleKind::HEAVY ? DamageKind::HEAVY_RUNOVER
                                                : DamageKind::RUNOVER);
          }
      }
      if (v.kind!=VehicleKind::TRANSPORT && valid && pilot->input.fire && v.remaining == 0 &&
          time_ >= v.reload_at && time_ >= v.next) {
        if (v.kind == VehicleKind::ROCKET) {
          V start = vehicle_muzzle(v),
            velocity = v.direction * ROCKET_TANK_SPEED + v.velocity * .5;
          auto hit = host.entity_ray(vehicle_pivot(v), start, v.key);
          if (!hit.blocked) {
            V previous = start;
            bool found = false;
            for (int i = 1; i <= 360; ++i) {
              double t = i * .25;
              V point = start + velocity * t - V{0, 10 * t * t, 0};
              auto impact = host.entity_ray(previous, point, v.key);
              if (impact.blocked) {
                double fraction = (impact.position - previous).length() /
                                  std::max(.001, (point - previous).length());
                v.barrage_center = impact.position;
                v.barrage_time = std::max(.1, t - .25 + .25 * fraction);
                found = true;
                break;
              }
              previous = point;
            }
            if (!found) {
              double t = std::max(
                  .1,
                  (velocity.y +
                   std::sqrt(std::max(0., velocity.y * velocity.y +
                                              40 * (start.y - v.position.y)))) /
                      20);
              v.barrage_time = t;
              v.barrage_center = start + velocity * t - V{0, 10 * t * t, 0};
            }
            V span=v.barrage_center-v.position;span.y=0;
            if(span.length()>ROCKET_TANK_RANGE){v.barrage_center=v.position+span.unit()*ROCKET_TANK_RANGE;v.barrage_center.y=host.ground_height(v.barrage_center.x,v.barrage_center.z);}
            v.barrage_phase = random_unit() * 6.283185307179586;
            v.remaining = 8;
            v.next = time_;
          }
        } else {
          if (v.rounds <= 0)
            v.rounds = profile.capacity;
          std::array<V, 2> origins;
          bool clear = true;
          for (int barrel = 0; barrel < profile.pair; ++barrel) {
            origins[barrel] = vehicle_muzzle(v, barrel);
            clear &= !host.entity_ray(vehicle_pivot(v), origins[barrel], v.key)
                          .blocked;
          }
          int free = 0;
          for (auto &s : projectiles_)
            free += !s.active;
          if (clear && free >= profile.pair) {
            for (int barrel = 0; barrel < profile.pair; ++barrel)
              launch_external(pilot->handle, v.team, 11, origins[barrel],
                              v.direction * 40 + v.velocity * .5, 100, 120, 5,
                              0, 4, .025, v.key, 0);
            --v.rounds;
            v.next = time_ + profile.interval;
            v.shot_at = time_;
            if (!v.rounds)
              v.reload_at = time_ + profile.reload;
          }
        }
      }
    }
    if(v.kind==VehicleKind::TRANSPORT) {
      for(size_t seat=0;seat<v.seats.size();++seat) if(auto *rider=resolve(v.seats[seat])) {
        rider->position=transport_seat(v,int(seat));rider->velocity={};host.seat(rider->handle,rider->position,true);
      }
    }
    if (v.remaining > 0 && time_ >= v.next) {
      int shot = 8 - v.remaining;
      V origin = vehicle_muzzle(v, shot);
      if (host.entity_ray(vehicle_pivot(v), origin, v.key).blocked)
        continue;
      double angle = v.barrage_phase +
                     6.283185307179586 * (shot + random_unit() * .6) / 8,
             radius = 15 * std::sqrt(.16 + random_unit() * .84);
      V offset{std::cos(angle) * radius, 0, std::sin(angle) * radius};
      Ballistic solution;
      for (int attempt = 0; attempt < 6 && !solution.valid; ++attempt) {
        V target = v.barrage_center + offset * std::pow(.5, attempt);
        V span=target-v.position;span.y=0;
        if(span.length()>ROCKET_TANK_RANGE){target=v.position+span.unit()*ROCKET_TANK_RANGE;target.y=host.ground_height(target.x,target.z);}
        auto low = ballistic(origin, target, ROCKET_TANK_SPEED, 20,
                             v.velocity * .5),
             high = ballistic(origin, target, ROCKET_TANK_SPEED, 20,
                              v.velocity * .5, true);
        solution = !high.valid || (low.valid &&
                                   std::abs(low.time - v.barrage_time) <=
                                       std::abs(high.time - v.barrage_time))
                       ? low
                       : high;
      }
      if (!solution.valid) {
        V target = v.barrage_center + offset / 32.;
        solution = {true,
                    (target - origin) / v.barrage_time +
                        V{0, 10 * v.barrage_time, 0},
                    {},
                    target,
                    v.barrage_time};
      }
      if (launch_external(v.pilot, v.team, 5, origin, solution.velocity, 152,
                          152, 20, 20, ROCKET_TANK_FUSE, .3, v.key, 0)) {
        --v.remaining;
        v.next = time_ + .15;
        v.shot_at = time_;
        if (!v.remaining)
          v.reload_at = time_ + 30;
      }
    }
  }
}
} // namespace cqauthority
