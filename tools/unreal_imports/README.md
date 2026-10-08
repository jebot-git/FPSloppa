# UT99 map conversion attempts

Sources are the [ChaosUT KOTH index](https://unrealarchive.org/unreal-tournament/maps/chaosut/index.html)
and [Assault index](https://unrealarchive.org/unreal-tournament/maps/assault/index.html).
`catalog.json` retains the original player declarations and page URLs. KOTH
selection uses the seven KOTH-prefixed entries. AS selection requires an
explicit declared maximum capacity of at least eight: 383 of 444 entries.
Unknown player capacity is excluded. Variants remain separate entries.

`fetch.py` downloaded all 390 selected archives and verified their advertised
SHA-1 hashes. Downloads, extracted data and prototypes stay under ignored
`local/`. Original archive contents are never executed.

`package.py` reads bounded UE1 package tables, compact indices, tagged actor
properties and native UModel geometry. Format references are the primary
[SurrealEngine implementation](https://github.com/dpjudas/SurrealEngine/tree/master/SurrealEngine/Packages).
It handles pre-64 name tables in texture packages, validates export bounds,
and preserves texture paths, texel UVs, surface flags and actor properties.
`attempt.py` translates selected world meshes to compressed OBJ and structured
geometry, plus actor/objective inventories. These are review artifacts, not
installed game maps. `retry_archives.py` handles uncommon archive codecs via
7-Zip/unar through stdout without running installers or UnrealScript.
All 390 selected archives reached geometry extraction; `summary.json`
distinguishes that result from playable installation: all seven KOTH maps are
now installed; Assault remains an evaluated conversion shortlist.

## Gameplay gates

Geometry extraction does not imply working KOTH or Assault. UT lighting stores
visibility information for its lighting system, not interchangeable Quake RGB
light samples. Missing texture packages, moving brushes, FortStandard event
chains, damage/touch objectives, spawn activation and scripted actors require
explicit adapters. No fake lightmap UVs or guessed objective sequences are
installed in production. Each `attempts.json` entry retains its blockers.

KOTH imports preserve authored hill count: a single hill is fixed; multiple
hills use the current timed rotation. No implicit additional spawn hills are
created for a map marked `hill_authored=1`.

`build_koth.py` builds the seven playable KOTH adaptations. It preserves world
polygon UVs and supplied texture pixels, substitutes varied existing project
materials for missing retail packages, transforms moving brushes, converts warp
portals into ordinary teleporters, and rebuilds water/lava volumes. Light baking
uses source light positions/colours with adapted attenuation and an ambient
floor for readable interiors. Unused Quake PVS bytes are omitted; Godot uses its
own renderer and physics, while BSP collision and light samples remain intact.

TryTitan and Dungeon receive ramps over otherwise unsuitable 32-UU stairs.
Safe long drops in the imported arenas are checked with capsule sweeps and
exposed to the existing bot drop behavior. Wilderness retains its ten authored
red/blue starts; unused green/gold starts are excluded for two-team play.
Authored hill counts are 13/5/3 for Buttnutt/TryTitan/Thunderdome, and one each
for Temple/Cerebro/Dungeon/Wilderness. All 88 starts are clear and grounded;
all 372 directed spawn-to-hill routes pass the actual runtime planner.

Adaptation limits are explicit: Chaos-specific weapons become classic arena
pickups; the scripted Titan, decorative actor meshes and UnrealScript effects
are not imported. Doors use ordinary proximity activation. Warp zones become
paired teleporters rather than seamless portals. Source text notices and
material licenses are copied to `maps/UnrealImports/`. These are local playable
imports, not assertions of identical ChaosUT rendering or scripting.

`installed.json` binds each map to its source and runtime validation;
`assets.json` records lightmap/mipmap/BC7/ASTC verification. Navigation meshes
are saved from the configured runtime, including lowered lift decks, rather
than from unconfigured editor geometry. Full renders and live bot receipts
are under `test-results/koth-gallery/` and `test-results/koth-imports/`.

All seven 90-second 5v5 combat soaks completed. Five maps recorded hill
scoring in that window; Wilderness also scored during its completed
180-second follow-up. Buttnutt had active combat but no scoring in its
90-second receipt. Its route checks pass, but bot objective-play quality
remains unverified. See `live-bots.json`; process success is not counted as objective
success. The extended Buttnutt run ended with signal 15 before producing a
complete receipt and is not counted as a passed full-rotation test.

The verified render gallery contains 76 full-resolution 1920×1080 images,
with current BSP hashes and no renderer script errors. `gallery.json` records
the packaged gallery checksum.

## Assault shortlist

`as-candidates.json` ranks actual objective implementation suitability rather
than objective count. First batch: Pumpfac, Skyville, Twintower, Atlantica.
Second batch: HyperBlast, UrbanAssault. Each entry includes the original
FortStandard properties, outgoing event recipients, declared capacity and the
specific adapter work. Ordinary trigger/touch objectives map to switches;
damage objectives map to destructible targets. NPC-kill objectives, complex
scripted death chains and grouped target logic are not first-batch candidates.
The current AS two-step limit would need a bounded extension for otherwise
simple three-step maps; their objectives should not be merged or dropped.
No Assault map has been installed by this shortlist work.

## Commands

```sh
python3 tools/unreal_imports/catalog.py
python3 tools/unreal_imports/fetch.py
/tmp/st-tools-env/bin/python tools/unreal_imports/attempt.py
/tmp/st-tools-env/bin/python tools/unreal_imports/retry_archives.py
/tmp/st-tools-env/bin/python tools/unreal_imports/build_koth.py
python3 tools/unreal_imports/validate_all.py
/tmp/st-tools-env/bin/python tools/unreal_imports/install_koth.py
python3 tools/unreal_imports/prepare.py
python3 tools/unreal_imports/soak.py
python3 tools/unreal_imports/render.py buttnutt cerebro dungeon temple thunderdome trytitan wilderness
python3 tools/unreal_imports/package_gallery.py
python3 tools/unreal_imports/as_candidates.py
```

Python conversion dependencies: Pillow, NumPy, Shapely, libarchive-c; optional 7-Zip and unar/lsar.
The builder uses ericw-tools 0.18.1 from the session toolchain path.
