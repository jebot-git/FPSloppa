## 0.4v map storage

Maps now live in external `maps/`, not inside the Godot package. Five extra LibreQuake arenas are available as an optional pack. ThreeWave is tools-only on GitHub; converted BSPs remain local for non-commercial testing/server use. See [setup and compatibility](docs/EXTERNAL-ASSETS.md).

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

Select **IMPORT BSP…** beside ARENA and choose a standalone Quake I BSP29 or BSP2 file. Imports require at least two deathmatch spawn entities and a file no larger than 25,000,000 bytes. The game saves a source copy and compiled Godot scene in its user-data `maps/` directory. Reimporting identical content selects the existing entry. Imported maps appear in the arena selector after restarting, too.

Clients automatically download the host’s current BSP when their local map checksum does not match. The host sends the original BSP, never a Godot scene or script. The client checks the size, SHA-256 and BSP structure, compiles it locally, caches it under `user://maps/`, and then joins. Cached matching content avoids downloading again.

Transfers use reliable ENet channel 5, 32 KiB chunks, a 256 KiB acknowledgement window and a 2 MiB/s aggregate host budget shared across downloading clients. The 25,000,000-byte map limit is the same byte cap as the 25 MB VRM limit. Transfers with invalid sizes, checksums or chunk order fail; 30 seconds without progress cancels the transfer and removes its partial file. Map compilation may briefly stall a client. There is no interrupted-download resume or map-cache eviction. Hosts should select maps they have permission to redistribute.

## Supported behavior

The adapter uses [jitspoe's Godot BSP importer](https://github.com/jitspoe/godot_bsp_importer), with project-specific entity templates and runtime behavior. It supports textured world and brush geometry, triangle collision, deathmatch spawns, entity lights, doors, cycling platforms, teleporters, damage triggers, and liquid contents read directly from the BSP world tree (including existing cached and TF maps). Waist immersion enables swimming; head immersion adds an underwater tint and a 12-second air indicator, followed by increasing server-controlled drowning damage. Surfacing restores air. Holding jump continuously swims upward; stair stepping is automatic. Player collision and damage hitboxes remain identical for all VRM models.

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

## Optional local AD conversions

[The AD adaptation tools](https://github.com/jebot-git/FPSloppa/releases/tag/0.5v) screen Arcane Dimensions 1.80 patch 1 maps, exclude test maps and incompatible geometry, and add current-game multiplayer entities. Converted BSPs remain local with original notices. Optional `<mode>_ad_maplist.txt` files suggest rotations without changing the default maplists. These are experimental asymmetric arenas and have not been certified for standalone headset performance.


The forty-map Arena Collection 1 and ThreeWave, TeamFortress and Arcane Dimensions conversion tools are archived exclusively with [0.5v](https://github.com/jebot-git/FPSloppa/releases/tag/0.5v). They are no longer included or maintained; see [the archive policy](docs/ARCHIVED-EXTRAS.md).

Map textures default to linear anisotropic filtering with mipmaps. **Settings → Graphics → Textures** also offers trilinear and pixelated-with-mipmaps sampling; the choice is saved in the client config. Existing cached maps are upgraded at load time, so a cache rebuild or map-format change is not required.

Map/model transfers use bounded disk-worker queues for chunk reads and writes, checksums, metadata validation and cache installation. Acknowledgements follow successful writes; join readiness still waits for verification and preparation. Server map uploads use the same approach, including disk-budget checks and maplist writes. Disconnects invalidate pending callbacks and schedule partial-file cleanup. HTTP base-asset downloads, archive verification/extraction and hostname lookup run asynchronously. Godot multiplayer dispatch, scene import/instantiation and GPU resource creation remain on the main thread; first-time scene preparation can still cause a loading hitch.

The brief filtering-switch freeze reported in live WiVRn testing has been optimized in source. Texture pixels and three retained filtering variants are prepared at asset load; changing the setting skips pixel processing and untextured/UI materials. Temporary hidden mesh instances prepare pipelines and are then removed. Existing live materials and their gameplay colour/uniform changes are preserved. Baked-light materials keep one shader and select the sampler through a uniform, including an automatic upgrade for older cached shaders.

The [filter-switch profile](docs/validation/filter-switch-profile.json) reproduced this on lqdm1 with the Vulkan Mobile renderer: repeated switches trigger draw-time pipeline compilations, and the settings path additionally reads back 26 textures despite existing mipmaps. Omitting pixel processing reduced direct settings work to about 2 ms but left roughly 78–80 ms until draw completion. The [optimization results](docs/validation/filter-switch-optimisation.json) show repeated switches around 5–7 ms on lqdm1/lqdm2 and the baked-shader fixture, with no pixel readbacks and no repeat draw-time pipeline compilations. New drivers or rendering configurations may still require first-use compilation; a new wearer check remains pending. These timings are desktop-renderer measurements on the test machine, not headset latency measurements.

## Converted-map traversal audit

The local AD, original TF and ThreeWave conversions have a repeatable physics audit: [results and compatibility limits](docs/CONVERTED_MAP_TRAVERSAL.md). Run `python3 tools/validate_converted_traversal.py` with the retained local maps, then `python3 tools/report_converted_traversal.py`. The audit covers movement/swimming, door collision, lift passengers, teleport destinations and push triggers.

Brush triangle collision now uses the same inverse entity rotation as the visible mesh. The runtime also corrects old cached brush collision, so previously cached angled doors and lifts receive the repair without requiring users to remove files. Teleport destinations apply Quake’s 27-unit upward adjustment before conversion to player feet coordinates.

FortressOne TF candidates were converted and reviewed locally; none passed base-map acceptance. See [the review](docs/FORTRESSONE_MAP_REVIEW.md) and [reproducible tools](tools/fortressone/README.md). Their BSPs stay outside the repository and default TF rotation.

## Optional original Quake deathmatch source ports

DM1–DM6 plus bonus DM7 can be compiled from the GPL source release with the shared LibreQuake/generated counterpart dictionary. Singleplayer maps and DM8 are excluded. See `tools/quake_source/README.md`. Missing named textures in all imported BSPs use the same dictionary; embedded art stays intact. See `tools/texture_replacements/README.md` for conversion and preview tools. ThreeWave and original TF conversions remain local only.

## Experimental HiSpeed Assault concept

The optional, locally generated BSP29 train map and experimental **Assault**
mode are documented in [tools/hispeed_concept/README.md](tools/hispeed_concept/README.md).
It uses LibreQuake textures, ordered objectives, paired timed attacks and three
destructible map sentries. Build output is `../Builds/HiSpeed-Concept`; it is not
installed into the production rotation. See the [playtest report](tools/hispeed_concept/PLAYTEST.md)
for collision, turret, networking and VRM lighting checks.

## HiSlop (AS)

The base package includes `as_hislop.bsp` (HiSlop), a train Assault map with
baked lighting and moving scenery. Its separate rotation is `maps/as_maplist.txt`.
See [AS.md](AS.md); texture notices and provenance ship in `maps/HiSlop/`.

## Frigate (AS)

`as_frigate.bsp` adds an independently built harbor assault: board the warship,
destroy the aft compressor, then activate the upper gun controls. It has a
submerged alternate entry, two stair routes, defensive sentry and a six-minute
playtest configuration. The source build installs it in the AS maplist; the next
base asset package includes its BSP, scene caches and navigation. Construction,
reference attribution and tests are in [Frigate notes](tools/frigate_concept/README.md);
texture provenance and notices are in `maps/Frigate/`.
