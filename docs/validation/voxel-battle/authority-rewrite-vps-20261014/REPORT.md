# Full VPS authority comparison — 14 October 2026

All ten two-minute cases passed on the 12-vCPU / 24-GB VPS. The production CQ process was suspended for the comparison and automatically resumed afterward. The original PID (1600382), installed release (`20261014-jolt-6abfbf5`) and zero-restart count were verified. A public UDP 7777 client probe then connected, stayed admitted for ten seconds and received 231 snapshot packets without rejection.

The suspension lasted approximately 34.0 minutes. No release, unit, server configuration or kernel network setting was changed. A detached guardian and supervisor cleanup guarded restoration; four local tests exercised PID-identity checks, resume behavior and test-process-group cleanup.

## Conditions

- One identical prepared game binary/PCK/native library, with cumulative switches added in the documented order.
- Real ENet clients, scripted movement/shooting inputs and synthetic tracked head/hands, cached-asset admission, no AI and no rendering.
- 120 measured seconds per case, 32 and 64 separate client processes; client fleets ran on VPS loopback, port 27879.
- Existing Jolt world, CS movement and selected native snapshot preparation/encoder in every case, including the reference.
- Identical fine attribution enabled in every case. These absolute timings should not be compared directly with older runs using coarser instrumentation.
- All clients completed successfully; no rejection, transport-loss or attribution errors. All snapshot queues reported zero busy events.

## Physics callback and tick rate

Milliseconds per callback. The 32-player cases all sustained approximately 30 Hz. None of these profiled 64-player cases sustained 30 Hz.

| Stage | Players | Achieved Hz | Callback p50 | Callback p95 |
| --- | ---: | ---: | ---: | ---: |
| reference | 32 | 30.004 | 14.066 | 20.087 |
| reference | 64 | 28.348 | 28.336 | 44.506 |
| player-state | 32 | 30.005 | 14.069 | 19.624 |
| player-state | 64 | 28.120 | 30.220 | 43.520 |
| input-state | 32 | 30.003 | 14.595 | 19.960 |
| input-state | 64 | 27.646 | 31.387 | 45.995 |
| fanout | 32 | 30.004 | 14.170 | 19.493 |
| fanout | 64 | 27.681 | 30.032 | 49.543 |
| buffers | 32 | 30.005 | 13.767 | 18.924 |
| buffers | 64 | 28.903 | 27.389 | 41.270 |

The cumulative immutable-buffer stage was the strongest observed prototype at 64 players: **1.96% higher tick rate**, **3.34% lower median callback time** and **7.27% lower p95** than the reference. This was one sequential pass per case, not a repeated confidence-tested A/B study. The improvement is modest, and the isolated bookkeeping, input and fanout stages did not improve 64-player throughput.

## 64-player category breakdown

Mean milliseconds per simulation tick. The player bookkeeping group sums disjoint `player.*` self-times plus player-loop and roster-binding self-time. It excludes measured movement/physics children. Input and snapshot preparation use their inclusive totals because their child scopes are not separately added here. These means must not be added to callback percentiles. Idle input work is carried into the next attributed tick.

| Stage | Player bookkeeping | Input | Movement queries | Snapshot prep | Transport | Match/class |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| reference | 7.488 | 3.887 | 3.989 | 3.244 | 2.705 | 2.107 |
| player-state | 7.781 | 3.905 | 4.035 | 3.276 | 2.843 | 2.148 |
| input-state | 7.944 | 4.033 | 4.065 | 3.285 | 2.897 | 2.167 |
| fanout | 7.888 | 3.985 | 3.971 | 3.290 | 2.917 | 2.084 |
| buffers | 7.149 | 3.942 | 3.831 | 3.188 | 2.677 | 2.013 |

The primary remaining cost is authority-side gameplay/state work. These partial native ports retained the legacy Dictionary/API migration boundary and did not remove enough work. That boundary is a plausible limitation, rather than a proven function-level cause; larger native-owned state operations or avoiding repeated work should be tested before expanding scalar wrapper ports. The encoder queue itself did not back up.

## Snapshot handoff

| Stage | Players | Main preparation p50 | Encoder p50 |
| --- | ---: | ---: | ---: |
| reference | 32 | 2.553 | 1.653 |
| reference | 64 | 4.639 | 2.799 |
| player-state | 32 | 2.330 | 1.546 |
| player-state | 64 | 4.772 | 2.808 |
| input-state | 32 | 2.520 | 1.605 |
| input-state | 64 | 4.769 | 2.852 |
| fanout | 32 | 2.402 | 1.590 |
| fanout | 64 | 4.751 | 2.869 |
| buffers | 32 | 2.287 | 2.322 |
| buffers | 64 | 4.572 | 3.531 |

The buffer stage executed 2,422 native captures at 32 players and 2,407 at 64, with zero fallback captures. It moved work toward the encoder: the 64-player encoder median increased from 2.799 to 3.531 ms. Main snapshot-preparation median only fell from 4.639 to 4.572 ms relative to the reference, so the whole callback improvement cannot confidently be assigned to freezing alone.

## Whole-case process samples

CPU percentages use 100% for one vCPU and include authority startup, admission and the client-fleet tail. They exclude the load-generator processes. RSS is authority resident memory; UDP drops are the cumulative kernel counter for its owned sockets, not an input-only loss rate or a disconnect count.

| Stage | Players | Main CPU p50 | All threads CPU p50 | Peak RSS MiB | UDP drops |
| --- | ---: | ---: | ---: | ---: | ---: |
| reference | 32 | 57.0% | 67.0% | 515.9 | 325 |
| reference | 64 | 99.0% | 111.0% | 514.5 | 6778 |
| player-state | 32 | 56.0% | 65.0% | 515.1 | 240 |
| player-state | 64 | 99.0% | 112.0% | 514.5 | 5604 |
| input-state | 32 | 57.0% | 67.0% | 515.4 | 321 |
| input-state | 64 | 99.0% | 112.0% | 512.9 | 10495 |
| fanout | 32 | 57.0% | 67.0% | 515.3 | 352 |
| fanout | 64 | 99.0% | 112.0% | 513.8 | 9383 |
| buffers | 32 | 55.0% | 67.0% | 516.3 | 77 |
| buffers | 64 | 98.0% | 112.0% | 517.0 | 6172 |

At 64 clients the main thread stayed near one fully used vCPU, while the authority used approximately 1.1 vCPUs across all threads. Authority memory stayed around 0.5 GiB. More idle cores do not directly resolve this serial path.

The runtime requested a 4,194,304-byte receive buffer, but `SO_RCVBUF` reported 425,984 bytes both before and after the request; the host `net.core.rmem_max` is 212,992. This cap remained unchanged for fair comparisons. It is a separate network test target; these measurements do not establish that raising it would fix the tick-rate shortfall.

## Decision and reuse

Keep all new authority switches **off by default**. The buffer path is worth an isolated, repeated reference-versus-buffer-only comparison, including an uninstrumented control, before promotion. The other small native ports have not demonstrated a throughput benefit. The unsupported 64-slot setting should remain unsupported.

The [local regression/smoke report](../authority-rewrite-20261014/REPORT.md) records the 23 passed prepared regression stages, 11,665 player/input/motion checks and 1,392 snapshot checks on both handoffs. [Runner documentation](../../../../tools/player_simulation/README.md) covers the switches and optional service suspension.

Full logs and per-thread process samples: `/home/blux/Documents/cq-authority-vps-results-20261014`. Compact category reports, tested bundle manifest, resume receipts and the external health probe are stored beside this report.
