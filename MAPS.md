# Quake BSP arenas

Choose **ARENA** before hosting. Eight free deathmatch maps from [LibreQuake v0.09-beta](https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta) are bundled:

| ID | Arena | Deathmatch spawn points |
|---|---|---:|
| lqdm1 | Solstice | 8 |
| lqdm2 | Torture Pit | 8 |
| lqdm4 | Psychofuge | 9 |
| lqdm7 | Boomstick Basement | 12 |
| lqdm8 | Alichar Sector | 8 |
| lqdm3 | Hyperborea | 10 |
| lqdm5 | Transport Tubes | 8 |
| lqdm6 | Ghost Quarter | 9 |

**PRACTICE VS BOTS** starts a fully offline match with three bots on the selected BSP arena, using the same pistol-only inventory, pickups, damage, respawns and frag/time limits as multiplayer. No listening network socket is opened. The original Entryway map and its assets have been removed; `--debug-entryway` is no longer supported.

Bots navigate a baked navigation mesh, search for pickups, acquire visible opponents, aim with a reaction delay, and fire through the normal weapon logic. They are simple practice opponents: they do not reason about teleporter destinations, timed platform rides, or advanced Quake movement routes. Custom BSP navigation is baked asynchronously when practice starts. Bots are offline only. Launch directly with `-- --practice --map lqdm1`.

A dedicated server can select an arena with:

```bash
./run-desktop.sh --headless -- --server --map lqdm8 --port 7777
```

All eight support dedicated TDM, CTF and KOTH through the objective adaptations described in [GAMEMODES.md](GAMEMODES.md). The new maps are original LibreQuake v0.09-beta BSP/LIT files with the same BSD-3-Clause notices as the existing pack. No original id Software texture data is bundled.

## Custom maps

Select **IMPORT BSP…** beside ARENA and choose a standalone Quake I BSP29 or BSP2 file. Imports require at least two deathmatch spawn entities and a file no larger than 128,000,000 bytes. The game saves a source copy and compiled Godot scene in its user-data `maps/` directory. Reimporting identical content selects the existing entry. Imported maps appear in the arena selector after restarting, too.

Clients automatically download the host’s current BSP when their local map checksum does not match. The host sends the original BSP, never a Godot scene or script. The client checks the size, SHA-256 and BSP structure, compiles it locally, caches it under `user://maps/`, and then joins. Cached matching content avoids downloading again.

Transfers use reliable ENet channel 5, 32 KiB chunks, a 256 KiB acknowledgement window and a 2 MiB/s aggregate host budget shared across downloading clients. The 128,000,000-byte map limit is independent of the 25 MB VRM limit. Transfers with invalid sizes, checksums or chunk order fail; 30 seconds without progress cancels the transfer and removes its partial file. Map compilation may briefly stall a client. There is no interrupted-download resume or map-cache eviction. Hosts should select maps they have permission to redistribute.

## Supported behavior

The adapter uses [jitspoe's Godot BSP importer](https://github.com/jitspoe/godot_bsp_importer), with project-specific entity templates and runtime behavior. It supports textured world and brush geometry, triangle collision, deathmatch spawns, entity lights, doors, cycling platforms, teleporters, damage triggers, and BSPX liquid regions. Space jumps or swims on BSP maps; stair stepping is automatic. Player collision and damage hitboxes remain identical for all VRM models.

Quake weapon, ammunition, health and armor entities become this game's server-controlled pickups. Nail weapons use the chaingun/plasma equivalents; lightning uses the BFG. Grenade-launcher pickups become shotguns; Quake artifacts become large health pickups. Combat remains Doom-inspired.

This is a map adapter, not a Quake engine: QuakeC, monsters, custom scripted entities, trains, button/trigger chains, original baked lightmaps, and Quake-specific powerup behavior are not executed. Lighting uses ambient illumination and the nearest eight map lights on PC / four on standalone headsets. Trigger regions and BSPX liquids use bounding boxes, which approximate irregular brushes. Maps without embedded textures use the importer's fallback material; the supplied palette is LibreQuake's. General community maps may need entity adaptation. The eight supplied BSP29 maps are tested; BSP2 parsing is provided by the importer but has no bundled BSP2 fixture.

## Assets and rebuilding

`deathmatch/maps/raw/` contains original BSP files and available LIT companions; LIT lighting data is retained for future lightmap support. `cache/` contains packed Godot scenes for fast startup. `navigation/` contains prebuilt bot navigation meshes; regenerate them with `godot --headless --path . --xr-mode off --script res://tools/bake_navigation.gd` after changing map geometry. `manifest.json` records IDs, scene paths and source checksums. The `.gdignore` in `raw/` prevents a second automatic import with generic templates.

Rebuild cached scenes after importer/template changes:

```bash
godot --headless --path . --script res://deathmatch/tests/build_maps.gd
```

LibreQuake maps, embedded textures and palette are BSD-3-Clause. Original notices are preserved in `deathmatch/maps/LibreQuake-COPYING.txt`, `LibreQuake-CREDITS.txt` and `LibreQuake-README-IMPORTANT-LICENCE-INFO.txt`. No LibreQuake QuakeC or `progs.dat` is included. The BSP importer is MIT; its license is in `addons/bsp_importer/`.

Validation: `tests/maps.gd` checks all eight scenes and 72 spawn floors; `tests/map_import.gd` exercises custom compilation, cache loading, hashing and imported weapon meshes; `run_network_tests.py --bsp` runs a server and two clients with different initial map selections, teleporting and platform movement. Run `map_import.gd` with an isolated XDG_DATA_HOME because it intentionally creates a custom map entry.

`run_network_tests.py --maps` tests a host and two clients with isolated caches: automatic BSP download, checksum/cache validation, joining, pistol-only inventory and replicated VR poses. `tests/map_transfer_guards.gd` checks oversized/unsolicited transfers, invalid chunk order and malformed texture tables.
