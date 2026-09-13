# Ashfall Boulevard — TITANBALL

Original sealed ruined-city payload map for FPSloppa, `tb_ashfall`. Select TITANBALL in Host, then Ashfall Boulevard. The game reads the native TB route, spawn, checkpoint, resupply and hangar-gate entities directly from the BSP. The previous procedural testing corridor is no longer used.

- 300 m winding course, nominal 26 m street with shoulder cover and a clear central robot route; buildings/ruins and solid back walls run along both sides, with ground-floor ambush passages.
- 42 cover groups: 8 brush-built wrecks, 28 irregular rubble piles and 6 broken walls, placed outside the robot collision envelope.
- Closed attacker hangar; 60-second preparation, firing slits and automatic gate opening. The 1.2 m door sits inside a 2 m wall pocket, with 0.4 m recess on either face.
- Two 13.2 m overpasses with switchback ramp towers, followed by paired 4.2 m firing positions and fortified defender base.
- Attacker groups at 0/72/172 m; defender group at 300 m; four positions per group. Six universal engineer dispensers (one at each base, two per checkpoint), no natural pickups.
- Checkpoints at 80/180 m; rear clearance triggers at 90/190 m. Fixed 10:00 active timer plus two once-only 3:00 extensions.

## Editing and rebuilding

Open `tb_ashfall.map` with `ashfall.wad` in a Quake brush editor such as TrenchBroom. Source uses Quake map planes, structural brushes for enclosure and visibility, `func_detail` for ornament/ramp geometry, and a separate `func_wall` gate. The structural grid is 64 Quake units; 32 Quake units represent one game metre. Native TB entities are plain key/value entities, so retain their fields when editing. No mesh scenery is required for the city geometry.

The reproducible authoring generator is `tools/titanball/build.py`; `route.json` is its route source. Regenerating overwrites the editable MAP, so preserve manual edits separately first. Existing local Makkon/LibreQuake archives supply the textures. Compile with ericw-tools v0.18 or a compatible local installation:

```sh
python3 tools/titanball/build.py --compiler /path/to/ericw-tools/bin
```

The tool runs QBSP, full VIS, and extra4 coloured light with one bounce and baked dirt/AO. No real-time map lights or fog are added. It verifies BSP29, the import size limit and absence of a leak file. Compiler logs are in `test-results/titanball/`; this build retains clipped-portal/detail warnings, so it is not a warning-free compile.

After geometry changes, update the map catalog SHA, regenerate importer caches and run `tools/titanball/acceptance.gd` to rebake `maps/navigation/tb_ashfall.res`. `navigation-sha256.txt` identifies the BSP used for the current navigation. Run `tools/titanball/prepare_assets.gd` to rebuild raw, BC7 and ASTC4 scene caches plus texture-dictionary aliases; do not use ASTC8. Register the new BSP SHA in `deathmatch/maps/skies/SOURCES.json` to preserve its default sky. The acceptance bake retains the connected street/ramp navigation component and excludes disconnected scenery tops; it verifies all sixteen spawns, six stations and twelve vantages remain reachable. Keep the uncompressed fallback cache and BSP for imports.

## Files and validation

`../tb_ashfall.bsp` is the playable BSP. `tb_ashfall.map` and `ashfall.wad` are the editing sources. `manifest.json`, `texture-sources.json`, and `texture-audit.json` record build hashes and original texture provenance. The embedded source miptex records are unchanged.

BSP tests check all spawn clearances, robot clearance every half metre at torso yaw −7.5°, 0° and +7.5°, both closed street edges throughout the route, hangar/slit collision and navigation to both overpasses. Separate mode and network tests cover preparation, dispensers, boarding, damage, checkpoints and results. See [TITANBALL documentation](../../docs/TITANBALL.md) and [BSP results](../../test-results/titanball/acceptance.json).

Autonomous 6v6 bot trials are documented in `docs/TITANBALL-COVERAGE-R6.md`. Human combat balance and live Quest performance remain unverified. The map is a playtest candidate, not a claim of competitive balance.

## Credits

Geometry and new map entity layout: original FPSloppa work, CC0-1.0. Industrial/Metal textures: Ben “Makkon” Hale, with palette/LUT credit to ptoing, under the included Makkon license and the project owner's previously confirmed permission. LibreQuake textures are BSD-3-Clause. Licenses and source credits are included separately; the texture collection is not collectively CC0. The BA-2 robot uses its own existing model attribution in `deathmatch/vehicles/ba2/SOURCES.md`.

The current gameplay markers define six shared resupply stations (one per base,
two around each checkpoint) and twelve tactical high-ground positions.
`python3 tools/titanball/update_markers.py` updates these markers in the BSP and
editable source while verifying that geometry, lighting and BSPX lumps are
unchanged. Run `tools/titanball/update_cache_markers.gd` afterwards to update
all three prepared scene caches without recompressing textures or rebaking light.
