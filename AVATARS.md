## 0.4v avatar storage

Default and imported VRMs now live in external `vrm/`. Dedicated servers persist received models there across restarts. The per-model limit remains 25 MiB. See [external assets](docs/EXTERNAL-ASSETS.md).

# VRM player models

Requires Godot 4.7 or newer. The supplied V-Sekai Godot-VRM 2.0.1 and MToon plugins are enabled in the portable project.

## Choose or import

1. Open **MODEL…** beside the callsign in the main menu (also available through Esc during a match).
2. Select one of the three bundled VRoid models. The live preview offers idle, walk, run, firing, rotation, and weapon selection.
3. Choose **IMPORT .VRM…** to browse your computer for a custom VRM 0.x or VRM 1.0 humanoid.
4. Press **USE THIS MODEL**. Your selection persists across restarts. In a match, selection changes are limited to roughly once every three seconds.

The preview uses the same rig and scale rules as multiplayer. Practice targets also use bundled VRMs. The local player's VRM is hidden in first person; VR uses tracked glove hands and a freely aimed 3D weapon; desktop keeps the original weapon view.

## Fairness and motion

- The fully skinned rest pose is uniformly scaled to 1.70 metres high and grounded before IK. Tiny or giant authored units, skeleton transforms and inverse skin binds are included in the measurement. The result is cached once per decoded VRM and shared by its instances; crouching or jumping never changes model scale.
- Full-body tracking preserves displacement from the model's own neutral hip and ankle heights. This avoids pulling short legs up onto their toes or forcing long legs into a squat simply to match a generic calibration skeleton. Real crouches and foot lifts still animate normally.
- Every player shares a 1.65 m standing height and 0.30 m radius movement capsule. Crouch/prone shorten collision and damage heights together, with clearance checks before standing. Imported mesh size never changes collision, damage, speed or validated reach. Cosmetic geometry outside the standard damage volume is not hittable.
- Godot-VRM retargets humanoid bones to GeneralSkeleton / SkeletonProfileHumanoid. Procedural gait feeds analytical two-bone IK for both legs, with knee poles and terrain foot raycasts. Arm IK retains aimed weapon grips, wrist alignment and finger curl. See the stance controls below.
- Movement direction, speed, weapon, and pitch come from the existing authoritative snapshots. Recoil follows replicated shot effects. Death immediately disables the hitbox, plays a short cosmetic fall, then hides the avatar until respawn.
- Hair and secondary motion use the VRM plugin's spring-bone implementation. Unusual proportions, extreme accessories, custom shaders, and nonstandard rigs can still need author-side adjustment. The preview lets you inspect these before selecting a model.

VR snapshots also carry validated head, grip and weapon transforms. Smoothed head orientation, crouching hip motion and two-bone arm IK follow the tracked poses. Gun-hand selection is replicated. Pain adds a short directional body flinch; heavy kills can produce cosmetic gibs. Headset motion is never driven by hit animations.

Motion is authored procedurally in this project; no third-party animation clips are redistributed.

## Leg animation and stances

Untracked legs blend between walking and running in eight body-relative directions,
including backwards and diagonal movement. Crouching shortens the stride; prone
uses an extended crawling pose. Jumping has a distinct knee tuck on ascent,
extended legs while falling, and brief landing compression. The walking cycle
pauses in the air. The fallback marine also has articulated leg animation.

Desktop controls default to **hold Ctrl to crouch** and **Z to toggle prone**;
both can be rebound in Settings → Bindings. VR keeps physical crouching and adds
physical prone: while standing play and physical crouching are enabled, a headset
below 55 cm enters prone and rising above 68 cm leaves it. Physical prone can be
disabled separately. The server checks actual headset height and ceiling clearance.

| Stance | Movement speed | Bullet spread |
| --- | --- | --- |
| Standing | 100% | 100% |
| Crouching | 55% | 75% |
| Prone | 18% | 45% |

Spread bonuses require ground support and do not apply in water. They tighten both
axes of spread weapons; melee reach and already perfectly accurate shots are
unchanged. Prone blocks jumping, including a held jump request, and is suspended
in water so swimming remains usable. These rules run in both server simulation
and client prediction.

Tracked feet remain authoritative by default. **Settings → Bindings → Animate
tracked legs while still (optional)** adds a restrained gait only during grounded
locomotion after both feet stay within 5 cm and 12 degrees for 0.55 seconds.
Intentional foot/knee movement, raised feet and low hip poses immediately restore
fully tracked legs. This cosmetic assistance never generates physical melee kicks.
The preference and stance bindings persist in the client config.

Stance, grounded state and the assistance preference replicate to other clients
and new demos. Old demos remain readable. Multiplayer uses protocol
`fpsloppa-31-team-radio`, so clients and servers need matching updates.

Run `python3 deathmatch/tests/run_stance_tests.py` for movement, tracking,
prediction, actual weapon spread, demo/config and independent server/client
checks. `deathmatch/tests/avatar_stances.gd` renders a six-pose comparison.

## Death animation

Deaths use a short authored bone animation: knees buckle, the body falls backward,
and the head, arms and uneven legs settle into a loose face-up pose. This replaces
the whole-avatar forward tilt that resembled live prone movement. The same sequence
is available on the download/error fallback marine. Low or prone deaths begin at
the current hip height, without standing the avatar up first.

Death stops locomotion, aiming, eye tracking and full-body tracking; later look/yaw
updates cannot rotate the corpse. Weapons disappear and supported eyelids close.
The pose settles in 0.9 seconds, then reuses cached bone transforms until the
existing 2.5-second corpse visibility limit or respawn. There are no ragdoll bodies,
joints or extra floor probes. Respawn clears the pose cache and stance blend.
Freeze Tag, gib hiding, spectator hiding and the local death-camera body policy
retain their separate behavior. Multiplayer continues using the existing dead
state; no additional pose packets or protocol change are required.

This is a cosmetic animation, without per-limb collisions or adaptation to uneven
floors/walls. Validate with `python3 tools/validate_death_animation.py`; add
`--preview` for the rendered comparison. The [validation receipt](docs/validation/death-animation.json)
covers all three bundled VRMs, standing/prone/tracked entry, tracking/yaw isolation,
respawn, fallback and fighter visibility states, plus stance/scaling regressions.
Script timing measurements exclude GPU skinning, hair and rendering; headset
performance has not been newly measured.

## Sharing and limits

Selected custom files are automatically uploaded to the host and downloaded by match participants who need them. Use models you have permission to share. Three CC0 defaults are included specifically so the portable game can be redistributed. The other models in the connected project's original `vrm/` directory have not been added to the portable default pack.

- Maximum file size: **25 MB = 25,000,000 bytes**, inclusive. The import path, server advertisement handler, transfer start, and receiver all enforce this limit.
- Only self-contained binary VRMs with embedded PNG/JPEG textures are accepted. External buffers, texture URLs and data URIs are rejected.
- Additional limits: 4,096 nodes, 64 textures, 8,192 pixels per texture dimension, 64 million total texture pixels, and bounded geometry counts. These prevent a small compressed file from creating excessively large resources. Thus not every file below 25 MB will be accepted.
- Files are identified by SHA-256, never by a remote filesystem path. Complete files are checked for size, hash, and VRM structure before being registered. Invalid, unsolicited, oversized and out-of-order chunks are discarded.
- ENet reliable channel 4 carries 32 KiB chunks, with an eight-chunk acknowledgement window and a 2 MiB/s aggregate sender budget. Gameplay keeps its existing separate channels. Only models currently referenced by players can be requested from the server.
- One outgoing transfer per destination; other requested models wait and retry. Transfers time out after 30 seconds without progress. A fallback marine remains visible while downloading or if a model fails.
- Completed files are cached under `user://avatars/`; old unselected, unused files are evicted when needed to keep cached VRMs within 1 GB. Active selections are retained. Decoded scene caching keeps up to four model resources in addition to live instances. Partial transfers are removed on failure or disconnect.
- First-time model decoding/material creation is currently synchronous and can briefly stall the receiving client, especially for complex VRMs. Cached scenes avoid repeat decoding.
- Dedicated servers relay and validate the original files without creating visual avatars. Direct-IP/port-forwarding requirements are the same as the existing game.

## Source files

`deathmatch/avatars/library.gd`: validation, cache, runtime Godot-VRM loading, selection persistence.

`network.gd`: server-mediated model catalog and acknowledged chunk transfers.

`picker.gd`: model selection, preview, animation controls, filesystem import.

`rig.gd` / `pose.gd`: normalized visuals, AnimationPlayer clips, locomotion and aiming IK.

`fighter.gd` / `arena.gd`: integration with fixed collision, snapshots, shot events, death, and reconnects.

The installed VRM plugin's `_import_post` / `_export_post` overrides needed four explicit `return OK` additions for Godot 4.7's inherited Error return types. Changes are in `VRMC_springBone.gd`, `VRMC_materials_mtoon.gd`, and `VRMC_materials_hdr_emissiveMultiplier.gd`. For release-runtime compatibility, custom resource arrays in the spring-bone root/secondary/collider scripts and node-constraint applier use ordinary Arrays; one spring-runtime local has an explicit type. This avoids failed typed-array assignments when instantiating cached VRMs. Bone algorithms and model data are unchanged.

## Validation

Run from the project directory with the Godot 4.7 executable:

```sh
godot --headless --xr-mode off --path . --script res://deathmatch/tests/avatars.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/avatar_transfer_guards.gd
python3 deathmatch/tests/run_network_tests.py --avatars
python3 deathmatch/tests/run_network_tests.py
```

The avatar network test starts an independent server, uploader, and receiver with isolated caches. It modifies a CC0 sample's metadata to create a new ~14 MB custom VRM, verifies upload, relay, SHA-256 identity and runtime loading, then disconnects/rejoins the receiver to check catalog restoration and cache reuse. Temporary test files are removed. Results are written to `test-results/`.

`avatars.gd` also accepts extra VRM fixture paths after `--`. VRM 1.0 was additionally checked with pixiv's official `VRM1_Constraint_Twist_Sample.vrm`; this test-only download is not bundled.

The project ZIP contains source and original VRM files. When creating an executable export, preserve the raw `.vrm` files and `models/manifest.json` in the package: runtime loading reads the original GLB bytes, not only Godot's editor-imported PackedScene files.

The Entryway raw asset export plugin explicitly adds original VRM/BSP bytes to the PCK; an include filter alone does not retain editor-imported VRM source files. Keep this plugin enabled when exporting.

Original UT99 humanoid model/skin packages can be prepared with the separate [UT Avatar Converter](https://github.com/jebot-git/UTAvatarConverter/releases/tag/v0.1.0). Female Soldier (`SGirl`), Female Commando (`FCommando`) and Rumiko have tested starting presets. Export the VRM into `vrm/`, then use the normal picker. The generated skeleton and weights are approximate; inspect the pose preview and test movement before using the avatar in VR.

Quake humanoid MDL models can be prepared using the experimental [MDL Avatar Converter](https://github.com/jebot-git/MDLAvatarConverter/releases/tag/v0.1.0). Supply the matching game palette or a PAK containing it, review the source frame and landmarks, then export a VRM. Its estimated rig can distort arms and attached equipment; GoldSrc/Source MDL is unsupported.
