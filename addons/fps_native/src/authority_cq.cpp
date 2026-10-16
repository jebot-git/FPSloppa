#include "authority_cq.h"
namespace cqauthority {
bool ClassState::choose(int r, int slot, int value) {
  if (r < 0 || r > 3 || slot < 0 || slot > 2)
    return false;
  int level = std::max(0, xp[r]) / 500;
  if (slot == 2) {
    if (value != 1 && value != 2)
      return false;
    if (value == 2 && level < 15)
      return false;
    utility_t2[r] = value == 2;
    return true;
  }
  static constexpr int t1[4] = {4, 9, 3, 5}, t2[4] = {1, 10, 12, 11}, t3[4]={14,16,13,15};
  int base = slot == 0 ? t1[r] : (r == 1 ? 8 : 2),
      advanced = slot == 0 ? t2[r] : 0;
  if(slot==0 && value==t3[r]) { if(level<10)return false;primary_t3[r]=true;primary_t2[r]=false;return true; }
  if (value != base && value != advanced)
    return false;
  if (value == advanced && level < (slot == 0 ? 5 : 10))
    return false;
  if(slot==0)primary_t3[r]=false;
  (slot == 0 ? primary_t2 : secondary_t2)[r] = value == advanced;
  return true;
}
int ClassState::weapon(bool secondary) const {
  int r = int(role);
  static constexpr int t1[4] = {4, 9, 3, 5}, t2[4] = {1, 10, 12, 11}, t3[4]={14,16,13,15};
  return secondary ? (secondary_t2[r] ? 0
                      : r == 1        ? 8
                                      : 2)
                   : (primary_t3[r] ? t3[r] : primary_t2[r] ? t2[r] : t1[r]);
}
void ClassState::award(int amount) {
  if (amount > 0)
    xp[size_t(role)] =
        int(std::min(int64_t(INT32_MAX), int64_t(xp[size_t(role)]) + amount));
}
int Points::held(int team) const {
  int n = 0;
  for (size_t i = 0; i < count; ++i)
    n += zones[i].owner == team;
  return n;
}
void Points::decide() {
  if (winner != -2)
    return;
  if (scores[0] >= 200 && scores[1] >= 200)
    winner = -1;
  else if (scores[0] >= 200)
    winner = 0;
  else if (scores[1] >= 200)
    winner = 1;
}
int Points::kill(int team) {
  if (winner != -2 || team < 0 || team > 1)
    return 0;
  int n = held(team);
  scores[team] = std::min(200, scores[team] + n);
  decide();
  return n;
}
void Points::advance(
    double delta, const std::array<std::array<bool, 2>, MAX_ZONES> &presence,
    const std::array<std::array<int, 2>, MAX_ZONES> &counts) {
  if (winner != -2 || !std::isfinite(delta))
    return;
  for (size_t i = 0; i < count; ++i) {
    auto &z = zones[i];
    z.contested = presence[i][0] && presence[i][1];
    for (int team = 0; team < 2; ++team)
      if (!presence[i][team] || z.owner == team)
        z.progress[team] = 0;
  }
  double remaining = std::max(0., delta);
  while (remaining > .000001 && winner == -2) {
    double step = remaining;
    for (size_t i = 0; i < count; ++i) {
      auto &z = zones[i];
      if (z.owner >= 0)
        step = std::min(step, std::max(.000001, 10 - z.credit));
      if (z.contested)
        continue;
      int team = presence[i][0] ? 0 : presence[i][1] ? 1 : -1;
      if (team >= 0 && z.owner != team)
        step = std::min(step, std::max(.000001, (10 - z.progress[team]) / std::max(1, counts[i][team])));
    }
    for (size_t i = 0; i < count; ++i) {
      auto &z = zones[i];
      if (z.owner >= 0) {
        z.credit += step;
        if (z.credit + .000001 >= 10) {
          scores[z.owner] = std::min(200, scores[z.owner] + 1);
          z.credit = std::max(0., z.credit - 10);
        }
      }
      if (z.contested)
        continue;
      int team = presence[i][0] ? 0 : presence[i][1] ? 1 : -1;
      if (team < 0 || z.owner == team)
        continue;
      z.progress[team] += step * std::max(1, counts[i][team]);
      if (z.progress[team] + .000001 >= 10) {
        z.owner = team;
        z.progress = {};
        z.credit = 0;
      }
    }
    remaining -= step;
    decide();
  }
}
} // namespace cqauthority
