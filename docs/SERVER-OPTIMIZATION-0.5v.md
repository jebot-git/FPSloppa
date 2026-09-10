# Server optimization — 0.5v

Optimizes the projectile-heavy server regression measured in
[the original audit](PERFORMANCE-AUDIT-0.5v.md), against base commit `cec9edd`.
Measurements use the same i7-12700 and Godot 4.7.2 Fedora build as that audit.

## Changes

- Return immediately for zero-rewind traces. Previously every projectile built
  a nested position-history dictionary for every player, then discarded it.
  Remote hitscan shots still use the original bounded historical interpolation.
- Reject disjoint capsule/segment bounding boxes before solving capsule roots.
  Bounds cover both endpoints of the relative-motion segment, preserving fast
  player crossings and initial overlaps.
- Build a small X/Z player grid once per projectile update. Each player occupies
  the cells covered by their swept capsule; each projectile queries its swept
  radius. Exact capsule, wall, cover and fortress-building checks still decide
  the hit. Candidate order preserves the original overlapping-target tie break.
  Fresh shots and respawn serial changes retain their original motion rules.
- Bound grid insertion and query sizes. Large sweeps, teleports and coordinates
  outside the safe integer-conversion range use a conservative full scan.
  The grid is local to each update and retains no players or scenes between ticks.

Weapon cadence, damage, projectile lifetime, network protocol and configured
player limits are unchanged.

## Measurement method

`server_load_audit.gd` simulates 8, 16 or 32 stationary players firing plasma
outward at full cadence. Long projectile lifetimes deliberately stress the
server collision path. Each comparison uses 120 warmup and 600 measured ticks
at 60 Hz. Peak projectile counts must match the baseline: 281 / 523 / 1,085.
Tick timing includes authoritative simulation and history recording. Snapshot
construction/broadcast invocation is measured separately every third tick.

This isolates server CPU cost with synthetic actors; it does not measure 32
connected clients, network bandwidth, every map or worst-case team-mode load.
The existing experimental status of 32-player hosting remains appropriate.

## Results

Final verification, including the extreme-coordinate fallback:

| Players | Original median / p95 tick, ms | Optimized median / p95 tick, ms | p95 reduction | Optimized max tick, ms |
|---|---:|---:|---:|---:|
| 8 | 4.930 / 5.419 | 1.914 / 2.254 | 58% | 5.274 |
| 16 | 16.246 / 17.094 | 3.449 / 4.050 | 76% | 8.728 |
| 32 | 64.299 / 66.797 | 6.832 / 7.820 | 88% | 11.583 |

Peak projectile counts matched the baseline at every capacity. Optimized p95
snapshot cost was 0.316 / 0.603 / 1.119 ms respectively. The 16-player fixture
has substantial room inside the 16.67 ms simulation budget again.

Intermediate measurements isolate the improvement: avoiding unnecessary history
copies plus capsule bounding boxes brought the 16-player p95 to 9.218 ms;
adding the grid reduced it to 3.805 ms. A repeat before the final coordinate
guard measured 3.826 ms; final verification measured 4.050 ms. This modest
variation should not be interpreted as a precise per-function timing.

All eight collision/combat/fortress regression scripts passed. The grid test
retained all 3,052 exact hits in 12,000 swept queries, discarded 309,401 distant
player/query pairs, and matched all 300 authoritative full-trace results.
All 40,000 capsule-reference comparisons matched.

Eight real ENet impairment profiles passed: 20/40/60/80/100 ms RTT, 50 ms with
10 ms jitter and 1% loss, 100 ms with 15 ms jitter and 2% loss, and asymmetric
20/80 ms latency with 5 ms jitter and 1% loss. All 236 shots accepted by the
server hit the intended targets. Dropped input packets can prevent a shot from
being accepted; this is not a claim that every attempted input survives loss.

The 6,000-tick (100-second) 32-player soak maintained 1,085 live projectiles
after warmup. Settled counts stayed at 2,518 objects, 390 resources and 413 nodes,
with zero orphan nodes. Godot RSS stayed at 196,936 KiB in the 15–95 second
sampling window, with 26 threads and 12 file descriptors. Static tracked memory
increased by about 244 KiB; the benchmark itself retains growing timing arrays,
and this short test is not a proof that all native allocations are leak-free.
Teardown returned to three autoload nodes, with zero orphan nodes.

The longer soak measured 8.154 ms p95 and a 19.708 ms maximum tick. Isolated
spikes above the 60 Hz budget remain possible; the improvement concerns sustained
projectile-processing cost, not a hard real-time guarantee.

TF rules/maps and three-process class/custom-avatar replication passed.
The four-process server/shooter/target/spectator regression also passed. All
final suites exited normally with no surviving child processes or forced cleanup.

The [machine-readable results](validation/server-optimization-0.5v.json) retain
baseline and staged timings, final tests, memory samples, network results,
process summaries and hashes of the optimized production files. These results
come from the source project; exported binaries were not rebuilt or published.

## Reproduction

Run from the project root, after importing the project with the installed Godot:

```sh
python3 tools/validate_server_optimization.py --stage check --players 8 16 32
python3 tools/validate_server_optimization.py --stage soak --skip-tests --players 32 --ticks 6000 --memory
GODOT_BIN=/usr/bin/godot python3 tools/validate_lag_network.py
GODOT_BIN=/usr/bin/godot python3 tools/validate_fortress.py
```

Set `GODOT_BIN` if Godot is not on PATH. Run CPU benchmarks without other test
suites in parallel. Logs and measurements go under `test-results/`; use distinct
stage names to preserve earlier measurements. The validator times out and reaps
its child processes. `tools/audit_processes.py` can additionally supervise a
suite and sample its process family on Linux.

Correctness checks include 40,000 deterministic comparisons against the frozen
0.5v capsule solver, 12,000 spatial queries, grid-boundary tangencies, enormous
sweep fallbacks, and 300 comparisons of full and filtered authoritative traces.
Existing regression tests exercise relative-motion hits, fresh shots, respawn
serials, walls, side cover, rocket/plasma/BFG damage, rocket jumping, lag
compensation, packet ordering and fortress rules.

These changes do not address the separately documented pre-existing native
Steam Audio singleton shutdown warning. Memory measurements distinguish that
exit-time warning from allocations accumulating during server operation.
