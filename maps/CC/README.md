# Chainsaw Circus arenas

These four maps are the base game's CC rotation:

| ID | Title | LibreQuake source | CC rebuild |
|---|---|---|---|
| `cc_hyperborea` | Hyperborea · Blood Court | lqdm3 | Compact temple court with dry crossings and side routes; distant eastern arena removed, horizontal court scale 87.5%. |
| `cc_psychofuge` | Psychofuge · Saw Pit | lqdm4 | Wider central lava crossing, passing lane and return ramp; a hazard remains at the perimeter. |
| `cc_ghostquarter` | Ghost Quarter · Butcher's Walk | lqdm6 | Joined upper walkways and a longer ramp connecting the lower court. |
| `cc_basement` | Boomstick Basement · Meat Grinder | lqdm7 | Direct lower-to-upper ramp and landing instead of a long stair detour. |

Each has sixteen clear, dry starts with short connected walking routes. Unused pickups and collision-free ornament entities are removed. Floor materials reuse the source map's own palette. Geometry and lighting are compiled into BSP29; scene and navigation caches accompany the maps. CC's health drain, healing, chainsaw damage, range and parry rules are unchanged.

Original sources by **ZungryWare / LibreQuake contributors**, [LibreQuake v0.09-beta](https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta). Original and adapted MAP sources are supplied in `original/` and `source/`. Retain the BSD-3-Clause COPYING, CREDITS and licence-information files. Makkon textures retain the separate included licence and original donor miptex records; no resampling or generative use is performed. The project owner's existing permission covers FPSloppa's promotional-art association.

`source/cc-used.wad` contains only used textures and animation companions. `BUILD.json` records geometry source hashes, rebuilt BSP hashes, removed entities and texture correspondence. These are distinct derivatives; original LibreQuake arenas remain in the optional LibreQuake Expansion.

Rebuild from the repository with `python3 tools/cc/build.py`, then `godot --headless --xr-mode off --path . --script res://tools/cc/bake.gd`. The builder shares the locally procured LibreQuake/Makkon sources and ericw-tools used by `tools/koth/build.py`; source locations are documented in that tool. `tools/cc/spawns.json` is the reviewed placement file. Research and test results: `docs/CC-BASE-DISTRIBUTION.md` and `docs/validation/cc-distribution.json` in the repository.

Imported maps and explicit server maplists may still run CC on other arenas. These restrictions select the base distribution, not maps owned by players or server operators.
