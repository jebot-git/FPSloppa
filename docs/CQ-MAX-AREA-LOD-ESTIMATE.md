# BSP29 versus VoxelSpace at large area with aggressive LOD

2026-10-12. Estimate for the Intel N95 / ADL-N desktop, Godot 4.7.2 Mobile Vulkan, 1440×900 mono. This is a calculation using the existing 250 m experiments, **not a new maximum-size rendering benchmark**. No production renderer or district capacity changes are included.

## Area and format limits

The project imports Quake coordinates at 1/32 metres per unit (`deathmatch/maps/loader.gd`, `addons/bsp_importer/bsp_reader.gd`). BSP29 node and leaf bounds use signed 16-bit coordinates. Their representable span is approximately 65,536 units, giving a roughly **2.048 km square / 4.19 km²** bounding envelope at this scale. Leave room for compiler padding; this is not a guarantee that a detailed map of that size will compile. Vertices are floats, so this is a bound on correctly represented spatial bounding boxes, not an absolute limit on every vertex field. Faces, vertex indices, nodes, clipnodes and compiler limits can constrain detailed maps earlier. The original Quake design bounds include 32,767 nodes and 65,535 vertices/faces. [Original BSP29 definition](https://github.com/id-Software/Quake/blob/master/WinQuake/bspfile.h).

That envelope is 8.192 times the current 250 m map width and **67.11 times its area**. VoxelSpace has no corresponding BSP29 coordinate-format ceiling. Its practical limits are terrain storage, streaming, traversal distance, precision and polygon structures. The present prototype is finite, resident and configured for 250 m; it does not already implement a streamed large world.

Minimum GPU height/color buffer storage for a 2.048 km square, at four bytes each per sample:

| Grid spacing | Samples per side | Height + color |
|---|---:|---:|
| 0.5 m | 4,097 | 128.06 MiB |
| 1 m | 2,049 | 32.03 MiB |
| 2 m | 1,025 | 8.02 MiB |
| 4 m | 513 | 2.01 MiB |

These exclude CPU copies, meshes, collision, texture pyramids and rendering targets. Reusing the current 513² grid across the larger area saves memory by reducing spatial detail to 4 m; it does not preserve the existing approximately 0.49 m sample spacing.

## Performance estimate

Keep a **250–300 m detailed view radius**, simplify distant buildings to the existing 86-triangle proxy, and stream/cull geometry beyond that radius. Under these assumptions, larger total area mostly increases storage and loading work rather than frame cost. Do not multiply frame time by 67.

| Approach | Expected scaling from 250 m to a 2.048 km square | Timing evidence / planning expectation |
|---|---|---|
| Spatially partitioned BSP-derived polygon meshes with aggressive LOD | Approximately constant for the same visible materials, triangles, shadows and radius; dense interiors can increase cost | A few milliseconds is a reasonable map-only target for simple factory content, but there is no matched BSP measurement establishing a numerical range |
| Classic VoxelSpace columns, 360×225 internal resolution, polygon factory | Approximately constant at fixed traversal distance; more traversal if drawing to a distant horizon | Current 250 m hybrid: 2.599 ms median / 4.708 ms p95. Use **roughly 2.5–4 ms median** as a provisional planning allowance with aggressive sampling, not a measured 2 km result |
| OpenNova-inspired raster heightfield patches with LOD | Approximately constant visible mesh budget, provided selection and residency also remain bounded | Current patch/factory scenes: approximately 1.7–2.3 ms median, depending on view and repeat; this is the strongest existing local baseline |

The column timing estimate assumes the same simple terrain shading, limited nearby polygon structures and output resolution. It could be exceeded by bandwidth pressure, denser structures, shadows or other presentation changes. It does not establish that columns beat a tuned BSP renderer. Patch rendering is ordinary GPU rasterization of a heightfield; it is distinct from classic VoxelSpace screen-column traversal and from greedy voxel meshes.

For the column renderer, sampling grows approximately logarithmically with far distance. The shader advances `d_next = d + base_step + adaptive_step * d`, starting at 0.4 m. Upper bounds before skyline early exit:

| Sampling | 250 m | 300 m | 2,048 m |
|---|---:|---:|---:|
| Existing: base 0.25 m, factor 0.007 | 297 samples/column | 320 | 582 |
| Aggressive proposal: base 1 m, factor 0.02 | 91 | 98 | 189 |

At 360 columns, the aggressive 2,048 m case is at most about 68,040 terrain samples/frame, versus 106,920 for the existing 250 m settings. Initial sky writes and vertical terrain fills also depend on internal pixel count, not total terrain area. This makes roughly current-cost distant horizons plausible, but the larger steps can miss narrow hills and produce visible popping. There is no filtered height hierarchy in the current implementation to control this error. Those proposed sampling parameters have **not** been visually validated or benchmarked.

## Work needed to make the estimate hold

The BSP reader can separate meshes on a grid, but that option defaults off and the runtime loader does not enable it. It batches opaque world faces by texture into large meshes and generates Godot occluders; it does not use Quake PVS for rendering. Aggressive BSP LOD is therefore additional import/runtime work, not a benefit automatically supplied by the BSP29 format. Large texture batches can keep otherwise hidden geometry submitted when their bounds remain visible.

The patch renderer contains hardcoded 250 m origins/bounds and scans its current 64 patches when the camera moves. Preserving approximately 32 m chunks over the larger envelope would require roughly 4,096 chunks. Scanning all of them each update and retaining all meshes would defeat the bounded-work assumption. Add spatial selection, terrain streaming, a coarse distant representation and seam handling. The classic column renderer accepts extent parameters, but resident buffers, collision and polygon-building placement also need a large-world design.

BSP-derived meshes are a good fit for multistorey interiors, overhangs and collision. A single-height VoxelSpace field cannot represent those interiors; the factory must remain polygon geometry. The column prototype also uses yaw-only projection. A fair comparison must use the same factory geometry, materials, camera, shadows and gameplay features. The existing district BSP scene's approximately 19.8 ms median has different content and presentation and is **not** evidence of an inherent BSP performance disadvantage.

## Effect on the 32-player goal

Existing 32-avatar tests with springs off and avatar distance LOD remain about 12.3–12.9 ms median and 18–20 ms p95 across generated map variants. Map medians cannot be added directly to these scene medians: these are overlapping full-frame measurements. Increasing area while bounding visible terrain should preserve similar rendering cost; neither terrain method removes the avatar/spring bottleneck or certifies reliable 60 fps with 32 nearby avatars. Sparse players across a large area may reduce visible avatar cost, but district population is not the same as simultaneous nearby rigs.

Prefer the measured patch heightfield plus polygon factory/interiors as the next large-area baseline. Retain classic columns as an alternative for distant terrain, where coarse detail is acceptable. Do not change district capacity based on this estimate.

Existing measurements: [factory mesh/LOD experiment](CQ-FACTORY-MESH-OPTIMIZATION.md), [VoxelSpace experiment](CQ-VOXEL-FACTORY-EXPERIMENT.md), [raw patch/column timings](validation/cq-voxel-factory-rendering.json), [raw factory/voxel timings](validation/cq-factory-mesh-optimization.json).
