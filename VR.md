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

**Smooth turning is the default.** The menu offers recentering, switching the gun hand and switching between smooth turning and 30-degree snap turning. These VR preferences last for the session. Recenter after changing play posture. Weapon translation and rotation follow the controller’s aim pose in all six degrees of freedom; server shots and projectiles follow that pose, including weapon roll. Grips do not reload: ammo, automatic weapon cycles, damage, projectile speeds and pickups retain the classic arena rules. There is no physical magazine manipulation.

Multiplayer players spawn and respawn with **only a pistol, 50 bullets and 100 health**. Offline practice uses the same inventory rules. Pick up weapons in deathmatch to expand inventory.

## Interface and avatars

A large world-space panel provides hosting, joining, map selection and model preview. Both controller rays work with its controls. Text fields and file dialogs use the XR Tools virtual keyboard. During a match, select CHAT in the menu and use the keyboard’s Enter key to send. Health, armor, weapon and ammunition appear on the left wrist. Menus are rendered above world geometry so a nearby wall cannot conceal their controls.

Choose MODEL to preview any bundled VRM or import a self-contained custom VRM up to **25,000,000 bytes**. Models download through the server for other players. See [AVATARS.md](AVATARS.md) for structural limits and licensing. Missing BSP maps download from the host before joining; see [MAPS.md](MAPS.md).

Head, hands and weapon poses are replicated. Remote avatars use smoothed tracked head orientation, crouching hip motion, arm IK and ground-aligned feet. Every model keeps the same movement capsule and damage volumes. Leaning does not relocate the damage hitbox; room-scale movement requests move the capsule through server collision checks within the normal speed budget. Implausible/nonfinite/scaled poses are rejected. A muzzle through a wall cannot shoot. Losing gun-controller tracking blocks firing. Head penetration fades the view to black.

Voice chat is available through VOICE in the menu; push-to-talk uses V or the off-hand grip. See [VOICE.md](VOICE.md).

## Combat feedback

Recorded CC0 gunfire, impact and footstep variants supplement the original synthesized effects. Combat and voice audio use spatial attenuation, wall occlusion and room reverb; see [AUDIO.md](AUDIO.md). Hits produce directional avatar flinches, blood bursts and surface stains. Heavy kills produce low-poly head/meat/bone gibs. These effects are cosmetic and bounded: 12 blood bursts, 48 stains, 32 gibs and 32 simultaneous combat sound voices. VR hit and shot feedback includes controller haptics; hit animation never kicks or rolls the headset camera.

## Validation and remaining device checks

Automated checks passed for the 25 MB VRM limit, transfer rejection/cleanup, tracked weapon translation and independent aim, real server hit resolution, wall-blocked shots, Touch and Index action profiles, simulated XR UI construction, and crouched hand IK/weapon following on all three default models. Independent server/client processes passed combat, avatar upload/relay/cache, automatic BSP downloads and replicated VR poses. Results are in `test-results/`.

OpenXR startup was exercised with Monado. The available runtime had no active hand controllers: physical Touch/Index button behavior, headset comfort, controller calibration and sustained headset frame rate still require hardware testing. First-time VRM decoding and BSP compilation are synchronous and can cause a loading stall. Network testing used local independent ENet processes, not a WAN session. Fast arena locomotion is preserved; teleport locomotion is not included.

Useful automated checks (disable XR for headless runs):

```sh
godot --headless --xr-mode off --path . --script res://deathmatch/tests/vr.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/vr_ik.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/vr_ui.gd
python3 deathmatch/tests/run_network_tests.py --maps
```

Optional full-body input, SlimeVR setup, Quest body/hand support and native Pico limitations are documented in [TRACKING.md](TRACKING.md).
