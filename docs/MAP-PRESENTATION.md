# Static rendering recommendations 4–6

Implemented on Mobile/Vulkan. Map skyboxes, animated surfaces and stone weathering are default behaviour; the former switches were removed. Fog rendering has been removed. Classic/Contrast lighting remains a separate choice. See the later [static-assets and Contrast validation](STATIC-ASSETS.md).

## What changed

**4 — Sky backgrounds.** Audited panorama skyboxes are selected by map, with procedural fallbacks for remaining profiles. All maps, imports and the lobby render without depth or volumetric fog. Ambient lighting and explicitly authored skies are preserved. Sky resources are cached with 128-pixel radiance maps.

**5 — Surface animation.** The importer retains complete numeric and alphabetic Quake texture sequences separately, including frames not referenced by visible faces. Missing frames or mismatched dimensions retain the original static material. Complete sequences advance at 5 Hz, changing base and glow together. Baked liquids, lava and teleporters use a bounded 0.025-UV sine warp in their existing shader pass; glow also follows conveyor offsets now. UV2/lightmaps stay stationary. Unbaked imported StandardMaterials use bounded UV drift to preserve their existing shading and transparency. Opaque liquids remain depth-writing; there is no refraction, screen copy or underwater camera distortion. Shader-only liquids need no CPU process callback. Disabling animation restores each material's original texture and offset.

**6 — Authored surface variation.** Cache preparation adds subtle damp lower courses and broad runoff bands to selected neutral stone, brick and rock in Pressureworks and Vesper. The tint is symmetric between team bases, leaves coloured identification trims and moving brushes alone, and adds no polygons, overlays, texture samples or material splits. It uses a vertex-colour stream on 37,761 existing vertices. Original Makkon/LibreQuake pixels and licences are unchanged. Imported maps receive no weathering.

Generated caches now require both their source BSP hash and the presentation-data version. This prevents older caches from silently omitting animation assets. All current base-map caches and active texture-dictionary aliases were refreshed. Concurrent KOTH spawn-balance and DM3 navigation changes were retained; this rendering work does not alter BSP geometry, source artwork, lightmaps or navigation.

## Validation

- All 25 bundled maps: exact vertex/index, UV/UV2 and collision checks; unchanged material/surface counts and lightmap pixels; serialized cache round trips and actual loader checks.
- Settings persistence, independent UI buttons, a 960×600 scrollable layout, profile reuse/reset, animation toggles, filter changes, incomplete/alternate sequences, source-hash/version rejection and symmetric bounded tint tests passed.
- Real third-party BSP tested both with and without its experimental bake opt-in. A separate DM1 control with bake opt-in disabled exercised unbaked liquid/frame animation.
- 11,340 measured desktop Vulkan frames across nine maps and 18 valid viewpoints, with effects isolated and combined, repeated combined samples, and baseline restoration. Focused renders of a Hyperborea animated pad, a DM1 teleporter and emissive DM2 lava visibly animate and restore pixel-identical original images when disabled.
- On the Arc A770 at 1280×800, 4× MSAA, combined effects added a median paired **0.0255 ms GPU time**, with **zero additional draw calls**. Paired p95 delta was 0.01925 ms. These are small desktop measurements with noise, not Quest performance certification. Most cost came from atmosphere.
- Toggle comparisons allocated no additional texture memory, because both variants already held their resources. Retained animation frame images total 286,659 bytes including mip levels; vertex colours and cached sky resources are additional memory, not free effects.

Quest HMD tests were explicitly deferred. Thermally warmed stereo and 4v4/6v6/8v8 headset play remain device-validation work. No executable/APK rebuild or publication is included here.

## Vesper “hole” investigation

The old nave test camera at `(18, 2.2, 24)` was inside solid masonry, as confirmed by the BSP contents query. It exposed the floor faces correctly omitted beneath that wall. The apparent opening also existed in the previous static-lighting images; the brighter sky made it conspicuous. The camera is now at `(15, 2.2, 24)` in the playable corridor, where the floor renders continuously. Both rendering suites now reject viewpoints inside solid BSP space. No geometry patch or two-sided rendering workaround was needed.

Review images: [comparison sheet](../test-results/map-presentation/mobile/review.jpg), [corrected Vesper nave](../test-results/map-presentation/mobile/tf_vesper-nave-combined.png), [graphics settings](../test-results/map-presentation/settings.png). Machine-readable results: [validation receipt](validation/map-presentation.json).

## Reproduce

Run `deathmatch/tests/map_presentation.gd`, `client_preferences.gd`, `lighting_profile.gd` and `map_colour_mips.gd` headless. Prepare caches with `tools/lighting_experiment/presentation_prepare.gd`; optional trailing map IDs limit regeneration. Run `presentation_integration.gd` after preparation.

Use `python3 tools/lighting_experiment/run_render_tests.py presentation`, followed by the `surfaces` and `presentation-ui` suites. After reviewing images and successful reports, `python3 tools/lighting_experiment/presentation_report.py --install` verifies sources and installs prepared caches with backups. `static_cache_verify.gd` checks all active loader paths. Rebuild the local base-assets archive with `python3 tools/build_base_assets.py`.
