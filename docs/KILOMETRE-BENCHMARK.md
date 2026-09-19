# One-square-kilometre BSP29 / 64-bot prototype

Measured on 2026-09-19 using Godot 4.7.2 Fedora (editor/debug-capable runtime), Core i7-12700, Intel Arc A770, Mobile Vulkan, 1280×720, 4× MSAA. These are local offline measurements, not release-build, VR, or network capacity guarantees.

## Map and validation

- Exactly 1,000 × 1,000 m playable ground; centred at the origin. BSP29, 2,387,232 bytes. The sealing walls extend to ±502 m.
- Sixteen connected districts, 64 buildings, cover, roads, ramps, 64 spawns and 128 pickups.
- Baked lightmap import has no invalid faces. Fast VIS is used for this prototype.
- 11,448 map triangles; original importer mesh split into 80 spatial batches; 114 inset box occluders.
- Coarse navigation: 4,126 polygons at 1 m horizontal / 0.25 m vertical resolution. All 64 spawn floor rays and paths from the first spawn pass. The diagonal route contains 105 points.
- All 64 bots moved and fired in every run. Real movement, weapons, pickups, damage, deaths and respawns were enabled. No AI sleeps behind occlusion.

## Active simulation

| Run | Simulated / wall seconds | Achieved speed | Game tick p50 / p95 | Shots / deaths |
|---|---:|---:|---:|---:|
| Headless, target 1× | 120.02 / 216.57 | 0.55× | 26.54 / 50.72 ms | 13,434 / 305 |
| Desktop, target 1× | 30.02 / 107.20 | 0.28× | 38.42 / 66.92 ms | 6,016 / 87 |
| Live follow camera, target 4× | 30.02 / 105.71 | 0.28× | 38.68 / 65.77 ms | 5,803 / 93 |

The 4× request uses `Engine.time_scale = 4` and 240 physics ticks/second, preserving a 1/60 s simulated movement step. It achieved **0.28×**, so **4× real-time playback was not reached**. Its measured mean rendered frame interval was 467.99 ms (approximately 2.1 FPS); p95 was 561.99 ms. The live overlay displays requested speed, achieved speed, simulation time and FPS.

Tick percentiles exclude the initial ten simulated seconds. `game_tick_ms` measures the explicit game physics call, plus the game visual update in graphical runs. It excludes other node processing, renderer work and the benchmark bookkeeping. `engine_physics_ms` is Godot’s aggregate physics processing per engine frame, which may contain several catch-up ticks; it must not be interpreted as cost per individual tick. Wall-time speed includes the full active run, after map/avatar/navigation setup.

The projectile pool reached its 256-projectile cap. The headless run sampled about 61 MiB of Godot static allocations; the desktop run about 350 MiB. These counters exclude total process RSS and GPU memory. The real-time target is already missed headlessly, establishing a simulation CPU bottleneck independently of GPU rendering. Graphical avatar/effect processing adds further cost. Detailed CPU profiling is needed before attributing that cost to a specific subsystem.

## Matched rendering comparison

Identical actors and camera are frozen for each comparison. Each case uses 90 warmup frames and 240 measured frames. These fast static frame times are **not live-match FPS**. Rendering timings below are medians.

| View | Representation | Draw calls | Triangles/primitives | GPU ms | Render CPU ms | Frame ms |
|---|---|---:|---:|---:|---:|---:|
| district | original | 628 | 378,834 | 0.711 | 0.501 | 1.371 |
| district | zones_off | 718 | 338,571 | 0.641 | 0.554 | 1.504 |
| district | zones_on | 685 | 335,219 | 0.651 | 0.956 | 2.095 |
| gate | original | 414 | 320,624 | 0.676 | 0.343 | 1.056 |
| gate | zones_off | 483 | 277,558 | 0.627 | 0.351 | 1.064 |
| gate | zones_on | 304 | 203,736 | 0.593 | 0.550 | 1.241 |
| overview | original | 184 | 138,804 | 0.476 | 0.204 | 0.735 |
| overview | zones_off | 238 | 94,435 | 0.428 | 0.217 | 0.718 |
| overview | zones_on | 204 | 84,413 | 0.422 | 0.437 | 0.987 |

`original` is the importer mesh without occlusion; `zones_off` uses district batches with frustum culling; `zones_on` adds native occlusion. Gate-view occlusion reduces submitted primitives by 26.6% and draw calls by 37.1% relative to `zones_off`. Nevertheless, the CPU overhead raises total median frame time in all three views. This low-detail environment is too inexpensive to draw for these occluders to pay off on this hardware. Keep this as an opt-in experiment; do not enable the same policy globally on the strength of triangle savings alone.

All three off/on screenshot pairs were pixel-identical. That checks the sampled views, including a view through an opening, but is not exhaustive proof against culling artifacts at every camera position. Larger/diverse scenes, more viewpoints, lower-end CPUs and VR need separate tests.

Godot’s occlusion culling operates on render instances, which motivates spatial mesh splitting; it incurs CPU work and may be unsuitable for open or inexpensive scenes. [Godot occlusion documentation](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).

## Scope and reproduction

The shipped dedicated limit is 32. Only the offline benchmark overrides population to 64. There are no remote clients, snapshot traffic or latency in these tests; this does not establish 64-client networking support. Existing production settings, maplists and base asset bundles are unchanged.

The importer’s lightmapped material path and the production two-effect weapon illumination cap are retained. Graphical runs emitted existing MultiMesh physics-interpolation warnings from `deathmatch/experimental/visuals.gd`; no script failures occurred. Shutdown reported one leaked ObjectDB instance headlessly (also present in check-only runs), and six instances plus one resource still in use in the live graphical run. These shutdown diagnostics remain unresolved; they are not a clean shutdown claim.

See [map source and commands](../maps/Benchmark1km/README.md), [machine-readable results](validation/kilometre-benchmark.json), and [benchmark harness](../tools/km_benchmark/simulate.gd).

Local screenshots: [overview](../test-results/km-benchmark/overview-zones_on.png), [gate](../test-results/km-benchmark/gate-zones_on.png), [4× live view](../test-results/km-benchmark/live4x64.png). Screenshots and raw run logs are generated local artifacts; the consolidated JSON is retained with this report.
