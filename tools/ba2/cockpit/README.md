# BA-2 remote cockpit concept

An isolated, runnable local prototype using the animated 10 m BA-2 and the game's existing VR/avatar tracking stack. The pilot cannot locomote, jump or turn the gameplay capsule. Head, hands, face and body targets remain live. **Physical sitting is optional**: the chair is cosmetic, and recentering adjusts the console and screen to the pilot's current height without shifting the tracking floor or forcing the avatar to crouch.

From the project root:

```sh
# Desktop preview
./run.sh --xr-mode off res://tools/ba2/cockpit/main.tscn

# Headset, through the configured OpenXR runtime (WiVRn or SteamVR)
./run-vr.sh res://tools/ba2/cockpit/main.tscn
```

## Controls

- Face the desired forward direction, standing or sitting. Press **B/Y** to recenter. The console height adjusts on initial tracking acquisition and when recentered; it does not follow each head movement.
- Reach either joystick and hold that hand's **grip**. Its button turns cyan when held. Move the hand around a small **11 cm circular range** relative to the grab position; precise wrist rotation or matching the gun's hinge angle is unnecessary. The visual stick tilts up to 24° in any direction, with a smooth centre deadzone. The right joystick drives both gun pairs together within their mechanical limits. The current X-only cannon hinges use forward/back deflection for elevation; sideways deflection and left joystick movement are cosmetic. Releasing the stick stops slewing and retains the aim angle.
- Each hand's **trigger** fires its side's **upper and lower guns together** while that joystick is held. Each pair shares one heat bar and converges on its own L/R aim marker. Releasing grip, moving the hand too far away, losing controller tracking or losing XR focus stops firing. Tracking recovery requires releasing and gripping again.
- **A/X** recalibrates external tracker mounting orientations. Face forward with feet pointing forward in your chosen posture. Measured joint positions are retained; this does not run the standing/T-pose calibration. Native body joints and controller gestures use the existing tracking implementation; SlimeVR uses the existing OSC configuration.
- Desktop: **Up/Down** aim, **left/right mouse button** fire left/right cannon, **Space** pauses the robot route, **Escape** exits. **R/C** correspond to recenter/calibration when VR is active.

The latest authored rig constrains each cannon to its **local X hinge, ±4°**. No extra cannon yaw axis is introduced. Aim slews at up to 7.5°/s. The body's authored ±3° yaw and compensated walk remain intact. The camera follows the front of that body, independently of the pilot's headset.

## What works

- Stationary cockpit below the ordinary world; robot and target range in an isolated `World3D`.
- Real 1280×720 monoscopic camera image displayed on a 3.2×1.8 m flat monitor. Looking around in VR changes the view of the monitor, not the camera feed.
- Simple sci-fi crosshair, one heat bar per side and venting state. The **L/R rings** mark each pair’s convergence point, found by raycasting along the midpoint between its barrels. Both rounds launch from their actual, separate muzzle openings toward that point. Each barrel checks cover independently; the marker turns red and the pair reads COVER if a barrel is obstructed. The central reticle is the camera’s optical centre reference.
- Independently triggered paired firing, raycast target hits, short tracers/impact flashes, reused firing audio and controller haptics.
- Eight rapid paired volleys (16 rounds) overheat a side. Heat, cooldown, firing audio and haptics advance once per volley, not per barrel. Cooling starts after 0.25 s without a shot; unlocking requires heat at or below 35% and trigger release.
- `WalkStart` followed by five `WalkLoop` cycles along a level demonstration route; stops at the final cycle boundary. Space can pause the route. Cannon aim remains available when stopped.
- Locally selected VRM avatar loading, visible local body, tracked fingers/body/face through the existing rig. An anchored support state avoids unintended airborne leg animation. The furniture is visual and does not push the avatar or obstruct its tracking.

This is a local concept, not a networked vehicle or an Assault objective. Targets count hits; they do not implement production player damage. Enter/exit interaction, vehicle ownership, damage balancing, route collision/navigation and multiplayer replication remain separate integration work. No ordinary match scene, robot source mesh, export preset or release package is changed. `tools/*` is already excluded from game exports.

## Validation

```sh
./run.sh --headless --xr-mode off --log-file /tmp/ba2-cockpit.log \
  res://tools/ba2/cockpit/main.tscn -- --cockpit-test
./run.sh --xr-mode off --resolution 1600x1000 \
  res://tools/ba2/cockpit/main.tscn -- --vr-test --cockpit-test
```

Reports, logs and rendered screenshots are under `test-results/ba2/cockpit/`. Tests cover the hinge axes/limits, heat independence, paired muzzle hits and convergence, per-barrel cover blocking, world isolation, immobilisation, preserved native/external body targets, avatar visibility, standing height and reach adjustment, and trigger/grip inputs injected through XRServer. Graphical output was inspected. These are desktop and simulated-XR checks; live headset reach, comfort, haptics and tracker mounting ergonomics still need a user test.

The existing arena setup reports one ObjectDB instance at headless shutdown, two with rendering, and XR Tools emits stale-UID warnings before successfully loading glove assets by path. No script errors occurred in the completed checks.

`mounts.py` regenerates the muzzle anchors from the animated GLB's cannon-weighted vertices and inverse bind matrices. It needs Python/numpy only when regenerating anchors; runtime does not need Python. Model credits and texture provenance remain in [BA-2 sources](../SOURCES.md).
