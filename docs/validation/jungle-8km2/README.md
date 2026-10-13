# Jungle Frontier validation and foliage comparison

Godot 4.7.2, Vulkan Mobile, Intel Arc A770. Local runs on 12–13 October 2026.
The foliage runs contain no avatars, AI, navigation or physics simulation.
Stereo is simulated using two independent 2160×2376 viewports, not WiVRn
multiview. Camera transforms, IPD, terrain, seeded plant transforms, culling,
LOD thresholds and scene lighting are matched between modes.

## Final foliage results

Median summed-eye GPU time in milliseconds. Mesh and SVO values come from the
initial four-mode run; billboard and hybrid values come from the follow-up
with the final compressed, mipmapped atlas. Other scene inputs are unchanged.
Each cell represents 15 measured seconds after terrain settling and a
three-second mode warmup. Readbacks are outside measurement.

| View | Visible plants | Mesh | Billboard | Hybrid | Sparse octree |
|---|---:|---:|---:|---:|---:|
| Canopy edge | 949 | 0.549 | 1.206 | **0.485** | 54.528 |
| Canyon overlook | 967 | 0.530 | 0.851 | **0.450** | 41.792 |
| Mountain foothills | 87 | 0.372 | **0.359** | **0.359** | 7.391 |

Whole-application frame timing, median / p95 (milliseconds):

| View | Mesh | Billboard | Hybrid | Sparse octree |
|---|---:|---:|---:|---:|
| Canopy edge | 1.921 / 4.287 | 3.086 / 5.134 | 1.851 / 4.231 | 54.661 / 56.912 |
| Canyon overlook | 1.922 / 4.285 | 2.222 / 4.486 | 1.834 / 4.187 | 41.873 / 44.447 |
| Mountain foothills | 1.049 / 4.013 | 0.915 / 3.937 | 0.919 / 3.923 | 7.516 / 9.909 |

**Keep hybrid as default:** real geometry near and in the middle distance,
cutout cards far away. Mesh-only remains competitive. Full billboarding helps
little in the sparse view and costs more under dense canopy. The SVO prototype
is much slower in all three views, especially dense canopy; its GPU median
nearly accounts for the complete application frame. Given the bounded tiny
SVO assets and matching instances/draw counts, the expensive work is the
per-pixel octree ray traversal, overlapping proxy volumes and custom-depth
fragment processing. This is an inference from the mode comparison and shader
implementation, not a hardware instruction-level profile.

The result applies to this fragment-shader SVO prototype and these low-polygon
tree assets, not every possible voxel renderer. Compute-based traversal,
coverage/depth rejection, larger geometry workloads and true native XR would
need their own tests. CPU and GPU overlap; eye GPU times do not include the
window compositor, while application frame times do.

The raw atlas had no mipmaps or VRAM compression. Compression plus mipmaps
reduced the dense-canopy full-card GPU median from 2.356 to 1.206 ms (48.8%).
Application frame median changed from 3.139 to 3.086 ms, so this did not produce
an equivalent whole-frame speedup. S3TC atlas data with mipmaps occupies about
1.33 MiB, versus 4 MiB for the original uncompressed atlas without mipmaps.

## Receipts

* `baseline/results.json`, `baseline/frames.csv.gz`: all four modes, 180
  measured seconds, 70,725 samples; 230.857 s including setup/warmups/readbacks.
* `mipped/results.json`, `mipped/frames.csv.gz`: changed card modes only,
  90 measured seconds, 45,426 samples; 122.671 s including setup/warmups/readbacks.
* Images in each run directory are left-eye captures after each measured phase.
* `terrain.json`: 11,836 successful area, elevation, deterministic planting,
  tile seam, reserved-pad, water-edge and all-LOD road-clearance checks.
* `environment.json`: 279 successful culling, LOD, matched-instance,
  load/eviction/regeneration and SVO demand-streaming checks.
* `physics.json`: 97 successful world-ground, spawn, pad, boundary, interior,
  complete POI connectivity and bounded staged-routing checks.
* `water.json`: 906 successful water continuity, pier safety, actual fighter
  kill/armour/spawn-protection, score and respawn checks.

Streaming peaked at 245 resident terrain tiles and two worker jobs; 729 tile
uploads occurred in the initial run. Tile generation median was 37.287 ms on
workers; upload median was 0.027 ms. The atlas cache remains capped at 384 tiles
and two terrain uploads/frame. Canonical SVO resources total 224 KiB: six shared
species/LOD octrees, demand-loaded with at most two uploads/frame and evicted
when unused. Instance transforms stream with terrain tiles. This does not
allocate or page a separate unique octree for each planted tree.

The collision test covers 2,030,625 height samples and 93,214 authoritative
trunk colliders grouped by tile. Navigation has 196 cached chunks and 1,144,828
polygons, with 180 explicit road-seam walk links. Runtime staged routes use a
359-node road graph and the native 4,096-polygon query cap; trips from radar to
the five sites took 12, 12, 11, 11 and 1 local legs. Unlimited queries are used
only by offline connectivity assertions.

Godot emitted NaN-normal warnings during deliberate ray probes into water
holes, and a few navigation edge-merge warnings in the cached forest geometry.
All listed assertions pass, including all 38 interior storeys and long routes.
These receipts are not a new 16v16 gameplay or network/XR validation run.

Reproduction and authoring: [map documentation](../../JUNGLE-8KM2.md).
