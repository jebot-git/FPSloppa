# Native avatar preparation and bot AI

This implements the next two items from [the remaining native study](REMAINING-NATIVE-OPTIONS.md), on top of the existing native pose helpers, projectiles and network codec. The previous implementations remain available for comparison and fallback.

ST is now enabled in merged main. See the [current ST integration audit and remaining-cost study](NATIVE-CURRENT-ST-STUDY.md); the earlier DM results below do not measure specialized ST steering. The standard parity runner now also includes `native_st_bots`.

The [next implementation and 16/32-actor comparisons](NATIVE-ST-BATCHES.md) add native ST corridor/precision steering, facial composition and remote tracking interpolation. It supersedes the script-ownership descriptions below for those specific kernels; these earlier measurements remain unchanged.

## Measured results

Paired runs use the installed Godot 4.7.2 Fedora runtime, i7-12700 and Arc A770, with portable release libraries. Both reference and native runs retain all earlier native optimizations. [The validation receipt](validation/native-avatar-bots-2026-09-29.json) records runs, scope and build hashes.

| Avatar workload, 16 avatars | Previous preparation | Native preparation | Reduction |
| --- | ---: | ---: | ---: |
| Nearby pose CPU, all full detail | 1.439 ms/frame | 1.005 ms/frame | 30% |
| Repeated nearby block, existing mixed tiers | 1.385 ms/frame | 1.077 ms/frame | 22% |
| Distant pose CPU, existing XR policy | 0.577 ms/frame | 0.538 ms/frame | 7% |

The first nearby block's mean wall-frame time changed from 8.271 to 7.449 ms; p95 ranged from 8.771–10.089 ms before to 8.075–8.343 ms after. The repeated nearby block changed from 7.848 to 7.506 ms. Distant XR-policy wall-frame means were essentially unchanged, 6.623 versus 6.638 ms. These are isolated scene measurements; they do not establish headset frametimes or an overall-game FPS gain.

| Bot workload, 16 bots | Previous loops | Native loops | Reduction |
| --- | ---: | ---: | ---: |
| Steering CPU | 1.092 ms/tick | 0.827 ms/tick | 24% |
| Combat CPU | 0.710 ms/tick | 0.682 ms/tick | 4% |
| Perception CPU | 0.408 ms/tick | 0.391 ms/tick | 4% |
| Complete bot AI CPU | 3.227 ms/tick | 2.962 ms/tick | 8% |
| Measured server tick, mean | 6.550 ms | 6.349 ms | 3% |

Server-tick p95 was 9.357–9.809 ms before and 9.211–9.494 ms after; these ranges overlap. Steering is the meaningful isolated bot improvement. Combat and perception gains are small, while planning, callback work, physics and other server systems remain. This port does not establish a large server-capacity increase. The four runs have identical perception/planning/combat/steering invocation counts. Avatar preparation source is unchanged between its paired measurements and the final bot-only refinement; the avatar fixture contains no bots.

## Implementation

[Avatar preparation](../addons/fps_native/src/pose_preparation.cpp) now performs live target selection, coordinate conversion, hips/chest/limb/head preparation, controller and optical hand alignment, snapped grips, finger curls and pain reactions in one synchronous native call per solve. It reuses the solver's bone IDs, authored rest transforms, rest rotations and floor caches. The existing native IK and orientation methods run inside this call. Floor probes retain the same conditions, endpoints and cadence.

GDScript retains tracking interpolation, gait, animation scheduling, remote pose interpolation, LOD policy, teleport/context resets and death transitions. Local first-person solves remain immediate. No tracking samples are deferred, no worker thread touches the scene tree, and no update rate or LOD distance changes. `--gdscript-preparation` restores only the previous preparation path while retaining existing native math/blending; `--gdscript-poses` disables all native pose work. Missing extensions and older pose libraries fall back to GDScript preparation.

[Bot perception and combat](../addons/fps_native/src/bots.cpp) and [steering](../addons/fps_native/src/bot_steering.cpp) now execute their common loops in C++. Each call reads current player/actor state, preserves candidate order, uses the existing brain dictionaries and updates ordinary player inputs. Property/method names and dictionary keys are cached per AI instance to avoid repeated string construction at the script/native boundary. Combat reuses its eye position and base weapon traits and performs the original yaw/pitch alignment math directly. Steering reuses a world-ray query with the original collision mask. The short-lived native context does not retain actor snapshots across ticks, respawns or map changes.

The strategic planner, weapon selection, correlated aim drift, line-of-sight checks, team coordination, navigation links, hazard/clearance helpers, class abilities and mode-specific callbacks remain in GDScript. Tribes keeps its specialized steering. Perception still runs on its existing 0.2-second schedule, planning on its existing schedule, and combat/steering at the original tick rate. Random calls, reaction timing, charging/cancellation and authoritative damage/ammo handling retain their original behavior. `--gdscript-bots` restores the three common loops; absence of `FPSBots` also selects this fallback.

## Validation and builds

The new differential tests compare complete results rather than only checking that the native methods execute:

- [Avatar preparation](../deathmatch/tests/native_preparation.gd): 225,612 checks over three VRMs, both optimization settings, full-body/head-hand tracking, optical hands, snapped grips, tracked knees/elbows, curls, scaled/rotated actors, floor-cache sampling, crouch/prone poses, pain, teleport, death/respawn and absent optional bones.
- [Bot AI](../deathmatch/tests/native_bots.gd): 900 matched perception/combat/steering scenarios, 673,858 checks, four loadouts and DM/team-DM. Compares all brain/player fields, team reports, aim-generator state and global RNG consumption, including water, obstacles, recovery, path progress, jumps, pads, drops and charged weapons.
- Existing native acceleration tests: 51,311 checks, including pose and projectile parity.

The focused regression runner also exercises actual weapon damage, movement and boost jumps, traversal, tactics, underpasses, assault, team coordination, objective roles, map triggers/transports, CS/DE behavior, smoothness, death and render motion. Legacy Tribes integration tests are excluded because `release_features.TRIBES` is false and the mode is absent from the release menu. Selected tests run again with the GDScript fallbacks. Regression loops use fixed simulation time to shorten execution; performance runs use ordinary timing.

Linux client, Linux dedicated-server, Windows x86-64 and Android ARM64 release libraries are rebuilt. The dedicated-server build excludes avatar/skeleton bindings. An isolated console-server package starts on loopback, loads the dedicated native library and runs with four bots. Cross-build success does not establish device performance on Windows or Android.

## Reproduction

```sh
python3 tools/native_study/validate_avatar_bots.py --regressions
python3 tools/native_study/validate_avatar_bots.py --bench-only --bench both
```

Run benchmarks without concurrent builds or tests. Avatar measurements require a display; the server fixture needs a local socket. The runner brackets two native runs with two reference runs for each workload and writes logs, JSON and disposable instrumented scripts under `test-results/native-avatar-bots`. User data and config are isolated under `/tmp`.

The reference flags disable only these new ports, preserving earlier native optimizations. Bot measurements use 16 active bots on `qsrc_dm1`, 120 warmup and 600 measured ticks, and include native projectiles, movement, AI, pickups and history. They exclude snapshot transport and the engine's separate physics step. AI scopes are nested and include instrumentation overhead. Native direct ray queries are included in native steering/combat totals, not the GDScript navigation-ray scope.

Avatar measurements use 16 avatars, three VRMs, eight full-body and eight head/hands, half speaking, springs off and 360 frames per block. Each run reverses near/desktop-far/XR-policy-far order. The first nearby block has 16 full-detail avatars; the repeated nearby block has 10 full-detail and six medium-tier avatars due to existing hysteresis. XR policy uses a synthetic XRCamera3D, not an actual headset. OS/GPU clocks are uncontrolled. Results describe this workload, not a universal FPS or server-capacity increase.
