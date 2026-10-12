# Factory CSG, mesh placement and voxel LOD experiment

2026-10-12, `experimental/cq-voxelspace`, building on `99b177f`. The existing 445 factory boxes were already batched into one ArrayMesh surface. Boolean union does not improve that draw count and increases tessellation. Conservative removal of completely hidden box faces saves 6.2% of triangles; distant visual proxies save substantially more. Neither produces a demonstrated frame-time win for the 32-avatar target on this desktop.

## Geometry comparison

| Factory representation | Triangles | Draw surfaces | Result |
|---|---:|---:|---|
| Original boxes, batched | 5,340 | 1 | Reference |
| Native Godot CSG, baked | 13,190 | 1 | More intersection triangles |
| OpenSCAD `.csg`, actual editor importer | 13,024 | 1 | More intersection triangles |
| OpenSCAD `.scad` → OFF → Blender planar cleanup | 13,372 | 1 | Cleanup leaves triangle count unchanged |
| Exact coordinate-compressed greedy union | 8,738 | 1 | More than reference despite merged exposed rectangles |
| Completely hidden face culling | 5,008 | 1 | 166 quads removed; partially covered faces remain unsplit |
| Factory medium / distant visual proxy | 4,230 / 86 | 1 | Removes interior details / substitutes opaque massing |

OpenSCAD's evaluated CSG text rounds coordinates; exporting that tree and the original high precision SCAD produces different triangulations. The measured importer uses the CSG result, not the 13,372-triangle SCAD export. All near candidates pass the interior probes. Blender collapse decimation produces 7,354 and 4,750 triangles, but moves bounds and floors; these are exploratory assets, not chosen near replacements.

The new `addons/openscad_import` editor plugin compiles `.csg` with OpenSCAD, reads its triangular OFF output and saves a one-surface ArrayMesh. It is enabled only in this experimental worktree. Source units are **metres**, with Z-up → Y-up conversion. An optional `.palette.json` restores this factory's colors; general OpenSCAD material semantics are not implemented. Reimport the CSG after changing its palette. Imported meshes need no live CSG or OpenSCAD process at runtime. Godot documents CSG as an expensive prototyping operation and provides static mesh baking; baking alone does not guarantee fewer triangles. [Godot CSGShape3D](https://docs.godotengine.org/en/stable/classes/class_csgshape3d.html), [editor import plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/import_plugins.html).

Factory LOD uses distance to the nearest point on the building bounds. LOD0 → LOD1 above 90 m, back below 70 m; LOD2 above 160 m, back below 140 m. Interiors retain LOD0. The far shader paints window bands on opaque boxes; it does not retain open windows, stairs or interiors. These are visual meshes, with no gameplay collision implementation.

## Voxel terrain placement

Offline greedy meshing writes 64 chunks of 31.25 m, each with three prebuilt meshes at cell sizes 0.9766 / 1.9531 / 3.9063 m. Runtime switches meshes, frustum visibility and hysteresis only. All-fine/middle/coarse totals are 114,414 / 30,428 / 8,166 triangles. The 2.4 m factory yard is exact at every level; hills become visibly stepped and coarse levels change the terrain silhouette. Each chunk includes closed boundary sides and a bottom, retaining redundant hidden faces to seal transitions between different resolutions.

Distance thresholds are 45 / 100 m, returning at 35 / 80 m. Stationary cameras and teleports resolve both level transitions immediately; the corrected front view contains 4 fine, 12 middle and 28 coarse visible chunks. Monolithic variants compare one terrain draw against chunk placement; they lose per-chunk visibility and independent LOD. There is no voxel editing, asynchronous streaming or terrain collision in this prototype.

## Actual Vulkan measurements

Intel N95 / Intel ADL-N GPU, Godot 4.7.2 Mobile Vulkan, 1440×900, mono, MSAA and vsync off. Each case has 120 warmup frames and 360 sampled frames. 35 cases include front, reverse-order repeats, diagonal, interior, moving flyby, far and repeated 32-avatar cases. Blender was closed before measuring. Screenshots are saved outside timing intervals. The first trial was discarded after finding the stationary-camera LOD bug.

| Front case | Frame median / p95 (ms) | GPU median (ms) | Draw calls |
|---|---:|---:|---:|
| Reference | 2.076 / 4.489 | 1.291 | 5 |
| Native baked CSG | 2.121 / 4.292 | 1.330 | 5 |
| OpenSCAD importer | 2.071 / 4.338 | 1.305 | 5 |
| Blender planar | 2.034 / 4.575 | 1.320 | 5 |
| Greedy factory union | 2.037 / 4.579 | 1.315 | 5 |
| Hidden-face culling | 2.038 / 4.467 | 1.311 | 5 |
| Fine voxel chunks | 2.519 / 4.902 | 1.684 | 45 |
| Voxel chunks with LOD | 2.039 / 4.159 | 1.192 | 45 |
| Monolithic fine voxels | 2.681 / 4.999 | 1.837 | 2 |
| Monolithic coarse voxels | 2.197 / 4.625 | 1.487 | 2 |

Reference/culling reverse-repeat frame medians are 2.127 / 2.134 ms. Voxel LOD repeats at 2.281 ms, GPU 1.443 ms. These differences do not support a reliable front-view speedup. Voxel LOD reduces front terrain triangles from 62,336 to 10,100, but adds draws and changes geometry. Fewer draws also do not make the monolithic fine variant faster. The far proxy reduces the factory from 5,340 to 86 triangles, while measured far frame medians remain 1.708 ms reference / 1.742 ms proxy.

With 32 animated copies of bundled D, springs off and existing production avatar LOD, reference medians are 12.576 / 12.286 ms and p95 18.367 / 18.222 ms. Factory LOD medians are 12.339 / 12.609 ms and p95 18.317 / 19.184 ms. Voxel LOD is 12.920 ms median / 19.429 ms p95. These changes **do not achieve reliable 60 fps for 32 nearby avatars**. This is not a test of 32 distinct uploaded models, district networking, combat, full spring physics or XR. Keep the existing district capacity decision; this experiment provides no evidence to raise it.

## Validation, tooling and reproduction

471 checks pass: all four floors, open facade windows and stairwells, all 48 stair steps across every near mesh, actual imported CSG, one-surface batching, near/far factory LOD, voxel culling, stationary/teleport LOD and closed chunk sides. The original stair probe at x=24 intersects a structural column at step 11. Boolean unions legitimately remove that hidden stair face; the new probe uses x=24.6 on the exposed tread. Independent greedy mesher fixtures verify six-quad solid cubes, inward cavity surfaces and enclosed volume 26. Render log has no errors or warnings.

OpenSCAD MCP 0.6.1 is installed in `~/.local/share/openscad-mcp-venv` and registered as `openscad` in Codex. The stdio MCP client actually exercised availability, syntax validation, CSG and OFF exports, using [RobertCoop/openscad-mcp](https://github.com/RobertCoop/openscad-mcp) pinned to `bde0b238c29c45408fef6f54aae7a1a14d5b64ee`. Blender MCP ran planar and collapse modifiers in a separate scene and saved `test-results/factory-optimization/factory-optimization.blend`; the user's startup scene was retained. Krita was unnecessary for geometry and frame-time work.

Preview: `./launch-factory-optimization.sh`. WASD/QE fly, RMB yaw, keys 1–8 compare candidates. Benchmark: `./launch-factory-optimization.sh --benchmark`. Geometry: `Godot --headless --xr-mode off --path . --script tools/voxelspace/validate_optimization.gd`. Set `GODOT_BIN` to override the launcher executable.

Regeneration: run `export_factory.gd`, then `openscad_mcp_bake.py` with the MCP venv Python; run `bake_csg.gd`; run `greedy_mesh.py` with NumPy and `cull_factory_faces.py`; run `blender_factory_cleanup.py` through Blender (`runpy.run_path` in the isolated scene, or `--python`); run `bake_meshes.gd`; reimport in the editor. CSG and palette sources and baked assets are included for direct preview. New machines need OpenSCAD for CSG import and the same Godot release for binary resource compatibility.

[Full measurement and geometry receipt](validation/cq-factory-mesh-optimization.json), [near interior](validation/cq-factory-culled-interior.png), [voxel LOD view](validation/cq-factory-voxel-lod.png), [far proxy](validation/cq-factory-far-proxy.png). Receipt includes source and asset hashes. Factory/terrain LOD counters in moving cases are final-frame snapshots; frame/render counters are sampled percentiles. The map has finite 250 m bounds, so outside views can see sky below its perimeter.

Retain the heightfield patch renderer as the measured baseline. Use hidden-face removal and far factory proxies where the content pipeline benefits, without expecting this factory to resolve avatar CPU or GPU cost. Consider batching compatible voxel chunks by LOD, with an explicit streaming/visibility tradeoff, before further voxel work.
