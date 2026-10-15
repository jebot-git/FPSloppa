#pragma once
#include <algorithm>
#include <array>
#include <cmath>

namespace cqauthority {
// Wall-time windows, bounded samples, and asymmetric pressure/recovery thresholds.
// The host commits a decision only between engine physics frames.
class TickGovernor {
  std::array<double, 512> samples_{};
  size_t count_ = 0;
  double wall_ = 0, simulated_ = 0, residence_ = 0;
  double fast_wall_ = 0, fast_simulated_ = 0;
  int fast_count_ = 0, fast_late_ = 0;
  int pressure_ = 0, recovery_ = 0;
public:
  bool enabled = false;
  int hz = 60, pending = 60, transitions = 0, fallbacks = 0, recoveries = 0;
  double p95_us = 0, simulation_ratio = 1;
  void enable() { *this = TickGovernor{}; enabled = true; }
  bool observe(double callback_us, double wall_seconds) {
    if (!enabled || !std::isfinite(callback_us) || callback_us < 0 ||
        !std::isfinite(wall_seconds) || wall_seconds <= 0) return false;
    wall_ += wall_seconds; residence_ += wall_seconds;
    simulated_ += 1. / hz;
    if (hz == 60) {
      fast_wall_ += wall_seconds; fast_simulated_ += 1. / hz; ++fast_count_;
      fast_late_ += callback_us > 1000000. / 60;
      if (fast_wall_ >= .5 && fast_count_ >= 8) {
        if (fast_simulated_ / fast_wall_ < .85 || fast_late_ * 4 >= fast_count_) pending = 30;
        fast_wall_ = fast_simulated_ = 0; fast_count_ = fast_late_ = 0;
      }
    }
    if (count_ < samples_.size()) samples_[count_++] = callback_us;
    if (wall_ < 2. || count_ < 16) return true;
    std::sort(samples_.begin(), samples_.begin() + count_);
    p95_us = samples_[size_t(std::ceil(count_ * .95)) - 1];
    simulation_ratio = simulated_ / wall_;
    if (hz == 60) {
      pressure_ = p95_us > 15000 || simulation_ratio < .92 ? pressure_ + 1 : 0;
      if (pressure_ >= 2) pending = 30;
    } else {
      recovery_ = p95_us < 11000 && simulation_ratio >= .98 ? recovery_ + 1 : 0;
      if (recovery_ >= 10 && residence_ >= 30.) pending = 60;
    }
    wall_ = simulated_ = 0; count_ = 0;
    return true;
  }
  bool commit(int rate) {
    if (!enabled || rate != pending || rate == hz) return false;
    hz = rate; ++transitions;
    if (hz == 30) ++fallbacks; else ++recoveries;
    wall_ = simulated_ = residence_ = fast_wall_ = fast_simulated_ = 0;
    count_ = 0; pressure_ = recovery_ = fast_count_ = fast_late_ = 0;
    return true;
  }
};
}
