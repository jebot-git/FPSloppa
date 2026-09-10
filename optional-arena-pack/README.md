# FPSloppa Arena Collection 1

Forty original BSP29 maps: **five each for DM, TDM, CTF, KOTH, IG, FT, CC and TF**. These are additional maps, including five TF arenas beyond Ironspan and Relayworks. Each has a distinct footprint/connection/elevation arrangement and a descriptive name. Shared architectural modules keep the visual language consistent across the collection.

## Install

Extract the all-mode ZIP or an individual mode ZIP. With Python 3 installed:

```sh
python3 install_arena_pack.py --game-dir /path/to/FPSloppa
```

The installer verifies every payload hash, refuses to overwrite different existing assets, installs into external `maps/` and `maps/navigation/`, and appends the maps to the corresponding `<mode>_maplist.txt`. Existing rotations are backed up before modification. Run it again safely; already installed matching assets and rotation entries are retained. `--dry-run` checks without changing files.

Without Python, copy the package's `maps/` contents into the game's `maps/` folder, preserving other assets. Append the IDs in `rotations/<mode>_maplist.txt` to your corresponding rotation. Rescan **ASSETS**, select the appropriate mode and map, then host or start practice. For Android, use the game's selected external asset directory; do not put BSPs into the APK. The existing server map-transfer system can send the BSP to clients.

Explicit `set dm_maplist "..."` (or another mode-specific list) in server.cfg overrides its external rotation file. Extend that setting too if your server uses it. For example:

```text
set sv_gametype "tf"
set tf_maplist "tf_kilnfront tf_abbeyline tf_capacitor tf_lockworks tf_obsidian"
map tf_kilnfront
```

Open **atlas/index.html** for screenshots, schematic floorplans and mode filters. The individual text readmes describe each layout. Schematics show room connections, heights, spawns, supplies and objectives; internal cover is visible in the screenshots and MAP sources.

## Gameplay

- DM: compact interconnected circuits, with major armor and weapons separated.
- TDM: mirrored room connections, heights, cover and supply locations.
- CTF: four native spawns per team, broad flag rooms with several approaches, mirrored routes and elevated flanks.
- KOTH: four approaches to the central room. Symmetric spawn extremes and a center spawn make the existing build choose the authored hill without new map scripting.
- IG: offset spawn positions, intermediate room cover and varied route heights break uninterrupted rail lines.
- FT: broad connections and room cover give thawing teammates space while allowing opponents to flank.
- CC: shorter circuits, low obstacle density and shallow ramps. Pickups remain in the BSP for other modes; the existing CC modifier disables every pickup. No map-specific health drain or melee rule replaces the game mode.
- TF: larger bases, four native spawns and two resupply areas per team, multiple approaches, and occasional separate capture rooms. All routes work without class-specific jumps or QuakeC.

Recommended populations are starting points, not balance certification: generally 2–8 for DM/IG/KOTH, 4–12 for team modes, and 2–6 for CC. No required route uses teleporters, moving platforms, rocket jumps or damaging liquids. Heights change through ramps. The current runtime limits visible map lights to four on Android and eight on PC; BSP geometry ranges from about 3,500 to 17,700 rendered triangles per map in validation.

## Validation and rebuilding

All 40 maps are compiled using ericw-tools v0.18.1 with full VIS and light data. The current development build imports the embedded coloured Quake bake, including static shadows and bounced illumination. Wall and corridor fixtures, sky courts and restrained live lights supplement it. Earlier builds still use their environment/point-light fallback; update the game to see the bake. RGB data travels inside the BSP for host downloads. See MAP_LIGHTING.md in the source checkout for implementation and limits.

The included validation report checks BSP lumps/indexes, finite nondegenerate render/collision triangles, spawn and pickup clearance, objective selection, every connecting ramp with the player's capsule, and bot routes from every spawn to every other spawn, pickup and objective. Native CTF/TF approach-length ratios are recorded. Short offline matches of 720 physics ticks with three bots also ran on every map; the report records travel distance and checks the CC/IG pickup modifiers and TF class state. This is automated validation, not a claim of tournament balance or 72 FPS on a particular headset. Long matches, crowded thaw fights and sentry placement need human playtesting.

From the FPSloppa source checkout:

```sh
python3 tools/generate_arena_pack.py --compiler-dir /path/to/ericw-tools/bin
godot --headless --xr-mode off --path . --script res://deathmatch/tests/arena_pack.gd
python3 tools/package_arena_pack.py
```

Pass `--only dm_cindercoil` (or other IDs) to the generator for a focused rebuild. The initial texture subset was extracted from LibreQuake v0.09-beta developer WADs; the exact WAD and per-texture hashes are included. The source pack contains the subset WAD, so an ordinary rebuild needs no asset download. ericw-tools is a separate GPL compiler, not bundled here.

## Rights

All new layout geometry, MAP sources, generator, installer, atlas and new documentation are CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . Texture pixels are solely LibreQuake BSD-3-Clause assets, with the original COPYING, CREDITS and license explanation retained. `texture-validation.json` proves every embedded mip matches the donor data. No original Quake/Doom/SkullTag/TeamFortress BSP, WAD, texture pixels or recorded footage is included. References inform gameplay principles; no reference layout was traced or decompiled. See REFERENCES.md.
