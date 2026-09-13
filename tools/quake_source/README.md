# Quake multiplayer source ports

Compiles the GPL map sources released by John Romero with Makkon, LibreQuake and original generated replacement art. The maintained addon contains the original retail deathmatch layouts DM1–DM6 and the source archive's bonus multiplayer layout DM7. Singleplayer maps, Start, End, item-model sources and DM8 (no deathmatch spawns) are excluded.

Official sources: https://rome.ro/resources and https://rome.ro/s/1996-quake-map-sources.zip

Reviewed archive SHA-256: `c2f0660617264e0918edc4a7c34dc66692ef396f2308c6cf9b6d12cfe595db7c`.

Maps are GPL version 2; original notices and the exact original/adapted `.map` sources accompany every packaged BSP. Most texture material is from LibreQuake v0.09-beta development WADs (BSD-3-Clause), supplemented by four original generated gothic motifs (CC0 dedication); corresponding attribution, WAD subset and per-texture hashes are included. No commercial Quake installation, texture WADs, music, sounds, models or QuakeC is required. These ports are unofficial modifications of id Software's layouts.

## Build

Use Python 3, Pillow and ericw-tools (`qbsp`, `vis`, `light`). The September 2026 texture review used v0.18; prior builds used v0.18.1. Obtain ericw-tools from https://github.com/ericwa/ericw-tools/releases/tag/v0.18.1 and LibreQuake's `dev.zip` from https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta. Extract the latter's `dev/texture-wads` and `dev/docs` together.

```sh
curl -L --fail https://rome.ro/s/1996-quake-map-sources.zip -o quake-map-sources.zip
python3 tools/texture_replacements/build.py --librequake /path/to/dev/texture-wads
python3 tools/quake_source/build.py --archive quake-map-sources.zip --librequake /path/to/dev/texture-wads --compiler /path/to/ericw/bin --output ../Builds/Quake-Multiplayer-Addon
python3 tools/quake_source/verify.py ../Builds/Quake-Multiplayer-Addon
python3 tools/validate_converted_traversal.py --directory ../Builds/Quake-Multiplayer-Addon/maps --results test-results/quake-multiplayer-traversal
python3 tools/quake_source/preview.py ../Builds/Quake-Multiplayer-Addon/maps
python3 tools/quake_source/network_test.py ../Builds/Quake-Multiplayer-Addon/maps/qsrc_dm1.bsp
python3 tools/quake_source/package.py ../Builds/Quake-Multiplayer-Addon
```

Each BSP is compiled with full visibility and a two-sample-per-axis, bounced light bake. RGB lightmaps are embedded in the BSP so host downloads carry the lighting without sidecar requirements. The source sets a modest lighting floor and sky contribution. Texture substitutions preserve special sky/liquid/clip semantics and use the explicit shared name-to-art dictionary, retaining protected texture semantics and button animation families. Makkon substitutions use the original donor names, dimensions and miptex bytes without resampling. Generic hash-selected substitutions have been removed. Switchable lights are baked on; key/shooting doors use native proximity activation. Original brushwork and multiplayer item/spawn locations are retained. Changes are recorded in `BUILD.json`; the game supplies its native pickups, weapon behavior, movers and trigger handling.

The swimming acceptance test now measures capsule headroom: a submerged sample immediately below a ceiling cannot reasonably be required to rise five centimetres. DM3's low-clearance sample moved approximately 3.2 cm with approximately 3.0 cm measured upward clearance. Clear-water swimming and surface exits are still checked normally.

## Install and modes

Extract the optional ZIP into the game's external asset root (the directory containing `maps/` and `vrm/`). Restart the map menu to discover `qsrc_dm1` through `qsrc_dm7`. For Android, use the game's app-specific external files directory or the existing host map-download facility. Keep the supplied `addons/quake-multiplayer` sources and notices with copies of the addon.

The pack adds `maps/dm_quake_maplist.txt`, `tdm_quake_maplist.txt`, `ig_quake_maplist.txt`, `ft_quake_maplist.txt`, and `cc_quake_maplist.txt`. These are optional lists; installing the addon does not replace base-game maplists. To select these maps for a dedicated server, copy the corresponding `set ..._maplist` lines from `addons/quake-multiplayer/quake-maplists.cfg` into the server configuration. The game does not parse arbitrary nested config includes. DM7 is labelled bonus and omitted from the recommended six-map rotation, but remains selectable.

These are arena layouts; no native TF/CTF objectives or class resupply rooms are added. Existing generic objective fallback remains available through the game's rules, but the addon does not advertise balanced TF/CTF play. Static bot navigation can have limitations at lifts, jumps and water. Desktop traversal/preview/network checks do not establish headset frame rate, long-match balance or every possible trick jump.

Tools authored here are CC0. GPL map-derived source files are separately labelled and distributed under their supplied license.

September 2026 texture update: the shared replacement dictionary now includes a used-only Makkon WAD. Makkon records are copied without resizing, renaming or changing mip levels; their separate licence accompanies the maps. Current provenance is recorded in tools/makkon/selection.json, docs/validation/makkon-shared.json and texture-theme.json where present. Older LibreQuake-only receipts describe the pre-theme geometry/source build. See docs/MAKKON_MAP_REVIEW.md for scope and validation limits.

The current Makkon review build has one DM6 swimming acceptance failure, also reproduced by its LibreQuake-only control. DM7 passes isolated remote multiplayer testing. Do not mark the complete seven-map pack validated until DM6 passes; the packager continues to enforce traversal receipts.

Current base distribution: all seven maps now ship for DM, IG, FT and TDM, including DM7. The earlier DM6 water-test failure is resolved by isolating swimming probes from submerged teleporters; all seven pass the current traversal run in `test-results/cc/quake-traversal/`. Sources/licences are bundled under `maps/Quake/`. The old optional-pack instructions above describe the historical standalone addon workflow.
