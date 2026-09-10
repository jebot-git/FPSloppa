# Local AD map adaptation for FPSloppa

These tools prepare **local testing conversions** of the non-test maps in Arcane Dimensions 1.80 patch 1. They do not contain or publish AD BSPs, textures, models, sounds, or QuakeC. Keep the original archive and its notices. Do not upload the converted maps to the public FPSloppa repository or releases.

Get the original package from the [author's release page](https://www.simonoc.com/pages/design/sp/ad.html), using its [Quaddicted mirror](https://www.quaddicted.com/files/maps/singleplayer/ad_v1_80p1final.zip). Read the included `ad_v1_80_readme.txt` and credits before use. Non-commercial use is not blanket permission to redistribute modified content: the package's distribution clause requires its current state and its readme. Many embedded textures also derive from Quake. This is an unofficial compatibility experiment, not an Arcane Dimensions release.

The current conversion produced **16 locally installed maps**. See [the validation report](VALIDATION.md) for mode coverage, exclusions and test results.

## Reproduce

Run from the Godot project root with Python 3 and the project's Godot version. The existing `optional-threewave-tools/librequake.wad` supplies replacement textures. Set `GODOT_BIN` if Godot is installed elsewhere. Allow roughly 2 GB working space plus scene caches. Run the stages **sequentially**.

```sh
python3 optional-ad-tools/prepare.py /path/ad_v1_80p1final.zip --output /path/AD-Local
python3 optional-ad-tools/validate.py /path/AD-Local
python3 optional-ad-tools/finalize.py /path/AD-Local --install maps
"$GODOT_BIN" --headless --xr-mode off --path . --script res://optional-ad-tools/postflight.gd -- /path/AD-Local
```

`prepare.py` applies PAK patches in order, excludes all test maps and prop BSPs, preserves embedded texture pixels, and substitutes LibreQuake pixels for absent textures. It keeps original baked lighting, embedding the companion RGB light data where it fits. Quake visibility data is removed because the Godot importer does not use it. BSP29 and BSP2 still have to pass the game's **25,000,000-byte** and geometry-index limits. No limit is raised.

`validate.py` checks every eligible map in a separate, time-limited Godot process. It imports geometry, checks finite nondegenerate triangles, finds dry capsule-clear floor positions, bakes navigation, selects one connected component, and checks routes between every selected spawn. Failed or oversized maps are excluded. See `inventory.json`, `validation.json`, per-map logs, and `adaptation-report.json` in the output directory.

`finalize.py` adds arena spawns, current-game weapon/ammo/health/armor pickups, team bases and spawns, TF capture/resupply zones, and an authored KOTH point. It writes external BSPs, navigation meshes, per-map readmes and original notices. The optional `--install` copies these into the game's external maps directory. Existing default rotations remain unchanged. `postflight.gd` verifies the final files through the real game runtime, including pickup modifiers and navigation to objectives and pickups.

## Selecting maps and modes

Installed maps appear in the map picker with an `AD arena:` title. Optional suggestions are in `maps/<mode>_ad_maplist.txt`. To opt into one locally, merge those IDs into the corresponding `<mode>_maplist.txt` after reviewing the list. For a dedicated server, copy the appropriate `seta <mode>_maplist "..."` lines from `maps/ad-maplists.cfg` into your private server configuration; the parser does not support `exec` includes.

DM, TDM, IG and FT use the accepted maps. Shorter routes qualify for CC and KOTH; suitably separated connected bases qualify for experimental CTF/TF. CC and IG use the existing mode-specific pickup suppression. These are asymmetric single-player environments; automated route checks do **not** establish competitive balance. Start with modest player counts and playtest each layout.

## Deliberate changes and limits

- AD monsters, QuakeC, scripted encounters, portals and puzzle logic are not run. Key/monster-gated doors and breakables are removed. Remaining decorative brush movers are static. Only one navigable component receives multiplayer spawns and equipment; inaccessible regions are not claimed as playable arenas.
- Embedded map art is retained under its original terms. External flame/candle models use BSD-3-Clause LibreQuake fixtures. Native FPSloppa pickups and effects replace gameplay models. Other unsupported external decorations and ambient sounds are omitted; this is not a complete visual or audio recreation.
- Original lightmaps illuminate surfaces; the game's bounded nearby lights illuminate players. Static surface batching and sliver cleanup are enabled only by conversion metadata. The importer still produces water/slime/lava volumes from BSP planes.
- Navigation is bundled externally for offline bots. Clients that receive only a BSP can bake their own navigation for later offline use. No AD QuakeC or executable is downloaded or executed.
- Large AD levels can be demanding. No 72 FPS claim is made for Quest, Pico or PCVR; these conversions require device playtesting. The largest maps are excluded rather than bypassing current engine or upload limits.

## LibreQuake fixture provenance

The checked-in `deathmatch/maps/librequake-props/` contains first-frame mesh/skin conversions of LibreQuake's `progs/flame.mdl` and `progs/flame2.mdl`, with source hashes, BSD license and credits. These are the only newly bundled art assets. To regenerate from a LibreQuake release:

```sh
python3 optional-ad-tools/convert_fixtures.py /path/librequake/id1/pak0.pak --output deathmatch/maps/librequake-props
```

Keep the license and credits alongside the generated JSON. Fixture animation is currently static; emissive flame pixels retain visibility independently of environment lighting.

The importer also preserves palette-index-255 transparency on Quake fence textures, and the baked-light shader applies the cutout. This prevents cobwebs and hanging vines from becoming solid pink polygons. AD scene caches carry a separate importer revision so older cached geometry is rebuilt after this fix.
