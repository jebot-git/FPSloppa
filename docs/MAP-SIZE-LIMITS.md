# Map extent limits: estimate and importer test

19 September 2026. For an ordinary single world BSP at the project's current scale, the largest horizontal geometry envelope accepted by the importer is **625 km × 625 km = 390,625 km²**, using modern **BSP2**. This is an import-coordinate ceiling, not a supported playable-world size or a performance guarantee.

Area here means the horizontal bounding rectangle, not the sum of floors in a multi-storey level. A sparse level may occupy only a small fraction of its rectangle.

## Derivation

`deathmatch/maps/loader.gd` accepts finite vertex coordinates with absolute value at most **10,000,000 BSP units**. Its scale is **1/32 metre per unit**. An origin-centred world can therefore span:

```
(10,000,000 - (-10,000,000)) / 32 = 625,000 metres per horizontal axis
625,000² / 1,000,000 = 390,625 square kilometres
```

BSP2 stores vertex coordinates and node/leaf bounds as floating-point values; the project's validation limit is much smaller than the numerical range of those values. BSP29 also stores floating-point vertices, but its correctly represented node/leaf bounds use signed 16-bit coordinates: -32,768 through 32,767. At this game's scale that bounding range spans **2,047.96875 m per axis**, approximately **4.194176 km²**. BSP29 files with incorrect/saturated bounds may pass this importer; that does not make them properly representable classic maps.

These are bounds on raw world geometry. Entity origins are not subject to the same coordinate validation, so translated inline brush models or other entity placement can put runtime objects outside the raw-vertex envelope. The 625 km figure is consequently not a comprehensive cap on every possible runtime object placement.

## Executed test

`tools/map_limits/generate.py` creates small, independent, six-face rooms in BSP29 and modern BSP2. No existing map, server maplist, or importer policy is changed. All BSP2 rooms have identical topology and **2,184 bytes**, isolating extent from complexity. The Godot probe calls the actual loader, measures imported mesh bounds, loads the BSP contents tree, and raycasts the floor at the centre and 2 m from a corner.

**37 assertions pass** on Godot 4.7.2, including accepted extents, imported bounds, empty interior contents, twelve floor raycasts, and rejection immediately beyond the vertex limit.

| Fixture | Side length | Footprint | Actual importer result | Float32 spacing at positive extent |
|---|---:|---:|---|---:|
| BSP29 signed-bound range | 2.04796875 km | 4.194176 km² | Loaded; both floor queries hit | 0.061 mm |
| BSP2 ±32,768 units | 2.048 km | 4.194304 km² | Loaded; both floor queries hit | 0.122 mm |
| BSP2 ±131,072 units | 8.192 km | 67.108864 km² | Loaded; both floor queries hit | 0.488 mm |
| BSP2 ±1,048,576 units | 65.536 km | 4,294.967296 km² | Loaded; both floor queries hit | 3.906 mm |
| BSP2 ±8,388,608 units | 524.288 km | 274,877.906944 km² | Loaded; both floor queries hit | 31.25 mm |
| BSP2 ±10,000,000 units | 625 km | 390,625 km² | Loaded; both floor queries hit | 31.25 mm |
| BSP2 ±10,000,001 units | 625.0000625 km | 390,625.078125 km² | Rejected: invalid vertex coordinate | — |

At the maximum accepted extent, adding either **1 mm, 2 mm, or 1 cm** to a coordinate produces **no position change** in the current Vector3 representation. A simple, flat floor raycast succeeding is not evidence of reliable movement, hit detection, small collision features or rendering at those coordinates. In particular, the emissive-light shader's 2 mm world-space surface bias cannot be represented on an outward-facing wall at that distance.

The legacy **2PSB** signature passes the wrapper's format check but is explicitly rejected by `BSPReader.read_bsp`. It is excluded from the supported-size estimate. Modern BSP2 uses the `BSP2` signature, integer value 844124994.

## Practical interpretation

Godot's official guidance gives an origin-centred **8,192 × 8,192 m** footprint (about **67.1 km²**) as a first-person, single-precision reference range. This is an engine precision guideline, **not a validated FPSloppa map-content budget**. Dense geometry, collisions, visibility, navigation and lightmaps impose separate limits. [Godot large-world coordinate guidance](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)

Current import policy additionally caps the BSP at **25,000,000 bytes**, up to **262,144 records per checked geometry lump**, **4,096 brush models**, **2,048 textures**, and **32 megapixels of embedded texture bases**. Consequently, no honest maximum for a *detailed playable* map can be expressed as an area alone. An empty giant room fits where a much smaller detailed city may exceed these limits.

This test does not run a light bake, navmesh bake, graphical frame benchmark, full match or headset session. Loading times from these tiny files should not be extrapolated to full-sized maps. Larger practical worlds would need a separate assessment of origin shifting, streaming/partitioning, network coordinates, and custom shader precision.

## Reproduce

```sh
python3 tools/map_limits/generate.py
godot --headless --xr-mode off --path . \
  --script res://tools/map_limits/probe.gd
```

Raw results: [map-size-limits.json](validation/map-size-limits.json). Generated fixtures and the original probe output are in `test-results/map-limits/`.

Format references: [id Software's BSP29 definitions](https://github.com/id-Software/Quake/blob/master/WinQuake/bspfile.h), the vendored `addons/bsp_importer/bsp_reader.gd` record layouts and version handling, and `deathmatch/maps/contents.gd` for BSP2 float-bound record sizes.
