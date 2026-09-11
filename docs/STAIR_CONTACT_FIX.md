# Stair contact correction after 0.9v

The [reported video](https://streamable.com/l02zcj) shows stair sticking in
Solstice (`lqdm1`). Tests reproduced slow/oblique ascent failures using both its
existing collision scene and isolated box/triangle staircases. No BSP geometry
or capsule dimensions were changed.

The old controller tested a point at least 15 cm ahead, lifted only vertically,
then performed a different horizontal movement. A rounded capsule could land
against the edge rather than the tread, slide back down, or lose its inward
velocity. Its initial sweep also omitted collision-recovery contacts, allowing
tiny motions to pass the step test but be stopped by `move_and_slide`.

The corrected controller tests the actual frame's up–forward–down path and
consumes that movement once. It includes opposing recovery contacts, validates
the tread surface when a rounded corner produces a steep contact normal, and
remembers step support for movement and VR physical-jump detection. Available
headroom can be smaller than the maximum step lift. Actual tread height remains
limited to 0.55 m; low ceilings and other players cannot be bypassed. Teleports
clear remembered support, and the existing view smoothing remains in use.

Godot documents the recovery-contact option in
[PhysicsBody3D](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html).

`deathmatch/tests/stair_contacts.gd` supplies 36 checks, including slow input at
60/90/144 Hz, box and triangle stairs, horizontal travel limits, headroom, ledge
height, jumping from a tread edge, and six real Solstice approaches. Installing
the base assets enables the map cases. The old source failed ten of the twelve
slow-ascent cases; the corrected source passes all twelve.

An exploratory 220-approach Solstice survey improved 40 stalled approaches, with
no newly blocked cases under the same progress threshold. Its remaining fourteen
cases are not certified navigable routes: generated tread pairs can lead into
walls, corners or insufficient headroom. This is not a claim that every possible
stair approach is now verified.

The existing stairs, Quake movement, rocket jump, room-scale, water, movement
audio, VR gesture and player-platform tests pass (137 explicit checks plus the
platform assertions). A short 16-player server check measured a 4.172 ms p95 tick,
with no orphan nodes in its samples or final cleanup. Existing isolated Godot
shutdown ObjectDB warnings remain. These are source tests; exact video inputs,
live headset comfort and new release binaries have not been tested here.

Full results: `docs/validation/stair-contacts.json`.
