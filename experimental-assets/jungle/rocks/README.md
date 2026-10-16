# Sparse rock cover — Jungle Frontier

Source models/textures: rubberduck, **CC0-1.0**:

- [more handpainted rocks](https://opengameart.org/content/more-handpainted-rocks)
- [handpainted style rocks](https://opengameart.org/content/handpainted-style-rocks)

Original archive SHA256 values and per-model geometry are retained in `source.json`. Ten large rock variants (five from each pack) and four loose-stone variants are used. Original render geometry, UVs and handpainted colour textures are retained. Authored low-poly collision meshes supply the large-rock convex hulls and CPU navigation faces. Normal/specular maps are omitted to match the existing baked-light environment pipeline.

`albedo.png` is a shared mipmapped VRAM-compressed (desktop S3TC / Android ETC2) 2048×1536 atlas with 504px texture cells and gutters. Each mesh has one shared material/surface and offline meshoptimizer LODs generated through Godot's ImporterMesh. Base meshes range from 71–440 triangles; far levels range from 4–12 triangles for large rocks, 15–59 for loose stones. The shared material uses the existing world irradiance/day/night/weather and vehicle-headlight shader. No realtime rock shadow pass or additional light is added.

`layout.json` contains 120 deterministic formations / 225 meshes over the 8 km² map: rocky ridges, foothills, verges, riverbanks and seven isolated channel rocks. Cover rocks range from crouch-height pieces to large outcrops; loose stone patches are decorative. River rocks are anchored to the solid bed and protrude at least 0.5m above the surface, with a conservative radius below 4m. No continuous rock dam is created.

Placement clearance uses full conservative footprint radii: site pads plus 22m, roads plus shoulders and 7m, map boundaries, existing tree trunks and neighbouring rocks. Authored capture circles, structures, spawns, vehicle staging and crossings remain inside the excluded site/road footprints.

Rendering uses static 64m spatial MultiMesh batches with engine frustum culling, screen-space mesh LOD (`lod_bias=0.65`) and a 700m distance limit. The 202 batches contain only immutable transforms. No script runs per frame for the rocks. Physics uses 215 convex colliders grouped into spatial bodies; their lifetime is independent of visual culling and streamed terrain residency. The same hull faces feed walking navigation, including standalone C++ server cooking. Ten small loose-stone patches have no collider.

## Rebuild

Download the two linked ZIPs outside the project as `more.zip` and `style.zip`, then:

```sh
uv run --with pillow python tools/rock_cover/prepare.py --sources /path/to/downloads
Godot --headless --xr-mode off --path . --editor --import
Godot --headless --xr-mode off --path . --script tools/rock_cover/bake.gd
Godot --headless --xr-mode off --path . --script tools/rock_cover/validate.gd
```

The terrain/navigation source fingerprints include the layout and geometry, preventing reuse of a server world/navigation cache with obsolete cover. Re-cook the standalone world after changing placements. The offline Python OBJ reader does not evaluate materials, external paths or source scripts. Source packages and authoring tools are not runtime dependencies.
