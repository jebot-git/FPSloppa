# Resident CQ authority implementation — 14 October 2026

The opt-in native authority now owns the CQ gameplay pipeline, with Godot retained for admission/assets, ENet, authored navigation queries and Jolt scene operations. The default live service has not been switched. Both ends negotiate protocol `fpsloppa-cq-frontier-18-resident1`.

## Validation

Standalone: **909,456 checks**, also passing under AddressSanitizer and UndefinedBehaviorSanitizer. Real Godot/Jolt functional suites: **592 movement/adapter, 16,817 VR/reload, 15,506 terrain/road/water and 603 entity/presentation checks**. These include an actual prone-death/restart collider regression.

Actual arena integration passed desktop and tracked clients through normal asset admission, native frame assembly and existing prediction/presentation. Each fired 17 shots and exercised grenades, NVG, prone suicide/gib/respawn, team switching and jetpack. A four-bot authored-map navigation smoke passed with 91.67m maximum displacement within one life over 600 ticks. This smoke's bots did not encounter targets; an earlier diagnostic run did record bot firing. Nineteen authored-navmesh edge-merge warnings are retained in the evidence. The smoke is not an AI capacity measurement.

The client test initially leaked service nodes by replacing an already-instantiated script. It now substitutes the scene script before construction. The actual CQ arena also freed an unused inherited match service when replacing the match object. Full-client testing caught and fixed a jetpack heading type mismatch (prediction expects Vector2). No test diagnostic was suppressed for these fixes.

## Local two-minute transport/Jolt cases

All cases use the authored jungle collision map, 11 capture sites, eight vehicle entities, four CQ classes, synthetic tracked head/hands, physical reload gestures and no AI/rendering. Vehicles are present but not driven by load peers. Input fire is deliberately pitched upward. These are steady-population fixtures, not lethal 32v32 matches.

Each measured phase follows an eight-second recorded warm-up. Normal cases retain finite ammo and combat damage. Stress cases refill reserve ammo/grenades and reject combat damage while preserving magazine gestures, reload delays and water/fall rules. This distinction matters: stress cases sustain more firing. Per-class shot counters are current-life counters, while the native global counter spans respawns.

| Workload | Players | Hz | Callback p50 ms | p95 ms | Shots | Input acceptance | Minimum frames |
|---|---:|---:|---:|---:|---:|---:|---:|
| normal | 32 | 29.999 | 1.714 | 2.959 | 2,442 | 99.961% | 2400 |
| normal | 64 | 30.001 | 3.997 | 8.044 | 4,976 | 99.959% | 2385 |
| stress | 32 | 30.003 | 1.777 | 3.388 | 4,524 | 99.972% | 2395 |
| stress | 64 | 30.000 | 4.294 | 9.624 | 9,022 | 99.957% | 2318 |

All four runs passed the workload, tick-rate, input-delivery, complete-frame, queue-bound and frozen-source/library gates. There were no malformed frames, unexpected disconnects or projectile/command queue saturation. Small input rejection counts were retained, alongside deaths/respawns; the report does not claim lossless input delivery or a measured rejection-reason breakdown. Startup transport counters and RTT/loss/throttle telemetry remain in the full summaries.

### Mean local callback categories

Milliseconds per tick; residual is callback minus the measured native phases, not an isolated transport measurement. No AI decisions run for these human load peers, so the AI scan overhead cannot establish bot cost.

| Workload / players | Movement + Jolt | Combat + queries | Encoding | CQ mode | AI scan | Adapter/compression/enqueue residual | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| normal / 32 | 1.0195 | 0.1778 | 0.0307 | 0.0022 | 0.0013 | 0.4995 | 1.7309 |
| normal / 64 | 1.9804 | 0.3642 | 0.0505 | 0.0023 | 0.0012 | 1.6946 | 4.0931 |
| stress / 32 | 1.0010 | 0.2662 | 0.0319 | 0.0019 | 0.0012 | 0.6192 | 1.9214 |
| stress / 64 | 1.9597 | 0.5934 | 0.0542 | 0.0024 | 0.0012 | 2.0789 | 4.6898 |

Movement/collision is the largest measured native phase. The residual also merits finer transport/compression attribution before another rewrite. Godot physics and transport work outside the callback are excluded; child percentiles cannot be added. These results are not a controlled speedup comparison with the earlier finely attributed script-authority VPS runs.

## Scope and reuse

See the [implementation/host contract and reproduction commands](../../../../tools/authority_core/README.md). Typed C++ modules are host-independent; the Godot adapter retains scene access on the owner physics thread. Native state is not mirrored back into authoritative player Dictionaries each tick. The main-branch migration boundary is the complete module set plus cold metadata/admission, typed ingress and client frame presentation, not isolated scalar helpers.

This remains an opt-in dedicated CQ path. Non-CQ legacy modes, waiting lobbies and district worker authority are outside this migration. The bot planner is a native prototype using authored ground routes; it is not feature-for-feature legacy AI parity. The current path does not claim to saturate twelve vCPUs: engine-thread collision commits and transport remain measured targets. Rendered headset/device validation, a lethal 64-player match and external WAN load remain separate from the fixtures reported here. The unsupported 64-player configuration is not promoted to a supported capacity based on these tests alone.

## Test findings retained

- The first real-map synthetic-client test overloaded the GDScript frame decoder. Load peers now use the bounded native validator; full semantic decoding/presentation is independently tested through actual clients and functional checks.
- Startup ENet packet throttling was observed. Warm-up counters remain recorded separately instead of being silently discarded or counted as successful measured input.
- Full-client admission caught and fixed multi-piece assembly resetting its map epoch, grenade selection defaults and the jetpack heading type.
- Prone/vehicle death exposed a collider reset requirement; native respawn/teleport restores standing dimensions and collision layers.
- The inherited jungle path description promised a 4,096-polygon bound but used an unrestricted query. It now applies that bound and a 180m search distance; long trips use short authored road legs. The inherited whole-mesh jump-link scan is omitted for this ground-route planner.
- Release export templates reject `--main-pack` overrides and do not expose the editor's `--script` launcher. A packaged `--resident-suite` entry runs the same fixture. Export-template smokes initially failed on shutdown diagnostics; these failures are not used as passing capacity results.
- Godot 4.7.2's RPC cache connects a bound `tree_exited` callback but its clear path disconnects an unbound callable ([engine source](https://github.com/godotengine/godot/blob/ed1daf0bf/modules/multiplayer/scene_cache_interface.cpp)). The portable fixture detaches completed client RPC roots during `server_disconnected`, before the engine cache clear. Logs remain strict; no disconnect diagnostic is filtered.

No commit/push was requested for this continuation. Earlier uncommitted work is preserved.

## VPS two-minute cases

12-vCPU / 24GB VPS, matched frozen portable binary/PCK/native extension, separate ENet loopback clients in groups of four, no rendering or AI. The service was suspended under a PID-identity guardian and resumed afterward. This is the same native jungle fixture as the local cases, reached through the release-template launcher.

| Workload | Players | Hz | Callback p50 ms | p95 ms | Max ms | Shots | Accepted/offered | Min complete frames |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| normal | 32 | 30.003 | 2.782 | 5.147 | 7.175 | 2,397 | 99.965% | 2400 |
| normal | 64 | 29.998 | 6.719 | 14.793 | 20.851 | 5,111 | 99.916% | 2349 |
| stress | 32 | 30.001 | 3.033 | 5.807 | 8.004 | 4,511 | 99.954% | 2390 |
| stress | 64 | 30.003 | 7.220 | 16.375 | 22.006 | 9,051 | 99.879% | 2280 |

All four cases passed strict diagnostic, client workload, frame delivery, tick-rate, queue and input-delivery gates. No malformed frames, unexpected disconnects or queue/projectile saturation occurred. Two-minute finite-ammo and stress cases are kept separate.

### Mean VPS callback categories

| Workload / players | Movement + Jolt ms | Combat + queries ms | Encoding ms | CQ mode ms | AI scan ms | Adapter/compression/enqueue residual ms | Total ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| normal / 32 | 1.6831 | 0.2531 | 0.0417 | 0.0043 | 0.0032 | 0.8914 | 2.8766 |
| normal / 64 | 3.1729 | 0.5432 | 0.0670 | 0.0042 | 0.0022 | 3.1947 | 6.9843 |
| stress / 32 | 1.6874 | 0.3929 | 0.0463 | 0.0044 | 0.0025 | 1.1302 | 3.2636 |
| stress / 64 | 3.1331 | 0.8435 | 0.0633 | 0.0040 | 0.0023 | 3.8445 | 7.8907 |

The remaining callback cost is concentrated in movement/Jolt and the adapter/compression/enqueue residual. The latter needs finer attribution before naming a specific transport function as the cause. Snapshot preparation is now native typed serialization rather than a repeated per-player Dictionary bridge. The core does not claim twelve-vCPU parallelism; all Jolt/scene access remains on the owner thread.

### Sampled server resources

CPU percentages use **one fully busy core = 100%**, not the whole twelve-vCPU machine. Samples cover the measured windows, excluding startup; 32-normal sampling began late and covers only the last ~82 seconds. Other cases have 120 samples over ~119 seconds. Client fleets share the same VPS CPU but are excluded from these server-process figures.

| Case | Mean process CPU | Mean main-thread CPU | Max RSS MiB | UDP drops at first / last measured sample |
|---|---:|---:|---:|---:|
| 32-normal | 15.88% | 12.33% | 437.60 | 0 / 0 |
| 64-normal | 30.82% | 26.51% | 438.10 | 9 / 9 |
| 32-stress | 17.86% | 14.15% | 437.72 | 0 / 0 |
| 64-stress | 33.34% | 29.05% | 438.24 | 12 / 12 |

The 64-client sockets accumulated 9 and 12 kernel receive drops before their first measured samples. No further server-socket drop increments appeared during the sampled measured windows. This does not assert lossless ENet delivery; accepted/offered counts and per-client telemetry remain the transport evidence. Memory figures describe this headless fixture, not a rendered client or an arbitrary populated production match.

### Restoration and public health

All four cases completed successfully and `resumed_original_process=true` was recorded. Service PID **1600382**, process-start identity **59460619**, `NRestarts=0` and installed release `20261014-jolt-6abfbf5` were preserved. The unit returned to active/running. A compatible client then connected through public **UDP 7777**, stayed admitted for ten seconds and received **229 snapshot packets** with no rejection. The existing production release remains installed; the resident authority is available in the isolated prepared bundle and opt-in branch path.

No service unit, release symlink, server configuration or firewall rule was changed. The sampled suite does not establish external 64-client WAN capacity or a lethal mixed infantry/vehicle battle. Keep 64 players an unsupported experimental setting until those gates are measured.

## Evidence

- [Native checks](standalone.json), [ASan/UBSan](sanitizers.log), [native build receipt](native-build-receipt.json).
- [Real arena/admission/client/bot results](arena/summary.json).
- [Local finite-ammo summary](normal/summary.json), [local stress summary](stress/summary.json), including frozen source/library hashes and full transport telemetry.
- [VPS full results](vps/results.json), [resource summary](vps/resource-summary.json), [raw process samples](vps/processes.jsonl), [restoration status](vps/status.json), [guardian](vps/guardian.json).
- [Public endpoint health](vps/cq-resident-post-public-health.log), [service health](vps/cq-resident-post-service.log), [suite console](vps/cq-resident-vps-full.log), [portable release hashes](portable-release-sha256.json).
