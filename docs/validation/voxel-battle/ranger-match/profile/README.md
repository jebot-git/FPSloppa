# Simulation cost diagnosis: 32 ranger VRMs, 16v16

A separate 60.009-second instrumented live-match run collected 424 render-frame samples and 2962 physics ticks (49.37 seconds of game time). Same ranger sources, CS TDM, jetpacks, prepass, spring-off, fixed stereo cameras and map as the two-minute baseline. Preparation and streaming are excluded. This diagnostic enables opt-in avatar timers and wrapper timings; its overhead is included and it must not replace the uninstrumented baseline.

**Bot AI is the largest measured simulation expense.** It consumed 35.69 seconds of CPU time within 50.85 seconds of authoritative simulation CPU time: **70.2%**. These are measured cumulative inclusive scope times, not ratios of independent medians.

At the median rendered frame, **steering** was the largest named AI stage (32.06 ms), followed by planning (28.99 ms). **Planning dominates total AI time and the tail**, with 44.5% of AI CPU and 98.17 ms p95 per frame. Steering accounts for 36.2% of AI CPU. Navigation path queries take 13.27 seconds overall; they are mostly nested in planning and must not be added to it.

| CPU scope | Median ms/render frame | p95 ms/render frame | Mean ms/render frame |
| --- | ---: | ---: | ---: |
| Authoritative simulation (inclusive) | 113.86 | 211.98 | 119.92 |
| Bot AI (inside simulation) | 73.73 | 168.65 | 84.16 |
| AI steering | 32.06 | 39.28 | 30.46 |
| AI planning | 28.99 | 98.17 | 37.45 |
| Navigation path queries (nested) | 23.86 | 78.06 | 31.29 |
| AI combat | 5.16 | 9.53 | 5.10 |
| AI perception | 3.37 | 5.04 | 3.31 |
| Jetpack safety (inside steering) | 0.46 | 1.40 | 0.53 |
| History | 0.79 | 0.97 | 0.75 |
| Snapshot | 1.38 | 2.04 | 1.37 |

The profile observed 6,211 path queries (mean 2.136 ms/query), 393,208 active-link lookups and 360,004 navigation rays. Active-link lookups averaged 7.75 ms/frame; rays 3.54 ms/frame, both nested within other stages. Jump-link maintenance averaged 5.62 ms/frame, with an uneven one-time/incremental construction workload early in the match.

All avatar `rig` callbacks combined used 523.57 ms total, or **1.23 ms per rendered frame on average**, including their nested pose/eye/morph scopes. This includes the production distant-view animation budget; it is not a close-up/full-detail avatar cost. Whole stereo viewport GPU time had a median of 2.66 ms. Avatar animation, GPU rendering, snapshots, pickups and water checks are substantially smaller measured costs here than bot simulation.

Several physics ticks execute between rendered frames (mean 6.99 ticks/frame). That catchup amplifies roughly 10–20 ms CPU simulation ticks into long wall frames. The remaining authoritative simulation time outside AI totals 15.16 seconds and includes player movement/collision, weapon execution, game rules and replication. Those activities are not all separately resolved by this profile; a movement/combat split would need additional scopes.

Optimization priorities inferred from this trace:

1. Reduce and stagger planning/path queries; cache reusable route results and avoid retrying unreachable POI routes without a cooldown.
2. Reduce steering work: repeated active-link searches, teammate separation scans and collision probes; inspect/cull candidates before costly queries.
3. Move navigation jump-link preparation outside the measured active match where possible.

These are targets for follow-up, not changes made to gameplay. Planning/path query timings include Godot's native navigation calls; the trace does not split native closest-point projection from path search. The first two diagnostic launches had script-signature errors and were stopped before any valid measurement; this receipt contains only the successful run. No errors/warnings occurred during measured work; exit reported remaining profiling wrapper resources. All timings and reports were saved before that cleanup warning.

[Scopes](profile.json) · [Run](result.json) · [Checks](checks.json) · [Frame samples](frames.csv)

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/profile_match.gd -- --representation vrm --simulate --seconds 60 --output res://test-results/ranger-match/profile
```

Wrapper classes live under `tools/vrm_to_mdl/profile/`. They forward calls to the original implementation and only time their execution. The map arena factory hook and separate jetpack safety helper preserve ordinary benchmark behavior.
