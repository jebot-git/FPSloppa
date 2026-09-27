# Lobby, VR performance, and death drops — 26 September 2026

These are source changes and local validation, not a deployment to the live server. Matching clients and servers now use `fpsloppa-40-weapon-drops`; older clients must not collect weapons whose visuals they cannot display.

## Reported Vive Pro 2 performance

The supplied Downloads screenshots show:

| Measurement | img1.png | img2.png |
| --- | ---: | ---: |
| Current / average FPS | 87 / 76.1 | 79 / 76.4 |
| CPU frame time | 9.8 ms | 12.4 ms |
| GPU frame time | 5.4 ms | 6.0 ms |
| GPU use | 50% | 53% |
| Reprojection ratio | 52.8% | 53.2% |
| Dropped frames | 154 | 141 |

The CPU times exceed GPU times substantially. This supports investigating CPU work and frame pacing; screenshots alone cannot identify the dominant function, establish the headset refresh rate, or separate network corrections from presentation stutter. No RTX 5090 / 9800X3D / Windows 11 / SteamVR hardware run was available here.

## Changes

- **Voting wall:** creation precedes the first lobby snapshot on a joining client. Previously an empty snapshot hid the panel, and the hidden panel stopped polling permanently. The wall now stays visible with a waiting message and disabled buttons, continues polling, and displays the ballot when it arrives. Menu panels retain their explicit open/close behavior.
- **Stairs:** stair smoothing now updates on physics ticks and interpolates alongside the capsule. Previously a new stair offset was applied to an older interpolated capsule position, introducing camera bobbing within each physics interval. Desktop and XR use the same corrected offset. Swept step collision and server authority remain intact. Delayed-input stair tests cover ascent/descent with 30 Hz commands, 20 Hz snapshots, and one-way delays of 1, 3, and 6 physics ticks; these cases produce no artificial vertical impulses.
- **Springs:** runtime VRM secondary motion uses Godot `SpringBoneSimulator3D`, native sphere/capsule collisions, imported per-joint parameters, collision-group membership, and terminal extensions. No scripted Verlet chains or legacy modifier callback are allocated at runtime. The plugin's existing editor preview remains available. The simulator follows humanoid IK; first-person tracked bodies, hidden/suspended models, and the graphics preference disable it. Resuming and teleporting reset history. Default simulation uses avatar-local coordinates to avoid distorting native spring lengths through uniform avatar normalization; explicit VRM centers remain supported. Native bone collider offsets account for model scale.
- **Graphics preference:** **AVATAR SPRING BONES: ON/OFF** applies to current and subsequently loaded avatars and persists in presentation settings. Existing configurations default to ON. This is cosmetic and does not change collision or gameplay.
- **Death drops:** actual deaths of players and bots drop only the equipped acquired weapon. The starting inventory is captured after mode/class loadout assignment at each spawn. Drops carry the remaining ammunition for that weapon, grant no map-pickup bundle extras, expire after 30 seconds, never respawn, and are capped at 64. Server snapshots reconstruct them for existing clients and late joiners. Collection, map/lobby changes, round restart, and Assault leg changes remove them. Demo playback and seeking restore/remove drops, and old pickup events remain readable. Freeze-tag freezing is not an additional actual death drop.

## CPU comparison

Host: Intel Core i7-12700, Linux, Godot 4.7.2. Eight avatars, three shared bundled VRMs, moving tracked head targets, 60 warmup frames and 360 measured frames, fixed 90 Hz simulation delta with uncapped wall-clock execution. Preview protection keeps scripted springs at the full cadence used in XR. Headless: no rendering, networking, headset, or compositor.

| Spring implementation | Median frame | p95 frame |
| --- | ---: | ---: |
| Previous scripted implementation | 4.777 ms | 5.221 ms |
| Native implementation | 2.038 ms | 2.150 ms |
| Springs disabled | 1.167 ms | 1.224 ms |

Native springs reduced the **whole synthetic scene's median CPU frame time by 57%** against the archived scripted implementation. These are local comparative CPU measurements, not expected headset frame rates. Native spring cost is engine work; the existing animation benchmark now reports its script timer as unavailable instead of misleadingly reporting zero cost.

Reproduce the native/off cases:

```sh
godot --headless --xr-mode off --path . --fixed-fps 90 --script res://tools/avatar_lod/benchmark_native_springs.gd -- native
godot --headless --xr-mode off --path . --fixed-fps 90 --script res://tools/avatar_lod/benchmark_native_springs.gd -- off
```

The `legacy` benchmark argument takes an archived secondary script path. For this comparison the pre-change `vrm_secondary.gd` from repository HEAD was copied to a temporary file, its `class_name` removed, relative resource paths rebased to `res://addons/vrm/`, and a no-op `update_native_state()` compatibility method added. No legacy runtime toggle was added to gameplay.

## raifslop integration review

Reviewed local branch `integration/golf-fishing` at `555e9fc`, including tracking changes in `459ed95`, the avatar fitting path, and the current IK implementation.

Adopted T-pose body calibration without calling recenter: body calibration no longer changes tracking origin or world scale. Explicit recenter remains available. Also adopted a rest-pose reset after retargeting so unanimated helper bones do not retain stale imported poses.

The integration branch fits the avatar's eye height to the physical user and adds viewpoint/torso alignment. Transplanting this whole system into FPSloppa would change normalized body proportions, tracking scale, controller reach, and their relationship to fixed competitive hitboxes. That needs a separate coordinated gameplay/tracking change; this patch retains the established 1.70 m avatar normalization and bounded explicit recenter. FPSloppa already has the source project's shared bone lookup caching, 12.5 Hz foot queries, distance-based IK, expression mixing, Mobile rendering, and local spring suppression, plus additional cached rotations and animation/mesh LOD. Copying those systems back would not provide another optimization. Fishing/golf environment panoramas and prop-specific optimizations do not apply to the BSP arena pipeline.

## Live server inspection

Read-only SSH inspection of `45.147.228.101` inspected `FPSloppa-Server/srv.log` and its three retained rotations, plus `server-engine.log`.

- Retained structured logs span September 20–25 and show version 0.16v / protocol 39, repeated matches/lobbies, and human joins on September 25.
- The engine log contains navigation-region edge-merge warnings (4-edge and 24-edge cases), including `as_hislop` and `tf_vesper`. No script errors were found in the inspected engine log.
- There are **no verbose health records** in the retained structured logs. Historical server tick durations, per-player input ages, and transport loss cannot be reconstructed from them.
- At inspection, no FPSloppa process or game-port UDP listener was running. The last log record is `2026-09-25T18:13:01Z`. This establishes its state at inspection, not why it stopped.
- No server files, settings, or services were changed or restarted.

## Validation

Passed targeted suites: lobby transition (including delayed/hidden wall recovery), local prediction, prediction landings and obstacles, delayed stair prediction, stair contacts and visual interpolation, avatar scaling, native springs, automatic calibration, client preferences, graphics presentation, pickup lifecycle, and death drops including demo restoration and legacy events. Native fixtures verify actual engine animation and collider placement at 0.5×, 1×, and 2× scale, every bundled spring chain, toggle/suspension, first-person suppression, and teleport reset. The adapted animation regression suite passes 702 checks.

Real loopback ENet scenarios pass for lobby transition, local VR alignment, and death-drop appearance/collection for both an existing client and a late joiner. Run `python3 deathmatch/tests/run_dropped_weapon_tests.py` to repeat the drop scenario. An isolated console-only package built successfully and passed its existing full map/runtime audit without client plugins. Native avatars were also rendered through Vulkan Mobile on an Intel Arc A770 and visually inspected.

The older `export_resources.gd` omnibus audit cannot run in this checkout because `maps/cache/lqdm4.scn` is absent; the targeted runtime avatar tests and packaged server map audit were used instead. The Godot host emits its existing one-object shutdown leak warning. No passing test run is counted when its log contains script errors.

For headset acceptance, repeat the original stair route and a crowded match with springs ON and OFF, recording SteamVR CPU/GPU timing and application `--frame-stats`. Enable verbose server health logging for that controlled reproduction if network rubberbanding remains; the retained logs are insufficient to confirm or rule out server stalls.

Native API reference: [SpringBoneSimulator3D](https://docs.godotengine.org/en/4.6/classes/class_springbonesimulator3d.html). The adapter was also checked against the installed engine API and Godot's native simulator/collision implementation.
