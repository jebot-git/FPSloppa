# Imported classic arenas

The local arena catalog now contains 31 imports: 22 Q30 Deathmatch Jam maps,
6 native Quake RCMD maps, and the three BSPs supplied in the home directory. The Q30 start
hub is excluded. Each arena supports DM, TDM, Instagib, InstaFreeze, Freeze Tag
and Clan Arena through the existing classic-mode rules. Default rotations are
unchanged. `maps/arena_imports_maplist.txt` lists the validated imports;
`maps/arena_imports_bot_maplist.txt` contains the subset with routes between
every ordered pair of safe starts.

Sources: [Q30 Deathmatch Jam](https://www.slipseer.com/index.php?resources/q30-deathmatch-jam.628/)
and [Spirit's map archive](https://maps.rcmd.org). Original archives and the home
BSPs are unchanged. Hashes, authors, original notices and conversion provenance
are retained in `tools/arena_imports/sources.json`, `conversions.json` and the
local `maps/ArenaImports/` folders. These additions are local assets, separate
from the previously bundled DE/ST expansion.

## Lighting and textures

All 31 maps have runtime baked-light atlases, complete color/glow mip chains,
and BC7 desktop plus ASTC4 mobile caches. Native Q30/Quake BSPs preserve their
original authored light samples, including valid RGB `.lit` data. Two native RCMD maps with mismatched external `.lit` files were rebaked.
Light atlases remain lossless and deliberately unmipped to prevent neighboring
packed faces bleeding together. Texture compression preserves their bytes.

Citadel and Garde2 retain their full-resolution source textures while obsolete
embedded lower mips are omitted to fit the loader's BSP size cap. Complete
runtime mip chains are regenerated from those full-resolution images.
The ten RCMD Quake II/III/Quetoo source adaptations were removed from the pack
on 2026-10-08 at the user’s request. Their converter sources remain archived
under the ignored `tools/arena_imports/local/retired-adaptations/` directory;
their BSPs, caches, navigation and renders are excluded from distribution.

`tools/arena_imports/validation.json` binds each BSP and both compressed caches
to SHA-256, counts baked faces and full-mip texture slots, and records spawn and
bot-route results. `test-results/arena-imports/` contains detailed per-map
preparation, physics and pathfinding receipts. Reproduce using:

```
python3 tools/arena_imports/prepare.py --resume
python3 tools/arena_imports/validate.py
python3 tools/arena_imports/summarize.py
python3 tools/arena_imports/render.py
```

## Gameplay validation and limits

Spawn capsules are checked against actual runtime collisions, grounded floors
and hazardous volumes. Unsafe starts are removed where a nearby correction is
not available. An inactive single-player monster teleport was removed from
Violacea. These entity edits preserve every
geometry lump and original lighting sample.

All ordered spawn pairs and pickups are queried through the real bot planner,
including its bounded jump and lift/teleport links. Many imports still have
partial bot connectivity; they remain available for human matches and are
excluded from the fully connected bot map list. Complete spawn connectivity
does not imply every pickup is reachable. Per-map coverage remains explicit in
the receipt. A finer navigation bake did not improve Junction's disconnected
routes and was reverted.

All non-native RCMD source adaptations are excluded. Earlier staging failures included: Spirit2DM5 exceeds the compiler's
128-face brush limit; Spirit3DM1, Spirit3T2, Spirit3T3, Spirit3T3A and
Spirit3CTFDuel1 require curved-patch/brush-primitive conversion. Their geometry
was not silently dropped. The Doom WADs and other non-BSP game formats from the
archive require separate loaders/converters. `rcmd-attempts.json` retains the
actual compiler failures and unsupported-format reasons.

The supplied local BSPs appear as Hektik, Toxicity and The Campgrounds. Hektik
has a fully connected spawn network; Toxicity and The Campgrounds currently
have partial bot-route coverage.

## Render gallery

`test-results/arena-gallery/index.html` provides full-HD overviews and up to six
spawn views per map. `python3 tools/arena_imports/package.py` verifies every
render against the current BSP hash and produces
`../Builds/FPSloppa-0.21v-Classic-Arena-Renders.zip`. The gallery shows route and
pickup coverage beside each arena. Detailed lighting and mipmap receipts stay
separate from the images so the visual review and asset checks can both be
inspected.


The current gallery and ZIP are regenerated from the 31 retained map receipts.
