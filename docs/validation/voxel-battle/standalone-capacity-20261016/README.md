# Standalone C++ CQ server capacity — 16 October 2026

All four synthetic capacity cases passed on the deployment VPS (12 logical AMD EPYC-Milan CPUs). Each used 120 measured seconds after eight seconds of warm-up, the current cooked jungle map, real ENet loopback clients, and all four current T1 classes. The live Godot-hosted service stayed active with the same PID, start time and zero restarts; no deployment or live configuration changes were made.

| Players | Fixed tick | Achieved Hz | Mean tick ms | p95 ms | p99 ms | Maximum ms | CPU, % of one core | Peak RSS MiB |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 30 | 30.000 | 1.63 | 2.49 | 3.07 | 4.69 | 13.7 | 324.2 |
| 64 | 60 | 60.000 | 1.50 | 2.22 | 2.79 | 3.96 | 18.8 | 324.4 |
| 128 | 30 | 29.999 | 2.98 | 5.30 | 6.78 | 9.32 | 32.9 | 368.9 |
| 128 | 60 | 59.997 | 2.58 | 4.37 | 5.94 | 8.65 | 40.8 | 383.3 |

At 128 players/60 Hz, the largest measured simulation callback was 8.65 ms against a 16.67 ms budget. Actual callback start intervals still show scheduling jitter: p95 18.75 ms, maximum 39.43 ms. Sustained simulation rate was 59.997 Hz. These are separate measurements; spare simulation CPU time does not guarantee perfectly periodic delivery.

| Players / Hz | Half-native mean / p95 ms | Standalone mean / p95 ms | Observed mean reduction |
| --- | ---: | ---: | ---: |
| 64 / 30 | 6.98 / 14.79 | 1.63 / 2.49 | 76.7% |
| 64 / 60 | 4.41 / 9.40 | 1.50 / 2.22 | 65.9% |
| 128 / 30 | 14.77 / 35.07 | 2.98 / 5.30 | 79.8% |
| 128 / 60 | No archived baseline | 2.58 / 4.37 | — |

The historical measurements ran on this same VPS on 14–15 October. Baseline paths are recorded in `comparison.json`. The 128/30 comparison uses the older **all-class reload** run, which fired 5,561 shots. The later `128-final` run measured 12.09/17.84 ms but fired only 527 medic shots and zero shots from the other classes, so it is unsuitable as the headline combat baseline.

This is a historical comparison, not a controlled engine-only A/B benchmark. The old server used Godot Jolt CharacterBody movement, GDScript orchestration and Godot RPC; the new server uses the standalone Jolt adapter, direct ENet framing and the current cooked world/spawn/vehicle configuration. Current medic T1 is an SMG (weapon 3), whereas the historical fixture requested the then-shared carbine (weapon 4). Peer IDs, trajectories, handedness assignments, combat outcomes and shot totals also differ. The observed improvement cannot all be attributed to removing GDScript alone. Old CPU samples include post-bind warm-up; new CPU samples approximate the measured window at 0.5-second intervals. RSS includes startup in both.

| Players / Hz | Minimum peer snapshot Hz | Worst measured snapshot gap ms | Accepted measured inputs | Shots | Outbound payload Mbit/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| 64 / 30 | 20.000 | 71.1 | 230,312 | 4,020 | 129.1 |
| 64 / 60 | 20.000 | 54.5 | 460,697 | 3,965 | 131.7 |
| 128 / 30 | 19.978 | 105.0 | 460,524 | 7,465 | 464.4 |
| 128 / 60 | 19.984 | 110.5 | 921,218 | 7,501 | 470.5 |

All runs admitted their full requested population, fired every class's weapon, decoded valid snapshots and completed without disconnects, input rejections, input queue overflow or projectile pool overflow. Socket monitoring found zero additional UDP receive drops during the sampled measurement windows. Admission caused some server socket drops before warm-up finished; reliable handshakes recovered. Full counter traces are in `sockets.jsonl.gz` and measurement-window deltas in `socket-summary.json`.

At 128 players, about **470 Mbit/s of application payload** was fanned out at 20 snapshots/s, versus about 132 Mbit/s at 64 players. This excludes UDP/IP/ENet overhead. The full-world broadcast grows approximately quadratically with player population, so interest management, delta snapshots and per-client relevance are stronger next candidates than more simulation CPU optimisation. This test establishes local sustained simulation/delivery under this workload; it does not establish Internet bandwidth, latency or packet-loss capacity.

The workload sends tracked head, controller, weapon and offhand transforms at the configured tick rate; uses a ten-second physical magazine/rack reload cycle; moves, crouches, goes prone and fires; activates scout/medic utility actions periodically; and uses normal ammunition/damage without stress invulnerability or infinite reserves. There are no rendering clients, AI bots, custom-avatar transfers or voice traffic. Player deaths/staging can reduce active movement later in a run. Test profiles are ephemeral and profile saves are disabled. Destruction and adaptive tick are disabled to match the historical fixed-rate fixture, so collapse bursts and 60→30 transitions are not exercised. Production defaults remain 64 players, adaptive 60/30 Hz and destruction enabled.

The first 64/30 attempt incorrectly placed all 64 simulated clients behind one ENet UDP socket. The VPS clamps requested buffers to `rmem_max=212992`, causing severe receive overflow and snapshot gaps despite fast ticks. Those timings are excluded. The final matrix uses four clients per process/socket, matching the historical process grouping, without changing kernel limits or the server. The discarded report and socket evidence are retained in `discarded-single-socket/`.

Validation also passed 105 standalone unit checks, explicit rejection of public-bind and invalid-player benchmark overrides, a ten-second local 64-player tracked smoke, and an eight-second local four-player tracked integration smoke with normal adaptive/destruction defaults (`default-config-smoke.json`, Intel N95; not part of VPS comparisons).

Reproduce using `tools/standalone_server/cook_benchmark_inputs.gd`, `tools/standalone_server/run_matrix.py` and `tools/standalone_server/compare_matrix.py`. The explicit 128-player override requires a loopback bind; normal server capacity remains capped at 64. Source/binary provenance is recorded in `source.json`, `server-build.json` and `benchmark-sha256-sharded.json`. Individual case directories contain server/client reports, logs, configuration and process resource samples. `comparison.csv` and `comparison.json` contain the combined data and phase breakdowns.
