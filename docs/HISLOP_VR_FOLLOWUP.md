# HiSlop, lobby cleanup and VR follow-up — 2026-09-11

The working map and source have been updated. No release binaries were exported
or published for this follow-up. Existing unrelated working-tree edits are retained.

## Lobby cleanup

Sentry models are children of the arena, outside the map scene. A client could
unload Assault geometry while retaining those models and its replicated buildings.
Lobby drawing skips combat-object drawing, so its usual removal pass never ran.

Client map preparation and lobby construction now explicitly reset fortress state
and free its cosmetic nodes. Lobby snapshots carry no structures, and receiving a
stale combat snapshot cannot repopulate them. Authority rotation keeps the sentries
installed for the destination Assault map. Tests exercise actual rendered sentry
nodes, state replication, lobby entry and return to Assault, plus a server and two
clients voting from the lobby into another mode.

## HiSlop interior

The three enclosed cars now have supply/passenger compartments, an upper switch
room, a lower vestibule, an equipment divider and an enclosed control cabin.
Offset openings separate the routes. The upper terminal opens a door that slides
sideways into the lower bulkhead. The cabin has a continuous ceiling/floor above
it, sealed lower side windows and a sealed locomotive end. The roof hatch reaches
the upper room. Checkpoint defenders spawn outside the locked cabin.

The BSP was compiled with ericw-tools 0.18, full VIS and supersampled RGB lighting.
Its existing embedded LibreQuake textures were reused with SHA-256 provenance
checks. Both Godot scene caches and the 2,077-polygon navigation mesh were rebuilt.
The installed BSP is 2,066,896 bytes:

`e477afa51ba190979722a7eacaedd0814387446de0b448f1f8ac105b5269d67c`

The production capsule walks the entire train route and the upper-switch → stairs
→ lower-door → final-terminal route. Collision checks cover the locked opening,
both sides of the bulkhead, ceiling, former windows and locomotive end. All three
sentries retain grounded firing lanes and respect covered targets.

This is an independently authored adaptation, not an extracted or measured copy.
The upper-switch/lower-control-room sequence follows the
[AS-HiSpeed reference](https://unrealarchive.org/wikis/the-liandri-archives/AS-HiSpeed.html).
Generator and rebuild instructions are in `tools/hispeed_concept/README.md`.

## Wall firing compared with 0.9v

Compared directly with release commit `5105fb8`. Its authoritative `_fire()`
already called `_weapon_blocked()`, using a ray from a fixed torso height to the
raw muzzle. However, connected clients played predicted sound, flash and recoil
without checking clearance. Offline authority rejected the shot before those
effects. This discrepancy can explain apparent online firing through a wall;
it does not prove that the reported remote shot caused damage behind the wall.

Current authority validates torso-to-hand clearance, then sweeps a projectile-sized
volume towards the muzzle and retracts a protruding muzzle to the near side. A
hand through a wall blocks firing. Ground-pointing rockets retain a safe launch
position and their rocket-jump impulse. Predicted effects now use the same clearance
check, including current local tracking when the server's pose echo is stale.
An invalid/absent VR pose cannot become a desktop firing fallback on authority.

Real ENet tests cover blocked main and offhand shots, preserved ammunition, covered
target health, clipped muzzle origins, ground rockets and an unobstructed positive
control. This does not reproduce every geometry/contact/latency case on the public
0.9 server, and no change was deployed to that server.

## Sludge and local avatar motion

The supplied 21.4-second recording was inspected; the wearer identified HiSlop.
The live trace confirms liquid recognition, sinking and upward swimming. A
production-map regression reproduced failure to clear the tank: its one-use surface
boost peaked below the raised rim. Surface takeoff is now 9.4 m/s; ground jump remains
7.4 m/s. One boost clears the actual rim at 60, 72, 90 and 120 Hz. Surface bobbing
cannot repeat it, held jump still swims up, and level strokes still allow sinking.

The local avatar already had interpolation disabled, but remained transform-parented
to the moving collision capsule. It now uses a top-level transform while first person,
driven by the same frame origin as the VR rig. Returning to third person restores the
parent-relative identity transform. A moving-body test with 60 Hz physics and a 144 FPS
render cap measured zero parent-induced displacement after the change. This preserves
the previous local spring suppression and current-frame hand IK.

The relevant engine distinction is described in
[Godot's interpolation guidance](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/advanced_physics_interpolation.html).
The first unsuccessful diagnostic used `get_global_transform_interpolated()` on an
already frame-driven node; it was replaced with checks of actual transforms after
physics movement and after all render callbacks. That earlier diagnostic is not
used as evidence of a second renderer interpolation.

The first live run also exposed filter warm-up coroutines resuming after a map was
freed. Warm-up now counts process frames on its own node, so destruction cancels it.
Vertical jump-pad streaks now choose a valid look-at up vector.

## Validation

All 318 automated checks pass. See `docs/validation/hislop-vr-followup.json`
for the suite counts and results. Raw logs, room screenshots and local headset telemetry are under the
ignored `test-results/hislop-interior/` directory. The rebuilt BSP, caches and
navigation are installed under `maps/`; published base-asset metadata is unchanged.

WiVRn 26.6.2 identified Meta Quest Pro at 2520×2772 per eye. The follow-up session
runs at roughly 71–72 FPS in the sampled windows. It recorded both terminals
completed, upward swimming, and a subsequent indoor lobby position with zero
authoritative sentries and zero sentry visuals. No runtime script/engine errors
were logged during that follow-up through the lobby check. This measures application timing,
not streaming/compositor latency. The wearer subsequently confirmed swimming, jitter, map layout, lobby and
weapon-wall behavior in the `last.mp4` follow-up; see [the review](LAST_VR_REVIEW.md). One ObjectDB shutdown warning persists in headless fixtures;
the first VR session also logged engine OpenXR cleanup errors on normal process exit.
