# Low-cost ambient occlusion assessment

The Compatibility measurements below are historical. FPSloppa now maintains Mobile/Vulkan and disables OpenGL fallback; see [renderer support](../../docs/RENDERER-SUPPORT.md).

Use modest **baked AO for authored BSP maps**. It works with the current Mobile and Compatibility renderers and adds no shader pass or texture lookup when merged into the existing RGB lightmap. The controlled trial below confirms a subtle visible benefit with no measurable systematic runtime cost. The low preset has now been applied to all 25 current base-distribution maps; the controlled trial below remains the historical baseline. See [the distribution receipt](../../docs/validation/lighting-ao-distribution.json).

## Controlled trial — 12 September 2026

The previous TF lighting experiment combined AO, supersampling, bounce and softer sunlight. This trial isolates AO: both variants use identical 4×4 supersampling, one bounce, 0.25 bounce color scale, four-degree sunlight penumbra and the map's authored minimum light. The low variant enables dirt/AO with a 32-Quake-unit radius, scale 0.5 and occlusion of minimum light. The control disables dirt and minimum-light occlusion. The [ericw light documentation](https://ericw-tools.readthedocs.io/en/latest/light.html) describes these bake controls; the tested compiler is the locally installed v0.18 binary recorded in the receipt.

Pressureworks and Vesper Abbey pass preservation checks for geometry, collision, visibility data, textures, gameplay entities, face topology and light styles. Their embedded RGB sample sizes remain 1,796,427 and 863,223 bytes respectively. Parallel compilation can reorder light offsets; the runtime test separately verifies identical repacked atlas UVs before swapping textures. Both variants use 4096×4096 atlases, unchanged material counts and the same production shader.

Each backend measured 5,760 frames at 1280×800 with 4× MSAA and VSync off: two maps × two views × Classic/Contrast × AO-off/low/low/off, warming 45 frames and measuring 180 per block. Atlas swaps occur in the same loaded scene. Both textures remain resident for the experiment, but only one is sampled; a map shipping one chosen bake retains one atlas.

| Renderer | Median paired AO GPU delta | Paired range | Extra draws / lookups / single-bake atlas bytes |
| --- | ---: | ---: | --- |
| Vulkan Mobile | +0.0015 ms | -0.0005 to +0.0185 ms | 0 / 0 / 0 |
| OpenGL Compatibility | +0.0025 ms | -0.0150 to +0.0130 ms | 0 / 0 / 0 |

These tiny deltas are consistent with timing noise: the GPU executes the same shader and reads the same texture dimensions. Bake time increased by about 3.4 seconds on Pressureworks and 1.1 seconds on Vesper in the recorded run. Clocks and background system activity were not controlled. This is one Linux Intel Arc A770, with static scenes, not headset or match performance certification.

Visual review finds restrained shading around wall/floor joins, column bases and the capture platform edges. Depending on view and lighting mode, roughly 1.3–7.0% of temporally stable image pixels darken by more than 0.01 in normalized displayed luminance. Decorative detail already painted into textures is not new geometric occlusion. The low setting avoids a broad darkening of the whole image, but dark routes still need playtesting before a bake is promoted.

The external `softbox.bsp` rebake was **rejected**: the compiler changed 229 face light-style assignments from unlit to style 0 while preserving face topology. That exceeds this trial's preservation contract. The original external BSP is unchanged. Recompiling arbitrary imported BSPs is not automatically a safe AO upgrade; it needs a separate review of the source lighting information and resulting behavior.

## Alternatives and graphics controls

| Approach | Fit for FPSloppa | Main cost or limitation |
| --- | --- | --- |
| AO merged into RGB bake | Recommended for authored map scenery; tested here | Bake time only; cannot independently toggle AO after it is merged |
| AO stored separately in an atlas channel | Candidate for an independent Off/Low graphics control | Importer/cache format work and potentially greater texture memory/bandwidth; requires profiling |
| Authored AO on avatar textures/vertices | Possible inexpensive self-occlusion approximation | Must preserve MToon styling and work with animated poses; no world contact occlusion |
| Small, distance-faded ground contact shadows | Plausible next experiment for moving players | Additional small blended draws and floor placement/culling; approximation only |
| Built-in SSAO | Poor match for the current default renderer | Supported by Compatibility and Forward+, but not Mobile in current Godot documentation |
| Custom half-resolution depth AO | Technically possible on Mobile | New screen/depth passes, filtering, stereo handling and bandwidth; unmeasured, with halo/edge/shimmer risks |

The current [Godot renderer feature matrix](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) lists SSAO on Compatibility and Forward+, but not Mobile; older documentation that says Forward+-only is no longer sufficient. A renderer change merely to gain SSAO is not justified by this experiment. Custom post-processing is available on Mobile, but its availability does not establish that it is cheap on a standalone headset.

The **Baked Lighting: Classic / Contrast** toggle controls the response to existing lightmap data. It cannot remove AO already baked into those RGB values. A genuinely independent AO toggle would need either a second bake or separate occlusion information. Holding two RGB atlases adds 48 MiB of raw image data for a 4096 map. Packing a scalar into a fourth channel would retain one lookup and increase raw RGB8 storage from 48 to 64 MiB; actual GPU allocation depends on the format/driver and must be measured. A grayscale AO texture would add a lookup. None of these toggle formats was implemented in this exploration.

Map baked light and MToon's controlled visibility fill are written through `EMISSION`, so merely writing the shader's `AO` output is not a replacement for integrating occlusion into those particular contributions. Godot documents separate [AO, direct-light AO influence and emission outputs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html). A future avatar implementation should modulate only the appropriate ambient/fill term and preserve authored emissive details, rather than darkening the entire finished avatar.

Static AO has no camera-dependent sampling, temporal accumulation or depth prepass, so this candidate does not add the mechanism responsible for the recently fixed OpenGL avatar spots. It also does not update occlusion around walking players or moving elevators. Native Windows, animated-avatar and physical Quest/Pico testing remain separate work.

## Reproduce and review

```sh
python3 tools/lighting_experiment/ao_bake.py --light /path/to/ericw-tools-v0.18/bin/light
python3 tools/lighting_experiment/run_render_tests.py ao
python3 tools/lighting_experiment/ao_report.py
```

The external check uses the previously prepared `test-results/lighting-coverage/external-optin.bsp`. See the [coverage preparation instructions](README.md#wider-map-coverage) if it is absent.

Open `test-results/lighting-ao/review.html` for unmodified before/after captures. The durable machine-readable record is [docs/validation/lighting-ao.json](../../docs/validation/lighting-ao.json). Source BSPs and game defaults were not changed by this experiment.

## Distribution rollout

All 25 base maps passed normalized face/style preservation, fresh import, cache round-trip, and identical atlas UV/dimension checks. The Vulkan sweep covers two views per map in Classic and Contrast, with off/low/low/off ordering: 24,000 measured frames, 100 paired groups, zero extra draws or texture allocation, median GPU delta 0.0 ms (individual pairs -0.0705 to +0.2800 ms; uncontrolled scheduling and clocks). Raw comparisons are in `test-results/lighting-ao-distribution/review.html`.

The compiler pruned or reordered dim style contributions in two KOTH maps and occasionally repacked sample allocation in others. The distribution normalizer restores original face/style order, retains authored samples for pruned contributions, and gives paired bakes identical offsets. Geometry, VIS, collision, textures and entity bytes remain unchanged. Normalized lighting blocks can add a small amount of BSP storage; GPU atlas dimensions remain fixed. Existing gameplay/art receipts retain their original hashes, with the AO receipt providing explicit preservation lineage.

To reproduce after rebuilding source maps, use a new/archived `test-results/lighting-ao-distribution` directory (the stage refuses to overwrite a differing original snapshot):

```sh
python3 tools/lighting_experiment/distribution_bake.py --light /path/to/ericw-tools-v0.18/bin/light
python3 tools/lighting_experiment/distribution_normalize.py
godot --headless --xr-mode off --path . --script res://tools/lighting_experiment/distribution_import.gd
python3 tools/lighting_experiment/run_render_tests.py distribution-ao --renderer mobile
python3 tools/lighting_experiment/distribution_report.py
# Review the low/off screenshots before installing:
python3 tools/lighting_experiment/distribution_install.py
python3 tools/build_base_assets.py
python3 tools/package_tf.py
python3 tools/build_android.py
python3 tools/verify_android.py
```

The source `.map` files and their historical build receipts are unchanged. Run this final lighting step again after recompiling geometry. Optional expansion maps and user-imported BSPs are outside the base-distribution rollout.
