# Classic Dust2 BSP29 reconstruction

See [the map notes](../../maps/Dust2Rebuilt/README.md) for reference attribution,
build commands, test coverage and fidelity limits.

- `build.py`: authored plan volumes, brush geometry, shared DE material pass,
  full BSP29/VIS/RGB-light compilation, manifest and optional local install.
- `bake.gd`: project importer, scene cache and bot navigation.
- `verify.gd`: spawn, forward/return movement, navigation and bridge checks;
  `--views` captures the imported scene.
- `smoke.gd`: actual local practice host with bots and pickups;
  `--views` captures the running map using the normal presentation pipeline.

Plan `(u,v)` coordinates follow the orientation of the author's CS 1.6 overview;
`z` is in Quake units. The conversion to engine coordinates is documented directly
in the generator and verification script. All source assets remain editable.
