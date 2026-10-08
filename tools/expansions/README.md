# Base-game DE and ST expansions

The base map catalog now contains all 22 additional Classic ST maps and 14 retained
validated Varq DE conversions. ST has 25 maps including the previous three;
DE has 16 including Aztec and Train rebuilds. These are base assets, selected
by the normal installer and desktop/server/Android bundle paths. Source archives,
rejected DE maps and the unsuccessful Source TF conversion attempt are excluded.

```sh
python3 tools/expansions/promote.py
python3 tools/expansions/prepare.py --resume
./run.sh --headless --xr-mode off --script tools/expansions/verify.gd
./run.sh --headless --xr-mode off --script tools/expansions/runtime_art.gd
./run.sh --headless --xr-mode off --script tools/expansions/gameplay_catalog.gd
python3 tools/mipmap_imports.py
python3 tools/build_base_assets.py
```

Preparation imports each of the 41 DE/ST BSPs, checks baked face coverage and
atlas offsets/packing, prepares complete color mip chains, and saves uncompressed,
BC7 desktop and ASTC 4×4 mobile caches. All use the current BSP hash and rendering
metadata. Missing DE navigation resources are baked with native door handling.
Existing ST navigation is retained; known disconnected bot routes are documented
in `docs/ST-T2-CLASSIC.md` and are independent of this lighting/texture audit.

Color textures use linear-light mip generation, including alpha-cutout coverage.
Packed light atlases deliberately stay lossless and unmipped: downsampling their
one-luxel gutters causes cross-face bleeding. Compression preserves their bytes
and glow textures exactly. `verify.gd` reloads every codec and checks full chains,
source hashes and unchanged lighting. `runtime_art.gd` separately checks embedded
textures in native ST vehicles, equipment, interfaces and DE/Tribes weapons.
Moving vehicles and weapons use runtime lighting, not world-space static bakes.

`validation.json`, `cache_validation.json` and `runtime_art.json` record the
results. `tools/expansion_assets.py` makes bundle generation fail on stale or
missing prepared assets. Original author notices and source/donor receipts ship
under `maps/ExpansionNotices/`; conversion does not relicense their artwork.

The retired map list in `deathmatch/maps/retired.json` blocks legacy Nuke,
Inferno and Dust2 plus the Xmas, 2006, 2009 and Snow Dust2 variants. This also
prevents old files left by an existing installation from reappearing in menus.
The converted `de_varq_dust2` is the DE default. Retired development inputs are
preserved outside the installed map directory and excluded from the bundle.
