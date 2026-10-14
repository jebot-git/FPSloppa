# Native backend prototype validation — October 13, 2026

The portable C++ backend is implemented and tested, with GDScript reference paths retained. It improves CPU/encoding work but does **not** establish sustained 64-player support. The production VPS service remains on the previous 32-slot release; tests used an isolated candidate on loopback UDP 7779. CoreCU remains stopped.

Implementation/build/reuse guide: [NATIVE-CQ-BACKEND.md](../../../NATIVE-CQ-BACKEND.md).

## Correctness and packaging

The final differential suite passed **11,468 checks**: anatomical swept volumes, cover axes, head classification, combined rewind and typed history, ordered candidate filtering at 1/2/4 workers, tracked-pose validation, room-scale math, immutable async snapshots, cache/record compatibility, malformed-job rejection, bounded queue ownership and reset/shutdown.

Existing suites also passed:

- Native codec: 15,248 checks, no failures. Its deliberately malformed UTF-8 cases still emit parser diagnostics.
- Native network packing: 6,335 checks, no failures.
- Projectile broadphase: 12,000 swept queries, 2,963 exact hits, no missed hits; boundary, overflow, extreme/nonfinite and stable-order checks pass.
- Player hitboxes, lag compensation and physical room-scale alignment/cover/weapon rebasing.
- Frontier movement/capture/scoring integration with native paths and with the reference switches. Known fixture exit diagnostics remain 21 ObjectDB instances / 8 resources.
- A final packaged 32-client local smoke test completed with all 32 clients and an active native/async profile. This is a short functional smoke test, not another two-minute VPS benchmark.

The legacy room-scale test referenced a removed full-body tracker. That obsolete setup expression was removed; all its remaining physical tests pass. The failed initial broadphase regression identified missing native overflow metadata; that was corrected and the full sweep suite rerun.

The Ubuntu 22.04 server-native build and release package passed library/source receipt and GLIBC compatibility checks. Python tooling compiles and `git diff --check` is clean. Test logs, final-package smoke logs, raw VPS reports and client exits are saved here.

## Local native kernels and worker count

For 3,000 randomized swept anatomical queries, direct native math took **1.705 ms total** versus **24.894 ms** in the GDScript reference (about 14.6× for this kernel). This is not a whole-server speedup.

The small 64-observer range batch took approximately 31 µs serial, 39 µs with two workers and 46 µs with four. The default therefore keeps this workload serial; larger batches can use workers above the configured threshold.

A separate 64-avatar / 24-projectile snapshot benchmark, with UT99 head/hand poses and body-tracking data removed, measured:

| Compute workers | Encoder median ms | Encoder p95 ms |
|---:|---:|---:|
| 1 | 0.429 | 0.655 |
| 2 | 0.426 | 0.572 |
| 4 | 0.376 | 0.514 |
| 6 | 0.374 | 0.529 |

Four remains the default: six did not improve p95. These are local CPU results; VPS tuning still needs controlled worker-count runs. The encoder itself is a separate thread even with one compute worker.

## Two-minute VPS live 32-client result

All 32 independent clients completed. Full population was maintained for **120.02 wall seconds**, achieving **30.05 Hz** at a 30-Hz target. Native backend and asynchronous snapshots were active; the encoder reported no busy-queue skips.

| Category | Median ms | p95 ms | p99 ms |
|---|---:|---:|---:|
| Simulation tick | 16.679 | 20.283 | 21.514 |
| Snapshot preparation/submission | 3.106 | 4.074 | 4.335 |
| Snapshot transport/fanout | 1.729 | 2.433 | 2.832 |
| Encoder worker elapsed work | 0.954 | 1.331 | 1.680 |
| History recording | 0.195 | 0.258 | 0.293 |
| Whole authority physics callback | 20.225 | 25.745 | 27.582 |
| Engine physics monitor | 27.946 | 31.145 | 52.607 |

Snapshot delivery age was **33.3 ms median/p95**, maximum 66.7 ms, measured in authoritative simulation clock. It excludes network latency. The earlier 32-player deployment run had callback p95 29.727 ms and engine p95 36.383 ms. The candidate reduces those to 25.745 and 31.145 ms, but these separate runs are not a strict replay-controlled A/B.

Authority sampling captured 21 OS threads: the original engine threads plus encoder/compute workers. In its captured 32-player window, main-thread CPU averaged about 69.9%, versus 76.7% across all authority threads. That window also includes population teardown, so it is not a full-population CPU average. The workers execute useful work, but the main thread remains dominant. Owned socket receive drops reached 1,201; the receive-drop problem is not eliminated.

## Live 64-client attempt

The candidate admitted **58 distinct players**, with peak admitted concurrency **56**. Only **29/64** clients completed. Kernel receive drops reached **63,557** in authority sampling. It never held all 64 players, so the full-population profiler did not start and there is no valid live 64-player frame-time result.

This improves admissions/completions over the earlier attempt (51 distinct, peak 49, 16 completions) without solving the problem. Different arrival/interactions and load are involved; do not interpret the difference as a proven 64-player reliability gain. Increasing timeouts or enabling more compute workers is not sufficient evidence of a fix.

## Consecutive isolated 64-player comparison

Both cases used the same full map, seed, 64 scripted actors, synthetic tracked transforms, initial firing, 120 simulated seconds plus three-second warmup, and synchronous snapshot packing. They ran consecutively on the same VPS, native first and reference second. The reference case disabled native math/codec/packing. No live networking, AI or rendering was involved.

| Category | Reference median / p95 ms | Native median / p95 ms |
|---|---:|---:|
| Simulation tick | 31.332 / 41.904 | 29.239 / 36.771 |
| Snapshot construction | 3.419 / 4.752 | 3.350 / 4.685 |
| Snapshot encoding | 6.743 / 10.059 | 2.683 / 3.775 |
| Achieved frequency | **22.86 Hz** | **26.08 Hz** |
| Wall time, including warmup | 161.44 s | 141.50 s |

The native case has approximately **14.1% more throughput** and **60.2% less median encoding time**. Both remain below 30 Hz; native simulation p95 alone exceeds the 33.33-ms budget. Consecutive shared-VPS runs can differ through host contention; the codec reduction is directly measured, while the overall improvement should be confirmed with repeated/alternating runs. The earlier isolated reference achieved 24.40 Hz, demonstrating run-to-run variability.

Native peak RSS was about 611.5 MiB. Estimated target-clock snapshot fanout remains about 59.8 Mbps; this is a reserve/fanout estimate, not a wire capture.

## Limits and next work

- Synthetic clients ran on VPS loopback and share host resources. This is not a WAN stability test.
- Ammo reserve refill does not perform physical magazine reload; firing is mostly the initial magazine, followed by movement/pose workload. The inherited stress flag's `infinite_ammo_invulnerable` name overstates this behavior: firing clears invulnerability, and bleedouts occur. No sustained-combat claim is made.
- Engine monitor timings overlap callbacks and catch-up batches. Do not sum percentile categories.
- Async encoding shifts work away from the authority and adds delivery age; the isolated synchronous probe does not measure that pipeline.
- The two-minute live candidate predates the final pose-validator/independent fallback switch and malformed-job hardening. Those additions passed the expanded differential suite and final packaged connected-client smoke. Their effect on full VPS load has not been separately established.
- CPU/thread sampling covered part of the 32-player window and the 64 admission attempt; it cannot describe a sustained full-population 64-player CPU distribution.

The remaining priorities are profiling movement/world queries and input delivery separately, measuring ENet queue/service and actual receive buffers, then considering native movement orchestration or a supported parallel query phase. Keep 64 explicitly unsupported until all 64 are admitted and the full 15-minute combat/utility/vehicle/voice/skin-transfer acceptance gate passes. No live service swap, physics backend change or socket tuning was performed in this task.
