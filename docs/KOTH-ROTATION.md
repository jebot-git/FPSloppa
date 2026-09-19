# Rotating KOTH — 19 September 2026

KOTH moves its active hill every **30 seconds**, cycling through three authored positions on each bundled map. The timer starts when the round starts and continues while the hill is empty or contested. It pauses during intermission. Ownership and fractional scoring credit reset on relocation; team scores remain. A long simulation step is split at relocation boundaries so occupants of the old site cannot keep earning points after it moves.

The floating label above the active ring shows the hill number and seconds until the next move. The HUD also shows the countdown. The server replicates all positions, the active index and time remaining; late joiners receive the current site. Older demo snapshots remain readable. Matching client/server protocol is `fpsloppa-39-rotating-koth`.

## Maps and bake

All four KOTH derivatives retain their original main hold space and gain two level decks with four shallow entry ramps. The scoring radius remains 3 m. Pickups and starts inside the new scoring areas are removed. The original Alichar marker moves 0.75 m within its existing deck to keep the complete circle clear of nearby structure.

| Map | Rotation |
|---|---|
| Solstice Crown | Raised courtyard → outer court → opposite courtyard approach |
| Torture Crucible | Lower dais → ground-level chamber → upper gallery |
| Hyperborea Tribunal | Temple tribunal → west court → east court |
| Alichar Overload | Upper control deck → west lower gallery → east lower gallery |

The build uses ericw-tools 0.18.1: QBSP, visibility, and `light -extra4 -bspxlit -bounce 1` with low ambient occlusion. Hyperborea uses conservative `vis -fast`; the Godot importer does not consume Quake PVS data. Lighting uses `-novisapprox` and complete ray tracing, independent of that table. Existing textures and their licenses remain unchanged. Scene caches, prepared color mipmaps, BC7/ASTC variants and navigation meshes are rebuilt from the resulting BSPs. `maps/KOTH/ROTATION.json` records coordinates, hashes and exact commands.

For imported maps, repeated `info_koth_control` entities define the route, ordered by zero-based `hill_index`. Their origins use the existing 0.70 m entity-to-floor offset. Authors should supply at least three distinct clear, connected sites. Older maps fall back to separated spawn positions; two-start maps also search for a nearby clear third floor.

## Round-end sound

Every match end plays `deathmatch/audio/round_gong.wav`, an original 5.5-second procedural bronze gong, via the effects bus. It follows effects volume and is independent of announcer speech. A reliable authoritative event plays it once; repeated round-end calls and snapshots do not replay it. Map-epoch checks discard stale events. No third-party recordings were used; the sound and deterministic generator are CC0.

## Reproduction

```sh
python tools/koth/rotation_build.py --compiler /path/to/ericw-tools/bin
godot --headless --xr-mode off --path . --script res://tools/koth/bake.gd
godot --headless --xr-mode off --fixed-fps 60 --path . --script res://tools/koth/validate.gd
godot --headless --xr-mode off --path . --script res://tools/koth/rules.gd
python tools/koth/network.py
python deathmatch/tests/run_bot_soak.py --label koth-rotation --case koth_solstice --case koth_torture --case koth_hyperborea --case koth_alichar --seconds 180
godot --path . --xr-mode off --script res://tools/koth/views.gd
```

The geometry checks cover every team spawn's path to every hill, paths between hills, sixteen floor samples around each scoring circle, box-player clearance, supplies and site separation. Network checks use a dedicated server, an observer and a late joiner. Bot tests use eight ordinary combat bots for two full rotation cycles per map. Render checks inspect the actual floating countdowns and gong playback. Final results are in `maps/KOTH/VALIDATION.md` and `test-results/koth-rotation/`.
