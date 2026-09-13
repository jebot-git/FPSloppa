# Map review and Well6 fixes — 12 September 2026

Well6's floating TF spawns/flags and tower elevators are fixed in the current source. Three additional reviewed Quaddicted DM maps are installed, and the shared texture replacement path now includes a used-only Makkon WAD. No new public release or production-server update was performed.

## Well6

The map represents its flags using `w_s_key.mdl` / `w_g_key.mdl`. The importer previously required “flag” in the model filename, so it missed these goals and substituted distant spawn locations. It now recognizes owned key goals referenced by capture points. Backpacks and unrelated keys are excluded. Native TF spawn, flag and capture markers receive bounded floor placement directly from BSP contents before spawning; the loader leaves liquid/invalid placements unchanged rather than dropping through them.

The four tower elevators are tall `func_door` brushes operated by floor-level `trigger_multiple` volumes. The runtime ignored those links and instead tested proximity to the brush centre, far below the boarding surface. Direct touch-trigger links now activate their target doors. Tower elevators retain their authored speed and wait, return with passengers, and synchronize their current position for clients joining mid-journey. This is direct door-target support, not a complete QuakeC interpreter.

Verified on Godot 4.7.2 and the actual console-only custom engine (all 17 packaged maps also passed the console loading/presentation-isolation regression):

- All 16 native TF spawns and both flags start about 3 cm above solid floor.
- All four tower elevators carry a rider approximately 17.18 m over their 17.22 m travel, then return with the rider.
- Late-join position recovery finishes only the remaining elevator journey.
- The broader Well6 traversal check passes all six platform lifts, doors, spawn settling and sampled water/teleport checks with no engine errors.

[Detailed results](validation/well6.json). Reproduce with a separately obtained Well6 BSP:

```sh
python3 deathmatch/tests/run_well6_tests.py /path/to/well6.bsp
python3 tools/build_console_server.py --template Builds/ConsoleServer/FPSloppaServer.x86_64 --output Builds/Well6Server
python3 deathmatch/tests/run_well6_tests.py /path/to/well6.bsp --server Builds/Well6Server
```

Well6 and original 2Fort/ThreeWave conversions remain local test material. No original TF BSP is newly bundled by this change. Both clients and servers should update to receive the placement and elevator synchronization fixes.

## Downloads and original notices

The [Quaddicted multiplayer index](https://www.quaddicted.com/files/maps/multiplayer/) contains 3,020 ZIP entries in its main directory. This selected review covers **103 map/archive candidates**, including previous Slipseer reviews, the dedicated TF directory and adjacent CTF candidates. It is not an exhaustive archive audit. ZIP extraction and readme inspection use the system `unzip`; unapproved downloads stay in ignored local storage.

Three additional adaptations join Lasercade and Painful Memories:

| Map | Author | Suggested players |
| --- | --- | --- |
| Ancient Tomb (`dm_anctomb_slop`) | RandyG | 3–6, author guidance |
| Ancient’s Hall (`dm_anchall_slop`) | Andrew “HamsterDeath” LeGalle | 4–8, estimate |
| Battle Field (`dm_battlef_slop`) | Adam Boyle | 4–8, estimate |

Their readmes permit the relevant adaptation/free Internet distribution and are included verbatim under `maps/Community`. Geometry, collision, VIS and lighting are retained; embedded art uses separately licensed replacements. These maps are selectable for DM/TDM/IG/FT/CC and listed in `maps/community_dm_maplist.txt`. Existing default rotations are unchanged. All five community maps pass spawn/collision/navigation/pickup checks and sampled traversal. Balance still needs human multiplayer testing; Battle Field's original readme notes possible brief sticking at its bridge.

The [dedicated TF archive](https://www.quaddicted.com/files/maps/multiplayer/tf/) was checked explicitly:

| Candidate | Readme and compatibility finding |
| --- | --- |
| Amethyst (`amth1`) | Readme permits redistribution when retained. Its four-team class-specific arenas use teams 3/4 for flag play; this does not map faithfully onto current two-team TF. No explicit modified-edition grant found. Original archive retained locally. |
| DeathX | Central neutral key, movement penalty and linked goals need different rules. No explicit redistribution/adaptation grant found in its readme. |
| FastFlag | Six keys with 1/3/1 scoring and timed resupply require multi-objective TF rules. No explicit redistribution/adaptation grant found in its readme. |
| Muskrat2 | BSP only; no accompanying readme found. Further goal-logic and permission review required. |

Redistribution conditions are checked per readme; archive location alone is not treated as permission. Adjacent CTF candidates with no-modification, intact-archive-only or conflicting terms were held out. [Individual decisions and archive hashes](../tools/community_maps/review.json).

## Textures and visual review

The shared dictionary now contains **123 explicit aliases** backed by a **46-record WAD2**, **15,344,124 bytes**. The selection includes runtime material-family replacements and original Makkon records already used in maintained maps. Unused archive textures are excluded. Original names, dimensions, indexed pixels and all four mip levels remain byte-for-byte intact. No training or generative-image use occurred. Makkon's original licence and the project owner's separately confirmed permission concerning promotional art remain documented.

The theme is installed on 13 LibreQuake maps and the authored TF arenas Ironspan/Relayworks. Expanded Assault maps retain their earlier Makkon theme; Tiny variants retain their original art. Metal/industrial aliases improve related Quake and locally tested TF/ThreeWave conversions. Liquid, sky, animation, masked, light/sign and suitable gothic/organic material identities are preserved. Runtime replacement still prioritizes embedded textures; offline replacement is explicit. Makkon uses native donor dimensions consistently in both paths.

All 15 newly themed maintained BSPs retain every non-texture lump and BSPX payload. Six ThreeWave and two original TF conversions pass byte-preservation/idempotence checks. The FortressOne wrapper was also checked against Well6. Seven rebuilt GPL Quake DM source maps pass texture/mip provenance and embedded RGB lightmap checks. Their complete optional package remains gated on traversal acceptance.

**160 actual game views across 40 maps** were captured: 13 LibreQuake, 2 authored TF, 6 ThreeWave, 2 original TF, 7 Quake source, 5 community maps and 5 FortressOne conversions. These support visual review, not a claim of VR performance or balance. Local gallery: `test-results/quake-source-previews/index.html`.

[Used-record verification](validation/makkon-shared.json), [maintained BSP preservation](validation/maintained-textures.json), [Quake texture verification](validation/quake-makkon-textures.json).

Known acceptance limits: DM6 has one sampled swimming failure and Hyperborea has seven; comparison builds with original textures reproduce them. The raw 2Fort source retains seven unused DM spawn markers that fail the generic settling check, while its native TF spawn placements pass. The five earlier FortressOne conversions (Bam4, Openfire, 2mach1, 2castle1, Turtler) were rebuilt locally from pinned sources with the updated wrapper. All retain geometry/collision/lightmaps, and four pass sampled traversal. Openfire still fails its two beam-door collision probes, matching its earlier review. These candidates retain dark/repetitive fallback areas and incomplete previously measured bot routes; they are not promoted to the base maps. [Additional conversion results](validation/fortressone-makkon.json). Earlier ThreeWave CTF2M4 testing reported two lifts meeting overhead geometry; this texture pass does not certify those as fixed.

## DM7 live-server test

The rebuilt `qsrc_dm7` was deployed to an isolated current-source console server at **45.147.228.101:27777**. Production **7777** was not replaced or restarted. The map loaded with 4 spawns and 33 pickups. A cold client completed map/model downloads before spawning; four active clients then ran for 120 seconds, travelling roughly 493–594 m each, with 22–26 ms reported RTT. Server logs recorded damage, pickups, deaths and respawns. No orphan nodes were reported. Across 25 health samples with at least four clients, physics time was 6.393 ms median, 19.007 ms maximum; this is not a capacity benchmark.

The test server was stopped after all test clients left; its empty-round timer remained paused and the production process remained running. [Logs-derived results](validation/remote-dm7.json). This was automated multiplayer validation, not a human VR playthrough.
