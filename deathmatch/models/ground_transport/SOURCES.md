# LPMAC allied ground transport

LPMAC_military truck by **Britdawgmasterfunk**:
https://blendswap.com/blend/29498
https://blendswap.com/profile/1312781

License: CC0 1.0, as declared by the uploader.
https://creativecommons.org/publicdomain/zero/1.0/

Procured through BlendSwap remote MCP `get_asset`, `get_balance`, and
`download_asset` on 14 October 2026. File 25729, Blender 3.0x / Cycles.
The free daily allowance covered the download; zero credits spent.
Source SHA-256 and metadata: `tools/ground_transport/source/provenance.json`.

Adaptation: turret, gun, mantlet, sensor, antenna and showcase geometry removed;
high-detail hardware reduced; original colour networks baked to one 1024² atlas.
31,854 triangles, two mesh surfaces/materials (opaque hull and transparent glass).
Godot generates mesh LODs. The native hull has no turret collider. Dimensions are
approximately 3.51 m wide × 2.82 m high × 8 m long, at metre scale.

The six existing side pods carry `Entry0`–`Entry5` and `Seat0`–`Seat5` markers,
three on each side. Their positions and boarding radius are in `manifest.json`.
The matching C++ constants are generated from this manifest.

Rebuild:

```sh
blender --factory-startup -b --python tools/ground_transport/export_transport.py
python3 tools/ground_transport/generate_geometry.py
python3 tools/ground_transport/generate_geometry.py --check
```

Keep authoring sources out of release packages. The frontier packager excludes
`tools/ground_transport`; runtime assets live entirely in this directory.
