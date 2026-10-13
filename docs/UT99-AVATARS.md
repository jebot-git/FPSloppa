# UT99 avatars — voxelspace prototype

Players import **UTX skins** from the player-model picker. The importer applies a skin to one of five prepared UT99 base models: Male Soldier, Male Commando, Female Soldier (SGirl), Female Commando and Boss/Xan. All five retain original vertex animation with constrained IK for the head, neck and both arms. VRM import/rendering and body, facial, eye and finger tracking are absent from the active prototype.

## Player import and recognition

Choose **IMPORT .utx SKIN…**, select a file, check the suggested base model, choose the skin family and face, then **IMPORT SELECTED SKIN**. Load the preview and choose **USE THIS MODEL** to publish the selection to the match. Importing alone does not change the currently advertised avatar.

Recognition checks that the required texture slots exist, then uses the package name, unique slot layouts and named face variants. Female model names take precedence over overlapping male names. Renamed Commando packages can be recognised by face variants in slot 2; Female Commando uses slots 1/2/4. Soldier, SGirl and Boss frequently share slots 1/2/3/4, so a texture-only package cannot always identify its intended mesh. The picker labels ambiguous suggestions, retains a compatible current model where possible, and always permits a manual override. A matching layout does not guarantee the artist intended that model.

The native GDScript reader supports classic UE1 package versions 61–69, ASCII object names, embedded palettes and P8 or DXT1/3/5 textures. It reads textures only; it does not execute UnrealScript, deserialize native objects, resolve external packages or invoke an extraction binary. Unsupported layouts, missing embedded palettes or malformed packages produce an error. Team texture variants are excluded from face choices; this player flow imports neutral families. Maximum source package size is 25 MB, texture dimensions 2,048², 512 textures and 64 MB decoded data.

## Multiplayer identity and cache

The existing avatar synchronisation flow now carries the selected prepared mesh, original frame data, constrained IK metadata and embedded skin atlas together in a validated `.utavatar` container. The selected model and face therefore have one SHA-256 identity. Different faces have different hashes; repeated imports of the same choice are deterministic. Peers request missing content, validate size/format/hash, cache it and render that identity. Late joiners receive the selection; cached peers avoid repeating the transfer. A skin does not rely on another player having the same UTX installed.

This prototype sends the complete converted avatar on a cache miss (around 6.2 MB for Soldier), rather than a separate texture delta. The original UTX is not transmitted. Cache: `ut99/`, preferences: `user://ut99_avatars.cfg`. Legacy VRM preferences and caches are not migrated. The protocol suffix is `-ut99-vertex1`; clients and servers must update together. CQ content routes are `POST /utavatar` and `GET /utavatar/<sha256>.utavatar`, backed by the same validator.

## Rendering and constrained tracking

One shared ArrayMesh/material per avatar hash, a padded mipmapped opaque skin atlas and a floating-point vertex-position texture retain native animation. Per-instance uniforms interpolate frames and apply six IK bone transforms. Identical frame textures are shared through weak references. Model scale is normalised once to 1.70 m visual reference height; subsequent animation uses the same scale and origin. Animated bounds protect culling. Collision and damage continue to use standard gameplay anatomy.

Authored topology regions cover complete arms and head/neck; coincident UV seams have identical weights. Animated torso sockets anchor fixed-length two-bone arms. Reach, shoulder direction, elbow bending and chest crossing are constrained. Neck IK preserves its segment length; head orientation is limited to ±50° pitch, ±75° yaw and ±25° roll. Female bind-head correction removes the tilted reference pose without changing their original animation frames. The remainder of each avatar uses vertex animation. The live XR preview uses this same production solver and shader.

Headset/controller transforms also drive aiming, room-scale movement, seated mode, physical crouch/prone/jump, VR menus and haptics. Head tracking can continue when controllers are unavailable; missing tracking is not replaced with synthetic poses in the live preview. No Skeleton3D, full-body trackers, optical fingers, gaze or expressions are required. Voice remains audio only. Custom converted models without an IK profile retain native animation and tracked weapon transforms. Historical VRM/MDL code and receipts remain for provenance but are unsupported and excluded from active exports.

## Defaults, provenance and rebuild

The first seven selections remain **World Leaders** by EvilGrins on Epic's Soldier: Jong-un, Judas Trump, Justin Trudeau, Macron, Netanyahu, Putin and Xi. Source: https://unrealarchive.org/unreal-tournament/skins/W/world-leaders_6ff65135.html . Downloaded `SoldierSkinsDictator.zip` SHA-1: `6ff651356db4157631a9b0986bfd1eb579f2f602`. The archive ReadMe credits EvilGrins. The five additional stock selections use locally installed BotPack meshes and the corresponding stock skin packages. Epic Games / Digital Extremes and skin author terms apply; these assets are not CC0. No original game packages or extractor binaries are shipped. The separately generated Field Marine test asset is original CC0 work.

Offline conversion uses `tools/ut99_avatar/convert.py` and Python numpy/Pillow with extracted `_d.3d`, `_a.3d`, `.uc` and PNG textures. The earlier UTAvatarConverter checkout can perform extraction; UnrealScript sequence metadata is parsed without execution. Rebuild the defaults from its extraction jobs:

```sh
python3 tools/ut99_avatar/world_leaders.py /absolute/world-leaders/extract-result.json
python3 tools/ut99_avatar/base_models.py --extracted /absolute/stock-extraction-jobs
```

`base_models.py` authors topology masks and animated sockets for the five specific stock meshes; arbitrary custom models need their own authored IK data. Rebuilding World Leaders preserves prepared base-model manifest entries. Player imports need neither Python nor the offline converter.

The internal `UTAV` version-1 envelope contains length-prefixed JSON, RGBAF position data and an embedded PNG. Admission limits are 25 MB, 4,096 vertices/frames, 1,048,576 animated vertices, 8,192 triangles, 256 clips and a 2,048² atlas, with finite coordinates and valid references. No resource scripts or external textures/URLs are loaded.

## Preview and validation

```sh
godot --xr-mode on --rendering-method forward_plus --path . tools/ut99_avatar/xr_preview.tscn
godot --xr-mode off --rendering-method forward_plus --path . tools/ut99_avatar/skin_preview.tscn
godot --headless --xr-mode off --path . --script deathmatch/tests/ut99_ik.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/utx_import.gd
python3 deathmatch/tests/run_avatar_network_tests.py --avatar-file /absolute/imported.utavatar
```

The separate native XR window selects models and original animations and accepts connected WiVRn-Pro head/controller input. Recenter establishes standing eye height and forward direction. [Current skin/IK validation](validation/ut99-skins/README.md) includes all five models, recognition, rendered picker and real network transfer checks. [Earlier 32/64 stereo shooting comparisons](validation/ut99-avatars/README.md) predate the accepted constrained solver and must not be treated as its performance measurements.

[Current 120-second 64-avatar Forward+ category profile](validation/ut99-avatars/shoot-64-forward-profile/README.md) measures the accepted constrained solver with shooting, no AI and actual wall-clock frame intervals.
