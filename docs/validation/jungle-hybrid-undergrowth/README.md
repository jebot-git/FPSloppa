# Tall grass, occasional undergrowth clusters and longer hybrid range

Tall grass is dominant; broad-leaf plants and two larger bush shapes occupy irregular seeded patches. Current residency checks found **92.45% tall grass, 3.47% broad-leaf clumps and 4.08% bushes** (119,824 candidate clumps). Grass is approximately 1.0–1.5 m high and bushes 1.5–2.0 m after seeded scaling. All undergrowth is collision-free. Opaque near/middle meshes switch to fixed-Y cutout billboards at 36 m, using a mipmapped atlas baked from the same near assets. This matches the trees' hybrid rendering approach. Terrain workers/residency/eviction remain shared.

The default radius is **96 m**, with 24/64/96/144 m controls in the live preview. Near/middle/far reservations total 2,048 instances, with at most 12 undergrowth MultiMesh draws per eye. Stable distant thinning, frustum/tile bounds and an eight-metre camera-relative height limit constrain submissions. CPU refreshes are limited to 30 Hz. More distance does not add collision or change authoritative simulation.

## Simulated stereo distance comparison

Godot 4.7.2, Vulkan **Forward+**, Intel Arc A770. Two 2,160×2,376 independent eye viewports, 92° vertical FOV and 64 mm IPD. Hybrid trees, terrain and structures are held constant. Three standing views at 1.7 m and one prone view at 0.45 m each repeat a five-second ±2 m walking/small-yaw sweep. Off plus four radii, 15 measured seconds each, six-second warmups, screenshots outside measured frames. No avatars, AI, physics simulation, headset pacing or encoding. This tests foliage cost and visual cover, not a full match or motion-to-photon latency.

**116,725 frames**, all with settled terrain, **300 measured seconds**. Including preparation, warmups and captures: 453.33 seconds.

Stereo GPU median, milliseconds (sum of both eye viewport timings):

| View | Off | 24 m | 64 m | 96 m | 144 m |
|---|---:|---:|---:|---:|---:|
| Canopy edge | 1.278 | 1.318 | 1.438 | 1.351 | 1.443 |
| Canyon overlook | 1.268 | 1.376 | 1.557 | 1.336 | 1.345 |
| Mountain foothills | 0.737 | 0.737 | 0.737 | 0.737 | 0.737 |
| Prone canopy | 1.325 | 1.365 | 1.477 | 1.444 | 1.456 |

Application frame p95, milliseconds:

| View | Off | 24 m | 64 m | 96 m | 144 m |
|---|---:|---:|---:|---:|---:|
| Canopy edge | 4.057 | 4.974 | 7.652 | 9.640 | 14.922 |
| Canyon overlook | 4.366 | 5.178 | 8.141 | 9.518 | 11.441 |
| Mountain foothills | 1.464 | 1.435 | 1.425 | 1.452 | 1.470 |
| Prone canopy | 3.699 | 4.822 | 7.612 | 9.785 | 15.250 |

| View | CPU refresh median, 96 / 144 m (ms) | Visible clumps median, 96 / 144 m | Farthest submitted clump median, 96 / 144 m (m) |
|---|---:|---:|---:|
| Canopy edge | 5.736 / 10.841 | 1184 / 1332 | 95.91 / 143.65 |
| Canyon overlook | 5.617 / 7.481 | 1099 / 1131 | 95.68 / 124.76 |
| Mountain foothills | 0.108 / 0.144 | 0 / 0 | 0.00 / 0.00 |
| Prone canopy | 6.016 / 11.300 | 1230 / 1353 | 95.92 / 143.57 |

GPU cost remains modest, but CPU culling/transform refresh becomes the main measured foliage cost at long distances. Prone frame p95 reaches **15.25 ms at 144 m**, compared with **9.79 ms at 96 m**. Keep 96 m as the prototype balance; 144 m is an experiment and not a smooth-VR guarantee. The canyon does not submit to the full 144 m because slope/vertical eligibility also constrains cover. The high mountain view has no eligible grass. GPU medians are not monotonic across sequential cases; background variation and changing visible LOD composition mean these are workload measurements, not isolated causal estimates. CPU and GPU costs overlap and cannot simply be added or subtracted.

[Standing at 24 m](0-hybrid-24m.png), [standing at 96 m](0-hybrid-96m.png), [standing at 144 m](0-hybrid-144m.png), [prone at 96 m](3-hybrid-96m.png), [prone at 144 m](3-hybrid-144m.png). The taller upright foliage gives visual concealment at prone height; no player-visibility or bot-detection rule was added.

## Validation and reuse

[Validation](validation.json): **2,610 checks, zero errors**. Includes dominant grass with occasional mixed patches, deterministic placement, roads/sites/water exclusions, complete collision-free subtree, actual extended-range submissions, fixed draw/instance budgets, mipmapped far cards, refresh throttling and terrain eviction/reload. [Checks](checks.json) independently verify raw CSV sample counts, settled streaming and reported median/p95 frame/GPU/draw percentiles. [Results](results.json), [compressed frame samples](frames.csv.gz), [run log](stereo.log), [source fingerprints](source-sha256.json).

[Renderer startup](renderer-startup.json) verifies Vulkan Forward+ launches and Mobile/OpenGL overrides exit 2 before gameplay. [Policy log](renderer-policy.log) and [small exported-pack audit](renderer-export.log) verify settings and the runtime guard, including omitted default-valued Forward+ settings. This audits a minimal pack, not a newly rebuilt full release or standalone headset run.

The off-case `grass_max_distance` field in this run retains its preceding enabled-case value; disabled foliage submits zero instances/draws. Ignore that inactive diagnostic field. All enabled-case distance measurements are current. Historical [flat undergrowth/Mobile results](../jungle-undergrowth/README.md) use different geometry and renderer and are not a controlled before/after comparison.

See [map implementation](../../JUNGLE-8KM2.md) for seeding, LOD, streaming, baking and reproduction commands. These foliage assets are original procedural project work.
