# ST capture reliability — 28 September 2026

Bot reliability takes priority over additional parity features. The Commander/PDA
is low priority. The current acceptance gate for local 6v6 tests is a first
capture by either team within ten **game** minutes, independent of test speed.

`tools/tribes/live_match.gd` enforces this gate at each physics step. A scoreless
test stops at 600 seconds with `termination_reason: no_capture_600s` and exit
code 2. Final samples, movement totals and flag-event timestamps are saved before
disconnecting the spectator. A first capture at the deadline counts. A capture
after it does not. Once a timely capture occurs, the ordinary requested duration
and match limits apply; this is not a rolling ten-minute scoring timer.

The previous `live-parity456-final` preview failed this gate: its first scoring
sample was at 972.77 seconds. Its verified server and Vulkan viewer were stopped.
The first ten minutes had several flag pickups, but no completed return.

The bot changes address two concrete losses of time on the flag deck. Final
approach now crosses the flag using the existing swept-touch rules rather than
braking to stand on it. Public flag state changes trigger planning on the next
physics tick, so a new carrier immediately abandons its old tower staging or
recovery target. Downhill escape routing considers incoming velocity when
choosing an exit instead of always preferring a short, sharp reversal.

Heavy bots supporting a push now acquire physically visible hostile turrets at
their firing position without waiting for a teammate's laser. Previously that
job had no fixture target, unlike the direct siege job. Mortars also wait for
their aim to converge within 0.012 radians of the ballistic solution. The generic
close-combat threshold of 0.12 radians could fire far short of the target; a
real-projectile regression reproduced the miss and now damages the turret.
World cover and friendly ownership still prevent acquisition.

The next contested seed also reproduced Godot's walking-mesh corridor error
from a low terrain island while chasing a dropped flag. Long ST trips now query
the terrain graph first, retaining the walking mesh as a fallback. This avoids
the failing preliminary walking query when a valid ski route already exists.
Both recorded positions are covered by full-planner regression cases.

Movement, health, energy, weapon damage, defenders and capture rules are unchanged.
Physical deck tests exercise eight approaches on both bases and ensure station
stopping and home-flag requirements are preserved. Contested runs are necessary
in addition to those fixtures; an unopposed capture alone does not establish
competitive bot reliability.

## Validation

203 focused checks pass, including eight physical flag-deck approaches, immediate
planning, the two recorded terrain-query failures, real mortar impact, role
regressions and cutoff boundaries. All sixteen integrated spawn-to-capture cases
pass in 141.92–195.48 seconds.

| Test | First capture | Observed result | Source scope |
|---|---:|---|---|
| 9286, ten minutes | 3:45.73 | Red 1–0 Blue | Flag movement changes; before artillery fixes |
| 9288, ten minutes | 7:00.85 | Red 1–0 Blue | Artillery fixes; exposed walking-mesh errors |
| 9288 repeated, ten minutes | 7:00.85 | Red 1–0 Blue | Final bot source; zero engine/script errors |
| 9287, Vulkan live preview | 9:20.90 | Red 1–0 Blue at validation | Before terrain-query reorder; continues to its duration limit |

The final repeat preserves the earlier seed's capture timing while avoiding the
walking-mesh errors. These runs pass the first-capture gate; the uneven timing
and lack of Blue captures still leave carrier survival and team coordination
unresolved. A flag pickup or a passing unopposed route is not counted as a match
capture. See the [validation receipt](validation/st-capture-reliability-2026-09-28.json)
for source boundaries, logs, hashes, final scores and the live snapshot.
