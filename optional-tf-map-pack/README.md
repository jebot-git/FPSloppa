# Original FPSloppa TF arenas

Two original, symmetrical team arenas inspired by classic fortress gameplay, with independently authored geometry:

- **tf_ironspan — Ironspan / Twin Foundries:** bridge and canal, two dry flank routes, three base entrances, sniper galleries and sheltered resupply alcoves.
- **tf_relayworks — Relayworks / Signal Towers:** elevated flags, separate ground capture points, twin ramps per tower, central tunnel and flanking routes.

Each side has four team spawns, a resupply point and two approaches to its flag area. Compiled geometry, team spawns and bot routes are validated in Godot. Player class badges remain independent of VRM appearance.

Extract the downloadable ZIP so the BSPs land in the game's external `maps/` and navigation files in `maps/navigation/`. Rescan the ASSETS menu, choose TF, then start a match. The included `tf_maplist.txt` is a suggested server rotation; preserve or merge your existing rotation before replacing it.

All layout geometry, MAP sources and generator are authored for FPSloppa and dedicated to CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . No original TF map data was used. Embedded texture pixels come only from LibreQuake v0.09-beta BSD-3-Clause WAD assets; retain the enclosed COPYING, CREDITS, important license info and texture-sources.json. Quake palette indices are used for engine compatibility; no id Software texture pixels are embedded.

Rebuild from the repository with `python3 tools/generate_tf_maps.py --compiler-dir /path/to/ericw-tools/bin` (tested with official ericw-tools v0.18.1, https://github.com/ericwa/ericw-tools/releases/tag/v0.18.1). The sources reference `librequake.wad`, supplied in `optional-tf-tools/`. The compiler is a separate GPL tool and is not bundled in this asset pack.

This is a playable initial layout, not a claim of competitive balance or headset performance certification. Report spawn camping, route balance and visibility issues during playtesting.
