# Classic defusal BSP29 reconstructions

Four independently brushed CS 1.6 layout studies for FPSloppa DE, built with
original and separately licensed material artwork. These are playable approximations, not conversions
of Valve's retail maps or exact competitive replicas.

| Map ID | Recreated layout landmarks |
|---|---|
| `de_nuke_rebuilt` | T canyon, lobby/radio, ramp room, upper A/lower B, vent connection, outside and garage |
| `de_inferno_rebuilt` | Mid, banana/B, apartments/balcony, A courtyard, library and CT arch |
| `de_aztec_rebuilt` | Ruined courts, double doors, suspension bridge, lower canal, A/B |
| `de_train_rebuilt` | Outer A/inner B rail yards, freight cars, main, ivy, upper/lower halls, Z connector |

Each map includes sixteen team starts, two surface-planting zones, original MAP
and WAD sources, full VIS, lightmaps, a native cached scene and baked navigation.
The objective registry binds starts/sites to the compiled BSP SHA-256; changing
geometry requires updating the registry through the builder. All five DE maps,
including Dust2, are in `maps/de_maplist.txt` and the base-asset selection.

The Nuke, Inferno and Train plans were independently traced against the classic
[CS 1.6 overview/callout guide](https://steamcommunity.com/sharedfiles/filedetails/?id=913388004).
Aztec initially used landmark-based reconstruction and
[classic-map reference imagery](https://cstake.ru/maps/de-maps/155-karta-de_aztec-dlja-cs-16.html).
No reference image is shipped as a runtime texture. CS map names and original
layout concepts belong to their respective creators/Valve; the new brushes are
authored for this project. The material pass uses original generated plaster,
paving and ruin stone, plus unchanged Makkon/LibreQuake wood, brick and metal.
See [material sources and prompts](../DEMaterials/SOURCES.md), each map's
`texture-sources.json`, and its retained license notices.

Fidelity limits: approximate distances and elevations; simplified architecture,
materials, lighting and cover; ladders replaced with stairs/ramps where needed;
no breakable windows, rotating doors or exact CS movement. Aztec's shallow
water brush does not reproduce all original water/environment behavior. Aztec
now has a rebuilt court/bridge/canal plan informed by the later BSP survey.
These need multiplayer balance and real
VR playtesting before competitive use.

The [2026-09-27 fidelity audit](../../docs/DE-MAP-FIDELITY.md) compares all five
DE maps with classic reference BSPs, identifies cover/decoration differences,
and assesses original moving doors, breakable panels and bullet penetration.
Its read-only survey can be repeated with `tools/classic_de/audit.py`.

The subsequent [restoration and penetration pass](../../docs/CS16-PENETRATION.md)
revises cover across all maps, rebuilds Aztec's east–west bridge/canal layout,
densifies Train's inner yard and restores Nuke's four paired sliding glass
doors. Their frames and panes share eight movers; touch activation, round
reset and network positions use the existing mover system. New convex
material volumes in the `FSLP_BALLISTICS` BSPX lump support CS shoot-through
cover with real thickness limits. These maps still do not contain breakable
windows or rotating doors. Retail faces and textures were not imported.

Rebuild with the installed ericw-tools binaries:

```sh
python3 tools/classic_de/build.py --compiler-dir /path/to/ericw-tools/bin
# Optional single map: --map nuke|inferno|aztec|train
# Fast preview VIS only: --fast-vis (release assets use full VIS)
godot --headless --xr-mode off --path . --script tools/classic_de/bake.gd
# Optional single bake: -- train
godot --headless --xr-mode off --path . --script tools/de_texturing/prepare.gd
```

Validate each map using `tools/classic_de/verify.gd -- de_nuke_rebuilt` (and the
other IDs). It walks authored routes both ways with the real fighter, checks
all spawn capsules/floors and verifies navigation connectivity. Add `--views`
on a native renderer to save the authored viewpoints. Reports and compiler logs
are in `test-results/classic-de/<map-id>/`. Run
`deathmatch/tests/defusal_maps.gd` for all-map configuration, hash, site, planting
and snapshot checks. Rebuild the internal asset archive before release packaging.

The [CS 1.6 tactics study](../../docs/CS16-MAP-TACTICS-STUDY.md) adds hut and
apartment occlusion, repairs the Aztec west canal and Train upper-hall routes,
and supplies hash-bound bot lanes/holds for all five DE maps. After compiling
new geometry, run `python3 tools/classic_de/tactics.py` and the documented
tactical regression alongside the map route checks.
