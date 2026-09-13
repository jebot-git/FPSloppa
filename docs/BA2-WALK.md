# BA-2 slow walk animation

An initial walk animation has been authored for the **10 m** version of BA-2. It uses a slow four-beat crawl, one foot lifting at a time, with a small amount of body motion. It reaches **0.45 m/s over 2 seconds** and then maintains that speed. Each 5.6-second cycle advances 2.52 m; toe clearance peaks at 0.38 m.

[Video preview](../test-results/ba2/walk/BA2-10m-walk-preview.mp4) · [Scale/pose preview](../test-results/ba2/walk/still-2.png) · [Blender file](../tools/ba2/animated/BA2-10m-walk.blend) · [Animated GLB](../tools/ba2/animated/BA2-10m-walk.glb)

The video shows the start and two subsequent cycles, covering 7.56 m in 17.8 s. The orange figure is **1.8 m tall** and the floor tiles are **2 m wide**. The camera follows the model; the fixed floor and figure show its travel. Preview shading reconstructs the packed diffuse and emission maps. It is a Blender preview, not a Quest or FPSloppa gameplay capture.

## Animation structure

`WalkStart` (6.6 s) accelerates for its first two seconds, then completes one cycle so it joins `WalkLoop` (5.6 s) at a matching pose and gait speed. These clips are in place for use with a route controller. `TurretSweep` (16 s) only animates the two cannon mounts. `RoutePreview` (17.8 s) combines forward root movement, walking and eased aiming for review.

Following the user's axis correction, each turret rotates **only around its local X hinge**, within **±4°**. Entry is eased over four seconds; maximum measured angular speed is **2.06°/s**. The body has a gentle **±3° yaw around the vertical axis** (Godot Y / Blender Z; the Body bone's local Y). Leg poses compensate for that body turn while retaining planted feet. Independent cannon tracks are excluded from the walk clips.

The original rigid weights and mesh are retained. The authored rig keeps 18 bones and removes the unused IK/FK controls. A deterministic two-link leg solve is baked to the existing weighted FK bones; holding each blade-foot's orientation steady keeps its actual lowest toe vertex planted. The editable file contains sampled actions, and `tools/ba2/author_walk.py` regenerates them from the original source with adjustable gait parameters.

## Validation

- Height at the initial pose: **10.000001 m**. Initial width/length: **11.06 × 9.06 m**.
- All **535** demonstration frames checked at 30 fps: maximum planted-toe movement per frame below **0.004 mm**, maximum floor penetration below **0.004 mm**, no unreachable leg targets, and at most one airborne foot.
- The walk loop endpoints and start-to-loop boundary match to numerical precision. All GLB clips start at time zero and have their intended durations.
- Godot **4.7.2** loaded all four clips and the 18-bone skeleton, evaluated finite poses, and reproduced **7.5600004 m** of root travel. Exported toe positions matched Blender's sampled positions within **0.006 mm**. Cannon X-only movement and the body's ±3° vertical yaw limit also passed after import.

Evidence: [baked motion checks](../test-results/ba2/walk/animation-checks.json), [GLB checks](../test-results/ba2/walk/glb-checks.json), [Godot checks](../test-results/ba2/walk/godot-checks.json). These small contact-error measurements describe numerical consistency on the authored level floor, not physical balance or accuracy on a real map. The final Godot test uses an isolated project. Blender completed its saves/exports/renders but requires interruption after an audio-shutdown stall in this sandbox; logs preserve that environment limitation.

## Use and limits

See the [asset README](../tools/ba2/animated/README.md) for clip timing, parent movement, turret layering and orientation. Use its baked scale once. The standard glTF conversion makes the source's forward direction +Z in Godot; route code should align that axis deliberately.

This is an animation prototype for a level, fixed route. Terrain adjustment, support-polygon/centre-of-mass simulation, collision between the moving parts and map, rideable surfaces, combat and multiplayer behavior are not implemented. No production gameplay files or distribution packages were changed. The source's [texture provenance notes](../tools/ba2/SOURCES.md) remain applicable.

Follow-up: the [TB — TITANBALL prototype](TITANBALL.md) now supplies gameplay integration and a winding test corridor. The limitations above describe the earlier animation-only assessment.
