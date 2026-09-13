# BA-2 fixed-route walker assessment

Follow-up: a [10 m slow walk prototype](BA2-WALK.md) has now been authored and exported. The acquisition assessment below records the original, unanimated source.

**Feasible, with moderate animation and gameplay work.** The downloaded model already has a suitable mechanical rig. A large walker following an authored route is a good fit; it does not require VRM conversion, autonomous navigation or a replacement mesh.

Source: [Quandtum's BA-2 listing](https://opengameart.org/content/ba-2-blast-all-bot-mark-2). Acquisition, checksum and texture provenance are recorded in [SOURCES.md](../tools/ba2/SOURCES.md).

## Verified in the downloaded file

| Property | Actual inspection result |
| --- | --- |
| Geometry | 3,380 source vertices, 6,696 triangles, one material and UV layout |
| Mechanical parts | 16 disconnected components, corresponding to 16 weighted groups |
| Skinning | Every vertex has exactly one nonzero bone influence; no unweighted model vertices |
| Rig | 38 bones including controls; four three-segment leg chains with IK/FK controls |
| Weapons | Separate `Cannon.L` and `Cannon.R` bones, 456 vertices each; each controls a complete twin-barrel side assembly |
| Existing animations | Only a one-frame `PoseLib` action; no walking cycle |
| Textures | Five packed 2048² maps: diffuse, normal, bump, specular and emission |

The source dimensions are approximately 3.98 × 3.31 × 3.74 Blender units. Uniformly scaling that inspected stance to **6 m tall** gives approximately **6.38 m wide × 5.30 m long**. This is a planning example, not an agreed final scale or a measured swept collision envelope. Leg swings, weapon aiming and turns require additional clearance. Enlarging the model does not increase triangles, but makes texture resolution and silhouettes more noticeable.

## Articulation tests

All six checks passed in Blender 5.2: both cannon assemblies rotated by 15° pitch and 25° yaw without moving other components; each of four IK foot targets moved 0.30 units forward and 0.25 units upward, with endpoint error below 0.00003 units and unrelated vertex displacement below 0.000001 units.

These checks establish independently usable rig controls. They do not establish collision-free motion throughout a complete cycle, mechanical clearance at all aim angles, or gait stability. The side mounting makes pitch visually natural; wide yaw and unrestricted 360° rotation need a separate swivel/mount design and clearance review. Additional top-mounted emplacements would require new geometry and bones or attachment nodes.

Preview poses: [neutral](../test-results/ba2/pose-0.png), [raised diagonal pair and aimed cannons](../test-results/ba2/pose-1.png), [opposite pair and aim](../test-results/ba2/pose-2.png). These are articulation samples, not a finished walk cycle. They use reconstructed diffuse/emission materials, not the original Octane material or FPSloppa rendering.

Detailed evidence: [inventory](../test-results/ba2/inspection.json), [pose checks](../test-results/ba2/pose-checks.json), [execution log](../test-results/ba2/pose-probe.log). All reports and three renders completed. Blender then stalled during audio shutdown in the sandbox and was interrupted; the log records that limitation separately from successful articulation checks.

## Suggested implementation if pursued

1. Author a slow four-beat crawl with three feet supporting the body for most of the cycle. Use the existing IK controls to keep stance feet planted, add restrained body motion and bake the evaluated deform-bone transforms into glTF animation. Strip unused controls from the runtime skeleton. Keep weapon aim out of the walk tracks so it can be applied independently.
2. Move a parent actor along a fixed, distance-parameterized route with smooth heading changes, explicit stop points and generous corner radii. Couple walk phase to distance traveled to avoid sliding as speed changes. On a deliberately level route, baked gait should suffice; uneven ground would need limited foot adjustment or terrain-specific clips.
3. In multiplayer, let the server own route progress, pauses and turret targeting; interpolate presentation on clients. Use simple body/leg hit volumes rather than a moving concave triangle collider. Decide separately whether players can stand on it: carrying riders and preventing crushing/clipping make this substantially more involved.

The current `train_motion.gd` only scrolls scenery around a stationary train and explicitly does not move solid collision. It is not an existing solid walker/path controller that can simply be reused.

## Cost and effort estimate

For one walker, the mesh and roughly 16 useful weighted parts should be modest compared with detailed avatars. Keep one opaque material where practical and use baked animation; avoid runtime rigid-body simulation for each limb. Five uncompressed 2048² RGBA maps with mipmaps would occupy about **107 MiB**, so texture selection/compression matters more than this polygon count. A runtime material need not sample both normal and bump; legacy specular data also requires deliberate conversion rather than blindly assigning it as metallic. No Quest performance claim is made from these CPU-rendered Blender tests.

Planning estimate: **1–2 working days for a local prototype** covering material conversion, one walk cycle, route movement and independent aiming; **roughly 3–7 additional days** for convincing planted feet/turns, collision and multiplayer integration, and desktop/Quest validation. These are estimates, not measured delivery commitments. Rideable behavior, destructible parts or newly modeled 360° turrets would expand the scope.

Only acquisition, inspection and isolated pose tests were performed. No gameplay code, production assets or distribution packages were changed.
