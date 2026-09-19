# Bullet and trail illumination without realtime light nodes

Current implementation: [weapon matrix and live map integration](WEAPON-EMISSION.md). The report below records the earlier isolated feasibility experiment.

19 September 2026. **Feasible as a bounded surface-shader approximation.** The isolated prototype visibly illuminates map surfaces around moving emissive bullets and trails without creating any `Light3D` nodes, rebaking maps, or adding a surface-render pass. It is not integrated into gameplay.

Follow-up: the [BSP occlusion experiment](TRAJECTORY-OCCLUSION.md) fixes the reproduced leakage, including thin walls and transformed door fixtures. It adds significant scene-dependent shading cost; see that report for the selected method and measured limits.

Emission alone makes the projectile visible but does not illuminate neighboring surfaces in the project's Mobile/Vulkan renderer. The experiment explicitly disables glow, ambient fill and reflected sky fill: the comparison isolates actual changes to surface shading rather than a bright screen-space halo. Godot's [GI comparison](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html) documents that VoxelGI, SSIL and SDFGI are unavailable in Mobile; baked lighting cannot follow a moving emissive projectile. A renderer switch and dynamic GI would be a separate, substantially larger experiment.

## Prototype

`trajectory.gdshaderinc` adds world-position and normal interpolation to temporary copies of the existing `baked_light.gdshader` and `quake_light.gdshader`. For each surface pixel, it finds the closest point on a projectile's recent path, applies a radius falloff and normal-facing factor, and adds texture-tinted color to the existing baked emission. A zero-length segment handles a bullet; a longer segment handles a trail. This is still dynamic shading math, even though it uses no engine realtime light objects or shadow maps.

The test limits the pool to eight segments, with 2.7 m influence radius and 3.5 m trail length. Both orange and blue colors are exercised. No new lightmap assets, shader texture fetches, or lighting draw calls are required. The prototype uploads arrays to 10 or 16 map materials each frame; a production implementation could share a small global parameter pool. The visual projectiles are simple emissive boxes so gameplay, particles and networking cannot influence the comparison.

## Validation

The real-renderer test uses Intel Arc A770, Mobile/Vulkan, Godot 4.7.2, 1280×720 and 4× MSAA. It exercises two existing BSP shader paths: dark authored Quake DM6 and Vesper's baked shader with Contrast enabled. Vesper is a brighter control, not an artificially darkened map.

Fourteen checks pass, including loaded scenes containing no realtime lights, nearby surfaces changing beyond the emissive projectile core, zero-length bullet behavior, exact thresholded restoration when the effect is disabled, and intentional reproduction of the occlusion limitation. Surface changes are measured at every second pixel with a 0.03 channel-increase threshold. The resulting comparison images were inspected visually. The Godot process reports one ObjectDB cleanup warning on exit, with no shader errors or failed checks.

Performance blocks use identical eight visible projectile meshes for every setting. Stock shaders, the modified shader with zero emitters, and 1/4/8 emitters are each measured twice in reverse order, after a three-second warmup per map. Each block measures 600 frames, for 12,000 measured frames total. CPU parameter updates and renderer CPU/GPU times are recorded separately. Raw data and summary are in `docs/validation/trajectory-light.json`; `test-results/trajectory-light/initial-run.json` retains the shorter, noisy preliminary run.

Final measurements below average the two block medians. Additional GPU time is relative to the stock shader rendering the same visible projectiles:

| Map | Stock GPU | +1 emitter | +4 emitters | +8 emitters |
| --- | ---: | ---: | ---: | ---: |
| Quake DM6 | 0.148 ms | +0.015 ms | +0.044 ms | +0.058 ms |
| Vesper | 0.194 ms | +0.013 ms | +0.045 ms | +0.089 ms |

All blocks had nine median draw calls. Median script update time, including updating the eight projectile transforms, ranged from 0.015 to 0.026 ms. The zero-emitter modified shader measured slightly faster than stock (-0.010 / -0.002 ms), illustrating residual measurement variation rather than an optimization claim. The preliminary short run had substantial clock/order variation; these longer measurements indicate small desktop cost in these views, not a fixed frame budget or a headset performance guarantee.

## Main limitation: occlusion

Distance and normal orientation alone do not know whether a wall blocks the emitter. A dedicated divider-wall fixture reproduces light appearing on the floor across the wall. Normal rejection keeps the wall's back face dark but cannot prevent illumination of other facing surfaces behind it. Real projectile collision must also clip the trajectory at impacts; this visual-only probe does not simulate projectile collision and its moving demonstration can cross geometry.

This version therefore demonstrates feasibility but is not ready to enable universally. Short ranges reduce leakage but do not solve it. For production, evaluate visibility against static BSP geometry, or raycast and draw patches clipped to the actual receiving surfaces. A generic projected decal or one center ray cannot guarantee correct occlusion. Either solution has its own CPU/GPU cost and needs a further test. Shadows from players and moving doors, bounced light, specular response and illuminating avatar shaders are outside this prototype.

## Recommended integration

- Start with a cosmetic pool of four nearby effects, with eight as a desktop quality option. Cull distant effects and smoothly fade or replace the least important entry. Avoid allocating a light influence to every nail, particle or pellet.
- Feed the pool from existing projectile interpolation and impact/tracer presentation in `deathmatch/experimental/visuals.gd`; keep damage and network state unchanged. End trails at authoritative impact geometry, and fade energy over their short presentation lifetime.
- Apply the receiver code to both baked BSP shaders while preserving their texture filtering and light-response options. Other materials need explicit support; emissive projectiles cannot automatically illuminate every shader in the scene.
- Resolve occlusion before gameplay rollout. Validate real weapon speeds, crowded fights, thin walls, doors, water and VR stereo. Mobile/Vulkan running on a desktop GPU is not a Quest/Pico performance test, and this experiment does not establish that the approximation is cheaper than unshadowed engine lights.

## Artifacts and reproduction

- `test-results/trajectory-light/comparison.jpg`: matching emission-only / surface-illumination views.
- `test-results/trajectory-light/trajectory-demo.mp4`: four-second, 30 fps deterministic illustration of a moving segment in DM6; not recorded gameplay.
- `test-results/trajectory-light/wall-leak.png`: deliberately failing physical occlusion case.
- `test-results/trajectory-light/report.json`: measurements and checks.

```sh
godot --xr-mode off --path . --rendering-method mobile \
  --log-file /tmp/trajectory-engine.log \
  --script res://tools/lighting_experiment/trajectory_probe.gd
python3 tools/lighting_experiment/trajectory_report.py
```

The probe requires a graphical session; headless mode cannot validate GPU behavior. The report utility requires Pillow and FFmpeg. All shader modifications are in-memory copies; production shaders, map assets and weapon behavior remain unchanged.
