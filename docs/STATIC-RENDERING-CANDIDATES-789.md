# Rendering candidates 7–9: isolated visual tests

13 September 2026. **Atlas packing is the strongest candidate to carry forward.** Selective colour compression is promising, but aggressive compression and blanket downscaling visibly damage detail. Glow artwork is a local artistic choice. Finer lightmap samples produced only subtle gains in these scenes.

These are experiments for review, **not production implementation**. No candidate shader, importer, BSP, cache or texture was installed into the game, and no distribution bundle was rebuilt.

## Visual comparisons

Open the [interactive A/B viewer](../test-results/candidates789/compare.html) in a browser. It includes the complete, unmodified renders; select `baseline-packed` versus `density-packed` to isolate recommendation 9. The static sheets are directly viewable:

- [7: glow artwork and alpha packing](../test-results/candidates789/glow-comparison.png), plus [minified emission](../test-results/candidates789/glow-mips.png).
- [8: compression and texture size, 1:1 crops](../test-results/candidates789/compression-comparison.png).
- [9: finer lighting, 1:1 crops](../test-results/candidates789/density-comparison.png). Only the explicitly labelled difference column is amplified 16×. Crops select the greatest mean difference on a 32-pixel grid; candidate renders are not enhanced.

Full measurements: [validation receipt](validation/candidates789.json). Raw renders, encoded-size records, compiler logs and isolated scene caches remain in `test-results/candidates789/`.

## 7. Authored glow masks and scalar alpha packing

Tested a warm tube aperture in Pressureworks, dimmer lava crust with brighter cores in DM2, and a faint ornamental inlay on Vesper's rose tiles. The rose inlay is **proposed new artwork**, not a supplied emissive property of Makkon's stone. DM2 runes are an unchanged control. Controlled material swatches use the same dark static bake, with no bloom or runtime lighting.

The tube's warmer colour is clear in the swatch but modest in the map because much of the fixture exposes its casing. The rose addition is subtle and adds roughly **2.875 MiB** of texture allocation in this prototype. The lava variant darkens the existing emission rather than revealing fundamentally new detail. The automatic map viewpoint labelled `lava` did not produce a useful view of the emissive lava; it is excluded from the viewer and aggregate visual judgments. The material swatch is the evidence for this proposal.

A separate prototype packs the **original** emission into RGBA. Current Quake palette extraction blacks emissive pixels out of the diffuse image, so simply adding alpha to that diffuse image would be incorrect. The test reconstructs combined colour and an emission fraction, then reconstructs diffuse and glow in the shader. It only targets existing glow materials whose alpha is unused; Vesper stone is unchanged in this variant.

This removes a separate glow fetch on eligible surfaces, but colour/emission correlation is imperfect after filtering and mipmapping. The dark close-up rune swatch has a mean channel error of **1.33/255**, with a maximum of **17/255**; the minified lava swatch has a mean of **1.00/255**. These are measurable edge/colour differences, not lossless packing. Whole-map errors are much smaller because emissive coverage is limited. Allocation savings are only **0.031 MiB** in Pressureworks and **0.109 MiB** in DM2.

**Assessment:** retain the original palette masks as the general fallback. Consider individual lamp artwork after visual review. Alpha packing has too little demonstrated benefit here to justify automatic conversion of all glow materials.

## 8. Atlas packing, BC7/ASTC, and smaller colour textures

The experimental packer sorts padded light patches by height/width, packs them into a smaller square atlas, copies existing pixels and one-luxel gutters, and remaps UV2. It adds no atlas, material split or draw pass. Baseline lightmap pixels are preserved; tiny rendered differences come from changed sampling coordinates/precision.

| Map | Atlas before → after | Padded occupancy before → after | Measured texture allocation saved | Further saving with selective BC7 |
| --- | --- | --- | ---: | ---: |
| Pressureworks | 4096² → 1024² | 5.11% → 81.81% | 60 MiB | 21.250 MiB |
| Vesper | 4096² → 1024² | 2.56% → 41.02% | 60 MiB | 12.750 MiB |
| DM2 | 2048² → 512² | 5.65% → 90.44% | 15 MiB | 5.786 MiB |
| Deepvault | 4096² → 512² | 0.79% → 50.66% | 63 MiB | 3.449 MiB |

The allocation numbers are Godot's texture-memory monitor on the A770, including unchanged rendering/sky resources. They are **differences**, not BSP disk sizes or guaranteed Android allocation. Raw RGB atlas data shrinks by 45 MiB for each TF map; the measured GPU allocation saving is 60 MiB. Do not conflate RGB file bytes with device allocation.

Packing alone has at most **0.0031/255 mean channel error** across reviewed views, visually indistinguishable in these captures. All variants preserve geometry, collision, base UVs and vertex tints; visible draw-call counts do not increase.

Compression tests include BC7 and ASTC 4×4 on colour/glow alone or on all textures, ASTC 8×8 on all textures, and halving large colour images by one existing mip level. Selective variants compress only colour/glow images larger than 128 pixels and leave lightmaps and small Quake textures uncompressed. Identical images are pooled within a map; repeated bindings are not presented as independent deduplication savings.

Selective BC7/ASTC 4×4 preserve the main stone and ornament shapes, with visible changes in fine mottling at close range. BC7 whole-view mean errors range from **0.008 to 2.86/255**; ASTC 4×4 from **0.007 to 2.30/255**. Blanket ASTC 8×8 visibly flattens colour/detail and blocks up DM2 surfaces. Halving large textures blurs the Vesper rose and removes floor detail; the rose view reaches **9.83/255** mean error. Global downscaling is not warranted by these results.

The desktop GPU supports BC7/BPTC but **does not support native ASTC**. ASTC images were actually compressed, then CPU-decoded before upload for honest visual inspection. Encoded bytes are recorded separately. ASTC desktop timings and uploaded RGBA allocation are **not measurements of Android ASTC performance or memory**. The installed Godot ASTC decoder also needed a test-only per-mip workaround for narrow, non-square mip tails. Godot documents platform-dependent compression support and its image compression API: [texture import guidance](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html), [Image API](https://docs.godotengine.org/en/stable/classes/class_image.html).

**Assessment:** atlas packing merits implementation first after review. Keep lightmaps uncompressed initially. Selective colour compression merits a native Quest trial; leave small Quake artwork and precision-sensitive textures on the existing path. Do not promote blanket ASTC 8×8 or half-size colour textures.

## 9. Selective 8-unit lightmap samples

This is a real fine bake, not an upscaled atlas. The installed ericw v0.18 compiler accepts per-face `LMSHIFT` and emits supplemental light offsets/styles. The test selects 8-unit spacing on nearby floor/wall/column faces while retaining 16 elsewhere. An isolated importer copy reads that spacing when reconstructing UV2. The shipping importer remains unchanged. This follows the installed version's [per-face lightmap implementation](https://github.com/ericwa/ericw-tools/blob/v0.18/light/light.cc), rather than assuming all current [light documentation](https://ericw-tools.readthedocs.io/en/latest/light.html) features exist in the older binary.

| Map | Fine faces / total BSP faces | Light-lump bytes before → after | Compact atlas | Occupancy at 8-unit selection |
| --- | ---: | ---: | --- | ---: |
| Vesper | 645 / 4415 | 288,214 → 391,150 | 1024², unchanged | 52.60% |
| Pressureworks | 432 / 6514 | 598,811 → 691,283 | 1024², unchanged | 91.93% |

Fine samples are freshly baked using the existing AO/bounce/supersampling recipe, then stitched into the original style order. All unselected light samples are retained byte-for-byte. Geometry, visibility, collision data and texture lumps are unchanged. A separately refreshed 16-unit control was not baked, so this compares the current production bake with a selective fresh bake using the same recipe, not a perfectly paired fresh compiler run.

The new samples fit the **same compact atlas dimensions**, adding no measured texture allocation relative to packing alone. Vesper's nave/floor differences are small; the highest-change 320×256 nave crop averages **0.144/255** channel error. Pressureworks' floor crop averages **0.140/255**. These soft bakes and detailed textures already conceal much of the coarse sampling. This does not establish a meaningful visible improvement across the maps.

**Assessment:** keep this selective and deferred. The packing result makes future local density practical, but these captures do not justify increasing density globally. A deliberately chosen hard shadow/arch boundary would be a better next trial; Pressureworks has little remaining 1024² atlas headroom.

## Test coverage and limits

Godot 4.7.2-stable, Mobile/Vulkan, Intel Arc A770, 1280×800, 4× MSAA, Classic lighting. Four maps, eleven captured viewpoints (one excluded from visual conclusions), 149 variant/view records, **17,880 measured frames**, plus 24 material swatches. Each record uses 45 warm-up frames and 120 measured frames. Animations are frozen; viewpoint, atmosphere and light settings remain identical within comparisons. Every camera is checked outside solid BSP. This is static-map coverage, not a 6v6/8v8 gameplay or thermal benchmark.

| Map | Baseline GPU ms | Packed GPU ms | Packed + selective BC7 ms | Restored baseline ms |
| --- | ---: | ---: | ---: | ---: |
| Pressureworks | 0.383 | 0.312 | 0.353 | 0.344 |
| Vesper | 0.275 | 0.314 | 0.280 | 0.319 |
| DM2, excluding lava view | 0.341 | 0.344 | 0.311 | 0.334 |
| Deepvault | 0.339 | 0.348 | 0.292 | 0.299 |

These are medians of the view medians; individual CPU/GPU median and p95 values are in the receipt. Baseline restoration reveals timing drift comparable to many candidate differences, so **no speedup is established**. Restored baseline images are visually unchanged (maximum mean channel difference below 0.000013/255), and texture-memory drift is zero for all four maps. No additional visible draw calls were measured.

Render assertions and all scene geometry/collision integrity checks passed. The render process nevertheless reported **six ObjectDB instances and two resources still in use at shutdown**. This is an unresolved test-harness teardown warning; it is not evidence of a measured per-variant texture leak, and it must be cleaned up before promoting this harness as a long-running regression tool. An initial ASTC decoding failure was corrected and the affected variant scenes regenerated before the final comparisons.

The production snapshot retained **129 of 132** hashes, including all snapshotted BSPs, scene caches and the base manifest. `atmosphere.gd`, `settings/panel.gd` and `settings/preferences.gd` changed during other work in the shared workspace; this experiment did not edit or revert them. Candidate files remain under the experiment tools and test-results directories.

Quest HMD, native ASTC, motion/stereo quality, thermal load and player-load tests remain deferred as requested. No ADB launch, production integration, bundle rebuild or release was performed for these candidates.

## Reproduce

Requires the current source assets, Godot editor, Python with Pillow/NumPy, and the ericw v0.18 compiler configured by `static_bake.py`. Run from the repository root. These scripts write only isolated experiment outputs; `render.gd` reads the current shared atmosphere, so later sky work can change a fresh comparison's background.

```sh
mkdir -p test-results/candidates789
python3 tools/lighting_experiment/candidates789/bake_density.py
python3 tools/lighting_experiment/candidates789/make_importer.py
godot --headless --xr-mode off --path . --script res://tools/lighting_experiment/candidates789/import.gd
godot --headless --xr-mode off --path . --script res://tools/lighting_experiment/candidates789/export_sources.gd
godot --headless --xr-mode off --path . --script res://tools/lighting_experiment/candidates789/variants.gd
godot --headless --xr-mode off --path . --script res://tools/lighting_experiment/candidates789/integrity.gd
python3 tools/lighting_experiment/run_render_tests.py candidates789
python3 tools/lighting_experiment/candidates789/compare.py
```

The comparison generator also reads the saved `production-before.json` snapshot. Preserve that file and the raw receipts when rerunning; the snapshot is an audit of this session, not automatically a baseline for future production revisions.
