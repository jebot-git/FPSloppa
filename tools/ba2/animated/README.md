# BA-2 — 10 metre slow crawl

Authored animation prototype, 13 September 2026. Original model: **Quandtum**, BA-2 v1.1. See [source and licensing notes](../SOURCES.md); original geometry and painted textures are retained.

- `BA2-10m-walk.blend`: editable rig and four baked actions, sampled at 30 fps. The active `RoutePreview` action occupies frames **0–534**.
- `BA2-10m-walk.glb`: one material, 18-bone skeleton and all four actions. Scale is included: **do not multiply it by ten again**. Godot import and exported toe positions were checked.

| Clip | Duration | Intended use |
| --- | --- | --- |
| `WalkStart` | 6.6 s | In-place start: accelerates from rest over 2 s, then finishes the first gait cycle |
| `WalkLoop` | 5.6 s | In-place crawl at 0.45 m/s; enable looping in the engine |
| `TurretSweep` | 16 s | Independent cannon-only sweep; enable looping and blend in over about 4 s |
| `RoutePreview` | 17.8 s | Combined demonstration with forward root motion, acceleration and eased turret aiming; do not loop the route translation |

For a fixed route, move a parent actor using `WalkStart` then `WalkLoop`. During the first two seconds, use `u=t/2`, speed `0.45*(3*u*u-2*u*u*u)` and distance `0.9*(u*u*u-0.5*u*u*u*u)` metres. After two seconds, distance is `0.45*(t-1)` metres. At 6.6 seconds, switch directly to `WalkLoop`; each loop advances 2.52 m. Walk actions contain no cannon tracks, allowing aiming to be layered separately. Both walk clips are in place: they need the matching parent movement to keep feet planted in the world.

The model faces **+Z after standard glTF conversion into Godot**, and the demonstration root moves +Z. Align that direction to the route tangent. Each cannon rotates **only around its local X hinge**, within **±4°**; its local Y and Z rotations stay zero. The body can yaw **±3° around the vertical axis** (Godot Y / Blender Z, also the Body bone's local Y). The gait compensates the legs for this body turn so stance feet stay planted. For gameplay targeting, preserve these axes and limits and turn gradually.

Reset the skeleton before switching from the root-motion demonstration to in-place use. Some importers remove constant rest-value tracks, so a previously translated demo root can otherwise remain offset. Blend only the two cannon bones for the turret overlay; avoid blending the entire skeleton against its rest pose.

The stance is approximately **11.06 m wide × 9.06 m long × 10 m high** at the start. The animation targets a level route and is not terrain IK, collision logic, a moving platform or multiplayer integration.

[Preview and validation report](../../../docs/BA2-WALK.md).
