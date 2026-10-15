# Authority rewrite prototype — 14 October 2026

The ordered player-state, input, fanout and immutable-buffer experiments are implemented and packaged. All four switches remain off by default. The live VPS service was not changed.

## Verification

- The prepared offline deployment passed **23 regression stages**, including the three native collision CTests, complete CQ gameplay checks and three real server/client test pairs.
- **11,665 player/input/reload-motion differential checks** passed.
- **1,392 snapshot checks** passed through both the existing and immutable handoffs, including exact bytes after producer mutation, typed-container fallback, owner-thread guards and bounded queuing.
- All **ten local smoke cases** passed: five cumulative stages at 32 and 64 separate ENet client processes. Each measured window was **10 seconds**, with a five-second client lifetime allowance. Every client was admitted, received snapshots and completed successfully; no attribution errors or async queue-busy events occurred.
- Immutable capture actually executed: 223 accepted captures at 32 players and 332 at 64, with zero fallback captures in those cases.
- The portable Linux library matches its native-source receipt and the GLIBC <= 2.35 requirement.

These are readiness smoke tests, not sustained VPS performance validation. The runner defaults to 120 measured seconds per case. Short-window achieved-Hz values can exceed 30 during catch-up; they do not indicate a higher configured tick rate. Spawn/combat transients and run-to-run variation prevent attributing the whole callback difference to a single changed kernel.

## Full-scene smoke timings

Milliseconds; callback percentiles are per physics callback, snapshot preparation is per snapshot. Categories overlap. The reference already uses the selected native snapshot preparation/encoder.

| Stage | Players | Callback p50 | Callback p95 | Snapshot prep p50 |
| --- | ---: | ---: | ---: | ---: |
| reference | 32 | 11.577 | 19.989 | 1.666 |
| reference | 64 | 26.585 | 38.688 | 2.945 |
| player-state | 32 | 10.906 | 19.643 | 1.608 |
| player-state | 64 | 27.291 | 38.776 | 2.973 |
| input-state | 32 | 11.050 | 19.357 | 1.600 |
| input-state | 64 | 18.879 | 34.091 | 2.394 |
| fanout | 32 | 10.202 | 19.079 | 1.609 |
| fanout | 64 | 18.916 | 31.598 | 2.396 |
| buffers | 32 | 11.212 | 19.231 | 1.641 |
| buffers | 64 | 19.856 | 36.157 | 2.710 |

## Isolated kernels

The bookkeeping benchmark reuses existing actor objects on both paths; it does not charge reference-only actor allocation. Native timings include roster reconciliation and the normal script/native boundary. These are fixture measurements, not end-to-end forecasts.

| Kernel | Players | Reference p50 | Native p50 |
| --- | ---: | ---: | ---: |
| bookkeeping | 32 | 0.068 | 0.072 |
| bookkeeping | 64 | 0.137 | 0.144 |
| reload-motion | 32 | 0.109 | 0.104 |
| reload-motion | 64 | 0.220 | 0.208 |

The small bookkeeping migration does not establish an improvement; reload-motion math provides only a small saving in this fixture. The immutable tree also raises preparation median relative to the preceding fanout stage, and requires worker-side container reconstruction. No experimental path is promoted to the default. A larger move to native-owned gameplay state must remove repeated Dictionary/API crossings rather than merely relocate a few scalar operations.

Fine attribution separates magazine/reload, combat-input, grenade, melee, stance, room-scale, timers, input validation/pose/event work, roster reconciliation and transport. Include `simulation.player_bind` when assessing the player-state path. Self-time means can be grouped across disjoint scopes; percentiles cannot be added or subtracted.

## Reuse and prepared deployment

See [the runner documentation](../../../../tools/player_simulation/README.md) and [native backend documentation](../../../NATIVE-CQ-BACKEND.md). Physics and ordered gameplay commits remain on the main thread. The persistent roster retains typed timer storage but imports legacy combat/reload changes at the original per-player commit point; this is a migration prototype, not the complete player-controller rewrite.

Prepared bundle: `/home/blux/Documents/cq-authority-suite-20261014`. The bundle has been run locally with all authority experiments enabled.

```sh
python3 /home/blux/Documents/cq-authority-suite-20261014/tools/player_simulation/run_suite.py \
  --binary /home/blux/Documents/cq-authority-suite-20261014/release/cq-server \
  --output /tmp/cq-authority-two-minute-comparison --seconds 120 --players 32 64
```

The bundle runner uses an isolated loopback port and does not operate system services. The existing baseline cleanup diagnostic (21 ObjectDB instances / eight resources) is retained in fixture logs and explicitly recognized by the regression harness; other script/runtime errors fail the suite.
