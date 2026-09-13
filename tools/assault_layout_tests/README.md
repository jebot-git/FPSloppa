# Assault defaults and Tiny variants

See [the layout notes](../../maps/AssaultLayoutTests/README.md) for geometry,
reference limitations and validation. Expanded HiSlop and Frigate are now the
standard maps. The old compact layouts remain selectable as Tiny, recommended
only for 2–4 players, and are omitted from the default Assault rotation.

`layouts.py` connects service routes, moves the train switch/checkpoint and
expands horizontal coordinates. The generators default to expanded geometry;
`--tiny` selects the compact layout, and `--layout-test` is a legacy alias for
the expanded default. The installer compiles all four BSPs with full VIS,
applies original Makkon textures to expanded maps, updates the production
catalog and prepares named scene caches and navigation.

```sh
python3 tools/makkon/fetch.py
python3 tools/assault_layout_tests/build.py --compiler-dir /path/to/ericw-tools/bin --install
python3 tools/assault_layout_tests/test.py
python3 tools/frigate_concept/test_network.py
```

`--skip-build --install` reinstalls existing compiler output and reapplies the
theme idempotently. Tiny HiSlop and its provenance provide the original
LibreQuake texture donor for future compiles; the expanded map is no longer a
LibreQuake-only donor. Geometry requires ericw-tools 0.18. Installed assets are
included on the next `tools/build_base_assets.py` run.

`pickups.py` defines the UT99-reference inventory and two HiSlop roof guards.
Both generators use it before layout scaling. `update_pickups.py` updates existing
BSP point entities while verifying that geometry, textures, visibility, lighting
and BSPX data are unchanged; `cache_pickups.gd` refreshes those entities in existing
platform scene bakes. See [the matching notes](../../docs/ASSAULT-PICKUPS.md).
