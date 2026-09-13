# Texture and material audit

The current maps use colour textures, baked RGB lighting/AO and selected glow masks. They do **not** have a normal/bump/specular material pipeline. Avatar normal maps work, but their filtering has two defects. This audit inspected the 25 current base maps and rendered the three bundled VRMs with Vulkan Mobile on the local Intel Arc A770.

| Surface or effect | Current behavior | Assessment |
| --- | --- | --- |
| Baked map surfaces | 543 baked materials; colour and RGB lightmap sampled | Working within the existing simple material model |
| Map normal/bump/height | No active maps or corresponding baked-shader inputs | Texture relief is painted colour detail, not reactive surface relief |
| Map specular/roughness/metallic | Baked shader disables specular, fixes roughness to 1, has no roughness/metallic textures | Metal and stone do not have physically distinct reflection responses |
| Map glow | 27 baked materials have glow masks | Imported fullbright/emission data reaches the baked shader |
| Avatar normal detail | All three rendered models respond when normal strength changes; all 241 inspected mesh surfaces have tangents | Normal decoding and tangent-space response work |
| Avatar normal filtering | All 49 normal bindings lack mipmaps, including 17 bindings to non-placeholder detail textures | Filtering defect; high-frequency detail has no suitable prefiltered mip levels |
| MToon filter selection | All 49 materials use shader includes and have no filter-variant bank | Graphics filter selection does not reach the included sampler declarations |
| Small avatar normal maps | Widths of 8 pixels or less are ignored | Valid custom tiny maps lose their effect; shipped 8×8 maps are flat placeholders |
| MToon specular, rim, matcap | Suppressed by FPSloppa's arena lighting branch | Deliberate anti-shimmer/readability policy, not faithful unrestricted MToon presentation |
| Authored avatar emission | Preserved with a brightness clamp | Render regression passes; authored-emission delta 0.00337, forced rim/matcap delta 0 |
| Regular glTF/PBR avatars and props | StandardMaterial3D supports texture channels; avatar policy caps metallic, raises roughness and clamps emission | Authored PBR appearance is deliberately moderated; not full material fidelity |

The 1×1 normal-map test produced no image change, while the same constant tilted normal at 32×32 produced a mean RGB change of 0.00887. The width heuristic in `mtoon_common.gdshaderinc:217` causes this difference. The bundled flat placeholders are uniformly RGB (127, 127, 255), so skipping those particular textures does not discard intended surface detail.

`filtering.gd` omits `_BumpMap` from texture preparation. Its generic shader-filter substitution examines only `source.shader.code`; MToon puts its sampler declarations in `mtoon_common.gdshaderinc`, beyond that substitution. Its colour samplers therefore remain fixed anisotropic, and its normal sampler retains the default filtering rather than following the user's selection. This is a quality/correctness issue, not evidence that it caused the earlier OpenGL spots or the unrelated controller interruption.

Normal data is correctly treated as linear data: `_BumpMap` uses `hint_normal` without `source_color`; colour/emission textures use `source_color`. [Godot's shader documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html) distinguishes colour textures from normal/roughness/metallic data. When fixing runtime normal preparation, use normal-aware mip generation, for which Godot exposes [`Image.generate_mipmaps(true)`](https://docs.godotengine.org/en/stable/classes/class_image.html#class-image-method-generate-mipmaps).

The map import/replacement path uses indexed WAD colour pixels and fullbright masks. No paired normal, height, roughness or metallic resources are supplied to the current baked shader. The inspected local Makkon archives provide WAD textures and associated previews/maps, with no named PBR channel set. Adding modern surface response would require suitable companion assets and a shader/material path. Existing static RGB lightmaps contain no light direction, and most map illumination is written through emission; merely assigning `NORMAL_MAP` would affect the small live-light component, not reconstruct detailed static directional lighting. MToon likewise has a different material model from ordinary metallic/roughness PBR; see the [MToon specification](https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_materials_mtoon-1.0/README.md).

The immediate corrective work is normal mip preparation and MToon filter selection, followed by replacing the tiny-texture heuristic with explicit normal-map presence handling. Map normal/specular support is a separate visual feature that needs selective asset work and performance testing. This audit changed diagnostic tools and documentation only.

Evidence: [machine-readable audit](validation/material-audit.json), `test-results/material-audit/runtime.json`, normal-on/off PNGs in that directory, and `test-results/lighting-coverage/emission-mobile.log`. The checks report no failures in normal-response/tangent assertions; the documented filtering findings remain unresolved. The diagnostic process reports the existing single ObjectDB instance leak at exit. No new Quest/Pico or Windows material benchmark was run.

```sh
python3 tools/lighting_experiment/run_render_tests.py material-audit --renderer mobile
python3 tools/lighting_experiment/run_render_tests.py emission --renderer mobile
```
