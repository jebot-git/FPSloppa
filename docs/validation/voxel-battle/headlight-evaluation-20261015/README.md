# Transport entry text and headlight feasibility — 2026-10-15

The transport's floating `DRIVER · USE` / `PASSENGER` entry labels are removed. All eight occupant seats and authored boarding points remain. The existing graphical transport suite passes **55 checks**, including boarding, dismounting, collision, cockpit/pod visibility and model replacement. The model audit reports eight seats and zero Label3D entry markers.

**Vehicle headlights are feasible, but pure vertex lighting is unsuitable for every current surface.** This is a source/geometry evaluation; no production headlights or offhand toggle have been enabled, and no headlight GPU timing or i7-12700 benchmark is claimed.

## Findings from actual meshes

| Surface | Measured topology | Consequence |
| --- | --- | --- |
| Near buildings | 40,344 triangles; 5,108 (12.7%) have a longest edge over 8 m | A narrow moving beam can miss corner vertices and disappear from an otherwise illuminated wall/floor |
| Middle buildings | 30,442 triangles; 4,844 (15.9%) over 8 m | The problem persists through LOD changes |
| Large site faces | Maximum edge 144.35 m; per-site near p95 ranges 16.02–28.00 m | Retessellating all surfaces solely for headlights would add substantial geometry and complicate the destruction bake |
| Streamed terrain | Actual tile side 31.78 m; vertex spacing approximately 0.99 / 1.99 / 3.97 / 7.94 m across LODs | Vertex cones are plausible on near terrain; coarse levels will show interpolation/popping |
| Global coarse terrain | Vertex spacing 22.10 m | Unsuitable for a narrow close beam; suppress/fade its contribution instead of forcing distant tessellation |

A geometric counterexample in the audit uses an ordinary 12 × 8 m wall, a lamp 10 m away at 1.2 m height and a 22° half-cone. Its center is illuminated, but **none of its four corners are**. Per-vertex evaluation would interpolate zero across the entire wall. This is a coverage calculation, not a rendered screenshot or performance result.

The baked near/middle building meshes currently store **no normal attributes**. They compute normals during offline irradiance authoring but do not retain them for runtime direct-light shading. A cone-only brightness approximation can work without normals; credible Lambertian headlight shading needs normals generated offline, or fragment-derived face normals for a per-pixel branch. The terrain shader currently computes `jungle_point` before GPU height displacement; headlight position/direction calculations must instead use the final displaced position, with height-gradient normals if surface orientation is evaluated.

## Recommended approach

1. Add analytic, soft-edged cone illumination to the existing baked shaders. Compute it per vertex on nearby terrain, and per pixel on coarse building/floor faces, rubble and vehicle materials. Add this contribution to the baked illumination, rather than replacing the day/night/weather blend or rebuilding meshes every frame. Enabling Godot's `vertex_lighting` flag alone will not make the existing `unshaded` custom materials respond to ordinary lights; see [Godot's spatial shader documentation](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html).
2. Start with a bounded nearest-light list: for example four nearby vehicles/eight cones, prioritizing the local driver's lights. Vehicle transforms already replicate, so only the on/off state needs additional authoritative replication. Range/cone width remain tuning choices; a 40–60 m driving beam is a reasonable prototype input, not a validated gameplay range or cost claim.
3. Mount paired lamps to the hull's rendered basis, including slope alignment, rather than turret aim. The source models need per-vehicle mounting coordinates and visible emissive lamp faces. Shader-only receiver illumination does not create a volumetric beam in rain/fog; that requires a separate bounded cosmetic effect.
4. Resolve occlusion explicitly. An unshadowed cone illuminates walls behind walls. A small driver-priority ray fan can conservatively truncate beam range for an inexpensive first approximation, but does not provide correct doorway/partial-object shadows. Accurate shadows require additional depth/shadow rendering. Current batched structures disable shadow casting, so ordinary shadowed SpotLight3D nodes are not a drop-in solution for this renderer. NVG exposure/glare must also include enabled headlamps, rather than changing only visible ALBEDO.

## Offhand-trigger routing

The raw VR trigger is available, but the current input pipeline intentionally suppresses it for mounted actors:

- `deathmatch/vr/rig.gd` gates `offhand_fire` behind dual pistols, weapon slot 2 and a held/tracked offhand weapon.
- `class_arena.gd::_local_command()` clears both `offhand_fire` and `reload_trigger` while mounted. The latter also normally depends on holding a gun.
- Therefore reuse the physical binding, **not the weapon-fire action**: sample a dedicated vehicle-light action while mounted, on the press edge. Route it through a sequenced authority action and replicate a bool in vehicle state. Holding a trigger must not toggle every tick or activate weapon/reload behavior.
- The authority should accept it only from the current driver (transport cockpit seat 6), with fresh valid input and menus/tracking block checks. Initialize the latch on boarding to require release/repress if the trigger was already held. Passenger presses must not change lights. Define reset/destruction behavior and ensure late joiners receive the current switch state.

On the i7-12700, this shader workload will principally depend on the **actual GPU**, screen/headset resolution, receiver vertex/pixel counts and shadow choice. CPU-model speedup estimates cannot establish headlight GPU cost. A useful next implementation probe would compare lights off/on with 1/4/12 vehicles, night/rain, terrain LOD transitions, occluding walls and VR stereo, recording GPU timestamps and CPU submission separately.

Reproduce the audit with `Godot --headless --path . --xr-mode off --script tools/voxel_battle/evaluate_headlights.gd`. `geometry.json` retains the per-site values and transport label check; `transport-checks.json` records the existing suite's result. There is no runtime lighting or authority change in this revision.
