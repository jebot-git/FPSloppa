# Streamed 2 km heightfield, VoxelSpace and direct GPU terrain

2026-10-12, `experimental/cq-voxelspace`, built on `5ad293e`. A render prototype covers **2,048 × 2,048 metres (4.194 km²)**, following the previous maximum-area estimate. Sixteen locations repeat on a 512 m grid: four small towns, four multistorey factories, four ports and four military bases. These are generated meshes; the factory reuses the previously validated synthetic factory assets. No BSP or proprietary game assets are required.

The streamed raster heightfield remains the best measured baseline on the Intel N95 / ADL-N desktop. Classic VoxelSpace works against the same streamed source but costs more at full resolution. Direct procedural GPU terrain also works, removes terrain generation jobs and height/color uploads, and costs more GPU time than sampling the cached field on this device.

## World and bounded streaming

The world contains 64 × 64 possible 32 m tiles. Each resident tile has 65 × 65 height/color samples, at 0.5 m spacing. At most **384** tiles can occupy the shared GPU texture arrays. Height plus color storage is **12.38 MiB**, excluding meshes, page tables, coarse textures, CPU scratch, output targets and engine overhead. Two WorkerThreadPool tasks generate deterministic tile bytes; the main thread uploads at most two completed tiles per frame. Completed-but-obsolete results are discarded when the camera moves. Ordinary frame updates never wait for an unfinished worker; benchmark resets and shutdown drain workers outside measured intervals.

Selection examines at most a local 19 × 19 rectangle, rather than all 4,096 tiles. Load/retain radii are 256/320 m with a conservative tile margin. Selection changes on tile-cell crossings. A 129 × 129 globally resident coarse field and one 8,192-triangle coarse mesh cover areas without resident detail. The shader suppresses coarse fragments under resident tiles, so loading and eviction do not remove the whole terrain. Residency is procedural generation and eviction, not disk or network asset streaming.

Four shared patch meshes use 1/2/4/8 m vertex spacing. Distance is measured to the nearest point on each patch: thresholds 48/112/208 m. AABB/frustum culling selects visible patches; each nonempty LOD family uses one MultiMesh draw. Three-metre skirts reduce gaps between differing patch resolutions. There is no geomorph transition; coarse-to-fine popping and transition seams remain prototype limitations. The render far plane is 640 m. This implementation stays within the finite world bounds; it is not an infinite-world system.

Structures use three shared meshes per type, per-site distance hysteresis, a 550 m cutoff and frustum culling. Empty instance groups are hidden, not merely assigned zero visible instances. Shared geometry stays available while placements enter and leave visibility; there is no expensive per-building mesh generation during traversal.

| Structure type | Near / medium / distant triangles |
|---|---:|
| Town | 2,224 / 352 / 216 |
| Factory | 5,008 / 4,230 / 86 |
| Port | 1,588 / 460 / 432 |
| Military base | 576 / 360 / 204 |

Town houses have pitched roofs and near window details. Factories retain the existing hollow four-storey geometry at near LOD. Ports have actual below-water basins, quay/pier meshes, containers, cranes and a cargo-ship proxy. Bases have barracks, hangars, a runway, watchtowers and a radar mast. Water is a static colored polygon surface. Distant meshes simplify interiors and silhouettes; these are visual assets, without gameplay collision or navigation.

## Comparable render paths

**Streamed raster:** reusable mesh patches sample GPU height/color texture arrays. Terrain displacement already executes in a vertex shader; the workers supply the sampled data.

**Classic VoxelSpace:** a compute invocation per screen column walks front-to-back terrain samples and fills the skyline. It samples the same bounded arrays, page table and coarse fallback, rather than allocating a full-resolution world buffer. The same polygon structures and LOD rules render at the final viewport resolution. The composite includes terrain depth. Columns still support yaw-only projection. Quarter/half internal resolutions are 360×225 / 720×450, composited into 1440×900. Full resolution is 1440×900. Aggressive sampling uses base step 1 m and factor 0.02; reference sampling uses 0.25 m and 0.007. Fewer samples can miss narrow features. Reduced terrain resolution is visibly pixelated and is a quality tradeoff.

**Direct GPU shader:** `procedural.gdshader` evaluates the deterministic height function per vertex and ground color per fragment. It uses the same patch families, structure meshes and placement/culling rules. The CPU selects logical patches and updates a small coarse-coverage page table; there are **no terrain generation jobs or height/color uploads while this mode is selected**. Patches become available immediately. This comparison harness still allocates the baseline atlas so users can switch renderers; those unused arrays could be omitted in a dedicated GPU-only implementation. The current measurements do not claim a lower total process memory footprint.

The direct shader preserves continuous ground-color evaluation instead of the atlas's quantized 0.5 m color samples, so color and road edges are not pixel-identical. The GPU and CPU height/color functions are checked independently. A local RenderingDevice computes the exact surface function extracted from the actual shader; readback and synchronization occur only in that separate correctness test, never in the rendering measurements.

## Measurements

Intel N95 CPU / Intel ADL-N GPU, Godot 4.7.2 Mobile Vulkan, 1440×900 mono, MSAA/vsync off, uncapped. Static cases settle requested tiles, warm for 120 frames and sample 360 frames. Alternating renderer order reduces simple order bias. Structure LOD state resets when changing render modes, and GPU-versus-atlas static cases also reset residency to match geometry. Screenshots are captured outside measurement intervals.

The primary moving comparison uses **160 m/s for 20 seconds (3.2 km)** with deterministic yaw-only camera motion and ground-relative altitude. This holds world travel speed constant while allowing each renderer's frame rate to differ. Raster repeats bracket both the VoxelSpace and direct-GPU comparisons. The optional original stress pass advances 4 m per frame for 1,200 frames (4.8 km); faster renderers travel faster in wall time and outrun generation, so those stress figures are not used as the main comparison.

| Settled location views | Frame median range (ms) | p95 range (ms) |
|---|---:|---:|
| Cached raster LOD | 2.07–2.43 | 3.80–4.59 |
| Raster, forced near geometry | 2.55–3.25 | 4.18–6.02 |
| Raster LOD, terrain culling disabled | 2.24–2.65 | 3.95–5.14 |
| Quarter-resolution columns, aggressive | 2.32–2.59 | 4.36–5.17 |
| Quarter-resolution columns, reference | 2.53–2.91 | 4.36–5.09 |
| Half-resolution columns, aggressive | 2.62–2.85 | 4.24–5.39 |
| Full-resolution columns, aggressive | 3.68–3.94 | 5.75–6.30 |
| Full-resolution columns, reference | 4.03–4.20 | 5.71–6.79 |

| Fixed-speed moving comparison | Frame median / p95 (ms) |
|---|---:|
| Cached raster LOD | 2.26 / 4.46 |
| Quarter-resolution columns | 2.53 / 4.64 |
| Full-resolution reference columns | 4.26 / 6.63 |
| Cached raster LOD (repeat) | 2.28 / 4.37 |

| Separate cached / direct-GPU moving comparison | Frame median / p95 (ms) | Generation jobs / height-color uploads |
|---|---:|---:|
| Cached raster LOD | 2.25 / 4.26 | 1628 / 1626 |
| Direct GPU terrain | 2.87 / 4.75 | 0 / 0 |
| Cached raster LOD (repeat) | 2.27 / 4.28 | 1628 / 1626 |

**27,509 CPU/cache/geometry checks pass.** GPU parity passes on **18,689 probes**, with maximum height error **0.333 mm** and maximum raw color error 0.00000304. The direct-GPU and cached static pairs submit identical primitive counts and structure LOD. All sampled frames in the settled and fixed-speed render cases stayed below 16.67 ms; this does not include players or gameplay.

The cold-cache raster start has one **27.93 ms** frame among 480 samples (median/p95 2.03/4.73 ms). Cold quarter columns measure 2.47/4.86 ms, maximum 7.12 ms. The raster case includes initial presentation/pipeline work, while compute initialization happens before the column measurement; these are startup diagnostics, not a matched shader-compilation comparison. After roughly 1.2 seconds the raster case has loaded 162 of 188 requested tiles; after 1.37 seconds the column case has loaded all 188. Coarse terrain remains visible during loading.

Viewport GPU and separate column compute timestamps are diagnostic measurements; do not add their medians or percentiles to derive full-frame cost. Frame time includes CPU work, scheduling and presentation. These timings demonstrate this synthetic content on this device, not an inherent BSP-versus-heightfield advantage or a prediction for another GPU.

The fixed-speed atlas/column runs loaded **1,626** tiles and evicted approximately **1,571** apiece, with a peak of **291/384** resident tiles and p95 pending requests of 17. Thus both render paths exercised comparable streaming work. The GPU shader's logical patch activations are not generated tile-data uploads. During fixed-speed motion it performs zero generation jobs and zero height/color uploads, but still pays CPU patch visibility and page-table costs.

The full-world overview, all four location views, VoxelSpace and GPU-shader views were visually inspected. Validation covers bit-identical adjacent source edges, flattened pads, below-water basins, conservative displacement bounds, decreasing structure LOD geometry, bounded selection/cache/worker counts, unique slots, eviction page invalidation, frustum culling, hidden empty groups, rapid teleports with jobs in flight, switching analytic/atlas modes and outside-world eviction.

## Reproduction and receipts

Run `./launch-streamed-heightfield.sh` from this worktree. WASD/Q/E fly; Shift increases speed; RMB turns yaw. Keys 1–4 visit town/factory/port/base. F1 uses raster LOD, F2 forces near geometry, F3 disables terrain frustum culling, F4/F5 select quarter/half columns, F6 selects full reference columns, and **F7 selects direct GPU terrain**. Escape exits.

`--static` runs the 32 static comparisons; `--paced` runs the fixed-speed raster/column comparisons; `--cold` measures cold-cache starts; `--gpu-shader` compares cached/direct GPU terrain in settled views and fixed-speed motion. `--benchmark` also includes the original per-frame stress pass. `--smoke` captures both raster/column views and the overview. Generated outputs go to ignored `test-results/streamed-heightfield`. `GODOT_BIN` overrides the launcher engine path.

CPU/cache validation: `Godot --headless --xr-mode off --path . --script tools/streamed_heightfield/validate.gd`. GPU parity: `Godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/streamed_heightfield/validate_gpu.gd`.

[Static measurements](validation/streamed-heightfield/rendering-static.json), [fixed-speed columns comparison](validation/streamed-heightfield/rendering-paced.json), [cold starts](validation/streamed-heightfield/rendering-cold.json), [GPU shader comparison](validation/streamed-heightfield/rendering-gpu-shader.json), [cache/geometry validation](validation/streamed-heightfield/validation.json), [GPU parity](validation/streamed-heightfield/gpu-parity.json), [source/asset hashes](validation/streamed-heightfield/sha256.json).

[World overview](validation/streamed-heightfield/world_overview.png), [town](validation/streamed-heightfield/town_raster_lod.png), [factory](validation/streamed-heightfield/factory_raster_lod.png), [port](validation/streamed-heightfield/port_raster_lod.png), [military base](validation/streamed-heightfield/military_raster_lod.png), [quarter-resolution columns](validation/streamed-heightfield/town_columns_quarter.png), [direct GPU terrain](validation/streamed-heightfield/town_raster_analytic.png).

Keep cached heightfield patches as the rendering baseline on this desktop. Direct GPU terrain is feasible and avoids terrain-generation latency, but computing ground color for every fragment costs more than sampling cached colors here. A next experiment could compute cached tiles on the GPU once, preserving cheap raster sampling instead of reevaluating color every frame. That GPU tile-baking pipeline is not implemented by this prototype.

This remains a standalone render experiment. There are **no avatars, spring bones, collision, networking, combat, shadows or XR in these measurements**, and no district admission limit changes. The earlier 32-avatar frame-time limits remain unaddressed by this test.
