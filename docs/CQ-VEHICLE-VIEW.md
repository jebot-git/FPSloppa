# Vehicle aim and seated movement presentation

The local desktop turret and its scope camera share one render-frame aim direction, derived from current mouse yaw/pitch and clamped to the gun's elevation limits relative to the hull. The camera follows the rendered muzzle, uses the hull's up axis and explicitly remains the scope viewport's current camera. This avoids waiting for the next simulation tick to update the local sight separately from the visible barrel. Gameplay still uses validated aim commands at the authority's tick rate.

In VR, the turret follows the weapon-hand controller through the existing weapon-pose function. Head gaze remains independent, and the normal stereo world view is retained. The projected boresight reticle follows the gun; no desktop scope feed is enabled in VR.

Vehicle models now render between physics poses. Received snapshots interpolate from the currently displayed pose over the observed update interval (bounded to 8.3–150 ms); teleports of 20 m or more and vehicle-type changes snap. Local fixed-tick rendering uses Godot's physics interpolation fraction. The manually animated model roots disable automatic interpolation, avoiding an additional interpolation pass.

The transport's desktop camera and VR origin use the seat point on that same rendered hull pose. Previously the hull used the latest physics position while the camera followed a separately interpolated player capsule, causing the cabin to shift around the eye between updates. Physics seating, collisions, input, vehicle speed and authoritative state remain unchanged. The camera retains its existing eye height; VR retains free head orientation.

Interpolation history clears with the vehicle service, and removed snapshot entities release their history. Headless script-authority hosts skip local render-history sampling; the native authority and network layout are unchanged.

[Validation](validation/voxel-battle/vehicle-view-motion-20261015/README.md). The local desktop fleet test is relaunched with all twelve vehicles grouped in the military courtyard.
