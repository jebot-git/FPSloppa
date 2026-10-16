# Sparse map rock cover — 2026-10-16

Added 120 formations / 225 rock meshes across Jungle Frontier. Sources are rubberduck's CC0 [more handpainted rocks](https://opengameart.org/content/more-handpainted-rocks) and [handpainted style rocks](https://opengameart.org/content/handpainted-style-rocks). [Asset provenance, source archive hashes and rebuild procedure](../../../experimental-assets/jungle/rocks/README.md).

| Location | Formations | Rock meshes |
| --- | ---: | ---: |
| Existing exposed rocky ridges | 41 | 81 |
| Foothills / slopes | 28 | 50 |
| Outside road verges | 28 | 50 |
| Riverbanks | 16 | 27 |
| Inside rivers | 7 | 7 |
| Small loose stones associated with formations | — | 10 |

The deterministic bake excludes full site footprints plus 22m, road/shoulder clearance, crossings and tree trunks. Capture circles, structures and spawns remain clear. River rocks sit on solid beds and emerge above the surface; conservative radii remain below 4m, preserving a route around them. This is sparse cover rather than a continuous rock field or river barrier.

Ten large rock variants reuse authored collision meshes; four loose-stone variants are decorative. All variants share one mipmapped VRAM-compressed colour atlas and one cached material using existing day/night/weather irradiance and vehicle headlight shading. Offline Godot ImporterMesh simplification generates indexed LODs, with one surface per mesh. Static 64m MultiMesh batches use engine frustum culling, screen-size LOD and a 700m distance limit. No per-frame rock script is added. Collider residency is independent of render visibility.

## Visual review

- [Large outcrop among vegetation](outcrop.png)
- [Smaller verge cover](verge.png)
- [Exposed rock in river, channel remains passable](river.png)
- [Same outcrop at night with NVG](night.png)

Reviewed the actual streamed map, not isolated asset previews. Canopy grass can overlap skirts naturally. New rock shadows are not rebaked into the world light atlas; rocks sample existing spatial irradiance and have no additional realtime shadow pass.

## Validation

[Placement/collision validation](validation.log): 138,186 checks, zero failures. Includes all roads and site exclusions, river exposure/channel width, native visibility bounds, reduced LOD geometry, convex collision count, weapon/LOS ray blocking and CPU navigation source geometry. Navigation is rebuilt from source triangle faces without GPU mesh readback.

[Full standalone world cook](world-cook.log) completed with 9,088 bodies, 1,215,193 navigation polygons and all 25 bundled avatars. [Native Jolt world validation](native-world.log) passed. [Cooked cover verification](server-cover.json) confirms all 215 cover transforms are present as native convex collision pieces and all source hashes are current. Ten loose-stone patches remain non-colliding. Source fingerprints now invalidate navigation/server caches when cover changes.

## Rendering cost

N95 / Intel ADL-N, Vulkan Forward+, full terrain/vegetation renderer, fixed settled cameras. Each visible/hidden comparison uses 100 frames after 25 warmup frames, vsync disabled. Capture output is 1152×720 under the project's canvas scaling; the viewport texture reports 921×576. No players, networking or physics simulation in this render fixture. [Raw timings](render.json).

| View | Extra draws | Extra visible triangles | GPU p50 rocks / hidden | Frame p50 rocks / hidden |
| --- | ---: | ---: | ---: | ---: |
| Outcrop | 17 | 1,039 | 6.072 / 6.155 ms | 7.996 / 8.132 ms |
| River | 14 | 629 | 5.431 / 5.419 ms | 7.426 / 7.212 ms |

GPU medians differ by less than 0.1ms; this short sample does not establish a speedup. Frame medians vary more, while p95 frame times are 8.710/8.955ms and 8.019/8.063ms respectively. Do not treat these as whole-game FPS, server capacity or i7-12700 measurements.

No commit, push or live deployment performed for this task.
