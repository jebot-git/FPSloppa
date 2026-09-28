# Tribes assets

Local bot matches use `python3 tools/tribes/run_live.py`. They stop automatically
if neither team captures within the first 600 game seconds, including accelerated
tests. `--seconds` still caps total duration after a qualifying capture.
`--headless` skips the Vulkan spectator. Results include exact first-capture and
flag-event timestamps; `report_match.py <output-folder>` summarizes the gate
separately from pickup totals. See `docs/ST-CAPTURE-RELIABILITY.md`.

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
