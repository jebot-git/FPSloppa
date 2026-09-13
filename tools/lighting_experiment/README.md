# Low-cost lighting experiment

**Current renderer policy:** Mobile/Vulkan is maintained; OpenGL fallback and its runtime workarounds have since been removed. The OpenGL results below are historical comparisons. New render runs default to Mobile. See [renderer support](../../docs/RENDERER-SUPPORT.md).

The follow-up [ambient occlusion assessment](AO.md) isolates a short-range AO bake from other lighting changes, measures both renderers, and compares options for an independent graphics toggle and moving avatars.

The game now offers **Settings → Graphics → Baked lighting → Contrast (experimental)**. It applies immediately to maps using FPSloppa's opt-in baked lightmaps and persists in the presentation preferences. Classic remains the default. Restart the game from the working tree to use the new setting; previously exported binaries do not contain it.

The contrast response reduces the old per-channel square-root lift, retains coloured lighting with a shared RGB shoulder, and keeps a small visibility floor. It uses the existing lightmap lookup, atlas and draw pass. Muzzle and projectile illumination retain their live contribution. Cached map scenes upgrade to the current shader while preserving atlas textures, alpha cutouts and glow. Texture-filter changes preserve the chosen lighting response.

## Offline bake trial

`bake.py` creates separate baseline and candidate copies of Pressureworks and Vesper Abbey under `test-results/lighting/`. Candidates use 4×4 supersampling, 64-Quake-unit ambient occlusion with strength 0.65, occluded minimum light at 24, four-degree soft sunlight and one bounce with 0.25 texture colour contribution. The existing atlas resolution and 16-unit luxel spacing stay fixed. These choices follow the compiler's [ambient occlusion, penumbra and bounce controls](https://ericw-tools.readthedocs.io/en/latest/light.html); the tested v0.18 compiler supports one bounce, unlike newer versions with multiple-bounce options.

The tool verifies all non-lighting BSP lumps, face topology/styles, gameplay entities and non-lighting BSPX data. Texture pixels, collision, VIS, routes and objectives are unchanged. RGB lighting sizes remain exactly the same: 1,796,427 bytes for Pressureworks and 863,223 for Vesper. Bakes took approximately 9.3 and 4.4 seconds on this machine. Shipping BSPs, navigation receipts and distribution bundles are untouched; the experimental files are excluded from game exports.

```sh
python3 tools/lighting_experiment/bake.py --light /path/to/ericw-tools-v0.18/bin/light
godot --xr-mode off --path . --rendering-method mobile --script res://tools/lighting_experiment/profile.gd
godot --xr-mode off --path . --rendering-method gl_compatibility --script res://tools/lighting_experiment/profile.gd
python3 tools/lighting_experiment/report.py
```

Open `test-results/lighting/review.html` for a four-way comparison: original/new bake × classic/contrast shader. It displays unmodified game captures. The profiling tool loads the copied BSPs and draws TF objectives without starting a server or changing saved preferences.

## Measured results, 12 September 2026

Godot 4.7.2 on Intel Arc A770, 1280×800, 4× MSAA, uncapped and VSync off. Both renderers completed 8,640 measured frames across three camera positions in each map, both bakes, and a classic/contrast/contrast/classic sequence. Each block warms for 45 frames before collecting 180 samples. Timing comes from Godot's [viewport CPU/GPU measurement API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-set-measure-render-time).

| Renderer | Median paired GPU cost of contrast | Largest positive paired delta | Extra draws / texture allocation |
| --- | ---: | ---: | --- |
| Vulkan Mobile | +0.0027 ms | +0.0050 ms | 0 / 0 |
| OpenGL Compatibility | +0.0035 ms | +0.0365 ms | 0 / 0 |

These are static scene measurements with no players, not whole-match performance or a headset budget guarantee. GPU clocks and OS scheduling were uncontrolled; one Vulkan classic block produced a large negative paired delta (-0.55 ms), so no speedup is claimed. Full block medians and p95 values are in each renderer's `profile.json`; paired results and bake hashes are retained in `docs/validation/lighting-experiment.json`.

Visual review: dim masonry and recesses have stronger separation from lit trim; the flag and capture markers remain clear. The combined change darkens floors and ceilings, so classic stays available for comfort and competitive readability. AO adds local contact shading; supersampling and the sun penumbra improve baked shadow edges without adding real-time shadow maps.

## Validation and remaining work

`deathmatch/tests/lighting_profile.gd` passes against a real pre-experiment compressed scene cache, checking upgrade, atlas/cutout/glow preservation, and reversible uniform-only switching. `client_preferences.gd` verifies persistence and the opt-in default. `baked_light.gd` retains passing luxel/UV/gutter/fallback checks. Both actual renderers imported all four BSP copies with RGB lightmaps and zero invalid or overflowing baked faces; shader compilation logs contain no errors.

Moving avatars still use the existing bounded live lamps and avatar fill. Elevators still carry their authored static brush lightmaps. This experiment does not implement probes, directional lightmaps, normal mapping, SSAO or real-time GI. The current importer consumes RGBLIGHTING or native grayscale samples; it has no directional or LIGHTGRID_OCTREE sampling path, and the installed v0.18 compiler lacks lightgrid output. A useful next experiment is a newer compiler's baked light grid with low-frequency, spatially interpolated actor sampling, checked for wall leakage and shared VRM material isolation. Native [Godot LightmapGI probes](https://docs.godotengine.org/en/stable/classes/class_lightmapgi.html) are another option, but require a separate bake/data integration rather than simply enabling the existing BSP atlas.

Promoting either TF rebake requires updating its map hashes/caches and validation receipts, then rebuilding asset bundles. Live 6v6 and Android/VR readability and performance tests remain necessary before making the new response the default.

## Wider map coverage

`prepare_coverage.py` snapshots the base bundle's BSPs into the test directory. The 12 September run covered the 21 maps present in `FPSloppa-0.10v-Base-Assets.zip` when preparation began: two AS, two TF, four KOTH, five community DM and eight legacy LibreQuake maps. Distribution cleanup proceeded separately during the tests; the isolated snapshot preserves that broader regression coverage without restoring removed maps to the distribution. Re-running preparation against a newer bundle can produce a different inventory.

The run also randomly selected `forrest_ctf_maps/softbox.bsp` from 97 BSP members in locally cached Quaddicted archives, using recorded seed 4041983142. [Source archive](https://www.quaddicted.com/files/maps/multiplayer/ctf/forrest_ctf_maps.zip). The untouched BSP tests legacy fallback. A second diagnostic copy adds only `_fpsloppa_bake` and `_fpsloppa_atlas` worldspawn keys so its native grayscale light data exercises the baked shader. All non-entity lumps and BSPX data remain identical. The external map is test-only, not a distributed asset.

All 23 import cases pass fresh import, compressed scene reload, atlas pixel hashes, baked counters, shader upgrade, cutout/glow preservation and reversible filtering/lighting changes. There are zero invalid or overflowing baked faces. The shipped caches also matched fresh lighting at initial import. Grayscale and RGB lighting both work. Maps without the opt-in marker keep their existing lighting; this is not automatic rebaking of every imported BSP. The existing first-lightstyle-only behavior remains, and elevators keep their authored static brush lightmaps.

Each renderer captured two usable spawn views per case and measured 22,080 frames. The final median paired GPU delta for Contrast is +0.0045 ms on Mobile and +0.0055 ms on Compatibility, with no additional draws or texture allocation from the toggle. The final GL run is noisy (paired range -0.7085 to +0.4135 ms); these measurements support low typical shader cost, not a hard upper bound. Dark maps such as Ancient's Hall lose brightness, so the mode remains optional.

```sh
python3 tools/lighting_experiment/prepare_coverage.py
godot --headless --xr-mode off --path . --log-file /tmp/lighting-import.log --script res://tools/lighting_experiment/coverage_import.gd
python3 tools/lighting_experiment/run_render_tests.py coverage
python3 tools/lighting_experiment/coverage_report.py
```

Open `test-results/lighting-coverage/review.html` for raw map comparisons. The durable receipt is `docs/validation/lighting-coverage.json`.

## MToon and the OpenGL speckling regression

The avatar suite loads sample_d, sample_f and sample_g VRMs in Frigate's RGB bake, Vesper's experimental RGB rebake and the external grayscale opt-in import. Both renderers pass all 18 map/model/backend cases, including dim silhouettes, red/blue live-light response, bounded flash response and unchanged MToon material policy when map contrast is toggled. OpenGL's fill is 0.16; Mobile retains 0.10. This small visibility calibration is not intended to make their different color pipelines pixel-identical.

The original numeric checks missed visible OpenGL surface patches. A separate test reproduces them by translating a fixed avatar/camera scene to `(20, 2, -60)`, including an ambient-only capture and a small camera sweep. Restoring the depth prepass makes all three translation checks fail: 10.6–19.8% of thresholded avatar pixels change by more than 0.05 in a color channel. With the prepass disabled, the changed fraction falls below 0.024%; the Mobile checks also pass. The native-vertex-transform shader variant is diagnostic only and was not adopted.

`project.godot` disables the depth prepass. It removes the reproduced spots without replacing MToon or adding another render pass. Mobile has no depth prepass and remains the default. A raw before/after gallery is at `test-results/lighting-coverage/mtoon-review.html`; timings, negative controls and hashes are in `docs/validation/lighting-mtoon.json`. Performance of removing the prepass is a separate question from the negligible cost of the map contrast toggle: high-overdraw scenes can cost more without it.

The focused current-source GL comparison measured 2,880 frames per prepass state. Median paired GPU cost of disabling it was +0.7495 ms, with block deltas from -0.006 to +2.002 ms. Per-map median deltas were +0.105 ms for HiSlop, +1.379 ms for Alichar and +1.221 ms for Pressureworks. Camera positions/directions matched exactly. These sequential runs did not control clocks or other system load; the result is a fallback-renderer tradeoff, not a claim of zero performance penalty. The default Mobile path is unaffected. The existing rim/matcap regression also passes on both renderers while authored emission remains active.

```sh
python3 tools/lighting_experiment/run_render_tests.py mtoon
python3 tools/lighting_experiment/run_render_tests.py shimmer
# Expected to fail: confirms the regression detects the original artifact.
python3 tools/lighting_experiment/run_render_tests.py shimmer --renderer gl_compatibility --depth-prepass on
python3 tools/lighting_experiment/run_render_tests.py coverage --renderer gl_compatibility --only-map as_hislop,koth_alichar,tf_pressureworks --depth-prepass on
python3 tools/lighting_experiment/run_render_tests.py coverage --renderer gl_compatibility --only-map as_hislop,koth_alichar,tf_pressureworks --depth-prepass off
python3 tools/lighting_experiment/mtoon_report.py
python3 tools/lighting_experiment/run_render_tests.py emission
```

These are Linux/Intel Arc desktop tests, not native Windows, Android or full animated match certification. OpenGL remains useful for old desktop GPUs and headset troubleshooting; see the [platform assessment](../../docs/RENDERER-SUPPORT.md). A rebuilt game is needed to receive the workaround; existing releases are unchanged.
