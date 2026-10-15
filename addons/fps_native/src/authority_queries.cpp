#include "authority_core.h"
namespace cqauthority {
double Core::damage_yaw(const Player &p) const {
  V forward = p.pose.head.basis.z * -1;
  return p.yaw + (p.pose.tracked &&
                          forward.x * forward.x + forward.z * forward.z >= .0001
                      ? std::atan2(-forward.x, -forward.z)
                      : 0);
}
void Core::record_history() {
  auto &frame = history_[history_next_];
  frame.time = time_;
  for (size_t i = 0; i < MAX_PLAYERS; ++i) {
    auto &p = players_[i];
    frame.actors[i] = {p.active && !p.dead && !p.staging, p.handle, p.position, p.height,
                       damage_yaw(p)};
  }
  history_next_ = (history_next_ + 1) % history_.size();
  history_count_ = std::min(history_count_ + 1, history_.size());
}
Hit Core::trace_hit(Host &host, V from, V to, Handle ignore, double radius,
                    double view_time, bool relative, uint64_t ignore_entity) {
  if (!cq.enabled)
    return host.trace(from, to, ignore);
  Hit closest = host.sweep_world(from, to, radius, ignore, ignore_entity);
  double first = closest.blocked
                     ? std::min(1., (closest.position - from).length() /
                                        std::max(.00001, (to - from).length()))
                     : infinity;
  const HistoryFrame *low = nullptr;
  const HistoryFrame *high = nullptr;
  double stamp = std::clamp(view_time, time_ - .20, time_);
  if (view_time >= 0 && !relative)
    for (size_t n = 0; n < history_count_; ++n) {
      auto &f = history_[n];
      if (f.time <= stamp && (!low || f.time > low->time))
        low = &f;
      if (f.time >= stamp && (!high || f.time < high->time))
        high = &f;
    }
  for (size_t i = 0; i < MAX_PLAYERS; ++i) {
    auto &p = players_[i];
    if (!p.active || p.dead || p.staging || p.handle == ignore || p.vehicle >= 0)
      continue;
    V position = p.position,
      previous = relative ? p.previous_position : position;
    double height = p.height, yaw = damage_yaw(p);
    if (low || high) {
      auto *a = low ? &low->actors[i] : &high->actors[i];
      auto *b = high ? &high->actors[i] : a;
      if (!a->active || !b->active || a->handle != p.handle ||
          b->handle != p.handle)
        continue;
      double t =
          low && high && high->time > low->time
              ? std::clamp((stamp - low->time) / (high->time - low->time), 0.,
                           1.)
              : 0;
      position = a->position + (b->position - a->position) * t;
      previous = position;
      height = a->height + (b->height - a->height) * t;
      double delta = std::remainder(b->yaw - a->yaw, 6.283185307179586);
      yaw = a->yaw + delta * t;
    }
    auto hit =
        body_fraction(from - previous, to - position, height, yaw, radius);
    if (hit.fraction >= first)
      continue;
    V point = from + (to - from) * hit.fraction;
    V center = position + hit.axis;
    // A protruding shoulder cannot bypass thin cover hiding its body axis.
    auto cover = host.world_trace(point, center, ignore);
    if (cover.blocked && (cover.position - point).length() > .001)
      continue;
    first = hit.fraction;
    closest = {true, p.handle, point};
    closest.headshot = hit.head;
    closest.fraction = first;
  }
  return closest;
}
} // namespace cqauthority
