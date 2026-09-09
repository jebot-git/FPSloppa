# Arena VR

This is a PC OpenXR VR FPS built with Godot 4.7.2 and Godot XR Tools 4.5.1. Start your OpenXR runtime and headset, then run `./run-vr.sh`. Use `./run-desktop.sh` for desktop play; both modes can join the same server. Set `GODOT_BIN` if the launcher cannot locate Godot. PC executable ZIPs and an optional dedicated-server ZIP are now supplied alongside the source project. Experimental Quest/Pico sideload APKs are supplied; see [STANDALONE.md](STANDALONE.md).

## Controls

| Action | Oculus Touch | Valve Index |
|---|---|---|
| Move, relative to headset direction | Left stick | Left stick |
| Walk | Left stick click | Left stick click |
| Turn | Right stick left/right | Right stick left/right |
| Cycle owned weapons | Right stick up/down | Right stick up/down |
| Fire | Gun-hand trigger | Gun-hand trigger |
| Jump / swim / respawn | Right A | Right A |
| Use nearby door | Left X | Left A |
| Scoreboard | Left Y | Left B |
| Menu | Right B or left menu | Right B |
| Select menu controls | Point and trigger | Point and trigger |

**Smooth turning is the default.** Open **TURN SETTINGS…** in the VR menu to select smooth or snap turning and adjust smooth speed (30–360°/s, default 120°/s) and snap angle (15–90°, default 30°). The large −/+ controls work with either controller pointer. Mode, speed and angle save immediately in the client config and load next launch. The menu also offers recentering and switching the gun hand. Recenter after changing play posture. Weapon grips sit at the controller’s palm position while orientation follows its independent aim pose, including roll. Local models, remote avatars and server muzzle positions use the same per-weapon grip anchors. Grips do not reload: ammo, automatic weapon cycles, damage, projectile speeds and pickups retain the classic arena rules. There is no physical magazine manipulation.

Multiplayer players spawn and respawn with **only a pistol, 50 bullets and 100 health**. Offline practice uses the same inventory rules. Pick up weapons in deathmatch to expand inventory.

## Interface and avatars

A large world-space panel provides hosting, joining, map selection and model preview. Both controller rays follow the runtime aim pose and stop at the closest panel or keyboard surface. Their collision mask selects only VR UI. Text fields and file dialogs use the XR Tools virtual keyboard with deferred input routed to the focused viewport. During a match, select CHAT in the menu and use the keyboard’s Enter key to send. A compact transparent HUD floats low in the view, independent of either hand, at a stereo depth of 1.5 m. Health, armour and current ammunition have distinct icons, numeric values and fill bars. The smaller top row shows match time and frags remaining for the leading score to reach the limit, plus a microphone indicator while transmitting. Melee weapons display ∞. The HUD hides during menus, the scoreboard and focus loss. Menus are rendered above world geometry so a nearby wall cannot conceal their controls.

Choose MODEL to preview any bundled VRM or import a self-contained custom VRM up to **25,000,000 bytes**. Models download through the server for other players. See [AVATARS.md](AVATARS.md) for structural limits and licensing. Missing BSP maps download from the host before joining; see [MAPS.md](MAPS.md).

Head, hands and weapon poses are replicated. Remote avatars use smoothed tracked head orientation, crouching hip motion, arm IK and ground-aligned feet. Every model keeps the same movement capsule and damage volumes. Small physical steps and leaning move the shared movement/damage capsule horizontally toward the headset, with a 2 cm tolerance. Tracking offsets are limited to 0.75 m and room-scale motion to 2.4 m/s, sharing the normal locomotion speed budget. The server validates the request against the headset pose and performs collision checks. Only actual capsule travel is subtracted from the tracking origin and replicated poses, preserving headset/weapon world positions when walls block movement. Capsule dimensions stay fixed; room-scale input cannot move it vertically. Implausible/nonfinite/scaled poses are rejected. A muzzle through a wall cannot shoot. Losing gun-controller tracking blocks firing. Head penetration fades the view to black.

Stair movement probes for reachable treads and snaps down to descending steps. A short visual height blend softens the step change in both desktop and VR while headset motion remains direct. Invisible map trigger volumes retain their behavior but no longer render opaque boxes, including on lqdm1.

Voice chat is available through VOICE in the menu; push-to-talk uses V or the off-hand grip. See [VOICE.md](VOICE.md).

## Callsign

Select **CALLSIGN** to open the virtual keyboard. Enter finishes editing and saves the name for the next match. The existing `user://deathmatch.cfg` keeps both the callsign and host address; it is created on first menu startup. A saved name takes priority, otherwise the system username (`USERNAME`, `USER`, then `LOGNAME`) is used, with `Marine` as the final fallback. Names are sanitized and limited to 18 characters. Steam/Oculus account APIs are not integrated into this project.

For a keyboard-free setup, copy `client.example.cfg`, edit `[player] name`, and launch with an absolute config path:

```sh
./run-vr.sh -- --client-config /absolute/path/client.cfg
```

Or supply a launch override: `./run-vr.sh -- --name "YourCallsign"`. The same options work with desktop mode, `--practice`, and `--connect`. Menu edits also update the selected config file. Names changed during a match apply on the next join.

The default config is under `~/.local/share/godot/app_userdata/Entryway Deathmatch/` on Linux, or `%APPDATA%\Godot\app_userdata\Entryway Deathmatch\` on Windows. Close the game before editing the file externally.

## Combat feedback

Recorded CC0 gunfire, impact and footstep variants supplement the original synthesized effects. Combat and voice audio use spatial attenuation, wall occlusion and room reverb; see [AUDIO.md](AUDIO.md). Hits produce directional avatar flinches, blood bursts and surface stains. Heavy kills produce low-poly head/meat/bone gibs. These effects are cosmetic and bounded: 12 blood bursts, 48 stains, 32 gibs and 32 simultaneous combat sound voices. Local damage adds a brief red edge tint and a quiet, unoccluded pain sound, including small hits. The tint fades quickly and is hidden over VR menus or on focus loss. VR hit and shot feedback includes controller haptics; hit animation never kicks or rolls the headset camera.

The super shotgun now has its own short double-barrel model, dark steel receiver, wood grip and red shell carrier. Player damage uses a continuous 0.40 m radius, 1.80 m tall capsule; movement collision remains unchanged. Rocket/plasma/BFG radii are 0.14/0.16/0.30 m, also reflected in their visible projectile sizes. Swept collision considers target motion between server ticks and blocks enlarged hits through cover. Existing hitscan latency rewind remains bounded to 200 ms.

This source revision uses protocol `entryway-dm-10-melee`; clients and server must use matching source/builds.

## Validation and remaining device checks

Automated checks passed for the 25 MB VRM limit, transfer rejection/cleanup, tracked weapon translation and independent aim, real server hit resolution, wall-blocked shots, Touch and Index action profiles, simulated XR UI construction, and crouched hand IK/weapon following on all three default models. Independent server/client processes passed combat, avatar upload/relay/cache, automatic BSP downloads and replicated VR poses. Results are in `test-results/`.

A live Quest Pro session through WiVRn 26.6.2 exercised both controllers, menu alignment, recentering and bounded room-scale movement. The session exposed native SolarXR body joints and led to fixes for hand orientation, finger bending and native orientation calibration. Index controllers and standalone Android behavior still require separate hardware testing. See [LIVE_VR_TEST.md](LIVE_VR_TEST.md) for the local probe and remaining checks. First-time VRM decoding and BSP compilation are synchronous and can cause a loading stall. Network testing used local independent ENet processes, not a WAN session. Fast arena locomotion is preserved; teleport locomotion is not included.

Useful automated checks (disable XR for headless runs):

```sh
godot --headless --xr-mode off --path . --script res://deathmatch/tests/room_scale.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/vr.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/vr_ik.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/vr_ui.gd -- --client-config /tmp/fpsloppa-ui-test.cfg
godot --headless --xr-mode off --path . --script res://deathmatch/tests/hit_detection.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/weapon_setup.gd
python3 deathmatch/tests/run_network_tests.py --maps
```

Optional full-body input, SlimeVR setup, Quest body/hand support and native Pico limitations are documented in [TRACKING.md](TRACKING.md).

## Controller pose hotfix (0.1.1v)

0.1v incorrectly selected `grip_pose` / `aim_pose` on XRController3D. Godot's OpenXR bridge exposes those actions as tracker poses `grip` / `aim`, so the old nodes remained at the tracking origin even with correct Touch bindings. 0.1.1v fixes both hands and weapon aim, hides untracked hands, and requires a valid pose for pointers and weapon input. Eye gaze now has a separate action to avoid sharing the controller default pose.

The Touch, Index and Pico profiles retain their grip/aim bindings. Automated XRControllerTracker tests verify late connection, movement, independent grip/aim poses, disconnection and profile bindings. VDXR and SteamVR still require a physical headset retest; no runtime-specific profile change should be necessary for this bug.

Engine behavior: https://github.com/godotengine/godot/blob/4.7.2-stable/modules/openxr/openxr_interface.cpp (`create_action`).

PC VR uses full-rate shading for clear streamed headset imagery and HUD text. Android retains XR variable-rate shading. See [LIVE_VR_TEST.md](LIVE_VR_TEST.md) for the Quest Pro/WiVRn hardware checks and their limits.

Swing the held weapon to **weapon whip** an opponent, even with empty ammo. A short swept weapon volume detects contact, deals 10 damage before armor and allows one target per swing, with a 0.8-second cooldown. Slow the weapon before the next swing. Holding it against a player, stick turning and ordinary locomotion do not initiate attacks. Menus, focus loss, invalid tracking and BFG charging disable the attack.
