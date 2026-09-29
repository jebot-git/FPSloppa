# Capture readiness and low-energy escapes

This experiment is confined to `experimental/st-raindance`; ST remains excluded
from release. Shared movement physics, weapon damage and chaser accuracy are
unchanged.

Light attackers now evaluate useful entry speed, predicted remaining fuel and
homeward alignment before committing to a contested stand approach. The working
threshold is 14 m/s (50.4 km/h) and 38% energy at the end of the estimated entry.
Launch-hill selection penalizes insufficient reserves. Preparation uses normal
recharge and ski/jet controls; it expires after 45 seconds, or two unsuitable
run-ups, into a 24-second support interval. An already airborne crossing is not
reversed because its fuel falls during the burn. Dropped-flag recovery remains
an immediate opportunity.

Medium and Heavy bots favour support unless alone near an apparently undefended
stand, or within handoff range of a healthy, charged, faster Light teammate
ahead toward home with clear line of sight. Enemy pressure uses ordinary
perception and team observations, not hidden enemy positions. Automatic flag
touch rules are unchanged, so incidental pickups remain possible.

The entry controller now requests forward acceleration when it has lift and
fuel to spare. Energy weapons and optional equipment targeting do not consume a
prepared flag runner's escape reserve. This does not guarantee the forecast:
terrain contact, heading correction and enemy hits can still change an entry.

After pickup, energy below 40% activates a recharge escape until 65% returns.
Route selection favours clear descending exits aligned with existing velocity
and penalizes early climbs/reversals. Low energy no longer disables all direct
flag exits. Ordinary downhill ski inputs gain speed while the pack recharges;
optional airborne acceleration burns, disc jumps and rearward fighting yield
to that travel. Necessary obstacle, turn and landing jets remain available.

## Original-game speed estimate

The [1999 Raindance capper recording](https://www.youtube.com/watch?v=3vi7vkBsz1U&t=148s)
provides a rough initial outbound approach around 2:28–3:10. Identifying the
inventory departure and the opposite flag approach gives approximately 40–45
seconds. The stock mission's flag coordinates are `(-221.812, 21.7952, 38.7137)`
and `(-379.16, 640.783, 52.8173)`, about 639 m apart horizontally. The inventory
departure is offset from the stand, so this is only approximate calibration.

That corresponds to roughly 51–58 km/h of direct base-to-base progress. Allowing
an assumed 20–40% extra distance for the visibly winding terrain route suggests
**about 60–80 km/h actual travel, with 70 km/h as a provisional baseline**.
The route-length allowance is an estimate, not a reconstructed world-space
trajectory. This is one sampled approach, not a measured average across entire
matches or across the supplied playlists, and does not establish peak speed.
The 640×360 footage has no usable numerical velocity readout in the inspected
frames. Stonehenge's inspected footage mainly shows local fighting and cannot
support an independent capper-speed average.

For distinction, telemetry from FPSloppa's recorded seed-9301 bot matches gives
attack/carry sample means of 34.82/36.37 km/h on Stonehenge and 42.27/38.81 km/h
on Raindance. Those are measured bot speeds, not the original-game baseline.

## Validation and live tests

- 20 capture-policy assertions cover speed/fuel/alignment, preparation timeout,
  airborne commitment, both heavier armour classes, viable/invalid receivers,
  lone grabs and dropped-flag recovery.
- 38 existing adaptive-tactics assertions pass.
- Six recharge assertions pass. A real-physics carrier starting at 5 energy
  travels 29.17 m downhill in three seconds, reaches 69.61 km/h, recharges above
  37 energy and issues no jet input. This is a controlled slope, not a match mean.
- All four recorded carrier escapes pass the existing 100 m separation and
  maximum-stall checks: Raindance 8.73/12.53 s, Stonehenge 23.67/11.08 s.
- Four recorded entry hills were replayed before/after the forward-thrust
  correction. Final pickup speeds range from 39.6 to 56.4 km/h; two steep red
  approaches still arrive with only 8–11 energy. These are diagnostic results,
  explicitly not proof that all admitted approaches satisfy the readiness target.

The first live 8v8 Stonehenge run (seed 9417, initial readiness policy) finished
**0–0 at the required 600-second cutoff**, with 13 pickups and 13 drops. Median
carry duration before death was 5.03 seconds. It made 22 prepared launches,
rejected 16 unready launches and switched to support after five preparation
timeouts and six unsuitable-run-up decisions. It did not demonstrate improved
capture reliability. This run predates the forward-thrust correction and the
low-energy escape policy.

The revised 8v8 run uses the same seed, a Vulkan spectator, video recording,
20-minute/five-capture limits and both existing 600-second inactivity gates.
It completed under `test-results/st-readiness/live-stonehenge-9417-recharge`
at 1,200 seconds, Red 1–0 Blue, with the first capture at 291.22 seconds.
There were 18 pickups, 16 drops and 11 returns. This single run does not
establish a reliable capture rate and predates the subsequent ski-safety and
slope-launch input changes. Viewer attachment reserves a seventeenth
seat so that all sixteen bots remain in the match. Headless batch team counts
are unaffected.

Evidence is under `test-results/st-readiness`. An initial sandbox networking
failure and an interrupted 7v8 spectator-capacity startup are retained there
and excluded from gameplay results. `sources-pilot.tar.gz` and
`sources-recharge.tar.gz` preserve the relevant executable scripts; each live
folder also contains launch options, source hashes, logs and telemetry.
