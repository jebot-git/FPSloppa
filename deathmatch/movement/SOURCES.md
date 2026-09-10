# Quake-style movement

Adapted from Raymond Hulha's [quake3-movement-godot](https://github.com/rhulha/quake3-movement-godot), commit `13f7ffcafe7e30666468ac00391ae0387f9b3f37`, specifically `QuakeMovement/Character/Quake3-movement-3.gd`. The repository credits dead_lucky_32 for the Godot port and WiggleWizard's Unity implementation as its starting point. The original MIT license is preserved in LICENSE.txt.

The source demo uses Godot 3 (`KinematicBody`, `export`, and the old `move_and_slide` API). FPSloppa ports its ground friction, directional acceleration, air acceleration and manual jump queuing into pure Godot 4 movement math, called from the existing `CharacterBody3D` simulation. No demo scene, input singleton, camera, texture or sound was imported. Godot 4.7.2 is the tested runtime.

Adaptations:

- Normalize wish direction correctly, clamp diagonal input and retain VR analog strength. Reduce the minimum friction control speed while moving slowly so it cannot overpower small thumbstick input or TF class movement.
- Keep FPSloppa's 9.4 m/s run, 5.2 m/s walk, class multipliers, 7.4 m/s jump and 20 m/s² gravity. Ground acceleration 14, air acceleration/deceleration 2 and friction 6 follow the demo's tuning.
- Ground friction stops released movement; airborne velocity persists. Directional acceleration permits air strafing and speed gain. Each press permits one takeoff with friction skipped on that frame. Holding the button after takeoff cannot auto-hop; release and press again for the next jump. A fresh press made in the air can queue one jump on landing while the button remains held.
- Retain the existing swimming, stair stepping/smoothing, room-scale capsule alignment, bounded external blast impulse and respawn reset paths. Spectator flight is separate.
- Server simulation, client prediction and bots use the same functions. Snapshots also correct horizontal velocity because air momentum no longer converges automatically toward a desired walking velocity. Expired input clears jump as well as movement.
- The demo's unused air-control field is not exposed as a working feature. This is an adaptation of its Quake-style movement, not a claim of frame-exact Quake III physics.

The multiplayer protocol is `fpsloppa-20-quake-movement`; older builds must not join a server with different movement prediction. Validation covers real ground/air collision movement, analog control, bunny hopping, swimming, stairs, rocket jumps, VR room-scale collision, and a server plus three clients exercising prediction and replicated movement.
