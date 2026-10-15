#include "authority_core.h"
#include "authority_nvg.h"
namespace cqauthority {
namespace {
double smooth(double a, double b, double x) {
  double t = std::clamp((x - a) / (b - a), 0., 1.);
  return t * t * (3 - 2 * t);
}
V weights(double time, double seconds) {
  double t = std::fmod(time / seconds, 1.);
  if (t < 0)
    t += 1;
  t=t<.275?t*.31/.275:t<.725?.31+(t-.275)*.375/.45:.685+(t-.725)*.315/.275;
  if (t < .2)
    return {1, 0, 0};
  if (t < .27) {
    double k = smooth(.2, .27, t);
    return {1 - k, k, 0};
  }
  if (t < .35)
    return {0, 1 - smooth(.27, .35, t), 0};
  if (t < .65)
    return {};
  if (t < .72)
    return {0, 0, smooth(.65, .72, t)};
  if (t < .8) {
    double k = smooth(.72, .8, t);
    return {k, 0, 1 - k};
  }
  return {1, 0, 0};
}
} // namespace
bool Core::configure_lamps(const std::vector<V> &lamps) {
  if (tick_ || lamps.size() > 8192)
    return false;
  for (auto p : lamps)
    if (!p.finite())
      return false;
  lamps_ = lamps;
  lamp_bins_.clear();
  for (size_t i = 0; i < lamps_.size(); ++i) {
    V p = lamps_[i];
    lamp_bins_[Terrain::key(int(std::floor(p.x / 24)),
                            int(std::floor(p.z / 24)))]
        .push_back(i);
  }
  return true;
}
void Core::tick_lighting(Host &host) {
  V w = weights(time_ + cq.cycle_offset, cq.cycle_seconds);
  if (cq.day_cycle)
    cq.light_fraction = w.x + w.y + w.z;
  if (tick_ % 3)
    return;
  V sun = (w.x > .25   ? V{-.4, .8, .3}
           : w.y > .25 ? V{-.95, .14, .28}
           : w.z > .25 ? V{.95, .14, .28}
                       : V{})
              .unit();
  for (auto &p : players_)
    if (alive(p) && p.classes.nvg) {
      p.classes.blind_until=0;
      T eye = eye_pose(p);
      V forward = eye.basis.z * -1;
      int x = int(std::floor(eye.origin.x / 24)),
          z = int(std::floor(eye.origin.z / 24));
      std::array<std::pair<double, size_t>, 2> nearest{
          {{infinity, 0}, {infinity, 0}}};
      for (int dz = -1; dz <= 1; ++dz)
        for (int dx = -1; dx <= 1; ++dx) {
          auto it = lamp_bins_.find(Terrain::key(x + dx, z + dz));
          if (it == lamp_bins_.end())
            continue;
          for (size_t i : it->second) {
            V offset = lamps_[i] - eye.origin;
            double distance = offset.length2();
            if (distance >= 196 || !nvg_direct(forward,offset))
              continue;
            if (distance < nearest[0].first) {
              nearest[1] = nearest[0];
              nearest[0] = {distance, i};
            } else if (distance < nearest[1].first)
              nearest[1] = {distance, i};
          }
        }
      for (auto entry : nearest)
        if (std::isfinite(entry.first) &&
            !host.world_trace(eye.origin, lamps_[entry.second], p.handle)
                 .blocked) {
          p.classes.blind_until = time_ + .14;
          break;
        }
      if (cq.day_cycle && sun.length2() > .1 && nvg_direct(forward,sun,true) &&
          !host.world_trace(eye.origin, eye.origin + sun * 1500, p.handle)
               .blocked)
        p.classes.blind_until = time_ + .14;
    }
}
bool Core::configure_spawn(int team, V point) {
  if (tick_ || team < 0 || team > 1 || !point.finite() ||
      spawns_[team].size() >= 256)
    return false;
  spawns_[team].push_back(point);
  return true;
}
V Core::spawn_site(const Player &p, Host &host) {
  if(cq.squads){
    double side=p.team==0?-1.:1.;
    V anchor{side*cq.map_limit*.72,0,(std::max(0,p.squad)-1.5)*96.};
    for(int i=0;i<64;++i){double a=(i%8)*.7853981633974483;double r=3.+(i/8)*5.;V at=anchor+V{std::cos(a)*r,0,std::sin(a)*r};at.y=host.ground_height(at.x,at.z)+.04;
      auto floor=host.world_trace(at+V{0,2,0},at-V{0,3,0},p.handle);if(floor.blocked&&floor.normal.y<.65)continue;
      if(host.water(at)||!host.clear_exit(p.handle,at,0))continue;
      bool occupied=false;for(const auto &other:players_)if(alive(other)&&other.handle!=p.handle&&(at-other.position).length()<1.2){occupied=true;break;}
      if(!occupied)return at;
    }
    return {NAN,0,0};
  }
  V result = p.spawn_position;
  double best = -1;
  for (V point : spawns_[p.team]) {
    if (host.water(point) || !host.clear_exit(p.handle, point, 0))
      continue;
    double distance = 100;
    for (auto &other : players_)
      if (other.active && !other.dead && !other.staging && other.handle != p.handle)
        distance = std::min(distance, (point - other.position).length());
    double score = distance + random_unit() * 2;
    if (score > best) {
      best = score;
      result = point;
    }
  }
  return result;
}
void Core::round_state(Host &host) {
  if (restart_requested_) {
    restart_requested_ = false;
    points.winner = -1;
    round_awarded_ = true;
    restart_at_ = time_;
  }
  if (points.winner == -2 && cq.round_seconds > 0 &&
      time_ - round_start_ >= cq.round_seconds)
    points.winner = points.scores[0] == points.scores[1]  ? -1
                    : points.scores[0] > points.scores[1] ? 0
                                                          : 1;
  if (points.winner == -2)
    return;
  if (!round_awarded_) {
    round_awarded_ = true;
    restart_at_ = time_ + cq.intermission_seconds;
    for (auto &p : players_)
      if (p.active) {
        p.classes.award(50 + (p.team == points.winner ? 100 : 0));
        p.grenade_primed = false;
        p.designation = {};
        p.burst_left = p.salvo_left = 0;
        p.velocity = {};
        p.count = 0;
        p.action_count = 0;
      }
    for (auto &s : projectiles_)
      s.active = false;
    for (auto &g : grenades_)
      g.active = false;
    for (auto &v : vehicles_)
      if (v.active) {
        v.speed = 0;
        v.remaining = 0;
        v.velocity = {};
      }
  }
  if (time_ < restart_at_)
    return;
  for (auto &p : players_)
    if (p.active && p.vehicle >= 0)
      vehicle_leave(p, host, true);
  for (auto &s : projectiles_)
    s.active = false;
  for (auto &g : grenades_)
    g.active = false;
  for (auto &b : boxes_)
    b.active = false;
  for (auto &f : fields_)
    f.active = false;
  for (auto &t : turrets_)
    t.active = false;
  for (auto &f : flights_)
    f.active = false;
  for (auto &v : vehicles_)
    if (v.active) respawn_vehicle(v, host);
  for (auto &p : players_)
    if (p.active) {
      p.dead = true;
      if(cq.squads&&!p.bot&&!p.stress)p.staging=true;
      p.kills = p.deaths = 0;
      auto h = respawn(p.handle, spawn_site(p, host));
      if (h.id)
        host.teleport(h, p.position);
    }
  for (size_t i = 0; i < points.count; ++i) {
    auto at = points.zones[i].position;
    double radius = points.zones[i].radius;
    points.zones[i] = Zone{};
    points.zones[i].position = at;
    points.zones[i].radius = radius;
  }
  points.scores = {};
  points.winner = -2;
  history_count_ = history_next_ = 0;
  event_count_ = event_next_ = 0;
  ++round_epoch_;
  round_start_ = time_;
  restart_at_ = 0;
  round_awarded_ = false;
}
void Core::drag(Player &p, Host &host) {
  if (p.classes.role != Role::MEDIC || !p.input.drag ||
      time_ - p.last_input > .35)
    return;
  V hand = p.position +
           B::yaw(p.yaw).apply(
               p.pose.tracked
                   ? (p.pose.left_handed ? p.pose.right : p.pose.left).origin
                   : V{0, .4, -.6});
  for (auto &b : players_)
    if (b.active && b.incapacitated && same_team(p, b)) {
      if ((hand - b.position - V{0, .35, 0}).length() > .6)
        continue;
      V motion = (hand - V{0, .35, 0} - b.position).limited(step_ * 2);
      V actual = host.room_move(b.handle, B::yaw(b.yaw).inverse(motion), b.yaw);
      b.position = b.position + actual;
      break;
    }
}
void Core::melee(Player &p, Host &host) {
  for (size_t hand = 0; hand < 2; ++hand) {
    auto &state = p.melee_state[hand];
    if (!p.input.melee || (p.input.vr && !p.input.weapon_held) ||
        time_ - p.last_input > .35 || p.charge_at > 0 ||
        (hand && (!p.input.vr || p.weapon != 2 || !p.pose.has_offhand))) {
      state.reset();
      continue;
    }
    state.ready_at = std::max(state.ready_at, p.melee_ready);
    MeleeSample sample;
    T frame;
    if (p.input.vr) {
      if (!p.pose.tracked) {
        state.reset();
        continue;
      }
      if (state.sequence == p.last_seq)
        continue;
      state.sequence = p.last_seq;
      Pose pose = p.pose;
      if (hand) {
        pose.weapon = pose.offhand;
        pose.left_handed = !pose.left_handed;
      }
      sample = state.sample(pose, time_, p.weapon);
      if (!sample.active)
        continue;
      frame = {B::yaw(p.yaw),
               p.position + B::yaw(p.yaw).apply(p.pose.head.origin)};
    } else {
      if (time_ < state.ready_at)
        continue;
      state.ready_at = time_ + MELEE_COOLDOWN;
      state.hit = false;
      sample.active = sample.started = true;
      auto pose = weapon_pose(p);
      sample.segments[0] = {pose.origin, pose.apply({0, 0, -1.25})};
    }
    if (sample.started) {
      p.melee_ready = time_ + MELEE_COOLDOWN;
      p.melee_state[1 - hand].swing_until = 0;
      p.invulnerable = 0;
      p.classes.cloak_until = 0;
      if (!p.input.vr)
        p.cooldown = std::max(p.cooldown, .3);
      emit(EventKind::MELEE, p.handle, weapon_pose(p).origin,
           weapon_pose(p).basis.z * -1);
    }
    V torso = p.position + V{0, std::min(.9, p.height * .6), 0};
    size_t count = p.input.vr ? 16 : 1;
    for (size_t i = 0; i < count; ++i) {
      V from = frame.apply(sample.segments[i][0]),
        to = frame.apply(sample.segments[i][1]);
      if (host.world_trace(torso, from, p.handle).blocked)
        continue;
      auto hit = trace_hit(host, from, to, p.handle, .10);
      if (!hit.actor.id ||
          host.world_trace(torso, hit.position, p.handle).blocked)
        continue;
      state.hit = true;
      p.cooldown = std::max(p.cooldown, .3);
      damage(hit.actor, p.handle, 10, DamageKind::MELEE);
      break;
    }
  }
}
} // namespace cqauthority
