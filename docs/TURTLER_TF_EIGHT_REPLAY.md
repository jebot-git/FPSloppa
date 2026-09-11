# Turtler: eight-player TF recording and replay

Tested on 2026-09-11 with Godot 4.7.2. The local conversion is
`../Builds/Turtler-Local/maps/tf_fo_turtler.bsp`, SHA-256
`552edc4ffde089f79c1d3aeb6ebb47a4d069a692cf2229e4e4adbf6c21741684`.
Map-specific redistribution permission remains unconfirmed; keep the BSP local.
See `TURTLER_REVIEW.md` for the conversion and navigation limitations.

## Results

A dedicated server and eight independent ENet clients passed the controlled
4v4 scenario. One client changed from Scout to Spy so all nine classes were
exercised without exceeding eight connected players. RED won by capture, 1:0.

| Class | Verified behavior |
| --- | --- |
| Scout | Sprint buff and increased movement speed |
| Sniper | Focus buff, enhanced rail damage and an actual remote shot hitting an enemy |
| Soldier | Thrown grenade and explosion damage |
| Demoman | Thrown pipe, arming, remote detonation and splash damage |
| Medic | Aimed healing, increasing a teammate from 40 to 75 HP |
| Heavy | Brace buff reducing a 100-damage input to 65 |
| Pyro | Napalm projectile, ignition, afterburn and flamethrower damage |
| Engineer | Sentry construction, firing and enemy damage; repair; destruction; dispenser healing and ammunition resupply |
| Spy | Cloak, copying an enemy VRM identity across all clients, and revealing on fire |

The recorded demo contains 551 snapshots over 27.55 seconds, all nine class
cooldowns, all three grenade types, both engineer buildings, and the final
capture announcement. Replay checks passed seeking and first-person/chase
selection for every player. Graphical playback completed without runtime script
errors; the objective voice finished before recording ended.

The chase video switches its selected player with each ability phase. It is
30.6 seconds, 918 frames, 1440×900 at 30 FPS, H.264 with 48 kHz stereo AAC.
Full FFmpeg decoding passed. Inspected captures show healing/repair effects,
flamethrower effects, sentry construction and enemy-perspective cloak rendering.
Class labels can overlap in the tightly staged corridor.

This is an ability and replay integration simulation, not an autonomous bot
match or headset/performance certification. The harness stages players in a
collision-checked lane, adjusts health and cooldowns between isolated cases,
and relocates the flag carrier to the actual map objectives. It does not resolve
the map's previously documented all-spawn navigation failures or establish match
balance. Godot still reports ObjectDB/resource cleanup warnings at shutdown.

## Fixes found during testing

- Player capsules no longer carry other players as moving platforms. A regression
  test reproduced an unintended 20 m displacement when the supporting player was
  repositioned; the fix leaves only 0.055 m of vertical settling. World lifts
  still carry riders correctly (tested with 0.5 m of movement).
- TF replay HUD weapon and ability information now uses the selected player.
  Previously it could access a nonexistent local player and throw errors.
- Spy replay visibility now uses the selected player's team perspective.

The platform regression and eight movement timing configurations passed.

## Local artifacts

- Demo: `../Builds/Turtler-Local/recordings/tf-eight-03.fpsdemo`
- Phase timeline: `../Builds/Turtler-Local/recordings/tf-eight-03.json`
- Replay audit: `../Builds/Turtler-Local/recordings/tf-eight-03-replay.json`
- Video: `../Builds/Turtler-Local/videos/tf-eight-03-final/tf-turtler-chase.mp4`
- Video metadata and hashes: adjacent `validation.json`
- Server/client results: `test-results/tf-eight-03/RESULT.json`
- Regression logs: `test-results/player-platform-fixed.log` and
  `test-results/tf-eight-movement-regression.log`

## Reproduction

Run from the Godot project directory. Choose fresh demo/output names; the tools
refuse to overwrite recordings. Graphical rendering requires a display/GPU.

```sh
python3 tools/tf_eight_test.py ../Builds/Turtler-Local/maps/tf_fo_turtler.bsp --output test-results/tf-eight-new --demo ../Builds/Turtler-Local/recordings/tf-eight-new.fpsdemo
Godot_v4.7.2-stable_linux.x86_64 --headless --xr-mode off --fixed-fps 60 --path . --script res://deathmatch/tests/tf_eight_replay.gd -- ../Builds/Turtler-Local/recordings/tf-eight-new.fpsdemo ../Builds/Turtler-Local/maps/tf_fo_turtler.bsp
python3 tools/render_tf_eight.py ../Builds/Turtler-Local/recordings/tf-eight-new.fpsdemo ../Builds/Turtler-Local/maps/tf_fo_turtler.bsp --output ../Builds/Turtler-Local/videos/tf-eight-new --views chase --renderer mobile
```
