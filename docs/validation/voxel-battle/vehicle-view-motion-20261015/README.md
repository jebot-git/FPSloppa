# Vehicle camera and cabin motion — 2026-10-15

[Behavior and implementation](../../../CQ-VEHICLE-VIEW.md).

- **76 focused checks** passed on Godot 4.7.2 / Intel ADL-N Vulkan Forward+: desktop boresight, rendered muzzle position, current scope camera, immediate mouse response and shared elevation clamp for light/heavy/rocket tanks; actual rendered barrel/camera basis equality; controller-driven VR aim independent of head rotation; VR origin/hull alignment; normal stereo view; transport seat/camera attachment at five interpolation fractions; continuous intermediate positions; actual model-to-eye transform equality; unchanged authority state; teleport snapping; received-snapshot history; dismount camera visibility and reset cleanup. The focused fixture exits without script errors or resource leak warnings.
- **5 existing VR stereo checks** passed: normal world/lighting, no desktop scope feed, stereo reticle, own-hull hiding and dismount restoration. Its fixture now supplies the player/controller pose needed to exercise render-frame aiming.
- **482 turret-axis checks** passed for imported light/heavy assets, including hull slopes and yaw/pitch limits.
- The existing **hover-tank suite** passed (`CQ_HOVER_RESULT []`), including boarding, driving, gun limits, firing/reloads and support normals. Its existing ObjectDB/resource cleanup warnings remain.
- The existing **55-check transport suite** passed in the graphical runtime, including vehicle/seat geometry, boarding, driver seat selection, normal camera masks, drive behavior and visuals. This fixture needs a desktop camera and its `/tmp/cq-lpmac` image-output directory; both were supplied for the final run.
- Editor import, arena script parse and `git diff --check` passed. No native build was needed because authority C++ and wire format are unchanged.

The desktop fleet test is reopened with four light tanks, two heavy tanks, two rocket tanks and four transports in one courtyard. VR behavior was checked using controller/head-pose fixtures, not a physical headset session. No VPS deployment or multiplayer load benchmark was performed.
