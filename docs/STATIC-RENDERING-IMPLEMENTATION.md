# First three static-rendering improvements

Implemented on September 12, 2026, following the [rendering study](STATIC-RENDERING-STUDY.md). These changes affect map surfaces; avatar shaders and realtime lighting were not changed.

1. **Colour response:** the existing Contrast option now uses `0.08 + baked * 2.6 / (0.65 + peak)`. It lifts midtones modestly while using one shared RGB shoulder instead of independent channel clipping. Classic and the Filmic tonemapper remain unchanged, and Classic remains the default. Select **Settings → Graphics → Baked lighting → Contrast** to see the revised response. There is no new draw, lookup, fullscreen pass or automatic exposure.
2. **Targeted bakes:** Pressureworks uses bounce scale 1.15 and Vesper Abbey 1.20. Both retain one bounce and the tested low AO; bounce colour scale is 0.20, sunlight samples increase to 128, and sunlight penumbra increases to six degrees. The changes provide restrained fill and smoother sunlight sampling. Geometry, entities, collision, VIS, texture data, light styles and navigation remain unchanged. Normalization preserves sample layout; atlas dimensions and UVs remain fixed. This is a refinement of the two TF maps, not a claim that every map was retuned.
3. **Map colour mipmaps:** floating-point linear-light averaging replaces averaging encoded sRGB values. The highest-resolution colour image is preserved; RGB textures retain RGB storage. Cutouts receive invisible edge-colour padding and per-level alpha-coverage adjustment. The new preparation applies only to BSP colour/glow textures, never to normal or lightmap data. The prepared resource records its version, so bundled caches load without repeating the conversion. Imported maps prepare and save their mips once when building their cache. Texture filter controls and anisotropic defaults remain available.

The cache audit also found that Vesper's dictionary-versioned scene could supersede its freshly rebuilt main cache. Scene caches now store and validate the source BSP hash using root scene metadata, without instantiating the scene twice. A stale or unversioned cache is regenerated; the base bundle also includes the current dictionary-versioned cache, avoiding that import on standalone installations.

Validation completed:

- Synthetic image tests verify an sRGB value of 188 for a half-black/half-white average, exact preservation of dark constant colours and level-zero pixels, RGB storage preservation, cutout edge padding, non-worsening alpha-coverage error, non-power-of-two images, version reuse and serialization. They also verify that non-map materials keep their previous preparation path.
- All 25 map caches pass atlas/UV/material-count and serialization checks. All 25 actual loader-selected caches pass a separate audit, including Vesper's alternate path. Source-hash acceptance/rejection is checked during cache preparation.
- Lighting-profile and client-preference regressions pass, including Classic restoration, saved Contrast selection and all texture-filter modes.
- The final Vulkan trial covers nine maps, two views per map, and seven blocks per view: baseline, response only, mips only, bake only, combined twice, baseline restored. This is **11,340 measured frames** at 1280×800 with 4× MSAA on the local Intel Arc A770. The maps cover all distributed mode families and an existing imported BSP. Shader/draw/sample counts remain the same; matching texture sizes are checked independently of both test variants being resident.

The [validation receipt](validation/static-rendering.json) contains the final paired GPU statistics, compiler flags/hashes, prepared cache hashes and active cache paths. The [contact sheet](../test-results/static-rendering/mobile/review.jpg) compares baseline, colour response, bake and combined results. Per-view PNGs and timings are retained in `test-results/static-rendering/mobile/`.

These are desktop Vulkan static-scene measurements, not a standalone VR performance certification. ADB reported no connected devices. No Quest/Pico or Windows-native run was performed, and head-motion/thermal/match-load testing remains necessary on the headset. The known single ObjectDB instance warning appears at test shutdown. Source assets and base/TF bundles were updated and verified; [package hashes](validation/static-rendering-packages.json) record the final artifacts. Application executables/APKs were not rebuilt or released.

The diagnostic tools are `static_bake.py`, `static_import.gd`, `static_render.gd`, `static_cache_verify.gd`, `static_report.py` and `static_install.py` under `tools/lighting_experiment/`. The bake/install tools deliberately refuse to overwrite differing baseline snapshots. The existing run's pre-change BSPs, shader and installed-cache backups remain in `test-results/static-rendering/`. After installing, the render trial continues to use its saved original TF BSPs to keep its comparison valid.

```sh
godot --headless --xr-mode off --path . --script res://deathmatch/tests/map_colour_mips.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/lighting_profile.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/client_preferences.gd
godot --headless --xr-mode off --path . --script res://tools/lighting_experiment/static_cache_verify.gd
python3 tools/lighting_experiment/run_render_tests.py static --renderer mobile
python3 tools/lighting_experiment/static_report.py
```

Later validation found that the historical Vesper nave camera was inside a solid wall. Recommendations 4–6 move it into the playable corridor and add a solid-space camera check. See [map presentation validation](MAP-PRESENTATION.md) for corrected images; the old nave screenshot should not be used to judge geometry or visual quality.
