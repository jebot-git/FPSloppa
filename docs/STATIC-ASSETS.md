# Static assets, default skies and Contrast validation

Integrated 13 September 2026 after review of recommendations 7–9. All **25 bundled maps** have regenerated, compact lightmap caches and separate full-resolution **BC7 desktop / ASTC 4×4 Android** colour caches. Runtime chooses only a supported codec; imports and unsupported devices retain an uncompressed fallback. Compression never runs on the gameplay thread.

Fog rendering is disabled for bundled maps, imports and the lobby. The sky/fog graphics control and saved preference have been removed. Audited skyboxes are default behaviour; explicitly authored backgrounds and ambient lighting are preserved. The five sky panoramas retain their original 2048×1024 pixels and now use BC7/ASTC 4×4 with mipmaps. Their import settings are preserved in source checkouts/archives.

Only opaque colour images larger than 128 pixels are compressed. **No resolution reduction or ASTC 8×8.** Lightmaps, coloured glow masks, cutouts and small Quake artwork stay uncompressed. Colour mipmaps retain the existing linear-light construction. Separate coloured emission avoids the alpha-packing artifacts observed in the experiment.

The reviewed warm tube mask, lava-core/crust adjustment and subtle Vesper rose inlay are generated during map import. Original embedded artwork is unchanged. These are surface emission only; they add no runtime lights, bloom or glow pass. The Vesper inlay is an artistic addition, not a source-supplied material property.

The two TF maps were rebaked selectively at 8-unit light samples: 645 Vesper faces and 432 Pressureworks faces. All other light samples retain the existing AO/bounce bake byte-for-byte. Both maps still fit 1024² compact atlases. BSP geometry, texture and collision data, original lightstyle order and navigation are preserved. Updated map hashes retain the audited sky assignments when downloaded under custom identifiers. Other bundled maps retain their existing AO light values, repacked without rebaking their geometry.

## Visual review

- [Interactive Classic/Contrast and compression comparison](../test-results/static-assets/compare.html).
- [Classic versus Contrast](../test-results/static-assets/classic-contrast.png).
- [Contrast compression close-ups at 1:1](../test-results/static-assets/contrast-compression.png).
- [All 25 maps in Contrast](../test-results/static-assets/contrast-all-maps.jpg).

All captures use the new skyboxes with fog disabled, including the older-cache reference. This isolates the asset/compression changes; the earlier fog experiment is not reintroduced into these comparisons.

Contrast provides stronger separation in the Gothic stone and dark corridors while retaining visible surface detail in the inspected views. BC7/ASTC 4×4 retain the ornamental shapes and floor detail that the rejected ASTC 8×8/half-size candidates lost. Small changes in painted noise remain at close range: block compression is not lossless. Contrast remains an existing graphics choice; its default has not been changed by the test request.

## Validation

[Structured receipt](validation/static-assets.json): 25 fresh map imports, 50 saved codec-cache checks, plus the previously randomly selected Softbox BSP in untouched and baked-opt-in forms. All passes confirm geometry/collision preservation, full colour dimensions/mips, uncompressed identical lightmaps/glow/cutouts, and persistence of compressed images through runtime filtering. All fine-bake imports have zero invalid or overflowing light faces.

Mobile/Vulkan on Arc A770, 1280×800, 4× MSAA: **120 captures / 10,800 measured frames in Classic**, repeated with **120 captures / 10,800 frames in Contrast**. All 25 maps pass fog-off and default-sky assertions and select their native BC7 caches correctly. Thirty fixed viewpoints cover sky openings, corridors, Vesper nave/rose, Pressureworks floor/lamp and DM2 runes. No added visible draw calls in either sweep. BC7 allocation savings versus the previous caches range from 0.15 to 81.25 MiB per map/view on this desktop, including atlas packing and the added glow artwork. These short static scenes do not establish a gameplay frame-time speedup.

The graphics-menu render confirms the retired control is absent and remaining controls fit/scroll. Sky fixtures cover hash aliases, authored-background preservation, unknown imports, rotation reuse and fog removal; settings fixtures check retirement of old saved values. Source-import settings produce both native BC7 and ASTC sky resources. All ten sky codec files pass direct format/dimension/mipmap inspection ([receipt](../test-results/static-assets/sky-compression.json)).

ASTC images in desktop comparisons are explicit CPU-decoded references because the A770 lacks native ASTC support. Native Quest stereo, motion, thermal and player-load testing remain deferred. The full render harness retains its six-ObjectDB/two-resource shutdown warning; there were no shader/render assertion failures. This warning is documented separately from successful visual checks.

Local base-assets (374.45 MiB, including both platform formats and the fallback) and original-TF bundles are rebuilt and audited; see [package receipt](validation/static-assets-packages.json). This work does not publish a release or claim that existing installed clients contain the new runtime code.

## Reproduce

Existing production BSPs contain the approved bakes. Rebuild the scene caches and compare with:

```sh
godot --headless --xr-mode off --path . --script res://tools/lighting_experiment/build_static_assets.gd
godot --headless --xr-mode off --path . --script res://tools/lighting_experiment/verify_static_assets.gd
python3 tools/lighting_experiment/run_render_tests.py static-assets
python3 tools/lighting_experiment/run_render_tests.py static-assets --contrast
python3 tools/lighting_experiment/static_assets_report.py
python3 tools/build_base_assets.py
python3 tools/package_tf.py
```

The comparison scripts require the original-cache snapshots and sky audit under `test-results/`; production rebuilds do not silently replace those historical references. The fine-bake compiler options and exact before/after BSP hashes are preserved in the validation receipt.
