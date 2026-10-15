# Mixed vehicle headlights and player shader — 2026-10-15

[Open the standalone comparison](comparison.html): unchanged 1280 × 720 renders with vertex/mixed pairs and off controls, including a player standing in the light path. Separate PNGs accompany it.

## Full-map measurements

Intel N95 integrated GPU, Godot 4.7.2 Forward+, V-sync/frame cap off. GPU medians in milliseconds; two 120-frame samples per mode, reversed order on the second pass. Map residency, culling, LOD and player pose are frozen. Exact draw/triangle counts match between vertex and mixed for each scene. No physics or gameplay simulation is measured.

| Scene | Off | Vertex | Mixed | Mixed minus vertex |
| --- | --- | --- | --- | --- |
| factory | 4.257 | 4.358 | 4.451 | 0.092 (2.1%) |
| driver | 4.715 | 4.816 | 5.088 | 0.272 (5.6%) |
| driver_player | 4.768 | 4.848 | 5.121 | 0.273 (5.6%) |
| driver8 | 4.732 | 4.987 | 6.116 | 1.129 (22.6%) |
| driver8_player | 4.750 | 5.048 | 6.245 | 1.197 (23.7%) |
| road | 3.927 | 4.047 | 4.086 | 0.039 (1.0%) |

`driver_player` and `driver8_player` add the actual bundled UT99 Malcolm soldier, 595 triangles, nine metres ahead of the vehicle origin. They reuse the exact frozen driver scene. The reference fragment-baked avatar shader is held constant in both sampling variants; the optimised baked-light path is measured separately below. Both lighting methods render the soldier similarly at this distance; the strongest improvement from mixed is the focused wall illumination rather than the broad triangular gradients of pure vertex lighting. One avatar's incremental cost is small and should not be extrapolated into multiplayer capacity. Eight-cone cases are arithmetic stress tests without additional vehicles.

Both variants use identical 60 m cones, 12°/24° inner/outer half angles, positions, intensity and falloff. Vertex samples all receivers at vertices. Mixed retains vertex sampling on displaced terrain and samples supported other surfaces per pixel. Captures have no exposure adjustment. Off controls hide the small lens meshes. Shader caches are warm; compilation hitches, moving-camera streaming, animation/IK CPU, VR stereo and populated matches are outside this comparison. GPU clocks are not pinned. No i7-12700 target GPU was provided or measured; CPU performance estimates do not scale these GPU times.

Raw 4,320 frames are in `frames.csv`; per-mode median, p95, maxima, repeat data and geometry counts are in `results.json`.

## UT99 shader optimisation

The current branch uses UT99 vertex animation rather than the older VRM loader. The rendering shader is already unshaded and uses shared GPU frame textures with optional tracked IK. A conventional PBR/MToon replacement would introduce work the model does not need. The new `vertex_lighting.gdshader` moves the two baked-irradiance atlas samples from fragment to vertex evaluation **after animation/IK displacement**, while retaining per-pixel vehicle headlights and the original skin atlas. Both variants share `vertex_animation.gdshaderinc`, preserving deformation and instance uniforms. The optimised variant is now selected by `visual_loader.gd`.

An isolated 1280 × 720 test compares identical 1- and 32-soldier scenes on a dark background with two production headlight cones. Two 180-frame samples per variant, reversed order, 90-frame warmup, frozen pose. Original GPU position fetches remain active; no CPU animation, IK or game simulation runs.

| Visible soldiers | Pixel baked lookup | Vertex baked lookup | Saving |
| --- | --- | --- | --- |
| 1 | 0.888 ms | 0.863 ms | 0.025 ms / 2.8% |
| 32 | 1.975 ms | 1.818 ms | 0.157 ms / 7.9% |

Both variants submit exactly 595 / 19,040 triangles. Original PNG differences are at most **one 8-bit colour step** in each tested scene. This checks the sampled placement and lighting, not every map location. See `avatar-shader/results.json`, `avatar-shader/frames.csv` and the four original PNGs. An avatar fills far more screen area in this isolated test than in the full-map driver view, so these savings are not additive to full-map timings.

## Gameplay implementation

- Offhand trigger toggles headlights while driving; desktop uses the existing offhand binding (right mouse by default). The binding is now visible as **Vehicle headlights (driver)** in CQ control settings. Passengers cannot change lights. Mounted input keeps the action separate from weapons, physical reloads and NVG activation.
- Both native and script authority own press/release latching. Entry, driver transfer or recovery from invalid input requires release before another press. Held input cannot repeatedly toggle. Wrecks stop emitting; respawn/round reset defaults off.
- Native vehicle flag bit 1 replicates lights without changing row sizes; grounded remains bit 0. Validator, decoder and remote presentation support it. Admission protocol advances to `fpsloppa-cq-frontier-28-headlights`, requiring matching client/server builds.
- Renderer uses at most **four cones / two vehicles**, prioritising the local driver then nearest enabled vehicle within 150 m. Lamp pose follows the interpolated hull including ground slope, independently of turret aim. Small emissive lens faces show enabled lamps. Unused global slots are zeroed; reset clears them.
- Terrain evaluates cones after height displacement in the vertex shader. Baked building surfaces, vegetation cards/SVO trees, water, transport hulls and UT99 avatars use per-pixel cones. This remains the tested unshadowed, normal-free analytic light model: it can illuminate through walls and does not add headlights to NVG glare or fog/rain scattering. Light-list truncation can change distant illumination when more than two lit vehicles are nearby.

## Validation and reproduction

Native core: **264,755 checks passed**, including new driver-only toggling/hold/focus/reset/wire cases. Jolt/binary/projection integration: **481 checks passed**, including independent grounded/light bits, remote replication and no accidental NVG toggle. Graphical headlight selection/reset/player illumination: **7 checks passed**. Existing transport render suite: **60 passed**, including script authority toggles and gameplay vehicle lens creation. UT99 geometry/LOD regression: **107 passed**. Tracked IK: **62,316 arm cases passed** across five models. Linux client native library rebuilt locally; no deployment or headset-device test was performed.

```
DISPLAY=:0 Godot --path . --xr-mode off --audio-driver Dummy --script tools/voxel_battle/compare_headlights.gd
python3 tools/voxel_battle/summarize_headlights.py
DISPLAY=:0 Godot --path . --xr-mode off --audio-driver Dummy --script tools/voxel_battle/compare_avatar_lighting.gd
python3 tools/voxel_battle/summarize_avatar_lighting.py
DISPLAY=:0 Godot --path . --xr-mode off --audio-driver Dummy --script deathmatch/tests/cq_headlights.gd
DISPLAY=:0 Godot --path . --xr-mode off --audio-driver Dummy --script tools/authority_core/transport_functional.gd
```

The full-map probe clones materials in its own process and controls vertex/per-pixel sampling independently of the gameplay globals. The avatar shader benchmark writes `test-results/avatar-headlights`; its archived results and captures are under `avatar-shader/`. All timings are development-machine observations, not a 64-player or headset budget certification.
