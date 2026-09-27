# Dust2 — classic layout reconstruction

`de_dust2_rebuilt` is a playable, independently brushed study of the CS 1.6
layout for FPSloppa. It is an approximation, not a conversion of the retail
GoldSrc BSP or a claim of exact competitive dimensions.

The installed map is `maps/de_dust2_rebuilt.bsp`. Its source copy, editable
Quake `.map`, embedded-texture `dust2.wad`, and build manifest are in this
folder. The map catalog calls it **Dust2 | Classic layout reconstruction**.
Select it for local practice, or add `de_dust2_rebuilt` to a personal DM/TDM/IG/FT/IF
maplist. Existing rotations have not been changed. It is also the fixed map for DE, included in the base-asset selection for future builds. It has not been deployed to a live server.

## Layout and presentation

- A and B sites, T spawn, CT spawn beneath short A, central slope and mid doors.
- Long doors, long A, its raised approach and the recessed pit with an exit ramp.
- Raised catwalk, short stairs and a solid bridge above the CT underpass.
- Upper/lower tunnels with a half-turn staircase, B doors and a raised B window.
- Fixed open wooden gate leaves, semicircular brush arches, crates, a faceted
  rock face, sandstone courses and original painted A/B markers.
- 21 deathmatch spawns and 18 Quake-style pickups, translated by FPSloppa's
  existing weapon-set rules. Weapon respawns inherit the project's normal
  mode policy; no map-specific timer override is embedded.
- BSP29 with full visibility compilation, embedded WAD textures and BSPX
  RGB lighting. A cached Godot scene and pre-baked bot navigation are installed.
  All architectural collision is native BSP brush geometry; no external models
  or runtime texture downloads are required. The project adds a desert sky.

[DE — Bomb Defusal](../../docs/BOMB-DEFUSAL.md) adds team starts, single-life rounds, purchases and surface planting throughout the authored A/B courts. The controller supplies these rules; the BSP remains compatible with the deathmatch-family modes.

## Reference and authorship

Layout reference: Dave Johnston's [The Making Of: Dust 2](https://www.johnsto.co.uk/design/making-dust2/),
particularly his published CS 1.6 overview. Credit for the original Dust2 design
belongs to Dave Johnston and Counter-Strike's creators. The reference image is
not included in this pack. No original Valve BSP, decompiled brushes, retail
textures, logos, sounds or models were used as build inputs.

Brush coordinates and source tooling were authored for this reconstruction.
The material pass uses original generated plaster/paving and unchanged licensed
Makkon/LibreQuake wood, stone and metal. See [material sources and prompts](../DEMaterials/SOURCES.md)
and the adjacent `texture-sources.json` and license notices.
Textures use FPSloppa's existing Quake palette. Tools
reuse the repository's `Arena`, convex polygon and WAD/miptex writers. The
compiler is [ericw-tools 0.18.1](https://github.com/ericwa/ericw-tools/releases/tag/v0.18.1).

## Rebuild and validate

From the repository root, with Python 3, numpy, Pillow, Godot and ericw-tools:

```sh
python3 tools/dust2_rebuild/build.py --compiler-dir /path/to/ericw-tools/bin --install
godot --headless --xr-mode off --path . --script tools/dust2_rebuild/bake.gd
godot --headless --xr-mode off --path . --script tools/de_texturing/prepare.gd -- de_dust2_rebuilt
godot --headless --xr-mode off --path . --script tools/dust2_rebuild/verify.gd
godot --headless --xr-mode off --path . --script tools/dust2_rebuild/smoke.gd
```

`--fast-vis` is available for iteration; the delivered BSP uses full VIS.
The MAP/WAD can also be edited in a Quake map editor and compiled manually with
`qbsp`, `vis`, and `light -extra -bspxlit`. Re-run the Godot bake after changing
the BSP. `--install` updates only this map's catalog record and installed BSP.

Visual captures of the fixture or an actual practice match:

```sh
godot --rendering-method mobile --xr-mode off --path . --script tools/dust2_rebuild/verify.gd -- --views
godot --rendering-method mobile --xr-mode off --path . --script tools/dust2_rebuild/smoke.gd -- --views
```

The traversal audit uses FPSloppa's real CharacterBody movement and triangle
collision, forwards and backwards through nine routes. It also checks every
spawn capsule/floor, nine navigation connections and the short-A bridge deck.
Engine time scale accelerates a fixed 60 Hz simulation; it does not teleport
between route waypoints. Actual route results are in `validation.json`;
compiler/test logs and full screenshots are under `test-results/dust2/`.

## Limitations

Room footprints and much of the architecture are simplified. Scale is estimated
from the published overview (six Quake units per plan unit; 32 units per engine
metre), not surveyed from the original BSP. Angled corners, trim, crate positions,
wall heights, exposure timings and precise sniper sightlines need comparison
and human playtesting before this can be called a faithful recreation. The B
window is an optional raised jump route, outside the nine audited walking routes.
Local import, physics, navigation and a four-player practice session were tested;
multiplayer balance, real-headset comfort and standalone VR performance are not
established by those checks.
