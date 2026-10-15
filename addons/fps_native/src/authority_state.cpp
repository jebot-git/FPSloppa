#include "authority_core.h"
namespace cqauthority {
// Out-of-line construction prevents the optimiser expanding 128 x 32 tracked
// pose initialisers inside every Core constructor/join. No per-tick allocation.
Command::Command() = default;
Player::Player() = default;
} // namespace cqauthority
