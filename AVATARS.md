# VRM player models

Requires Godot 4.7 or newer. The supplied V-Sekai Godot-VRM 2.0.1 and MToon plugins are enabled in the portable project.

## Choose or import

1. Open **MODEL…** beside the callsign in the main menu (also available through Esc during a match).
2. Select one of the three bundled VRoid models. The live preview offers idle, walk, run, firing, rotation, and weapon selection.
3. Choose **IMPORT .VRM…** to browse your computer for a custom VRM 0.x or VRM 1.0 humanoid.
4. Press **USE THIS MODEL**. Your selection persists across restarts. In a match, selection changes are limited to roughly once every three seconds.

The preview uses the same rig and scale rules as multiplayer. Practice targets also use bundled VRMs. The local player's VRM is hidden in first person; VR uses tracked glove hands and a freely aimed 3D weapon; desktop keeps the original weapon view.

## Fairness and motion

- Rest-pose visual bounds are normalized to 1.70 metres high; feet are aligned with the ground.
- Every player retains the same 1.65 m tall, 0.30 m radius movement capsule and existing fixed damage volumes. No imported mesh, bone, clothing, height, or accessory changes collision, damage, movement speed, or validated reach. In VR the camera follows the headset, independently of the fixed damage volumes. Cosmetic geometry outside the standard damage volume is not hittable.
- Godot-VRM retargets humanoid bones to GeneralSkeleton / SkeletonProfileHumanoid. Three authored AnimationPlayer clips provide idle breathing, walking, and running hip motion. A custom SkeletonModifier3D performs analytical two-bone IK for both legs and both arms, with knee/elbow poles, terrain foot raycasts, aimed weapon grips, wrist alignment and finger curl.
- Movement direction, speed, weapon, and pitch come from the existing authoritative snapshots. Recoil follows replicated shot effects. Death immediately disables the hitbox, plays a short cosmetic fall, then hides the avatar until respawn.
- Hair and secondary motion use the VRM plugin's spring-bone implementation. Unusual proportions, extreme accessories, custom shaders, and nonstandard rigs can still need author-side adjustment. The preview lets you inspect these before selecting a model.

VR snapshots also carry validated head, grip and weapon transforms. Smoothed head orientation, crouching hip motion and two-bone arm IK follow the tracked poses. Gun-hand selection is replicated. Pain adds a short directional body flinch; heavy kills can produce cosmetic gibs. Headset motion is never driven by hit animations.

Motion is authored procedurally in this project; no third-party animation clips are redistributed.

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
