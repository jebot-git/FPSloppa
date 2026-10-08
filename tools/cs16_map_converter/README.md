# CS 1.6 → FPSloppa DE converter

Convert a locally supplied **GoldSrc BSP30** map and its **WAD3** textures into
a self-contained **BSP29** for FPSloppa's Bomb Defusal mode. Python 3.10+ is the
only conversion dependency. Linux and Windows use the same scripts.

**Requires FPSloppa 0.20v or later.** The 0.19v binaries do not understand
the embedded DE layouts or per-texture palettes. Use matching clients and
servers; 0.20v uses protocol `fpsloppa-68-st-native-main`.

## Convert and validate

From the FPSloppa project directory:

```sh
python3 tools/cs16_map_converter/convert.py /path/to/cstrike/maps/de_example.bsp \
  --wad-dir /path/to/cstrike --wad-dir /path/to/valve \
  --output converted-maps --validate
```

In the standalone tool ZIP, use `python3 convert.py` (Windows: `py -3 convert.py`).
Pass `--project /path/to/updated/FPSloppa` for validation, and `--godot /path/to/godot`
if Godot is not on PATH. Conversion itself works without Godot; omit `--validate`
to produce an explicitly **unvalidated** output and report. A validation failure
returns a nonzero exit code and leaves diagnostic files for correction.

Each input produces:

- `de_example_fps.bsp`: geometry, textures, coloured lighting and DE objectives.
- `de_example_fps.conversion.json`: hashes, texture/WAD provenance, entity
  adaptations, spawn/site coordinates and limitations.
- With `--validate`, validation and engine logs alongside the BSP.

Several BSP paths can be passed before the options for batch conversion. WADs
can also be supplied individually with repeated `--wad FILE`. Files are searched
in the order supplied; directory entries are sorted, and first matching texture
names win. Duplicate names are reported. If a supplied texture's dimensions
differ, its mip levels are resampled to the compiled dimensions to retain the
map's UV scale; this is reported explicitly. Editor paths embedded in a BSP are
never opened automatically. Missing textures fail conversion with their names.
Unused `-1` texture-table slots receive invisible placeholders without changing
geometry or texture indices. Missing slots referenced by actual faces still fail.
Repeated editor `mapversion` metadata uses its last value; conflicting gameplay
keys remain rejected.

Original maps are never overwritten; differing existing outputs are rejected.
Use another output directory after changing conversion options.

## Missing WAD replacement routine

When the WADs are unavailable, explicitly opt into original procedural materials:

```sh
python3 tools/cs16_map_converter/convert.py ~/Downloads/de_prodigy32.bsp \
  --replace-missing --output converted-maps --validate
```

Names select concrete, metal, panels, tiled floors, rock, crates, doors, computer
screens, lights, glass, grates, hazard stripes or signs. Texture dimensions and
UVs remain unchanged; four mips and masked transparency are generated. Each
substitution is recorded as `generated:CATEGORY`. Embedded textures and supplied
WAD entries always take priority. No missing art is downloaded automatically.
These materials approximate function and setting; they do not reproduce the
missing artwork, lettering or original signs. `--strict` rejects replacements.

Override name-based guesses with `--texture-rules rules.json` alongside
`--replace-missing`. For example:

```json
{"grid2": "concrete", "lab1_comp3a": "screen", "crate07": "wood"}
```

Categories: `concrete`, `metal`, `panel`, `tile`, `brick`, `rock`, `wood`, `door`,
`screen`, `light`, `glass`, `grate`, `hazard`, `sign`, `black`, `sky`, `utility`.
Rules apply only to missing textures, not supplied art.

## Bomb-site labels and exceptional maps

```sh
python3 tools/cs16_map_converter/convert.py de_example.bsp --inspect > inspection.json
```

Inspection lists indexed entities and WAD basenames. The default requires two
sites, assigning A then B in entity order. If a map uses more than two trigger
entities, touching brush boxes are grouped into connected sites; exactly two
groups must result. Each component remains a separate planting volume, so gaps
in the overall bounding box do not become plantable. **Check
these against the map's painted labels.** Override the assignment with `--sites`:

```json
{
  "A": {"entity": 37},
  "B": {"entity": 42, "point": [512, -128, 0]}
}
```

For a site assembled from multiple brushes, use `"entities": [85, 88, 89]`
instead of `"entity": 85`. Selections must be distinct.

Coordinates are original GoldSrc X/Y/Z units, not Godot metres. `point` supplies
an accessible floor location when the site's centre is obstructed. Bounds come
from the compiled trigger brush. `min` and `max` can override them; both are
required for point-style `info_bomb_target` entities. Maps that cannot be grouped into exactly two
sites need explicit selections; one-site/hostage/escape modes are not
automatically reinterpreted as two-site DE. A map with disconnected routes or
blocked spawns must be corrected before deployment.

## Use in the game

Import the output BSP through the updated game's map importer, or copy it into
the installation's `maps/` directory. It appears in DE hosting and voting because
of validated embedded objectives, even after hash-based renaming. No registry
edit, WAD installation or JSON sidecar is needed on clients. The existing map
download/upload system transfers the single BSP and verifies its SHA256.

Example server configuration after copying the BSP into `maps/`:

```cfg
set sv_gametype "de"
map de_example_fps
set de_maplist "de_example_fps"
```

Navigation is generated using the game's normal bot agent settings. Sliding
doors are opened only during geometry collection for navigation, then retain
their live collision and round-reset behaviour. No imported executable scenes
or native libraries are distributed with a converted map.

## Preserved and adapted

The converter retains compiled world/brush geometry, UVs, planes, BSP trees,
visibility and collision hull data. Texture dimensions, all four indexed mip
levels and each texture's 256-colour palette are preserved. WAD textures are
embedded. GoldSrc RGB lighting is stored in `RGBLIGHTING`, with face offsets
converted from byte offsets to sample offsets. `FSL_PALETTES` carries colour
palettes; `FSL_DE` carries bounded, versioned JSON objectives. Runtime textures
use the engine's mipmap pipeline, masked index 255 stays transparent, and high
GoldSrc palette indices do not become Quake fullbright colours.

T and CT spawns are separated, projected onto supporting floors and retain
individual facing directions. Site trigger boxes and accessible floor points
become DE planting bounds and bot goals. Goal selection avoids solid consoles
and cover inside a site's trigger. Existing buying, bomb interactions,
rounds and CS equipment rules apply. Buying zones follow FPSloppa's preparation
rules rather than retail trigger timing.

Sliding doors and basic trigger/button chains use native mover logic. Use-only
doors become proximity doors unless targeted. **Rotating doors, breakables and
other unsupported solid brush entities become static cover.** Ladders, external
MDL/sprite decorations, non-solid brush effects, sound entities and unsupported
scripts are reported and omitted. GoldSrc blend modes and external skybox images
are not reproduced. Animated textures and lighting use static frames/styles.
The conversion report lists these caveats; `--strict` rejects behavioural
fallbacks. Geometry conversion is not a claim of complete GoldSrc entity parity.

The final BSP must fit FPSloppa's **25 MB** map-transfer limit and texture budgets.
Collision follows FPSloppa's imported surfaces; GoldSrc clip-only hull barriers
are not reconstructed as extra invisible geometry. Review maps that rely on them.
Retail geometry, textures and other assets are not supplied with this tool;
their original licences and distribution permissions still apply.

## Validation and development

`--validate` checks the actual Godot importer, standing clearance at every spawn
and site, supporting floors, lightmap atlas errors, mipmaps, and a bot navigation
route from every team spawn to both sites. It does not simulate a complete match
or guarantee advanced ladder/vent tactics. Test converted maps in gameplay too.

The regression fixture is an independently authored room, compiled with ericw
tools and encoded as BSP30, with embedded/external textures, coloured lighting,
masked geometry, two sites, separate team spawns and a sliding door. The user-supplied `de_prodigy32.bsp` additionally exercises 32 spawns, four
bomb brushes grouped into two sites, blocked site-centre avoidance, 214 missing
textures, real server/client transfer and Vulkan rendering. The map is not
bundled with the tool. Its separate regression suite requires the local source
and a validated output:

```sh
python3 tools/cs16_map_converter/test_prodigy.py ~/Downloads/de_prodigy32.bsp \
  converted-maps/de_prodigy32_fps.bsp
```

```sh
python3 tools/cs16_map_converter/make_fixture.py \
  --output test-results/cs16-map-converter/fixture --compiler-dir /path/to/ericw/bin
python3 tools/cs16_map_converter/test.py
python3 tools/cs16_map_converter/run_network.py /path/to/converted-fixture.bsp
```

The supplied `de_santorini.bsp` and `de_santorini.wad` exercise duplicate editor
keys, WAD art preservation, resolution mismatches and float32 light extents.
75 of 79 textures come from the WAD; `aaatrigger`, `clip`, `grid2` and `null` use
the explicit replacement option. All 36 spawns route to both sites. External
sprites, decals and the original skybox are still separate dependencies and are
not recreated from the WAD.

```sh
python3 tools/cs16_map_converter/convert.py ~/Downloads/de_santorini.bsp \
  --wad ~/Downloads/de_santorini.wad --replace-missing \
  --output converted-maps --validate
python3 tools/cs16_map_converter/test_santorini.py ~/Downloads/de_santorini.bsp \
  ~/Downloads/de_santorini.wad converted-maps/de_santorini_fps.bsp
```

Format references: [Valve's GoldSrc BSP structures](https://github.com/ValveSoftware/halflife/blob/master/utils/common/bsplib.h),
[CS bomb-target entities](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/dlls/triggers.cpp),
and [GoldSrc door behaviour](https://github.com/ValveSoftware/halflife/blob/master/dlls/doors.cpp).
The converter is independently implemented; reference source is not bundled.
