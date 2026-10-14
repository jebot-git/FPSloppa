# CS-only collision replacement and OpenNova review

October 14, 2026. The branch now defaults to Godot’s integrated Jolt backend and ramp colliders. The standalone collision services below remain experimental; their performance is not the runtime’s performance. See the current integration section below. The CS-only movement restriction described below is implemented. [Measured attribution](validation/voxel-battle/movement-attribution-20261014/REPORT.md) remains the performance baseline.

## Recommendation and scope

A purpose-built native collision world is justified as an experiment. Replace the gameplay collision/query/controller path as a coherent module, retaining the Godot client, renderer, map tools and networking initially. This branch now has one player locomotion contract: CS, with a flat-ended cylinder. Quake selection is removed from configuration, RCON, replicated mode state and player creation. Legacy configuration keys are ignored for migration, and legacy movement records cannot change the client controller. Matching clients/server use protocol suffix `cs-only1`.

Do not implement a general rigid-body/joint/soft-body engine as the first milestone. This map primarily needs terrain, fixed structures, trunks, kinematic actors/vehicles, projectile queries, overlaps and triggers. The current procedural rocks belong to the terrain, and undergrowth has no collision. A complete replacement of those gameplay collision services is a smaller, more useful scope than replacing every PhysicsServer API.

The CS-only rule removes capsule *locomotion*, but not every capsule query: existing headroom and vehicle-exit clearance tests use capsule-shaped volumes. Preserve those contracts until a separately verified replacement is chosen. Physical crouch/prone/jump, standing on players, jetpack and room-scale displacement remain required.

## What OpenNova actually implements

Reviewed upstream commit **60f12528504974efd237043c1a7780c951b8841f**, dated October 13, 2026, in a read-only shallow checkout. Its stated target is the Joint Operations generation of NovaLogic games, with C++ runtime and Godot presentation. This is relevant heightfield-engine evidence, not proof that its renderer/collision exactly reproduces every earlier Comanche/Delta Force Voxel Space generation. [Project README](https://github.com/opennova-net/opennova/blob/60f12528504974efd237043c1a7780c951b8841f/README.md).

| Observed implementation | Source | Relevance here |
|---|---|---|
| Native heightfield sampling, world/atlas coordinate routing and bilinear height/gradient helpers | [height_field.cpp](https://github.com/opennova-net/opennova/blob/60f12528504974efd237043c1a7780c951b8841f/engine/runtime/terrain_query/height_field.cpp) | Terrain queries can read cached numerical terrain directly rather than construct generic scene queries for every contact. |
| Terrain ray kernels with a short near-vertical path, coarse samples with bilinear confirmation and a separate refinement routine | [terrain_raycast.cpp](https://github.com/opennova-net/opennova/blob/60f12528504974efd237043c1a7780c951b8841f/engine/runtime/terrain_query/terrain_raycast.cpp) | Use terrain-specific traversal and refinement. Preserve exact thin-cover/earliest-hit requirements instead of copying its sample spacing. |
| Authored object collision sections containing bounds, spheres, volumes and plane runs; separate projectile face data | [collision.h](https://github.com/opennova-net/opennova/blob/60f12528504974efd237043c1a7780c951b8841f/engine/runtime/world/collision.h) | Separate render data from compact query data, and choose geometry by query purpose. |
| Object segment queries reject by bounds then clip against convex planes; projectiles also have dedicated face/polygon paths | [collision_query.cpp](https://github.com/opennova-net/opennova/blob/60f12528504974efd237043c1a7780c951b8841f/engine/runtime/world/collision_query.cpp) | Static boxes/convex volumes can use compact direct math. Movement proxies must not accidentally weaken ballistic cover. |
| Per-tick proximity tables, bounded candidate storage, cached source slices; stable LOS has a spatial cell index | [collision_world.cpp](https://github.com/opennova-net/opennova/blob/60f12528504974efd237043c1a7780c951b8841f/engine/runtime/world/collision_world.cpp) | Separate static/dynamic broadphases, reuse candidates and avoid repeated global scans. |
| Movement resolves a small set of points/radii, contact forces/gameplay flags, repulsion and a ground-settle probe | [collision_resolve.cpp](https://github.com/opennova-net/opennova/blob/60f12528504974efd237043c1a7780c951b8841f/engine/runtime/world/collision_resolve.cpp) | It is a custom game controller/contact system, not a drop-in equivalent of our flat-ended CS cylinder sweeps. |
| Ground and LOS combine object-volume queries with terrain-specific sampling | [collision_los.cpp](https://github.com/opennova-net/opennova/blob/60f12528504974efd237043c1a7780c951b8841f/engine/runtime/world/collision_los.cpp) | Treat terrain and objects separately, then return the nearest relevant result through one query API. |

The important connection is numerical heightfield terrain plus authored object collision, independently of how terrain pixels/meshes are rendered. A 3D voxel occupancy tree is not a prerequisite. Our current terrain collider is likewise a 1425-by-1425 heightfield; visual voxel/mesh/tree LOD does not define authoritative collision residency.

OpenNova also keeps target views/section matrices cached for repeated projectile queries. That is a useful data-lifetime lesson: static query data should be prebuilt and dynamic transforms prepared once per phase. Our existing native anatomical/grid/history kernels should be reused rather than rewritten to mimic its model formats.

## Behaviors to adapt carefully

- **Controller shape/response:** its sampled-radius/contact-force resolver is not the required cylinder controller. Preserve flat feet/head, circular horizontal footprint, current stair limit, slope rejection, floor snap, air movement, crouch/prone and recovery.
- **Candidate cadence:** the reviewed code refreshes normal candidate slices every 17th tick, with explicit refresh paths. Copying that cadence into a 30-Hz jetpack/vehicle game could leave candidates stale for roughly 0.57 seconds. Build conservative swept dynamic bounds every tick, or prove a motion-bounded cache invalidation rule.
- **Terrain interpolation:** OpenNova's bilinear/atlas rules are retail-specific. Match this map collider's triangles, scale and contact normals, or intentionally update both client and server collision data together. Center-point grounding alone is insufficient for a finite-radius body at edges, slopes and walls.
- **Retail edge cases:** its source explicitly preserves some asymmetric buried/vertical ray behavior, fixed-point rounding and atlas extent rules. These are compatibility requirements there, not desired new FPS semantics here. Keep explicit initial-overlap, finite-segment and map-boundary contracts.
- **Parallelism:** the collision world owns mutable candidate/cache/query scratch data, and movement resolution can mutate flags, health and contacts. Reusing that world concurrently would require a new ownership scheme. Our workers should read immutable geometry and frozen dynamic states, use private scratch, and return results/events for ordered commits.
- **Evidence:** no comparable FPSloppa 64-player speedup follows from this code review. OpenNova is architectural/reference material; its retail-oriented fixed-point arithmetic is not itself evidence of faster execution on this VPS. Its root license is MIT; no upstream source was copied into the gameplay implementation during this assessment.

## Proposed collision world

**Static data:** export the existing baked heightfield at its exact scale/diagonal convention, structure AABBs, bridge OBBs, trunk cylinders, solid boundaries and stable material/layer/shape IDs. Use a coarse spatial grid with per-cell primitive BVHs and a heightfield min/max hierarchy. Handle long/large primitives conservatively across cell boundaries. Keep a triangle fallback for geometry that cannot be represented faithfully by those primitives. Full authoritative static residency is independent of client grass/tree LOD and culling.

**Dynamic data:** a compact per-tick array for 64 player cylinders, vehicle hull/turret compounds, deployable solids and moving supports. Build conservative old-to-new swept bounds; include life and map generation. Reuse existing native anatomical hit geometry and lag history for shots. Water, road mobility and gameplay fields remain explicit typed tests/events, not generic fluid or rigid-body simulations.

**Query API:** batched raycasts, finite-radius sweeps, overlap/recovery, floor/support probes and bulk character movement. Return earliest hit fraction, normal, stable object/shape ID, material, penetration and support information. Separate movement/ballistic/LOS/trigger masks without loosening existing cover. Keep narrow-phase scratch and contact storage preallocated per worker. Avoid a GDScript/Variant conversion for every primitive test.

**Controller:** preserve CS acceleration/friction/jump/fatigue and cylinder dimensions; replace its slide/step/snap/recovery implementation with one native contact pipeline. Attempt additional stair work only when the relevant contact requires it. Zero motion must still recover from genuine overlap or a changed support. Vehicle sleep must wake for slope/gravity/support changes, driving, destruction and map updates. Arbitrary fast motion needs continuous collision detection, including initial overlap; a height clamp or discrete center sample is insufficient.

**Parallel phase:** freeze the collision scene; dispatch coarse static-query/movement preparation batches to 2/4 workers; resolve player/vehicle moving pairs and support dependencies in stable order; then commit transforms and gameplay events. Crossing trajectories require relative-motion tests, not just final-position overlaps. Players standing on players create dependency islands: process coupled islands coherently and expect less parallelism in dense combat. Never mutate live CharacterBody nodes, shared caches or damage state from these workers.

**Integration:** begin as a reusable C++ service behind the existing native extension. In shadow mode it receives frozen inputs and compares query/controller results without committing a second set of gameplay effects. Native client prediction must use the same collision manifest/controller before authoritative locomotion switches over. Only after all world queries are routed should the replacement stop constructing the corresponding Godot colliders. A partially duplicated scene would retain overhead and can disagree about cover/support.

The service can later move into a standalone server. Implementing a full Godot PhysicsServer replacement is possible, but its extension API includes many required body/shape/area operations and broad compatibility obligations. Registering a custom server occurs at startup, not as a runtime switch. That is a larger integration scope than the proposed gameplay service. [PhysicsServer3DExtension](https://docs.godotengine.org/en/4.7/classes/class_physicsserver3dextension.html), [PhysicsServer3DManager](https://docs.godotengine.org/en/4.7/classes/class_physicsserver3dmanager.html).

## Kernel choice and performance gate

Compare three implementations behind the same exported-world/query contracts:

1. Existing Godot reference.
2. Direct native Jolt queries/controller orchestration, to measure the benefit of batching/data ownership without writing every geometric kernel.
3. Purpose-built heightfield/primitive collision, adding more complex narrow-phase math only where coverage requires it.

Jolt documents concurrent virtual-character updates, but this does not mean its default controller matches CS cylinder/support rules or that direct integration is faster than the current backend. Its virtual characters also require explicit treatment for ordinary queries and character-character contacts. It is a useful benchmark alternative, not an established performance winner. [Jolt character architecture](https://jrouwe.github.io/JoltPhysics/#character-controllers).

A custom terrain path should traverse only swept-footprint cells with conservative min/max rejection, then test the finite hull against the actual terrain surface. Ray traversal must preserve earliest hits through narrow ridges and thin walls. OpenNova's coarse/refine separation is a useful pattern; copying its retail march increments or merely bilinearly sampling the player's center would not provide that contract.

Using the *same attributed run* as an illustrative fixed-rest model: average wall interval is 49.66 ms, of which measured queries account for 18.96 ms. Holding everything else constant gives:

| Replacement query phase | Modeled tick interval | Modeled average Hz |
|---:|---:|---:|
| 8 ms | 38.70 ms | 25.8 |
| 5 ms | 35.70 ms | 28.0 |
| 3 ms | 33.70 ms | 29.7 |
| 0 ms, impossible limiting case | 30.70 ms | 32.6 |

These are arithmetic scenarios, not speedup forecasts. They assume the recorded query work maps directly to replacement critical-path latency and leave profiling/other work fixed. Reaching 30 Hz by query reduction alone would require roughly 2.63 ms for this phase, about an 86% reduction. A rewrite that also removes repeated controller/state marshalling can improve the remainder, but that saving must be measured separately. State orchestration and replication still need optimization for comfortable tail-latency headroom.

The first milestone should be a query/controller benchmark on the **exported real map**, with identical traces for 64 actors distributed across terrain, dense POI stairs/interiors, trunks, bridges, prone clearance, stacking and high-speed jetpack/vehicle paths. Record candidates, feature tests, contacts, recovery iterations, allocations, marshal time, worker waits and p95/p99 elapsed time, including actor/location-tagged long calls. Compare at 1/2/4 workers and retain a serial reference.

Correctness gates: no missed thin-wall/terrain hits, stable earliest-hit ordering, matching slope/stair/ceiling outcomes, no terrain penetration or unintended player lift, valid overlap recovery, correct moving-support/stack behavior, unchanged road/water/runover rules and compatible client prediction. Keep tolerances explicit and validate visible traversal, not only synthetic distances. Then repeat off-host 64-player full-combat/utility/vehicle/network tests. Do not mark a complete replacement successful on a flat-plane microbenchmark or connection survival alone.

## Implemented CS-only change and validation

- Fixed CS actor creation and cylinder hulls; removed Quake toggle and replicated selection.
- Removed active configuration/default/range entries and RCON help/command. Old config entries cannot enable it.
- Updated class protocol and synthetic-client handshake to require matching CS-only builds.
- Updated current gameplay documentation and both 32/64 sample configurations.
- Frontier integration, 31 CS movement checks and paired real ENet server/client tests pass, including ignoring the retired snapshot field. Existing fixture cleanup warnings remain.
- New portable package built locally. Production VPS was not changed or restarted.

Evidence: [CS-only test logs](validation/voxel-battle/cs-only-20261014/). No collision engine implementation or OpenNova code import was made in that earlier CS-only change.


## Isolated implementation and measured gates

The proposed first milestone now has a standalone C++17 service and real-map
Godot comparison harness in [tools/collision_service](../tools/collision_service/README.md).
It implements immutable primitive/heightfield collision, continuous translational
sweeps, overlap recovery and a prototype cylinder slide/step/snap controller,
with 32/64-command batches on 1/2/4 workers. It has no live server binding.

[The recorded experiment](validation/voxel-battle/collision-service-20261014/REPORT.md)
passes 534 native checks but fails 26 of 2,368 engine comparisons. Four workers
reduce a 64-command slide/snap batch from 1.341 to 0.423 ms median locally;
these timings are not server tick measurements. Buried terrain exits, grazing
casts and controller velocity/position require compatibility work. Dynamic
islands, moving supports, gameplay integration and client prediction remain
outstanding. A subsequent direct Jolt comparison is documented below. Promotion is explicitly disabled.


## Direct Jolt comparison implemented

The optional direct backend now links pinned Jolt 5.6.0 and runs the same
exported world, traces, pool and batch harness as the custom service. It uses
native narrow-phase queries and a cylinder `CharacterVirtual` adapter.
[The comparison report](validation/voxel-battle/jolt-direct-20261014/REPORT.md)
records 284 passing Jolt regression checks and 18/2,368 failed engine cases,
compared with 26 failures for the custom backend. All 64 isolated movement
comparisons pass for Jolt. Release and full-library sanitizer checks pass.

For 64 commands on one worker, movement takes 0.279 ms median with Jolt versus
1.333 ms custom, and cylinder sweeps take 0.179 versus 3.792 ms. Small sphere
and capsule workloads offer little benefit, and worker scheduling affects tails.
These remain local kernel/controller measurements with frozen static geometry,
not evidence of sustained 64-player server performance. Jolt is the stronger
next candidate for a shadow integration experiment; collision semantics, dynamic
islands and gameplay/client prediction parity still need validation before any
live switch.


## Jolt blocker triage and ramp experiment

[The follow-up experiment](validation/voxel-battle/jolt-blockers-20261014/REPORT.md)
adds 305 passing blocker checks. It tests front-face terrain rays, precise
cylinder-ray intervals, nominal sweep radii, tighter cast tolerance, CS blocking
without horizontal player shoving, support carry and bounded contact handling.
Three legacy cast-distance differences remain visible, while independent analytic
fixtures validate Jolt's physical results. Full release and sanitizer suites pass.

The opt-in test exporter replaces 304 authored tread colliders with 19 thin ramp
slabs while preserving render geometry. Every flight passes both directions
with Jolt stair assistance disabled. This supports omitting per-tread collision
and special stair solving for those authored flights, not removing all CS
small-obstacle stepping or publishing the map change yet. Dense 64-character
blocking islands remain separated with side pushing disabled; vertical stacking
and support transport still pass.

Live server/client bindings, prediction manifest parity, dynamic lifecycle and
mixed rotating-compound islands, typed gameplay integration, and off-host
network/capacity validation remain real gates. A generic rigid-body/joint/soft-body
service and reproduction of observed legacy numerical errors are unnecessary
scope for this kinematic gameplay service. Production remains unchanged.


## Jolt is now the branch runtime default

The runtime selects `Jolt Physics` explicitly in `project.godot`, with enhanced
internal-edge removal for simulation, queries and motion queries. Existing
`CharacterBody3D` movement, vehicle compound bodies, collision layers, exclusions,
space queries and prediction use Godot’s shared Jolt world. There is no second
collision world and no live binding of the standalone `CharacterVirtual` adapter.
Its precision shims, worker batching and contact policy are not implicitly part
of this integration. No separate-thread physics switch has been enabled.

CQ refuses startup if Jolt is unavailable or another backend is selected.
Both endpoints must restart with a Jolt-enabled Godot 4.7 build. Normal client
exports and the dedicated package retain these project settings; custom export
binaries must include the Jolt module. The CQ protocol is now
`fpsloppa-cq-frontier-17-jolt-ramps1`, and the map identity includes the ramp source.
Synthetic load clients use the same protocol constant. Existing VPS processes
and installed packages have not been redeployed.

The runtime map substitutes all 304 tread bodies with 19 thin ramps using
`tools/voxel_battle/stair_ramps.gd`. Visual stairs and baked meshes remain
unchanged; the accepted visual/foot offset remains. The historical exporter can
still disable substitution to reproduce tread geometry. Small-obstacle stepping
remains available for other CS obstacles. CS floor probes now start above the
uphill support plane instead of inside ramp geometry, preventing false ledge
friction; supported uphill tangent motion retains ground acceleration.

[Integrated runtime acceptance and measurements](validation/voxel-battle/jolt-runtime-20261014/REPORT.md)
cover all 19 flights in both directions without stair assistance, player stacks,
32/64-player convergence, prediction, stance/water/jump/jetpack behavior, vehicles,
ordnance, local ENet replication and real-map terrain/bridge queries. This makes
Jolt the branch default, but does not promote 64 slots beyond unsupported status
or establish sustained VPS performance. The earlier direct-native integration
and off-host capacity gates still apply to that separate experiment.
