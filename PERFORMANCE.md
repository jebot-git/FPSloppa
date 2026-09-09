# VR performance and verification

The target is native 72 FPS or better: 13.89 ms per frame at 72 Hz, 11.11 ms at 90 Hz. This build is optimized toward that target, but has **not** demonstrated it on Quest, Pico or PC VR hardware. No headset was connected for this release. A successful APK export is not a frame-rate or thermal test.

## Changes

- Vulkan Mobile renderer on PC and Android, following Godot's current XR recommendation. OpenXR handles stereo/multiview and headset frame pacing; desktop VSync is disabled in XR. PC retains the runtime's refresh selection. Standalone requests the lowest advertised refresh rate at or above 72 Hz when the session starts.
- OpenXR VRS on the main viewport; medium dynamic foveation for compatible runtimes. Unsupported runtime extensions are optional. This is not a guarantee of eye-tracked foveation on every device.
- 4× MSAA on PC, 2× on Android; no SSAO, glow or dynamic sun shadows. No second full-scene spectator render is added.
- BSP occlusion culling and bounded nearby unshadowed lights: eight on PC, four on Android, selected at 5 Hz. Ambient illumination remains available throughout the maps.
- VRM outline passes and shadow casting disabled. Meshes retain their authored materials, transparency and expressions. Geometry is hidden beyond 65 metres.
- Cached bone lookup and foot contact queries at 12.5 Hz. Body IK runs at display cadence within six metres, approximately 30 Hz beyond six metres and 15 Hz beyond eighteen metres, retaining the last solved pose between updates. Eye, head/weapon presentation and locomotion continue through the existing render/snapshot paths; authoritative combat is unchanged.
- Hidden/disabled avatars skip signal-driven spring-bone simulation. Silent mouth expressions stop doing blend-shape work once they reach rest.
- Bot decision/line-of-sight work runs at 5 Hz per bot and path queries at most every 0.6 seconds. The five supplied navigation meshes are baked ahead of time. Audio and combat effects retain their existing bounded pools.

Custom VRM size limits are not GPU-complexity guarantees. Eight unusually expensive custom models, imported map compilation, initial VRM decoding, or a large effects-heavy fight can still miss the frame budget. Runtime VRM/BSP imports remain synchronous at their existing import points; do them before a match where possible. No reprojection or generated frame count is represented as native FPS.

## Repeatable desktop measurement

`deathmatch/tests/benchmark.gd` loads Solstice and eight player models (local model hidden, seven remote models visible), places them above the map geometry for a consistent view, warms up, and records 360 frames while gently rotating the camera. It saves a screenshot and JSON percentiles in `test-results/`. This is a rendering stress comparison, not a playable-map route or a headset test. Both compared runs use the same final gameplay/IK code; the reference restores the earlier expensive rendering settings.

Hardware: Intel Graphics ADL-N, Linux, 1440 × 900 single viewport, VSync off, Godot 4.7.2 editor binary running the game script.

| Configuration | Median frame | 95th percentile | Median FPS equivalent | Draw calls (median) |
|---|---:|---:|---:|---:|
| Forward+ reference; SSAO/glow, sun shadows, outlines, all map lights, no occlusion | 49.315 ms | 52.572 ms | 20.3 | 1446 |
| Final Mobile renderer and bounded effects | 16.390 ms | 20.411 ms | 61.0 | 36 |

Median frame time decreased by approximately 67%. The measured result still misses 72 FPS on this integrated GPU. Different renderer batching and shadow passes affect draw-call accounting. Source JSON and screenshots: `benchmark_render_reference.*`, `benchmark_optimized.*`. The older `benchmark_baseline.*` used a different camera placement and should not be used for this controlled comparison.

Reproduce optimized run:

```sh
godot --path . --xr-mode off --script res://deathmatch/tests/benchmark.gd -- optimized
```

Reproduce rendering reference (explicitly select Forward+):

```sh
godot --path . --xr-mode off --rendering-method forward_plus --script res://deathmatch/tests/benchmark.gd -- render_reference
```

## Real-headset acceptance test still required

Launch with `-- --frame-stats` to print ten-second frame percentile summaries after a five-second warmup. Use `-- --practice --map lqdm1 --frame-stats` for an offline session. These application timings supplement, rather than replace, compositor CPU/GPU timing.

Test each headset and supported PC GPU at native resolution and its selected refresh rate, with eight crossplay participants, voice enabled, several different VRMs, tracking active, weapon effects and each BSP arena. Run at least 20 minutes to catch thermal throttling. Use Meta OVR Metrics/Performance Analyzer, SteamVR frame timing and PICO Graphics Probe as appropriate; inspect CPU and GPU costs separately, missed frames and reprojection. Verify tracking latency and image readability in addition to FPS. Repeat with heavy permitted custom content and during joins/downloads. Keep 72 FPS unverified until these measurements pass.

Sources informing these choices:

- [Godot: Setting up XR](https://docs.godotengine.org/en/stable/tutorials/xr/setting_up_xr.html) — Mobile renderer recommendation.
- [Godot: OpenXR settings](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_settings.html) — VRS and foveation support.
- [Meta: Testing and performance analysis](https://developers.meta.com/horizon/documentation/unity/unity-perf/) — device profiling and required performance assessment.
- [Valve: Advanced VR Rendering, Alex Vlachos](https://media.steampowered.com/apps/valve/2015/Alex_Vlachos_Advanced_VR_Rendering_GDC2015.pdf) — frame budgets, stereo efficiency and MSAA.
- [PICO: Graphics Probe](https://developer.picoxr.com/blog/graphics-probe-tool/) — device graphics profiling.
