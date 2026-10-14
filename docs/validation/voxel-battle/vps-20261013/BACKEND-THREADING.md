# CQ backend: using the VPS CPUs and extending native C++

This is a source inspection and proposed implementation sequence, not a measured multithreaded speedup or a completed native port. It supplements [CAPACITY-64.md](CAPACITY-64.md).

## What the server already does

An SSH inspection confirmed 12 exposed vCPUs, with virtual topology reporting six cores and two threads per core, on EPYC-Milan/KVM. That topology does not guarantee six exclusive physical cores. The running CQ process has 16 OS threads, but previous load measurements show the main authority path saturating approximately one logical CPU. Creating more threads alone will not distribute `_server_tick()`.

The branch contains an optional native module: `addons/fps_native/CMakeLists.txt` supports `FPS_SERVER=ON`, registering **FPSCodec only**. Native scalar/transform serialization, input packing, per-record encoding and compressed packet packing already exist in `codec.cpp` and `network_packing.cpp`. The general build also registers FPSPose, whose skeleton/face/finger work is outside this server's UT99-only backend.

The deployed package does not activate FPSCodec. `tools/frontier_vps/package.py` explicitly lists only TwoVoIP in its extension list; native runtime discovery additionally requires a real `fps_native.gdextension` and the matching library at its configured path. Shipping a native backend must update packaging and loose-library checksums, not just compile C++.

`deathmatch/network/disk_worker.gd` already provides asynchronous, bounded, serial disk jobs with main-thread completions. Asset verification/import metadata lives in `asset_jobs.gd`. This is useful infrastructure, but increasing its disk thread count is not expected to fix the movement-only simulation bottleneck.

Local runtime inspection with the project loaded reported physics separate thread disabled, worker pool maximum `-1` (automatic), and physics engine selection `DEFAULT`. FPSCodec was absent. This inspection used local Fedora Godot, not the VPS release template: the effective physics backend behind `DEFAULT` must be identified on that template before comparing engine settings. No live physics/thread settings were changed.

## Native candidates and realistic parallel boundaries

| Priority | Code / workload | Native opportunity | Worker boundary |
|---|---|---|---|
| First | `network/replication.gd`, `snapshot_codec.gd`, existing FPSCodec | Activate existing server codec; then batch record preparation, change detection and packet construction | Encode immutable snapshot records in coarse batches; stable merge/sequence/cache commit and RPC remain on authority thread |
| High | `projectile_targets.gd`, `hit_detection.gd`, `avatars/hit_body.gd` | Typed spatial grid, candidate masks, swept body/box/sphere tests and head-hit classification | Independent math over frozen poses; return ordered candidates; Godot world/cover queries and damage stay serialized |
| High | `lag_compensation.gd`, Arena history/rewind helpers | Fixed-capacity typed history ring and one combined position/height/yaw rewind result | Read-only rewind batches can run on workers; preserve life serial, teleport cutoff and 300-ms rewind bound |
| Medium | `conquest/classes/spotting.gd`, `turrets.gd`, recon/vehicle target filters | One shared actor/vehicle spatial index, team/range/alive filtering and target ranking | Parallel candidate preparation only initially; confirm LOS and commit spotted timers/turret shots on main thread |
| Medium | `vr/poses.gd`, `vr/room_scale.gd`, `avatars/controller_arms.gd` | Batch finite/basis/range checks, constrained hand reach and weapon transform math | Pure numeric validation from immutable input; admission, sequence/life validation and authoritative movement remain ordered |
| Conditional high | `fighter.gd`, `movement/cs16.gd`, Quake and jetpack helpers | Batch acceleration, friction, stamina and posture/velocity preparation; eventually native kinematic controller | Pure preparation can parallelize; current CharacterBody movement, step-up, floor snap and room-scale collision cannot simply be threaded |
| Conditional | `conquest/classes/battery_tank.gd`, ballistic helpers and projectile integration | Batched trajectory math, road/water lookup, conservative swept-volume candidates | Math on workers; terrain/structure queries, runover, vehicle destruction and crew damage commit in original order |
| Low initially | Frontier capture/progression/timers, healing/box budgets | Native only if profiling finds significant allocation/scanning cost | Tiny jobs are likely cheaper serial; eligibility may use shared candidates, scoring remains main-thread authority |
| Separate bot experiment | `bot_ai/navigation.gd`, aim/teamplay/planning | Route requests, candidate scoring and numerical aim can be queued | NavigationServer read-only queries have a supported threading path; freeze inputs and return commands tagged by tick/life; actions and fallback physics rays stay main-thread |

Some important checks are already optimized: projectile candidates use a conservative spatial grid with stable tie-breaking and overflow fallback; replication already suppresses unchanged eligible records for up to one second. Extend these paths rather than introducing another incompatible broadphase or dropping required state. Sparse snapshot serialization and compression already call native engine code; the remaining opportunity is reducing interpreter loops, allocation, repeated record preparation and recompression searches.

Spotting currently scans at 10 Hz, filters enemy pairs and casts up to two world rays per pair until a team has seen that target. Turrets also scan at 10 Hz and prioritize visible vehicles before infantry. Keep those cadences and semantics; distribute coarse work instead of doing every observer's scan in the same tick. The theoretical balanced 32-versus-32 population has 2,048 directed enemy pairs per scan before exclusions/range/visibility reuse. This is an algorithmic bound, not the observed ray count.

Rewind currently builds separate dictionaries for position, height and yaw, including a current history copy for each path. One typed rewind result per request can remove redundant work. History itself is inexpensive in the measured movement baseline (32-player median 0.178 ms), so prioritize this for sustained firing rather than treating it as the established baseline bottleneck.

Movement and world collision are already backed by C++ engine functions. A native wrapper can remove script orchestration overhead but does not automatically speed up `move_and_slide()` or the physics broadphase. Profile script math and engine queries separately before rewriting locomotion.

## Safe threading design

Keep one authoritative main thread. At defined boundaries in a tick, capture typed immutable data for a native backend: actor IDs and life serials, teams and flags, current/previous transforms, heights, velocities, validated commands and tick/map generation. Freeze the data until its jobs complete. Avoid per-player GDScript callbacks and repeated Dictionary conversion: enter C++ once per batch, copy into contiguous native arrays, then use workers operating only on those arrays.

Workers own separate output ranges or local buffers. Join them and reduce results in stable actor/projectile order on the main thread. Only the main thread mutates players, classes, health, ammunition, vehicles, capture points, scene nodes, ENet/RPC state and replication caches. Tag results with map epoch, tick and actor life; discard stale results after death, teleport, disconnect or map restart. Define shutdown so pending tasks finish or cancel before buffers are freed.

For same-tick movement/hit preparation, impose a bounded completion barrier and record its wait time. Do not slip damage work into a future tick merely to hide its cost: that changes fire/cover ordering. A frozen post-commit snapshot can be encoded asynchronously after a tick, with a bounded queue and the source tick/time in its header. Input decoding may be offloaded later with per-peer FIFO and bounded queues; accepted command/life validation still occurs on the authority thread. Queue age is as important as throughput.

Initially use Godot's existing WorkerThreadPool with a limited number of tasks per batch rather than a second unbounded pool. If native pool access complicates ABI bindings, use a small persistent native pool with explicit shutdown, not new threads per tick. The server build profile would need the added binding classes (currently no WorkerThreadPool or CharacterBody3D) and registered backend type. Measure marshal, schedule, compute, barrier and apply costs separately.

### Physics boundary

Godot documents that active scene-tree access is not thread-safe. It separately documents physics-server threading settings, but direct physics-space queries must execute at the supported physics synchronization point. Enabling separate-thread physics does not authorize arbitrary workers to call `CharacterBody3D.move_and_slide()` or raycast a live space. See [thread-safe API guidance](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) and [ray-casting synchronization](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html).

Keep live physics queries on the authority thread in the first prototype. For true parallel world queries later, either establish a supported engine/backend query phase with explicit synchronization, or maintain an immutable native collision representation. The latter must match the heightmap, cylinders, building geometry, movers, vehicles, radius sweeps, thin-wall cover and water rules; it is a substantial correctness obligation.

Test explicit Jolt selection versus the verified current backend, and separate-thread physics as independent experiments. Jolt is an available built-in alternative, but changing engines may alter character recovery, steps and floor snapping. It cannot distribute the existing script's serial control flow. See [Godot's Jolt integration notes](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html). No backend change should be accepted without the existing movement, room-scale, projectile/cover and vehicle regression tests plus actual 64-player timings.

## Initial CPU allocation and experiments

Start with **two and four compute workers**, then compare six, eight and ten only if batch size and CPU scheduling justify them. Reserve capacity for the authority thread, physics/engine jobs, network handling, disk/voice and the OS. vCPU topology and SMT mean twelve busy compute threads are not twelve full cores. Avoid CPU affinity until steal/host contention and sibling placement have been measured.

Use coarse batches (for example four batches of 16 actor preparations), with sequential fallback below a measured threshold. Encoding the identical global snapshot once and reusing it for all recipients is better than making 64 workers encode identical copies. Interest-based snapshots can use shared records/groups, then worker batches per distinct group. Do not globally increase Godot's automatic worker count and assume that script loops will parallelize.

The minimum useful experiment sequence is:

1. Add detailed script/physics/queue timing to the existing profiler; repeat fixed-seed 32/64 human-input workloads with continuous magazine reload and off-host clients.
2. Package and activate existing server FPSCodec; compare byte/semantic correctness and 120-second serial timings against GDScript. Do this before adding threading, to isolate language savings.
3. Port typed hit/broadphase/rewind and input/hand math as independently switchable native kernels, first serial and then two/four workers. Retain reference fallbacks for differential tests.
4. Move frozen snapshot encoding into bounded asynchronous jobs; measure end-to-end delivered snapshot latency, tick p95/p99 and queue age, not just worker CPU time.
5. Add batched spatial candidate preparation and stagger 10-Hz scans while preserving maximum scan delay. Benchmark dense POI combat and dispersed map populations separately.
6. Evaluate physics backend/thread settings or a native controller only if remaining profiles implicate those costs. Run the 15-minute full 64-player acceptance gate after each promising combined configuration.

Threading is only worthwhile if useful compute exceeds capture/scheduling/synchronization costs. Godot warns that small WorkerThreadPool jobs can make performance worse and requires completing/reaping submitted tasks. See [WorkerThreadPool documentation](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html).

The authority remains partly serial. As an illustrative Amdahl calculation, moving 30% of a workload onto four perfect workers yields only about 1.29× overall speedup before overhead; moving 50% yields 1.60×. These are hypothetical bounds, not estimates of this backend's parallel fraction. Twelve vCPUs will not yield a twelvefold improvement.

## Recommended scope

First activate the existing codec and add a server-only `FPSBackend` extension for **typed hit/broadphase/rewind batches and candidate filtering**, with a bounded worker API and main-thread commit. Keep the C++ module reusable by the main branch through reference fallbacks, explicit feature switches, wire compatibility tests and build profiles that exclude avatar rendering dependencies.

Do not port facial/full-body animation to this server, spread live CharacterBody nodes across workers, or restore legacy district subservers as an expedient threading mechanism. The main-branch animation module can remain a separate build option. A full native authoritative world is a later option if measured physics serialization still prevents 64-player operation.

## Implementation follow-up

The first native/threaded stages have now been implemented. See [native backend guide](../../../NATIVE-CQ-BACKEND.md) and [candidate validation](../native-backend-20261013/REPORT.md). The original proposals above describe the larger sequence; remaining physics/controller/interest-replication work is not represented as complete.
