# Integrated Jolt runtime default — October 14, 2026

Jolt is now selected explicitly for this branch's client and server runtime.
This uses **Godot's built-in Jolt Physics backend**, retaining one collision
world for player movement, vehicle compounds, space queries and prediction.
It does not bind the standalone direct-Jolt test service into gameplay.

The map now replaces 304 authored stair tread bodies with 19 ramp slabs by
default. Stair visuals and baked meshes remain unchanged. The previously
accepted visual offset is retained. The standalone exporter preserves its
opt-in ramp flag for historical comparisons, sharing the runtime helper.

CQ checks Jolt availability/selection at startup. Both client and server must
restart using a Jolt-enabled Godot build. Protocol
`fpsloppa-cq-frontier-17-jolt-ramps1` prevents older clients with different
collision behavior from joining; the map digest includes the ramp helper.
Dedicated packaging copies these project settings and the helper without
requiring an extra native library. Existing VPS installations were not changed.

## Runtime corrections

The integrated traversal test exposed a CS floor probe starting inside uphill
ramps, incorrectly enabling edge friction. Its origin now follows the supporting
floor plane. Real ledges still enable edge friction. Supported uphill tangent
velocity also retains ground acceleration instead of being treated as takeoff.
Generic small-obstacle stair assistance remains available elsewhere.

## Validation

Godot `4.7.2.stable.fedora.ed1daf0bf`, Linux, Intel Core i7-12700. Headless,
XR disabled. Logs and machine-readable results are stored beside this report.
All listed test processes exited zero and all behavioral checks passed.

| Test | Passed checks/cases |
|---|---:|
| New integrated runtime acceptance | 48 checks |
| CS movement at 30 Hz | 31 checks |
| Jetpack, including 30/60/120 Hz trajectories | 44 checks |
| Rocket battery vehicle | 58 checks |
| Light/heavy tanks and repair | 44 checks |
| Road mobility and water destruction | 28 checks |
| Barrage ballistics | 192 cases |
| CQ authority/configuration/capture rules | 50 checks |
| Local prediction | 14 checks |
| Physical crouch/water behavior | 39 checks |
| Local ENet server/client CQ replication | 10 checks |
| Actual map terrain, POI ground, water/bridges/boundaries | 59 checks |

The new acceptance fixture builds the real 1,425² heightmap and map colliders.
All 19 flights pass ascent and descent with an actual gameplay fighter subclass
whose stair assistance always returns false, 95 ticks in each direction at
30 Hz. This exercises Godot's integrated controller, not the separate native
`CharacterVirtual` implementation. Standing player support and stance changes
pass. Dense 32/64-character convergence remains bounded, with minimum horizontal
separation of 0.5855/0.5973 m for nominal 0.6 m diameter hulls; the fixture accepts
at least 0.57 m, rather than claiming perfect analytic cylinder packing.

Existing arena fixtures emit **21 leaked objects / 8 resources still in use at
exit**, despite successful behavior checks and zero exit codes. A control run
of the battery fixture with the committed pre-switch project configuration and
class-arena script reproduces the identical cleanup diagnostics
(`legacy-cleanup.log`). The new runtime acceptance and terrain fixtures exit
without those diagnostics. Cleanup of the older arena fixture is separate work.

The unchanged standalone native build also passes CTest 3/3: 534 custom-service,
284 direct-Jolt and 305 blocker checks. This is regression evidence for those
test services, not proof that their custom policies are active in Godot.

## Local movement measurements

| Converging players | Batch p50 | Batch p95 | Samples |
|---|---:|---:|---:|
| 32 | 3.141 ms | 3.528 ms | 180 |
| 64 | 5.251 ms | 5.764 ms | 180 |

Each batch calls gameplay `simulate` for all players after a physics-frame
boundary, using 30 Hz commands, with 60 warmup and 180 measured ticks. Timing
includes GDScript CS movement, probes, step checks and synchronous body motion.
It excludes the engine's separate physics step, AI, rendering, networking,
weapons, snapshots and the full-map workload (the crowd phase uses an isolated
flat arena). These are **not server tick measurements**, a before/after speedup,
or evidence that the 12-vCPU VPS sustains 64 players. The earlier direct-Jolt
worker timings measure a different implementation and workload. 64 slots remain
an explicitly unsupported option.

## Reproduce

From the worktree with imported assets available:

```sh
godot --headless --xr-mode off --fixed-fps 30 --path . --script deathmatch/tests/cq_jolt_runtime.gd
godot --headless --xr-mode off --fixed-fps 30 --path . --script deathmatch/tests/cq_cs_movement.gd -- 30
godot --headless --xr-mode off --fixed-fps 30 --path . --script tools/voxel_battle/validate_jungle_physics.gd
ctest --test-dir /tmp/cq-jolt-build --output-on-failure
```

Run `cq_frontier_network.gd -- server` and `-- client` in separate processes,
starting the client after `DM_HOST_READY`. CTest requires building the pinned
native test suite as described in `tools/collision_service/README.md`.

## Prepared deployment validation

The [isolated deployment workflow](../../../../tools/collision_service/DEPLOYMENT.md)
now builds an offline bundle with pinned Jolt sources, the current server pack,
extension libraries, checksums, regression runner and optional capacity tools.
The prepared bundle passed all **15 runner stages** locally: configure/build,
three native CTest targets, ten runtime fixtures and the two ENet endpoints.
The release executable separately reached `CQ_FRONTIER_SERVER_READY` on
loopback UDP 28817 with the new protocol. Evidence is in `deployment/`.
This run packaged the pre-commit working tree, which its results record honestly;
the final distributable is regenerated from the clean committed tree.

Deployment checks found and fixed the full editor's TwoVoIP library lookup and
read-only package report paths. Jetpack and terrain reports now use `user://`.
The generic-arena `vr_crouch_water` fixture depends on separately installed arenas
and is excluded from this CQ package runner; its earlier source-project result
remains recorded above. CQ movement and runtime fixtures exercise stance hulls.

The VPS preflight confirms the current service is active and sufficient disk is
available. It currently lacks CMake, a C++ compiler and a full Godot executable.
Those documented prerequisites must be supplied before running this suite there.
Staging the isolated bundle does not switch the active production release or
establish 32/64-player VPS capacity.
