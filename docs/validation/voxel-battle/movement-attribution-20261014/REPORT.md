# Movement and world-query attribution — October 14, 2026

The opt-in attribution is implemented and the staggered-admission run retained all 64 clients for the full two-minute profile and 155-second client lifetime. Collision calls dominate movement cost. CS controller work outside the measured descendants is much smaller. No movement optimization, physics backend change, production deployment or server rewrite was made.

## Implementation and interpretation

`deathmatch/server/attribution.gd` records nested main-thread scopes only when `--attribute-movement` is enabled in the metered server. Scopes are balanced across early returns using wrappers. Per label it records call count, inclusive/self totals, mean/max call duration and per-tick distributions. Raw tick samples retain the category vectors and total callback duration for correlated analysis. Calls made during idle input handling are accumulated into the next tick; they are not necessarily part of that tick's physics callback.

Inclusive time contains child scopes. Self time subtracts measured child scopes; it still includes uninstrumented work and instrumentation overhead. Query timings are wall-clock latency around actual engine calls, including possible scheduling pauses, not hardware CPU-cycle measurements. API call counts are not the number of internal broadphase/narrowphase operations performed by a slide or sweep. Query parameter allocation belongs to its enclosing scope.

Coverage: player movement, CS controller, stair/posture handling, edge rays, stair obstacle/ceiling/forward/landing sweeps, slide and floor snap, room-scale collision (approximately zero requests separated), eight vehicle controllers and their terrain/water/clearance work, spotting and class services, hit/cover ray/shape/cast queries, spawn clearance, input acceptance, physics-step multiplayer polling, snapshot construction/fanout and history. Other modes and engine work outside these scopes remain unattributed. Recorder data is main-thread owned and must not be used from workers. It is held in memory for the bounded profile and written after timing ends.

The recorder and raw export are disabled by default. Disabled runs retain lightweight wrapper/branch overhead. `tools/frontier_vps/summarize_attribution.py` ranks exclusive means and calculates the aggregate query distribution from each tick's sum; it does not add category percentiles. See [README usage](../../../../tools/frontier_vps/README.md).

## Test conditions

Same VPS, native/async backend, 30-Hz target, full map, 64 separate cached-asset ENet clients, synthetic tracked head/hands, movement and initial firing. No AI, GPU rendering, physical reload sequence, occupied-vehicle driving, voice traffic or downloads. The production 32-slot server remained active and unchanged. Clients run on the VPS, so their CPU use and host scheduling can affect timings.

Four candidate runs distinguish simultaneous from staggered admission and recording enabled/disabled. Staggering starts clients 125 ms apart; it is a diagnostic load-test option, not a gameplay/admission policy change. Populations and firing interactions vary between runs, so these are controls with limitations, not deterministic command replays.

The first simultaneous attributed run completed 61/64 clients; the recording-disabled repeat completed 62/64. Neither is a sustained 64-player baseline. Their full-duration profiles are retained under `raw/enabled` and `raw/disabled` with `partial-summary.json`. Recording cannot be assigned as the sole cause of those drops. The earlier connection-fix successes do not establish robust repeated simultaneous-burst admission under overload.

The simultaneous attributed run also captured one ~1.95-second callback near the end, with long slide, stair, zero-request room-scale and snap calls. Its cause is not determined: elapsed scopes alone cannot distinguish collision-path stalls from scheduling pauses. It was retained in the data, not discarded. The full-population staggered attributed run did not reproduce that extreme stall (maximum callback ~93 ms).

## Full-population attributed result

All raw tick samples have 64 players, all 64 clients completed, and scope errors are zero. The profile contains 2,418 ticks over approximately 120 seconds, achieving **20.14 Hz**. Callback median/p95/p99 is **44.99 / 61.13 / 80.35 ms**.

| Scope | Mean inclusive ms per tick | Mean exclusive ms per tick | Mean calls per tick |
|---|---:|---:|---:|
| All player movement | 17.122 | 0.650 | 63.87 |
| CS controller, nested within movement | 16.472 | 1.195 | 63.87 |
| Character slide collision | 12.302 | 12.302 | 63.07 |
| Stair obstacle sweep | 1.790 | 1.790 | 61.51 |
| Zero-request room-scale collision | 1.160 | 1.160 | 63.25 |
| Vehicle slide collision | 2.437 | 2.437 | 8.00 |
| Player-loop remainder after measured descendants | 25.006 | 6.593 | 1.00 |
| Snapshot preparation, averaged across all ticks | 3.998 | 3.998 | 0.67 |
| Snapshot fanout, averaged across all ticks | 2.834 | 2.834 | 0.67 |
| Input acceptance, including idle work carried forward | 3.962 | 3.962 | 93.30 |

The table has nested categories and must not be summed. The player-loop remainder includes control/state orchestration, weapon/reload attempts, room-pose rebasing and other work not separately scoped; it is not a measurement of one specific function. No single “pure CS math” claim is made for the CS self scope.

Instrumented queries total **18.96 ms mean**, **18.48 ms median**, **22.64 ms p95** and **25.53 ms p99 per tick**, computed from same-tick query sums. Mean API calls are **340.8/tick**; median **282**, p95 **661**, p99 **1,097**. Character slide alone averages approximately **0.195 ms/call**, and vehicle slide approximately **0.305 ms/call**.

The slowest 5% of callback samples have mean query time **23.43 ms**, compared with **18.96 ms** over all samples. Their largest exclusive mean categories are character slide **13.26 ms**, player-loop remainder **12.24 ms**, fanout **7.94 ms**, projectile update remainder **7.57 ms** and snapshot preparation **5.46 ms**. These conditional means share the same hot-tick selection; normal snapshot work is intentionally zero on ticks without a snapshot. They show that tail optimization also needs combat/state/replication work, rather than collision alone.

Spotting LOS rays average only **0.153 ms/tick**; complete spotting work has p95 **2.73 ms** and a near-zero median because of its periodic scan. Native range candidate filtering and existing sharing mean spotting is currently a secondary priority to locomotion. Vehicle terrain mobility, water checks and clearance average much less than vehicle slide; the terrain-height lookup itself is not established as the dominant vehicle expense.

Raw evidence: [profile](raw/staggered-enabled/64/report.json), [per-tick vectors](raw/staggered-enabled/64/ticks.jsonl), [fleet](raw/staggered-enabled/64/fleet/fleet.json), [derived summary](summary.json). Build checksum and regression logs are alongside this report.


## Recording-disabled control and connection result

| Admission / recording | Successful clients | Profile population | Achieved Hz |
|---|---:|---|---:|
| Simultaneous / enabled | 61/64 | 61–64 | 20.82 |
| Simultaneous / disabled | 62/64 | p50 62, peak 64 | 20.79 |
| 125-ms stagger / enabled | 64/64 | 64 throughout | 20.14 |
| 125-ms stagger / disabled | 64/64 | 64 throughout | 20.96 |

The matched staggered recording-disabled control held 64 for its complete 120-second profile and all clients completed their 155-second lifetime. Callback median/p95/p99 was **42.55 / 59.14 / 79.98 ms**. Relative wall interval was about **4.07% longer** with recording enabled (49.66 versus 47.72 ms average). This observed difference includes host scheduling, population interaction/firing variation and enabled recording; it is not a calibrated or isolated profiler-overhead estimate. Both cases contain the wrapper branches, so it does not quantify disabled-wrapper cost against the previous build. Neither run reaches 30 Hz. Attribution times should not be presented as the optimized server's production timing.

[Recording-disabled control](raw/staggered-disabled/64/report.json), [control fleet](raw/staggered-disabled/64/fleet/fleet.json). The full attributed profile has min/max population 64/64 in its raw ticks; both full fleets report 64 successful clients. Production remains active with no restart.

## Revised optimization priorities

1. **Reduce collision work before porting movement arithmetic.** Player slide is the largest measured movement leaf. It is already an engine C++ call, so merely rewriting the script's acceleration/friction functions will leave most of this cost. Investigate collision representation, controller query/recovery behavior, verified backend experiments and a batched native controller/query phase. Measure engine internals or actor/location-tagged slow queries before assigning the exceptional stall to a particular map collider.
2. **Test two narrow fast paths first.** Zero-request room-scale calls cost about **1.16 ms/tick** in this neutral-tracker workload. Eight unoccupied vehicles still slide each tick, costing **2.44 ms/tick**. Their combined measured slide-call cost is ~**3.60 ms/tick**, an upper bound before required wake/recovery work and overhead. Skipping a zero motion can remove penetration recovery, and an idle vehicle still needs gravity, slopes, platform support and water/destruction rules. Implement guarded skips/sleep only with those invariants and regression tests. Real physical room-scale motion reduces the applicability of the zero-request case.
3. **Avoid redundant stair probes where behavior permits.** Obstacle sweeps cost ~**1.79 ms/tick**, with additional stair orchestration/other sweeps. A verified movement path that only attempts stairs after relevant blocking contact may reduce unnecessary tests, but must retain current floor, slope, corner and over-height rejection semantics. Do not simply disable step assistance.
4. **Address player/state and replication work next.** The exclusive player-loop remainder is **6.59 ms/tick**; input acceptance **3.96 ms/tick** includes carried idle work. These justify deeper control/fire/reload attribution and persistent native state. Snapshot preparation plus fanout averages about **6.83 ms/tick** in this run, supporting owner-only/event-driven state, interest groups and reduced distant-update cadence. These averages are per-tick measured totals, unlike the prior per-snapshot-event medians.
5. **Retain robust network service as a separate gate.** Two new simultaneous-admission runs lost peers while staggered attribution retained 64. The socket buffer is still kernel-clamped and the authority is overloaded. Staggering is a diagnostic mitigation, not proof of robust public-server admission. Repeated burst joins/reconnects and off-host sustained tests remain required.

Removing *all* measured exclusive CS controller work would remove only ~1.20 ms/tick, and the real saving is necessarily smaller. Narrow collision fast paths plausibly offer a few milliseconds if their applicability is confirmed, rather than the entire roughly 16-ms gap between this run's 49.66-ms average wall interval and a 33.33-ms budget. Larger gains require changes to collision/controller execution plus state/replication work. These opportunities overlap and their hypothetical savings must not be added without a combined benchmark.

A standalone rewrite still has the greatest architectural freedom, but the new evidence strengthens the case for a reusable native controller/query world first. A straight language translation does not eliminate the measured engine collision calls. Preserve the Godot client/content pipeline and measured references while testing that component; it can later move into a standalone authority if necessary.

## Correctness checks

- New attribution fixture: enabled/disabled controller trajectory and velocity match; zero-request/slide counts, balanced early-return scopes and exclusive-time accounting pass.
- CS movement/fatigue/jetpack checks pass.
- Stair-contact tests pass at 60/90/144 Hz and with box/triangle steps; optional Solstice asset traversal is skipped because its base assets are absent.
- Physical room-scale, player hitboxes and projectile broadphase/authoritative trace regressions pass; projectile suite reports zero missed hits.
- Frontier integration passes. Existing fixture cleanup diagnostics remain 21 ObjectDB instances / 8 resources.
- Metered script parses, portable package builds, Python summary tool compiles and whitespace checks pass.
