# Unsupported 64-player CQ option and sustained-capacity assessment

## Configuration

The frontier CQ arena accepts `set sv_cq_maxclients "64"` as an **unsupported experiment**. The default and normal sample configuration remain 32 slots; 33–64 slots emit the same unsupported notice. Values above 64 are rejected. `sv_maxclients` controls other arenas, not this CQ arena.

An explicit sample is provided at `tools/voxel_battle/cq_classes_64_unsupported.cfg`. From this worktree, launch it with:

```bash
godot --headless --xr-mode off --path . res://tools/voxel_battle/class_arena.tscn -- --server --config res://tools/voxel_battle/cq_classes_64_unsupported.cfg
```

On the deployed server, the equivalent opt-in is changing `~/fpsloppa-cq/server.cfg` to `set sv_cq_maxclients "64"` and restarting its service. The running VPS remains configured for 32 slots. The warning/status changes require rebuilding the server package before they appear on the deployed binary; its existing capacity setting already accepts 64.

Startup logs include `capacity_policy`; RCON `status` reports the selected slots, supported ceiling (32), maximum (64), unsupported flag and warning. Joining players receive the warning regardless of current occupancy. No additional confirmation or experimental flag is required: explicitly selecting the capacity is the opt-in. Listen-server limits remain 32.

The 32-slot ceiling is a configuration policy, not a performance guarantee: the existing 32-player test already has little headroom.

## Measured baseline

These results come from the October 13 VPS deployment, not a new benchmark. See [REPORT.md](REPORT.md) and the adjacent raw JSON/logs.

| Measurement | 32 live clients | 64 isolated players |
|---|---:|---:|
| Achieved simulation frequency | 29.94 Hz | 24.40 Hz |
| Simulation median / p95 | 16.84 / 21.12 ms | 29.13 / 39.59 ms |
| Snapshot median / p95 | 6.50 / 9.15 ms, including fanout | Build 3.21 / 4.60 ms; encode 6.14 / 9.57 ms |
| Authority peak RSS | 486.3 MiB | 609.5 MiB |
| Snapshot fanout estimate | 31.5 Mbps | 59.8 Mbps at target 20 Hz |

The live 64-player attempt never sustained 64: 51 distinct players joined, peak admitted concurrency reconstructed from join/disconnect events was 49, and only 16/64 clients completed. Kernel receive drops reached 56,494 in the authority process sampling. The cause of failed admission cannot be assigned exclusively to CPU without transport/queue profiling.

The isolated result requires approximately **23% higher throughput**, or **19% less wall work**, merely to reach 30 Hz on average. This is a lower bound; it does not include live transport or sustained combat and provides no reserve for tail latency. Simulation p95 alone exceeds the entire 33.33 ms tick budget.

Engine physics monitor includes callbacks and catch-up batches, so its percentiles overlap with script timing and cannot be summed. The 32/64 tests use different spawn distributions and are not a controlled scaling comparison. Firing mostly stops after the initial magazine: ammunition reserve refill is not physical magazine reload. AI, rendering and live XR are absent. Local client processes also share the VPS CPU during fleet tests.

## Work needed, in priority order

1. **Profile the authority tick more finely.** Separate CS movement/collision queries, tracked-pose validation, class abilities, spotting/designation scans, objectives, vehicles, projectile sweeps and damage/impact callbacks. Record mean CPU consumption and p95/p99 per tick, queue depth, clock lag and active effects. Current data establishes a simulation bottleneck but does not prove which subcomponent dominates. Repeat fixed-seed 32/64 runs with identical workload per player.

2. **Reduce snapshot cost and transport pressure.** The deployed package lacks the optional FPSCodec extension and uses GDScript packing. Build the existing server-native codec for the VPS ABI and verify byte/semantic compatibility before measuring its benefit. Encoding alone consumes about 123 ms of CPU per second at the observed median and target 20 Hz; snapshot construction adds about 64 ms/s. These are approximate budgets, not promised savings. `_send_snapshot()` currently sends world snapshots to all transport peers, including those still completing readiness. Restrict heavy replication to admitted, ready recipients, keep global CQ scores/objectives, and investigate distance/visibility-based pose update rates and delta replication. Preserve nearby combat, teammate information and scout designations. Audit large reliable records so recurring state does not congest reliable queues during joins.

3. **Investigate ENet admission and receive queues.** Capture per-peer input/snapshot rates, retransmits, reliable backlog, actual socket buffer sizes, kernel drops and admission-stage timing. Kernel buffer defaults/maxima were 212,992 bytes; raising a sysctl alone does not establish that ENet's socket buffer grows. The inspected Godot ENetConnection binding does not expose a socket buffer setter, so effective changes may require a native adapter or engine change. Longer disconnect timeouts alone do not solve starvation. Exercise staggered and burst joins, uncached skin/map readiness, reconnects and simultaneous skin changes.

4. **Reduce authoritative world-query and collision work without changing cover.** The full map carries 90,928 environmental collision shapes, spatially grouped into static bodies, plus its terrain heightmap and structures. Render LOD and streaming do not remove these server colliders. It is already grouped; simply grouping bodies again is not a new optimization. Evaluate a more efficient broadphase and conservative collision residency around players, vehicles and projectile swept paths. Any residency scheme must preserve long-range ordnance impacts, remote persistent vehicles and tree cover; grass already has no collision. Optimize measured hot loops/native batches before attempting a physics rewrite.

5. **Use hardware changes only against measured remaining cost.** The 12-vCPU, 24-GB VPS is constrained by the authority's largely serial CPU path, not memory capacity. More vCPUs do not multiply that thread's throughput. Check CPU steal and contention, then compare stronger sustained single-core performance if software work still misses the budget. Current snapshot estimates occupy roughly 6% of the nominal 1-Gbps link at 64 players, but are not wire measurements and exclude voice, assets and retransmits. Bandwidth headroom is plausible, not established under full gameplay.

6. **Retain one authority while optimizing.** Existing district workers assume separate maps. The unified jungle shares vehicles, projectiles, capture state and cross-map combat; those workers cannot simply be enabled to split its physics. A partitioned server would need entity ownership, border replication, cross-partition hits and deterministic handoff. Consider that larger redesign only if native hot-path and replication improvements remain insufficient.

## Acceptance gate before calling 64 sustained

Run independent load generators off the VPS over WAN for at least 15 minutes after all 64 players are fully admitted. Include movement and synthetic tracked arms/head, continuous firing with actual reloads, CQ capture/income/kills, all classes, tanks, drone, airstrike, healing fields and turret deployment. Include join/reconnect and skin-transfer bursts. Test bots separately after the human-input baseline.

Suggested engineering targets are stable 30-Hz wall-clock simulation, p95 total tick work at or below 25 ms and p99 at or below 33.33 ms, bounded tick lag and network queues, no server-induced disconnects, and no growth in receive drops during the controlled baseline. Validate client-side delivered updates, not just packets sent; record real wire bandwidth, voice traffic, CPU steal and RSS throughout. These are proposed release gates, not results already achieved.

Until both full simulation and transport pass this gate, 64 slots remain unsupported.

## Validation of the configuration change

`deathmatch/tests/cq_frontier_integration.gd` covers the 32-slot default, explicit 64 sample, rejection of 65, warnings above 32, a dedicated 64-slot host without clamping, and RCON capacity policy. It also retains the existing movement, capture, scoring and round-end checks. The test passes; known fixture exit warnings remain 21 ObjectDB instances / 8 resources.

The real full-map 64-slot startup also passed: it printed `unsupported_capacity=true` and the structured policy. The paired frontier ENet server/client regression completed with exit code 0 for both processes. Logs are saved alongside this assessment.

Threading and native-port details: [BACKEND-THREADING.md](BACKEND-THREADING.md).
