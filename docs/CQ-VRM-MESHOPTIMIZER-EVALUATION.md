# VRM import optimization with meshoptimizer

2026-10-12, `experimental/cq-voxelspace`. **On-import optimization is feasible**, with a conservative post-decode pass that preserves the avatar scene. Neither supplied repository's gltfpack is a safe replacement VRM importer in the tested configuration. A validated prototype is in `tools/meshoptimizer`; the production editor and runtime import paths are unchanged.

## Repositories and actual packer results

| Repository | Examined commit | Finding |
|---|---|---|
| [zeux/meshoptimizer](https://github.com/zeux/meshoptimizer) | `b2330430776a95a1545f03fc7bf16927f8cadc59`, 2026-10-09 | Upstream library 1.3; cache/fetch algorithms are usable independently. gltfpack omits VRM custom extensions. |
| [infosia/meshoptimizer](https://github.com/infosia/meshoptimizer) | `82c1daa768a81c853aa7771dfbaaac75b00fbf36`, 2021-04-07 | Fork based on 0.15, with VRM 0.x parser/writer and `.vrm` file handling. Its VRM reference remapping fails the bundled samples. |

Both were built locally and run against bundled D/F/G with `-kn -km -ke -noq` (keep named nodes, materials and extras; disable quantization). Inputs were copied to `.glb` filenames so upstream recognizes the container. Upstream returns valid glTF JSON but drops the entire `VRM` extension, including humanoid, expressions, first-person settings, secondary animation and VRM metadata. Its documented extension policy explicitly excludes custom vendor extensions. [Upstream gltfpack extension support](https://github.com/zeux/meshoptimizer/blob/b2330430776a95a1545f03fc7bf16927f8cadc59/gltf/README.md#extensions).

The infosia output retains `VRM`, but adds three nodes to each sample and leaves **54 humanoid references pointing at different node names in each model**. This was checked by resolving every output `humanBones[].node` and comparing its node name with the corresponding original humanoid bone. Its writer emits VRM node, mesh and expression indices directly, while the packer separately remaps scene indices; retaining an extension JSON object alone does not preserve its meaning. [Fork VRM writer](https://github.com/infosia/meshoptimizer/blob/82c1daa768a81c853aa7771dfbaaac75b00fbf36/extern/vrm/vrm_write.v0_0.inl), [fork node remapping](https://github.com/infosia/meshoptimizer/blob/82c1daa768a81c853aa7771dfbaaac75b00fbf36/gltf/node.cpp). This demonstrates a failure for these flags and models, not a certification of every fork feature or option.

Using gltfpack would require explicit remapping and validation of VRM node/mesh/material/texture indices, expression targets, spring/collider references and humanoid bindings, including VRM 1.0's extension family. Copying the old extension object into an optimized glTF is insufficient.

## Conservative probes

The offline `evaluate_vrm.py` uses upstream cache optimization and vertex-fetch remapping per primitive. It preserves all vertices, attribute bytes, joint/weight streams, every morph target and all application JSON references. Alpha-blended triangles keep their original order; opaque and alpha-cutout triangles may be reordered. No quantization, geometry simplification, material merging, node pruning or overdraw optimization is performed.

| Model | Simulated vertex transformations before / after | Reduction |
|---|---:|---:|
| D | 36,317 / 29,600 | 18.50% |
| F | 28,279 / 23,244 | 17.80% |
| G | 31,159 / 25,517 | 18.11% |

These are meshoptimizer cache-analyzer estimates with cache size 16, warp size 32 and primitive group size 256, **not measured GPU vertex invocations or frame-time savings**. The source VRM triangle order is analyzed before Godot conversion, material batching and avatar LOD; its improvement cannot be assumed to survive those stages. Upstream describes separate cache and fetch optimizations and requires all vertex streams to follow the same remap. [Meshoptimizer core pipeline](https://github.com/zeux/meshoptimizer/blob/b2330430776a95a1545f03fc7bf16927f8cadc59/README.md#core-pipeline).

The fetch probe appends separate streams for each primitive, intentionally retaining original buffers for inspection. It duplicates shared face/morph streams and produces 72–80 MiB local derivatives, exceeding the application's 25 MB upload limit. It is a correctness probe, not a shippable VRM packer. A separate index-only local derivative retains the original file size and every non-index byte exactly, and passes the application's VRM validation. All generated avatar files remain under ignored `test-results/meshoptimizer`; original bundled files and their manifest hashes are untouched.

Reordering raw VRM indices before import can also change Godot's generated tangent data slightly. The tested runtime prototype therefore operates **after decoding and tangent generation**. `index_cache.gd` uses Godot's existing meshoptimizer via `SurfaceTool.optimize_indices_for_cache()`, takes only the resulting indices, and patches a duplicate ArrayMesh's encoded index buffer. Packed vertices, normals, tangents, bones, weights, morph data, materials, bounds and existing LOD buffers remain unchanged. Transparent/custom materials are skipped using the existing opaque/cutout material whitelist. Full and first-person head-hidden variants retain their node and mesh layout. [Godot meshoptimizer registration](https://github.com/godotengine/godot/blob/4.7-stable/modules/meshoptimizer/register_types.cpp), [SurfaceTool](https://docs.godotengine.org/en/stable/classes/class_surfacetool.html).

This prototype uses Godot 4.7.2's private `_surfaces` serialization to avoid another vertex/morph quantization pass. It is version-specific and requires the encoded byte-equality checks before adoption on another engine build. A native implementation could patch indices without that private resource interface. Cache reordering alone needs no additional native dependency; full vertex-fetch remapping of packed skin/morph data needs a dedicated remapper or an appropriate importer-stage engine API.

## Import hook and next steps

For editor imports, an optional `EditorScenePostImportPlugin._post_process(scene)` can run after the final scene is configured. The existing VRM import options plugin is a suitable place to expose an explicit optimization option. Godot documents that final post-process hook. [EditorScenePostImportPlugin](https://docs.godotengine.org/en/stable/classes/class_editorscenepostimportplugin.html).

Custom uploaded avatars use a separate runtime path: `deathmatch/avatars/visual_loader.gd` decodes VRM, builds first-person variants, compiles eligible surfaces, measures rest bounds and packs a content-addressed scene. The corresponding hook belongs after those mesh transformations and before `PackedScene.pack` / derived scene caching. An editor-only plugin would not cover these avatars.

Generate LODs before final reordering, and preserve their indices during the comparison: simplification can produce different LOD geometry when fed a different base triangle order. The benchmark therefore copies each candidate after the original avatar's LOD job completes, preserving its completed LOD buffers and ready metadata. Do not regenerate them independently for an index-order A/B test. Include the optimization implementation/options/version in the runtime cache fingerprint, perform bounded preparation once per unique model, and share the resulting scene across instances. Retain original VRM hashes as upload/network identity; optimized scenes are local derived assets.

Full vertex deduplication must compare every attribute and every morph target, including joint IDs and weights; position-only welding can destroy deformation seams. Lossy simplification and quantization need separate deformation, expression and silhouette tests. Animation/spring-bone CPU work, material draw counts and the number of vertices processed by Godot's deformation pipeline do not disappear with index reordering. Meshlets also require a compatible rendering path; this experiment does not add one.

## Validation and reproduction

Offline probes check every reordered attribute/morph stream, oriented triangle multisets and extension/scene JSON equality. The post-decode Godot test compares encoded and decoded non-index arrays, all morph names and arrays, node paths and skin bind names/poses across D/F/G. It also checks oriented triangle multisets and retention of transparent triangle order. No production avatar import option is enabled by this evaluation.

Clone the pinned repositories under ignored `external-tools/meshoptimizer-zeux` and `external-tools/meshoptimizer-infosia`, adding `.gdignore` files. Build upstream `gltfpack`, the fork with its `MESHOPT_BUILD_GLTFPACK_MAIN` definition, and a shared upstream library exposing cache optimization, fetch remapping and cache analysis. The local shared probe library includes `vcacheoptimizer.cpp`, `indexanalyzer.cpp`, `vfetchoptimizer.cpp`, `allocator.cpp` and `rasterizer.cpp`. With NumPy and that library, run `python tools/meshoptimizer/evaluate_vrm.py --library /path/to/library.so`. Then run Godot with `--headless --xr-mode off --path . --script tools/meshoptimizer/validate_import.gd`, and use a real Vulkan window for `tools/meshoptimizer/benchmark.gd`.

The renderer benchmark uses the same Intel N95 / ADL-N GPU and 1440×900 Mobile Vulkan setup as the factory experiment, MSAA/vsync off. It runs original / cache / cache / original for each bundled model, 32 animated copies, springs off, existing distance/mesh LOD, 120 warmup and 360 timed frames per case. Avatar preparation, completed LOD generation and screenshots are outside timed frames. This is mono desktop evidence; it does not certify arbitrary VRM files, VRM 1.0 models, networking or XR.

## Measured results and recommendation

| Model | Original frame median range (ms) | Optimized frame median range (ms) | Original GPU median range (ms) | Optimized GPU median range (ms) |
|---|---:|---:|---:|---:|
| D | 12.253–12.557 | 12.391–12.639 | 7.313–7.485 | 7.354–7.360 |
| F | 12.460–12.527 | 12.564–12.615 | 6.470–6.520 | 6.486–6.522 |
| G | 12.653–12.664 | 12.623–12.745 | 6.952–6.954 | 6.945–7.057 |

All cases have 165 median draw calls. Per-model primitive medians/p95 agree between the variants: D 438,992 / 438,992; F 350,168 / 352,312; G 377,760 / 379,880. Thus the corrected comparison does not replace index reordering with a geometry reduction. Frame p95 remains 18.418–19.877 ms across the runs, exceeding the 16.67 ms 60 fps budget. There is **no consistent measured rendering win** on this desktop. The cache-analyzer estimate does not establish a 32-player capacity increase.

The script prototype takes 87.280 / 102.325 / 83.569 ms once per D/F/G model to build four optimized mesh resources. This is preparation cost outside timed frames; putting it directly in a live frame would create a hitch. A production pass would need bounded background work and persistent derived caching, or editor-time preparation. Its current practical value is a validated integration path and comparison tool, not a reason to enable it by default.

3,785 Godot checks pass with completed LODs present, including exact encoded/decoded vertex, tangent, skin, morph and LOD preservation; transparent triangle order and oriented triangle multisets are checked separately. The offline fetch probes pass 3,837 checks, and index-only file probes pass another 212 checks. Final rendering and validation logs contain no errors or warnings. Representative original/optimized screenshots were visually inspected; this does not substitute for expression or deformation tests on new models.

[Complete repository, correctness and rendering receipt](validation/cq-vrm-meshoptimizer.json), [32-avatar optimized scene](validation/cq-vrm-meshoptimizer-32-d.png), [post-decode prototype](../tools/meshoptimizer/index_cache.gd). The original model files, production imports and district capacity remain unchanged.

Prefer upstream's library algorithms through Godot's existing module. If the import pipeline is extended, start with opaque/cutout cache ordering after tangents and LOD preparation, then persist and share the result. Evaluate vertex-fetch remapping separately with complete skin/morph/LOD stream remapping; it is not covered by the measured index-only prototype. Do not use either tested gltfpack output directly as a replacement VRM. More GPU benefit will require reducing deformation/geometry/material work or improving avatar LOD, while spring and pose CPU costs require their own optimizations.
