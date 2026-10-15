# VPS capacity experiments — 15 October 2026

The branch was fast-forwarded from `7ac1da7` to `9c3bf11` before testing. Experiments ran **alongside the live service**, sequentially, on the deployment VPS: Ubuntu 24.04, 12 AMD EPYC vCPUs and 24 GB RAM. The test runner never suspended, restarted or repointed the live service. A live-service PID change was observed between the two measured cases; see the final service check below.

## Results

Both corrected cases passed the throughput/delivery/workload gates. **64 players at 60 Hz has callback headroom; 128 at 30 Hz exceeds its callback budget at p95.** Both still show scheduling jitter, so average Hz alone overstates timing consistency.

| Case | Achieved Hz | Callback p50 / p95 / max ms | Budget ms | Physics interval p95 / max ms | Shots | Accepted/offered | Min complete frames |
|---|---:|---:|---:|---:|---:|---:|---:|
| 128, 64/team override | 29.998 | 15.224 / 35.067 / 47.973 | 33.333 | 50.085 / 64.783 | 5,561 | 99.660% | 2,224 |
| 64, experimental 60 Hz | 59.999 | 3.436 / 9.403 / 17.100 | 16.667 | 22.854 / 29.260 | 3,306 | 99.927% | 2,216 |

All requested players were admitted. Both cases recorded zero malformed client frames, unexpected disconnects, native queue overflows and projectile-pool saturation. Minimum inputs offered per peer were 3,601 and 7,201, respectively. All four classes fired, but actual shot counts per player differ: this is a comparison of the observed finite-ammo workloads, not a controlled equal-shot microbenchmark. There were no deaths and only 4/1 damage-counter increments respectively.

| Case | Server CPU, % of one core | Peak server RSS MiB | Approx. fanout payload Mbit/s |
|---|---:|---:|---:|
| 128 / 30 Hz | 55.42 | 442.12 | 375.06 |
| 64 / 60 Hz | 41.49 | 442.31 | 114.47 |

CPU and peak RSS cover the post-bind sample window, including admission, warm-up and measurement; they exclude client-process resource usage and cold map construction. CPU is process CPU, not whole-host utilization.

Mean callback attribution in milliseconds:

| Case | Movement + Jolt | Combat + queries | Frame encoding | CQ mode | AI scan | Residual | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| 128 / 30 Hz | 4.306 | 0.575 | 0.090 | 0.004 | 0.003 | 9.795 | 14.772 |
| 64 / 60 Hz | 2.548 | 0.293 | 0.028 | 0.003 | 0.002 | 1.536 | 4.411 |

Residual is callback minus the native phases: adapter operations, metrics copying, compression, RPC enqueueing and other work inside that callback. It is not an isolated transport measurement, and percentiles cannot be subtracted or added this way. At 128 players it is the largest measured mean component. Native snapshot encoding is small; separately instrument compression and recipient fanout before choosing the next optimization. No AI decisions run for synthetic human peers, so the AI scan figure says nothing about bot cost.

Both cases offer approximately 3,840 inputs/second (128×30 versus 64×60), while player count and broadcast fanout differ. Snapshot publication stays at 20 Hz. The large residual and payload increase make recipient fanout/compression a useful next profiling target; these figures do not identify one specific function as the proven cause.

Full derived figures are in `comparison.json`; original summaries and telemetry remain in the two corresponding result directories.

The pass flag checks population, achieved average Hz, input acceptance, complete-frame delivery, process exits and diagnostics, disconnects and bounded command/projectile queues. **It is not a tail-latency certification.** Callback p95 must separately be compared against the tick budget. Physics callback intervals include scheduling jitter and engine work outside the instrumented callback.

## Workload and limits

Each case has 120 measured seconds after an eight-second warm-up. The authored jungle collision map, Jolt, 11 capture sites, eight vehicle entities and four CQ classes are active. Synthetic tracked head/hands exercise movement, stance, aiming, firing and physical magazine/reload gestures. Normal finite ammunition and damage rules apply; infinite-reserve/invulnerability stress mode is disabled. Fire is deliberately pitched upward. All four classes must record shots to pass the corrected workload gate.

Clients run on loopback in groups of four per process: 32 processes for 128 players, 16 for 64. They compete with the fixture server and live service for VPS CPU. There is no rendered scene, headset, avatar animation/IK cost, WAN traffic, navigation AI, driven vehicle traffic or representative lethal match. Launcher firing is relatively light; inspect per-class counters before treating this as heavy-weapons saturation. This is a two-minute steady-population experiment, not a supported-capacity or soak-test claim.

The payload fanout estimate multiplies shared compressed publication bytes by recipient count and divides by measured wall time. The byte counter also includes publication during warm-up, so the estimate uses measured duration plus eight warm-up seconds. It excludes ENet/UDP overhead and retransmission behavior and does not measure external NIC throughput.

## Authority changes

The original native authority defaults to 30 Hz and enforces 32/team with four eight-member squads. A 128-player attempt with the deployed native library fails admission; its failure logs are retained in `load-20261015-128-ready`. Its last periodic admission count is not a capacity measurement. Source inspection establishes the 32/team cap.

The explicitly approved experiment adds **64/team and 16/squad**, keeping storage bounded at 128. This requires `--team-limit 64` in the isolated runner; production defaults stay 32/team and 8/squad. The 64-player experiment uses those default admission limits.

`FPSAuthority.configure_tick_rate(60)` is an opt-in pre-admission/pre-tick configuration. Movement, gravity, projectiles, vehicles, cooldowns, regeneration, capture and the native clock use the configured time step. The Godot physics rate must match; unsupported rates and changes after admission/ticking are rejected. Both snapshot construction and transport publication remain 20 Hz. Synthetic gestures retain the same wall-time pace at 30 and 60 Hz. Production still defaults to 30 Hz.

The harness now waits for an owned UDP socket before launching clients. The jungle takes roughly 43 seconds to construct on this VPS; the previous one-second startup delay let clients time out before the listener existed. Admission/measurement deadlines start after construction. Early startup failures are not reported as performance results.

## Package and source provenance

The latest installed release at test time was `/home/blux/fpsloppa-cq/releases/20261014-cq-vehicle-respawn`. Both corrected large cases use the same isolated `load-20261015-reload-release` bundle derived from its executable, TwoVoIP library and PCK assets. A VPS-built native library from `9c3bf11` plus the recorded experiment changes, updated fixture scripts and embedded native source replace only registered PCK entries. This is **an experimental derivative of the deployment package**, not an unmodified production-binary benchmark. It is not installed as the live release.

The original PCK's 51 checked embedded source files are not all identical to `9c3bf11`: 47 match, while `authority.cpp`, `authority_gameplay.cpp`, `authority_vr.cpp` and `authority_weapon_geometry.h` differ. `original-source-verification.json` records both sets of hashes. `experimental-source-verification.json` verifies all 51 checked experimental embedded source files against the local working sources. The deployed weapon manifest remains part of the original asset pack; its reload anchors are within the native interaction tolerances exercised here.

`experimental-pack.patch.json` records original/output PCK hashes and every override. Each result directory includes the four-file release SHA-256 manifest, server/client logs, server measurements, post-bind resource samples and gate summary. `working-change.patch` captures the native/fixture/test changes against `9c3bf11`. The native library was built on Ubuntu 24.04 using an unprivileged GCC 13 toolchain and the repository's pinned Godot C++ bindings; no system packages or production libraries were replaced. A local Ubuntu 26.04 build was rejected for VPS use because of its newer GLIBC dependency.

## Diagnostics retained

`load-20261015-128-final` is the first overridden 128-player run. It held 30 Hz, but recorded only 527 shots, all from medics. It is **superseded for workload comparison**. The old fixture used generic magazine anchors and omitted the separate magazine trigger introduced by current CQ reload mechanics. The corrected fixture uses deployed manifest anchors, separate magazine-trigger/rack-grip gestures, and interpolated motion at 60 Hz. Both final comparison cases use this correction and require firing from all four classes.

`load-20261015-4-60-smoke` is an earlier five-second adapter smoke. It confirms real Godot/Jolt/native 60 Hz operation but is not a capacity result.

Standalone native tests passed **259,479 checks**, including 30/60 Hz native clock, gravity and cooldown duration, 20 Hz snapshot cadence, unchanged default limits, bounded 128-player admission and eight 16-member experimental squads. Python tool tests verify owned-socket readiness and PCK replacement/resource preservation, hashes and rejection of unregistered paths. The client/native source weapon-anchor check also passed. Real release-pack runs exercise GDScript parsing, the adapter and Jolt integration; this is not a rerun of every historical gameplay/rendering suite.

## Reproduction

Run sequentially against a prepared isolated bundle; never substitute the live release directory as output:

```sh
python3 tools/frontier_vps/run_capacity_case.py --bundle /isolated/load-20261015-reload-release --output /new/128-30 --players 128 --hz 30 --team-limit 64 --seconds 120 --port 27959
python3 tools/frontier_vps/run_capacity_case.py --bundle /isolated/load-20261015-reload-release --output /new/64-60 --players 64 --hz 60 --team-limit 32 --seconds 120 --port 27969
python3 -m unittest discover -s tools/frontier_vps -p test_capacity_tools.py -v
```

## Final service check

The release symlink and live executable still point to `20261014-cq-vehicle-respawn`. The service is active/running with `NRestarts=0`, and no fixture processes remain. **The live PID was not preserved:** it changed from 1637106 to 1652607, whose recorded start is 06:10:23 UTC. The cause is unknown; the runner contains no service-control operations.

The 128-player post-bind samples span 06:07:53–06:10:05 UTC and the 64-player samples 06:11:24–06:13:34 UTC. Thus the recorded new start falls **between** these measurement windows. Live-service co-load may differ across cases; this was not a fully controlled host comparison. No experimental bundle was installed into production. See `load-20261015-final-health.json` and the environment receipt. The accessible journal query yielded no service-manager events, so it does not establish a restart cause.
