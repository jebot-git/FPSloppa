# Tribes assets

Local bot matches use `python3 tools/tribes/run_live.py`. They stop automatically
if neither team captures within the first 600 game seconds, including accelerated
tests. `--seconds` still caps total duration after a qualifying capture.
`--headless` skips the Vulkan spectator. Results include exact first-capture and
flag-event timestamps; `report_match.py <output-folder>` summarizes the gate
separately from pickup totals. See `docs/ST-CAPTURE-RELIABILITY.md`.

For an 8v8 Vulkan live view with recording and route telemetry:

```sh
python3 tools/tribes/run_live.py --team-size 8 --map ctf_stonehenge --seconds 1200 --navigation-metrics --record --output test-results/st-readiness/example
```

The authority reserves an additional spectator seat so joining the view does
not evict one of the sixteen bots. The title and overlay show the chosen team
size. Match snapshots include capture-readiness decisions and preparation
counters; these are planning estimates, not guarantees of a successful escape.

For a headless 8v8 routing study, use:

```sh
python3 tools/tribes/run_batch.py --output test-results/st-routing/example --snapshot /tmp/st-routing-example --seeds 13 --workers 6 --seconds 1200 --port 29500 --wall-timeout 5400
python3 tools/tribes/report_routing.py test-results/st-routing/baseline test-results/st-routing/example --output test-results/st-routing/comparison.json
godot --headless --xr-mode off --path . --script tools/tribes/export_route_layout.gd -- res://test-results/st-routing
MPLCONFIGDIR=/tmp/st-route-plot python3 tools/tribes/plot_routing.py test-results/st-routing/baseline test-results/st-routing/example --output test-results/st-routing/routes.png
```

Thirteen seeds on each map produce 26 full-authority simulations. Repeat with
the same seeds for a paired comparison. The snapshot freezes executable game
scripts and shares large unchanged assets; source and BSP hashes are retained.
Do not modify shared map assets during a study. Godot's fixed-FPS mode removes
wall-clock pacing while retaining normal 60 Hz server ticks, ordinary combat,
respawns, equipment, energy and collision. There is no spectator. The existing
600-game-second inactivity cutoffs remain active; reports distinguish those
outcomes from normal match endings and exclude crashes/timeouts.

One-second route traces and frame-level contact departures/sudden speed losses
are passive instrumentation. A departure is not necessarily a sustained flight;
the report debounces them and does not infer that every loss was a wall collision.
`progress.json` lists completed jobs; each run keeps its logs, events, source
receipt, result and diagnostic traces. Both output and snapshot directories must
be new so earlier evidence cannot be overwritten.

The numeric report uses the Python standard library. Route plotting requires
Matplotlib; collision-height contours are optional. See
`docs/ST-ROUTING-STUDY.md` for the comparison protocol and its limitations.

The personal arsenal, packs, icons, synthetic sounds and new armour plates are
original project assets. The three armour bodies now incorporate a reduced
**MEC-VAL-白狐 suit by KEIV**, under its attribution and non-commercial terms.
See `deathmatch/weapons/tribes/SOURCES.md` and `sources.json`; combined bodies
are not CC0. No retail Tribes or Blend Swap geometry is included. Candidate
assessments are in `docs/TRIBES-ARMOUR-SOURCES.md`; the separately bundled CC0
avatar sources are in `vrm/SOURCES.json`.

`model.py` builds the personal arsenal and packs through Blender MCP.
`body.py` invokes `family.py` to build the three headless, skinned VRM bodies.
`mec_suit.py` extracts the fitted garment and sleeves, rebinds them to the shared
rig, and retains suit footwear for Light/Medium. `body_shapes.py` provides the
canonical bones and loft primitives. Run `python3 tools/tribes/paint_armour.py`
first to pack the two authorised suit textures and create the plate finish.
The input VRM and its notice live in `sources/`. Builds preserve other authoring
scenes, and write only the armour scene to `refined/tribes-bodies.blend`.
`heavy_shell.py` builds the distinct Heavy cuirass, articulated shoulders,
abdominal rings, pelvis, limb shells, boots and rear service panels. Set
`BUILD_CLASSES=['heavy']` in the execution namespace to rebuild the family
preview while exporting only Heavy. Then run
`godot --headless --xr-mode off --path . --script tools/tribes/import_bodies.gd -- heavy`.
The importer reuses byte-identical shared textures, preserving other classes.
`armour.py` is an older shell
prototype, not the current full-body generator.

`paint.py` creates and paints the atlas through the local Krita MCP, keeping its
layered `refined/finish.kra` source. `icons.py` and `audio.py` create the native
SVG icons and deterministic synthetic weapon sounds. Godot import scripts in
this directory produce the compressed runtime resources. Body imports must use
`import_bodies.gd` and the VRM extension, not the plain GLB model importer. The
body importer preserves distinct suit/plate textures and generates their
mipmaps without replacing the weapon atlas.

Blender source scenes and intermediate GLB/VRM files live in `refined/`.
`mesh-report.json` and `body-report.json` record geometry counts. Runtime code
and native tests are documented in `docs/TRIBES-LOADOUT.md`.

The [Scout vehicle pass](../../docs/ST-VEHICLES.md) provides a playable Raindance flyer. `scout_model.py` runs in Blender; `scout_audio.py` and `import_scout.gd` rebuild native assets. `test_scout_network.py` runs a real server/pilot/observer lifecycle test.

### LPC / HPC transports

`transport_models.py` adapts the same CC0 hull in Blender MCP; `import_transports.gd` builds the compressed native scenes and mipmapped icons. `test_transports_network.py` runs pilot/passenger/spectator lifecycle checks for both carriers, and `transports_preview.gd` renders their occupied decks and controls in Vulkan. See [ST vehicles](../../docs/ST-VEHICLES.md) for limits and validation.


The current vehicle artwork is rebuilt by `vehicle_models.py` in Blender MCP,
with `scout_model.py`/`transport_models.py` as subset entry points. The editable
source is `vehicle-sources/vehicles.blend`. Run `vehicle_texture.py` followed by
`vehicle_texture.gd` to regenerate the original SVG/PNG hull atlas before the
Blender build, then run both native import scripts. The designs follow original
Tribes vehicle silhouettes while retaining the tested cockpit/seat/muzzle mounts.


`prop_models.py` and `prop_sources.py` rebuild the ST stations, fixed turrets,
deployables, sensors and power equipment in Blender MCP. Current editable art
is in `prop-sources/st-equipment.blend`; CC0 kit sources and their license are
retained beside it. `import_props.gd` builds the native scenes with a shared
mipmapped vehicle atlas. `prop_icons.py` and `import_icons.gd` build the matching
seven deployable icons. `props_preview.gd` and `props_live_preview.gd` provide
Vulkan model and map reviews. See [equipment design](../../docs/ST-EQUIPMENT-DESIGN.md).

The [VR inventory fixes](../../docs/ST-VR-INVENTORY.md) add `menu_icons.py` and
`import_menu_icons.gd` for 24 original menu/remote-control pictograms. Their SVG
and mipmapped native outputs live in `deathmatch/tribes/menu_icons/`.
