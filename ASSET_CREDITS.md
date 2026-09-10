## 0.4v additions

The railgun uses `afps_8.glb`, the existing sniper mesh from drummyfish’s CC0 [Oldschool AFPS Weapons](https://opengameart.org/content/oldschool-afps-weapons). `tools/generate_rail_sound.py` generates the original rail effect. Optional LibreQuake maps retain upstream licenses, author readmes and texture provenance in `optional-map-pack/`. The ThreeWave tools contain only the converter and BSD LibreQuake texture donors; no ThreeWave BSPs are published. See `optional-threewave-tools/RIGHTS.md`.

# Asset credits

This is an independent arena shooter with Doom-inspired weapon behavior. The previous Entryway reconstruction, its map references and its environment assets have been removed from the game. Fallback marine geometry, HUD and game code were authored for this project.

Original Doom WAD files, music, sound samples, sprites, textures and engine source are not included. Weapon behavior was informed by id Software's published Doom weapon routines: https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_pspr.c

## VRM player models and plugins

Bundled `deathmatch/avatars/models/sample_d.vrm`, `sample_f.vrm`, and `sample_g.vrm` are the historical VRoid Studio AvatarSample D, F, and G models by **VRoid Project / pixiv Inc.**, released under **CC0 1.0**. These are the older beta samples, not similarly named models from newer VRoid Studio releases.

- Official conditions: https://vroid.pixiv.help/hc/en-us/articles/4402614652569-Do-VRoid-Studio-s-sample-models-come-with-conditions-of-use
- Original CC0 waiver: https://creativecommons.org/publicdomain/zero/1.0/
- Download mirror / provenance: https://opengameart.org/content/vroid-studio-cc0-models (uploaded by hecko, 2024-12-24).
- Download archives: `avatarsample_d_0.zip`, `avatarsample_f.zip`, `avatarsample_g.zip`.
- Original VRM files are retained without modification. Runtime scale, posing, weapon grips, and animation are applied by the game. Exact file hashes are in `models/manifest.json`.

**V-Sekai Godot-VRM 2.0.1** and **Godot-MToon-Shader**: https://github.com/V-Sekai/godot-vrm — MIT licenses preserved in the respective `addons/` directories. Copied from the connected Godot project's installed plugins. Four missing Error return values were patched for Godot 4.7; see AVATARS.md.

**Animation / IK code and clips**: authored for this project; no downloaded motion assets. Implementation uses Godot's SkeletonModifier3D API: https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html

**VRM 1.0 compatibility test only**: pixiv's official three-vrm sample, https://github.com/pixiv/three-vrm/blob/dev/packages/three-vrm/examples/models/VRM1_Constraint_Twist_Sample.vrm — not included in the distributed defaults.

## Quake maps

Five BSP maps (lqdm1, lqdm2, lqdm4, lqdm7, lqdm8), embedded textures and the palette come from LibreQuake v0.09-beta, BSD-3-Clause: https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta . The full attribution and license files are preserved in `deathmatch/maps/`. See MAPS.md for titles and adaptations.

Godot BSP importer by jitspoe, MIT: https://github.com/jitspoe/godot_bsp_importer . The vendored copy guards missing collision shapes and degenerate convex hulls. This project uses triangle collision plus separate trigger volumes and its own entity adapter.

## Weapon models

Oldschool AFPS Weapons by **Drummyfish** (also published as tastyfish), **CC0 1.0**: https://opengameart.org/content/oldschool-afps-weapons and https://blendswap.com/blend/28963 . Original archive: https://opengameart.org/sites/default/files/afps_weapons.zip . CC0 waiver: https://creativecommons.org/publicdomain/zero/1.0/ . The author's meshes and 1024-pixel textures were converted to GLB in Blender, reoriented and scaled. The saw sword serves as the chainsaw; the lightning-gun mesh is adapted into the BFG. The super shotgun uses the original textured shotgun mesh with a wider stock and the paired-bores adaptation in `deathmatch/art.gd`. Animations/recoil remain project code.

`deathmatch/weapons/fist.glb` is a posed right hand extracted from the CC0 VRoid AvatarSample D described above. This derivative is separate from the unchanged player-model VRM. Blender conversion scripts are in `tools/`; the downloaded source pack is also retained beside the project in `../WeaponSource/`.

## VR tools, hands and new effects

Godot XR Tools **4.5.1**, by Bastiaan Olij and contributors, MIT: https://github.com/GodotVR/godot-xr-tools/releases/tag/4.5.1 . License retained in `addons/godot-xr-tools/LICENSE`. This project uses its controller pointers, 3D viewport UI, virtual keyboard and hand scenes. Compatibility changes add the missing fallback return in `viewport_2d_in_3d.gd`, remove two initial unbound ViewportTexture material references (the scripts bind them at runtime), and dispatch virtual-key release events.

The tactical glove hand models by **DigitalN8m4r3 / Miodrag Sejic** are CC0. Their full waiver remains in `addons/godot-xr-tools/hands/License.md`.

The twenty WAV files in `deathmatch/audio/`, their generator `tools/generate_sounds.py`, and `deathmatch/effects/blood.svg` were authored for this project and are offered under CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . No original Quake/Doom sounds are used. New recorded CC0 firearm and foley assets are credited in `deathmatch/audio/recorded/SOURCES.md`; their original notices are retained alongside the audio. Blood particles and low-poly gibs are generated by project code. The free assets above remain under their individual licenses; this effects waiver does not relicense the whole game .

## Exported runtime and voice

PC/server binaries use the official Godot 4.7.2 export templates. Godot’s MIT license and bundled dependency notices are supplied as GODOT-LICENSE.txt and GODOT-COPYRIGHT.txt. Voice capture/relay/UI and the independent-block IMA ADPCM implementation were authored for this project; no third-party voice SDK, voice recordings or hosted voice service is bundled.

Release compatibility patches in Godot-VRM use ordinary Arrays for spring/collider and node-constraint resource collections, with an explicit spring-runtime local type. The authored `addons/entryway_export` plugin preserves raw avatar/map bytes in exported packs. See AVATARS.md for details.

## Android XR support

Official Godot OpenXR Vendors 5.1.0-stable: https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.1.0-stable. Addon and bundled third-party license notices are retained under addons/godotopenxrvendors. The new launcher icon (`deathmatch/icon-final.png`) was generated for this project using the built-in image generation tool. Its exact prompt and provenance are in ICON.md; it contains no intentionally borrowed game logo or character.

Godot-VRM secondary physics has a small runtime guard to skip signal-driven spring simulation for hidden/disabled avatars. Body IK caches bone IDs, samples floor contacts at 12.5 Hz and caches distant poses at 30/15 Hz. Eye animation code is authored for this project.

## Supply models and music

The bevelled ammo racks, rocket carrier, cell pack, medkit, armour vests and bonus supplies in `deathmatch/pickups/models.gd` were authored for this project. The meshes use a muted industrial vertex-colour palette, without external textures or downloaded models. These authored pickup meshes are offered under CC0 1.0.

**Iron Circuit**, **Pressure Lock**, **Foundry Run** and **Dark Relay** are original four-channel tracker scores using edited CC0 Karoryfer instrument recordings, offered under CC0 1.0. Editable MODs, compact Ogg playback and provenance are in [deathmatch/audio/music/SOURCES.md](deathmatch/audio/music/SOURCES.md). No existing game score or game recording is included.


## 0.3v additions

- LibreQuake v0.09-beta: Hyperborea (`lqdm3`), Transport Tubes (`lqdm5`) and Ghost Quarter (`lqdm6`), by ZungryWare. Original BSP/LIT files from the [official full release](https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta); BSD-3-Clause notices remain in `deathmatch/maps/LibreQuake-*.txt`. Objective placements are project-authored adaptations.
- Bebas Neue headline font: Copyright 2010 Dharma Type, SIL Open Font License 1.1. [Google Fonts source](https://github.com/google/fonts/tree/main/ofl/bebasneue), license `deathmatch/ui/OFL.txt`.
- Procedural CTF banners, team emblems and UI frames: original project assets, CC0. Mesh source: `deathmatch/modes/flag.gd`; no proprietary Doom/Quake UI artwork is used.
- Steam Audio integration/runtime notices: `addons/godot-steam-audio/LICENSE`, `STEAM-AUDIO-LICENSE.txt`, `THIRDPARTY.md`, and `SOURCES.md`.

- Additional soundtrack instruments: Karoryfer Lecolds / Brian Wood, CC0 1.0; Black and Green Guitars, Growlybass and Big Rusty Drums. Exact pinned recordings and transformations: `deathmatch/audio/music/SOURCES.md`. Original compositions and renders: CC0 1.0.
- Pain grunts: HaelDB, Male Grunt/Yelling Sounds, CC0 1.0. Selection and processing: `deathmatch/audio/recorded/SOURCES.md`.
