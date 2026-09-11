## 0.4v controls

Open **VR CONTROLS…** to mirror movement/turn sticks and their action buttons independently of weapon handedness. Seated mode translates headset height to standing eye level without scaling weapon reach; body tracking temporarily suspends that compensation. Recenter after changing seats.

# Arena VR

This is a PC OpenXR VR FPS built with Godot 4.7.2 and Godot XR Tools 4.5.1. Start your OpenXR runtime and headset, then run `./run-vr.sh`. Use `./run-desktop.sh` for desktop play; both modes can join the same server. Set `GODOT_BIN` if the launcher cannot locate Godot. PC executable ZIPs and an optional dedicated-server ZIP are now supplied alongside the source project. Experimental Quest/Pico sideload APKs are supplied; see [STANDALONE.md](STANDALONE.md).

## Controls

| Action | Oculus Touch | Valve Index |
|---|---|---|
| Move, relative to headset direction | Left stick | Left stick |
| Walk | Left stick click | Left stick click |
| Turn | Right stick left/right | Right stick left/right |
| Cycle owned weapons | Right stick up/down | Right stick up/down |
| Fire | Gun-hand trigger; other trigger fires second pistol in slot 2 | Gun-hand trigger; other trigger fires second pistol in slot 2 |
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

The default config is under `~/.local/share/godot/app_userdata/FPSloppa/` on Linux, or `%APPDATA%\Godot\app_userdata\FPSloppa\` on Windows. Close the game before editing the file externally.

Text chat also appears above the in-game VR notifications, including the sender's name. The two latest messages remain for eight seconds, wrap across lines, and do not replace active vote or flag-capture notices. They scale and move with the HUD; opening the menu shows the existing chat feed there.

## Combat feedback

Recorded CC0 gunfire, impact and footstep variants supplement the original synthesized effects. Combat and voice audio use spatial attenuation, wall occlusion and room reverb; see [AUDIO.md](AUDIO.md). Hits produce directional avatar flinches, blood bursts and surface stains. Heavy kills produce low-poly head/meat/bone gibs. These effects are cosmetic and bounded: 12 blood bursts, 48 stains, 32 gibs and 32 simultaneous combat sound voices. Local damage adds a brief red edge tint and a quiet, unoccluded pain sound, including small hits. The tint fades quickly and is hidden over VR menus or on focus loss. VR hit and shot feedback includes controller haptics; hit animation never kicks or rolls the headset camera.

The super shotgun again uses the original textured CC0 shotgun mesh, with its original wider stock and paired-bores adaptation for a consistent weapon style. Player damage uses a continuous 0.40 m radius, 1.80 m tall capsule; movement collision remains unchanged. Rocket/plasma/BFG radii are 0.14/0.16/0.30 m, also reflected in their visible projectile sizes. Swept collision considers target motion between server ticks and blocks enlarged hits through cover. Existing hitscan latency rewind remains bounded to 200 ms.

This source revision uses protocol `entryway-13-team-modes`; clients and server must use matching source/builds.

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

Dual pistols have independent aim, trigger input and shot haptics for each hand, including left-handed mode. Either pistol can perform a weapon whip; both share the same 0.8-second melee cooldown.

**Join as spectator** enables a free-flying view: left stick moves, right stick turns and its vertical axis changes height. The round-end scoreboard now opens its VR surface automatically. Audio, music and graphics options use large controls on the same pointer-selectable canvas; no native popup is required.

### HUD placement and size

Settings → Graphics provides **VR HUD size** (70–140%) and **VR HUD height** (−65 to +55 cm relative to eye level). Changes apply immediately and persist in the presentation section of the client config (`hud_scale`, `hud_y`). The HUD remains 1.5 metres in front of the headset and does not intercept menu pointers. Default: 100%, −46 cm.

With full body tracking, deliberately swing a raised foot to kick for 10 damage before armour. Either foot shares the 0.8-second cooldown with weapon whipping. Stationary feet, ground sliding and stale/discontinuous tracking do not count as kicks; the server checks reach and walls. Kicks follow the existing physical-melee restrictions in IG and CC.

## Movement and tracking follow-up fixes

Locomotion is interpolated between physics ticks for headset and desktop presentation; headset/controller poses and turning remain updated every rendered frame. Teleports snap the camera immediately. Stair contact briefly tolerates tread-edge separation and reapplies downward floor snapping. Ground jumps still require release and press; holding jump swims upward. Physical jumps trigger after a 5.5 cm rise with upward speed above 0.65 m/s, rearm after returning near standing height, and use a 0.25-second minimum cooldown. Short jump pulses are retained until the next client input transmission.

Controller-only VR shows the avatar's first-person arms even when body tracking is disabled or unavailable. The avatar's untracked lower body uses its existing procedural pose; measured hips/feet take priority. With hips and feet but no knee trackers, knee bend directions follow pelvis yaw with bounded toe influence. Headset validation allows heights up to 3.2 m for tall users and physical jumps while retaining horizontal playspace limits.

Ranged weapons have a 24 cm direction guide at the muzzle, clipped by nearby walls. It does not steer shots or select targets. The extra fist mesh is hidden. VR chainsaw contact follows the visible blade, with a 4 cm tip allowance in CC and 9 cm in other modes. The model retracts at walls without moving the tracked hand; blocked reach cannot damage or parry through geometry. Blade contacts produce sparks, a short grinding sound and haptic feedback.

Settings → Bindings supports trigger-drag scrolling on both the outer page and its dropdowns. Dragging outside a dropdown continues the scroll without selecting a row, and Back remains above the scrolling page. Desktop key capture is disabled in VR to prevent a trigger click from accidentally rebinding the mouse.

Movement integrates using Godot’s supplied physics delta, with per-render-frame interpolation for the headset view. The simulation tick rate is independent of headset FPS. Movement validation measured the same 9.4 m/s run speed at 30, 60, 72, 90, 120 and 144 render FPS, and at 60, 90 and 120 physics ticks per second. Network input/snapshot timers retain fractional elapsed time instead of discarding it.

## Arm swimming and automatic body calibration

While in water, short backward hand pulls propel you in the direction you look;
downward strokes lift you toward the surface. One arm or alternating arms work,
and a stroke of roughly 3.5 cm is enough to begin producing thrust. Point your
view downward while pulling to dive. Stroke strength is bounded and shares the
normal water movement speed budget with the stick. Holding jump still swims
upward and takes priority over arm strokes. Menus, lost tracking/focus, death,
spectating and frozen state stop gesture thrust; it cannot propel you on land.

With hip and both foot (or lower-leg) trackers available, stand upright and hold
your arms out at shoulder height in a T-pose for about **1.4 seconds**. A short
local bell jingle and haptic pulse confirm successful calibration. This works
with native body/Vive-role tracking and fresh SlimeVR OSC poses, including before
the external trackers have been calibrated. T-pose calibration also places
external elbow targets at shoulder height. Controller-only and upper-body-only
tracking do not trigger full-body calibration. Seated mode, swimming, airborne
movement, loss of focus and unstable poses prevent accidental calibration.
Lower your arms for at least 0.7 seconds before repeating; there is a five-second
cooldown. The existing manual calibration button remains available and also
plays the completion cue on success. The cue follows the sound-effects volume.
