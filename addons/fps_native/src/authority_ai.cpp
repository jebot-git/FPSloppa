#include "authority_core.h"
namespace cqauthority {
void Core::tick_bots(Host &host) {
  for (size_t index = 0; index < MAX_PLAYERS; ++index) {
    auto &p = players_[index];
    if (!p.active || !p.bot)
      continue;
    auto &brain = brains_[index];
    if (brain.life != p.handle) {
      brain = BotBrain{};
      brain.life = p.handle;
      brain.last_position = p.position;
      brain.think = time_ + double(index % 6) * step_;
    }
    Command c;
    c.life = p.handle.life;
    c.seq = p.last_seq + 1;
    c.weapon = p.weapon;
    c.yaw = p.yaw;
    c.pitch = p.pitch;
    c.respawn = p.dead;
    if (!alive(p) || points.winner != -2) {
      submit(p.handle, c);
      continue;
    }
    if (time_ >= brain.think) {
      brain.think = time_ + .2;
      brain.target = {};
      double range = spot_range(p);
      V eye = eye_pose(p).origin;
      std::array<std::pair<double, Handle>, 4> nearest;
      for (auto &item : nearest)
        item = {infinity, {}};
      for (auto &target : players_)
        if (alive(target) && target.team != p.team && target.vehicle < 0 &&
            target.classes.cloak_until <= time_) {
          double distance = (target.position - p.position).length2();
          if (distance > range * range)
            continue;
          for (size_t i = 0; i < nearest.size(); ++i)
            if (distance < nearest[i].first) {
              for (size_t j = nearest.size() - 1; j > i; --j)
                nearest[j] = nearest[j - 1];
              nearest[i] = {distance, target.handle};
              break;
            }
        }
      for (auto entry : nearest) {
        if (!entry.second.id)
          break;
        auto *target = resolve(entry.second);
        if (!target)
          continue;
        V at = target->position + V{0, target->height * .55, 0};
        if (!host.world_trace(eye, at, p.handle).blocked) {
          brain.target = target->handle;
          break;
        }
      }
      if (cq.light_fraction < .2 && !p.classes.nvg)
        toggle_nvg(p.handle);
      if (p.classes.role == Role::SCOUT && p.classes.equipped_t2 &&
          p.classes.drone_ready <= time_)
        recon(p, host);
      if (time_ >= brain.tool_until && p.classes.box_ready <= time_ &&
          ((p.classes.role == Role::MEDIC && !p.classes.equipped_t2 &&
            p.hp < 65) ||
           (p.classes.role == Role::TECHNICIAN &&
            (!p.classes.equipped_t2 ? p.ammo[2] < 3 : brain.target.id != 0)))) {
        brain.tool_until = time_ + 1;
        brain.tool = 6;
      }
      if (p.classes.role == Role::SHOCKTROOP && p.classes.equipped_t2 &&
          p.classes.strike_ready <= time_ && brain.target.id &&
          time_ >= brain.designation_until) {
        auto *target = resolve(brain.target);
        if (target && (target->position - p.position).length() > 20) {
          brain.aim = target->position + V{0, .08, 0};
          brain.designation_until = time_ + 6.5;
        }
      }
    }
    auto *target = resolve(brain.target);
    if (target && !alive(*target))
      target = nullptr;
    if (time_ >= brain.plan) {
      brain.plan = time_ + .8;
      double best = infinity;
      bool chosen = false;
      for (size_t i = 0; i < points.count; ++i) {
        auto &zone = points.zones[i];
        if (zone.owner == p.team)
          continue;
        double score =
            (zone.position - p.position).length() + (zone.contested ? 30 : 0) +
            double((i + size_t(uint64_t(-(p.handle.id + 1)) + 1)) % 3) * 7;
        if (score < best) {
          best = score;
          brain.goal = zone.position;
          chosen = true;
        }
      }
      if (!chosen) {
        if (target)
          brain.goal = target->position;
        else if (points.count)
          brain.goal = points
                           .zones[size_t(uint64_t(-(p.handle.id + 1)) + 1) %
                                  points.count]
                           .position;
        else
          brain.goal = p.spawn_position;
      }
      if (!brain.path.empty() && (brain.path.back() - brain.goal).length() > 8)
        brain.route = 0;
    }
    if (time_ >= brain.route) {
      brain.route = time_ + .8;
      brain.path = host.navigate(p.position, brain.goal);
      brain.step = 0;
    }
    while (brain.step < brain.path.size()) {
      V delta = brain.path[brain.step] - p.position;
      if (std::hypot(delta.x, delta.z) > .9 || std::abs(delta.y) > 1.2)
        break;
      ++brain.step;
    }
    V travel = brain.step < brain.path.size()
                   ? brain.path[brain.step] - p.position
                   : V{};
    travel.y = 0;
    int primary = p.classes.weapon(false);
    c.weapon = primary;
    if (weapons()[primary].ammo >= 0 && p.ammo[weapons()[primary].ammo] <= 0)
      c.weapon = p.classes.weapon(true);
    if (target && primary == 5 && (target->position - p.position).length() > 45)
      c.weapon = p.classes.weapon(true);
    V aim;
    if (target) {
      auto &w = weapons()[c.weapon];
      V at = target->position + V{0, target->height * .55, 0};
      double flight =
          w.speed > 0
              ? std::min(1., (at - eye_pose(p).origin).length() / w.speed)
              : 0;
      at = at + target->velocity * flight +
           V{0, w.gravity * flight * flight * .5, 0};
      aim = at - eye_pose(p).origin;
      c.fire = !host.world_trace(eye_pose(p).origin, at, p.handle).blocked;
    } else
      aim = travel;
    if (time_ < brain.designation_until) {
      c.weapon = 8;
      c.fire = true;
      aim = brain.aim - eye_pose(p).origin;
      travel = {};
    }
    if (time_ < brain.tool_until) {
      c.weapon = brain.tool;
      c.fire = true;
      travel = {};
      aim = B::yaw(p.yaw).apply({0, 0, -1});
    }
    if (aim.length2() > .001) {
      V direction = aim.unit();
      c.yaw = std::atan2(-direction.x, -direction.z);
      c.pitch = std::asin(std::clamp(direction.y, -1., 1.));
    }
    if (target && c.weapon != 8 && c.weapon != 6) {
      double noise = .007 * std::sin(time_ * 7 + double(p.handle.id));
      c.yaw += noise;
      c.pitch = std::clamp(c.pitch + noise * .5, -1.5, 1.5);
      if ((target->position - p.position).length() < 10)
        travel =
            travel +
            V{std::sin(time_ * 2 + index), 0, std::cos(time_ * 2 + index)} * 2;
    }
    V local = B::yaw(c.yaw).inverse(travel.unit());
    c.x = local.x;
    c.z = local.z;
    if (p.grounded && travel.length2() > .1 && brain.step < brain.path.size()) {
      V next = brain.path[brain.step];
      c.jump = next.y - p.position.y > .6;
      double moved = (p.position - brain.last_position).length();
      brain.stuck = moved < .015 ? brain.stuck + step_ : 0;
      if (brain.stuck > .8) {
        c.jump = true;
        brain.route = 0;
        brain.stuck = 0;
      }
    }
    brain.last_position = p.position;
    if (!target && p.clips[c.weapon] < weapons()[c.weapon].mag)
      c.reload = true;
    if ((c.weapon==2 || c.weapon==9 || c.weapon==10) && p.cooldown>step_) c.fire=false;
    submit(p.handle, c);
  }
}
} // namespace cqauthority
