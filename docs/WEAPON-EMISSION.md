# Weapon illumination and projectile validation

19 September 2026. The bounded BSP-occluded surface effect is now connected to live weapon visuals and the two baked-map shaders. It replaces the local weapon muzzle `OmniLight3D`; weapon illumination adds no realtime light nodes, shadow maps or map drawing passes. Damage, collision radii, firing rules, RPC signatures and demo event formats are unchanged.

## Coverage and changes

The graphical matrix exercises all 10 Doom slots, 10 Quake slots, both inputs for all 12 UT slots, all 32 owned TF class/weapon combinations, an eight-cell bio glob and a six-rocket volley: **78 cases**. Melee, scope-only and translocator secondary inputs are explicitly checked for no shot illumination. Actual sentry, titan cannon, flame, explosion and napalm effect code is exercised separately, as is shock combo.

- Doom rockets now have a rocket model and exhaust; plasma and BFG retain their defined projectile radius and gain blue/green trails and impact illumination.
- Nails and tranquilizer darts have short, readable streaks without room-lighting glow. TF engineer rail nails get a restrained blue contribution. Grenade bands and disc edges remain readable in darkness.
- Quake lightning, UT shock and pulse, and the instagib rail have distinct colours and beam widths. TF and UT sniper tracers remain thin and brief. Heavy and shotgun pellets share a muzzle source rather than lighting every pellet path.
- Charged bio uses its already-scaled definition radius once. Its small green contribution grows modestly with charge. Resting goo and translocator discs do not illuminate indefinitely.
- Projectile streaks follow recent rendered movement, clip against world collision, and do not bridge large corrections or long frame gaps. Flame puffs stop at their traced endpoint.
- Sources expire, coalesce by projectile, and clear on impact, disconnect and map transition. At most 64 candidates feed **two sources on both desktop and XR**, shared across all weapons and effects. Contributions are capped at 0.55 per linear colour channel.

## Occlusion and scope

The map pool loads the world BSP and registers solid brush model roots using the same transforms as their triangle collisions. It updates moving doors/platforms each frame. Per-source bounds prune the tree before upload. CPU pruning has depth and visit limits; GPU traversal has stack and visit limits. Invalid or excessive complexity fails dark. If more than four brush roots intersect the selected source region, illumination is suppressed rather than leaking through an omitted blocker.

This production receiver path covers `baked_light.gdshader` and `quake_light.gdshader`, including compatible cached BSP scenes upgraded by the existing material filtering code. Ordinary materials, water, and avatar materials do not receive this new contribution yet. The earlier [avatar receiver experiment](AVATAR-TRAJECTORY-LIGHTING.md) remains separate. Avatars and arbitrary non-BSP dynamic meshes do not cast occlusion into this effect. This is bounded shader illumination, not general dynamic GI.

## Validation

**490 graphical checks passed**, including actual live-arena plasma spawning/impacts, TF heavy hitscan, transition cleanup, all weapon cases and projectile impacts, the 2 cm wall, translated and rotated brush blockers, candidate limits and the live desktop/XR two-source cap, cyclic-tree rejection, and dark Quake DM6. The existing weapon/rules/demo suite passes **71 checks**; the optics/FX suite passes **23**; simulated-VR muzzle/interpolation presentation passes **28**. The simulated-VR run emits a PulseAudio microphone shutdown warning, after all assertions pass. Final graphical logs contain no script or shader errors; Godot reports its existing shutdown ObjectDB warning.

The comparison captures hold projectile and particle geometry fixed while disabling/enabling only receiver illumination. Small projectile tests place the projectile near the floor so its deliberately short-range light can be measured. They are visual/effect tests, not a new multiplayer balance or headset playtest.

An Intel Arc A770, Godot 4.7.2 Mobile/Vulkan, 800×600, 4× MSAA DM6 probe measures zero/two/two/zero sources after warmup, 300 samples per block. The latest two-source run adds approximately 0.15–0.30 ms GPU relative to its two zero-source blocks and 0.08 ms CPU upload/pruning, with unchanged map draw count. Clock/order variation is visible in the zero-source samples; use the [raw summary](validation/weapon-emission.json), not these figures as a full-match or headset guarantee.

Artifacts are under `test-results/weapon-emission/`: `highlights.jpg`, `all-profiles.jpg`, `tf-and-charged.jpg`, `dm6-comparison.jpg`, individual off/on and impact captures, `report.json` and `performance.json`.

```sh
godot --xr-mode off --path . --rendering-method mobile \
  --script res://tools/lighting_experiment/weapon_matrix.gd
python3 tools/lighting_experiment/weapon_report.py
```
