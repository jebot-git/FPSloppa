# CS shoot-through cover and DE maps

## Current base game (2026-10-08)

All 16 installed DE maps support bounded, server-authoritative penetration: the
14 converted maps use hash-bound BSP solid trees and surface roles; retained
Aztec and Train use authored convex metadata. Legacy Nuke, Inferno and Dust2
and the four requested Dust2 variants are retired.

The converted backend follows actual solid entry/exit intervals, including
active translated brush models, and confirms each exit against live physics.
Material roles are adapted from texture names with explicit overrides and a
concrete fallback; they are not a claim of exact retail CS material parity.
Missing or mismatched metadata, malformed trees, unsupported transforms and
query budget exhaustion fail closed. Profiles ship in the game PCK; BSPs and
lightmap caches remain unchanged.

Validation: 33,159 converted-map face probes, 6,290 successful exits, 68 real
combat fixture checks, 18 malformed-data/geometry edge cases and a two-process
ENet wallbang on converted Inferno pass. The retained authored backend also
passes 67 combat and 270 map-cover checks. See
[conversion validation](../tools/de_penetration/validation.json).

## Historical reconstruction work

The following describes the earlier five-map authoring work, including three
subsequently retired maps. Current weapon behavior below remains applicable.

Implemented 2026-09-27 in the working build. All five reconstructed DE BSP29
maps embed authored collision/material volumes. Eligible CS weapons can damage
a player beyond penetrable cover; thickness, incidence angle, material and
remaining penetration power limit each shot. Other loadouts retain their
existing behavior. This is an arena adaptation, not exact GoldSrc wallbang parity.

## Weapon behavior

| Weapon | Maximum solid obstacles exited | Initial power, BSP units |
|---|---:|---:|
| AK-47 | 1 | 39 |
| M4A1 / M249 | 1 | 35 |
| Desert Eagle | 1 | 30 |
| AWP | 2 | 45 |
| Glock / USP / MP5 / P90 / shotguns / knife | 0 | 0 |

The counts follow each weapon's firing call in the
[pinned ReGameDLL_CS compatibility implementation](https://github.com/rehlds/ReGameDLL_CS/tree/4a50c42e85fd3778c2b7d24731c7d30c83bbab01/regamedll/dlls/wpn_shared),
whose count includes the terminal impact. Calibre alone does not grant wall
penetration. Power, range and material loss are informed by
[`FireBullets3`](https://github.com/rehlds/ReGameDLL_CS/blob/4a50c42e85fd3778c2b7d24731c7d30c83bbab01/regamedll/dlls/cbase.cpp#L1268).
This is reverse-engineered compatibility code, not Valve's retail CS source.

Wood retains 60% damage, glass 50%, concrete 50%, vents 45% and metal 20% per
successful exit. Concrete and metal consume power faster than wood. Power is
converted using this project's 32 BSP units/metre; existing CS damage-range
falloff uses 39.37 units/metre. Remaining range is halved after each exit.
These rules deliberately use actual reconstructed thickness, rather than the
source game's forward-step approximation. A thick wooden crate may therefore
block a rifle even though a thin wooden door can be penetrated.

The server traces, spends ammunition once, applies ordinary rewind-aware
player hits/headshots/armor, and replicates damage and bounded impacts through
the existing network path. Bullets stop at the first player; player penetration
is not included. Bots retain ordinary visibility-based enemy acquisition.

## Feasibility work and implementation

The alternatives were examined before changing runtime combat: excluding the
world collider skips subsequent walls; backwards physics rays alone cannot
reliably identify connected solids; world BSP contents provide intervals but
do not retain sufficient material data for all detail brushes and movers.
Convex authored volumes preserve those details and permit bounded queries.
An independent Python geometry probe and 30 actual Godot collision checks
passed before this approach was connected to combat.

`tools/classic_de/ballistics.py` captures the same convex brushes used by QBSP,
before their material roles become atlas textures. It writes a BVH, face roles
and stable mover IDs into the versioned `FSLP_BALLISTICS` BSPX lump, preserving
RGB lighting and other BSPX entries. No reference-map faces or textures are
embedded. Existing BSP29 geometry remains usable by readers ignoring the lump.

`deathmatch/counterstrike/penetration.gd` clips rays against those planes,
merges touching solids, charges the strongest resistance in overlaps and
requires a real exit into air. It never excludes the merged world collider.
Nuke's sliding volumes follow their current translation. Missing, invalid,
unknown or over-budget data blocks the shot normally; arbitrary downloaded
maps and runtime props do not gain penetration automatically. The supported
authoring path currently covers these five DE maps and translational brush
movers, not rotating/scaled props or destructible surfaces.

Queries run only when an eligible CS shot reaches map cover. Limits include
256 candidate brushes, 2,048 visited BVH nodes, 8,192 authored static brushes,
128 movers, 32 planes per brush and an 8 MB metadata payload. Bounds and finite
values are checked while loading. There is no frame-by-frame wall scan.

## Map changes

| Map | Geometry and cover changes |
|---|---|
| Dust2 | Staggered A stacks, angled B crates, tunnel/rear cover and long-entrance detail; fixed door leaves remain fixed. |
| Nuke | Lower service chamber and passages, four paired glass sliding assemblies, revised tanks/outside cover, radio-room timber partition, hut and industrial details. |
| Inferno | Irregular site and banana cover, street corner chamfers, timber facade panels and balcony/pit low walls. |
| Aztec | Rebuilt east/west base and court relationships, east–west bridge, connected lower canal, ramps/decks and stone ruin cover replacing generic crates. |
| Train | Five outer-yard and six inner-yard cars, revised spacing, couplers, wheelsets and loading/depot details. |

Nuke uses two combined frame/pane movers per assembly, eight moving entities
in total. Travel is 64 BSP units, speed 50 and wait 10 seconds. Touch triggers
open each pair; existing collision, snapshots and bot door interaction are
reused. Authored doors close/reset at the beginning of a DE round. Glass is
transparent and penetrable; it does not break. Navigation is baked with door
collision disabled temporarily, while the installed scene retains closed-door
collision. The runtime tests exercise real automatic activation separately.

The [original fidelity audit](DE-MAP-FIDELITY.md) records the study sources and
baseline limitations. Distances, architectural details and elevations remain
approximate. Original hinged doors, shootable breakables and ladders are not
implemented by this pass; VR stairs/ramps remain where applicable.

## Validation and reproduction

The [validation receipt](validation/de-restoration-2026-09-27.json) binds tests
and caches to current map hashes. Checks cover merged-collider geometry,
material/angle/thickness limits, consecutive walls, all implemented CS guns,
headshots, ammo accounting, unchanged non-CS blocking, real map exits, moving
glass, automatic opening/closing and DE round reset. Real ENet checks cover a
late-joining spectator, partial door transforms, reset replication, demo mover
state and an AK damaging a remote player through Nuke's radio timber.

Thirty autonomous 6v6 rounds (six per map, sides swapped after three) completed
with twelve bots retained in every sample. This also exposed and fixed an
uninitialized bot reload-input read during bomb interactions. All authored
walking routes pass in both directions; all ten sites retain grounded crosses,
wall-backed red letters and no floating guides. Native renders were inspected.
The tests are not a real-headset performance or competitive-balance benchmark.
Godot still reports shutdown resource/ObjectDB warnings in some harnesses.

```sh
python3 tools/classic_de/ballistics.py
python3 tools/classic_de/ballistics.py --fixture test-results/de-restoration/penetration-fixture.json
godot --headless --xr-mode off --path . --script tools/classic_de/test_penetration.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/cs16_penetration.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/de_cover.gd
python3 tools/classic_de/run_network.py
python3 tools/defusal/check_site_markings.py
godot --headless --xr-mode off --fixed-fps 60 --path . --script tools/defusal/bot_soak.gd -- restoration
```

Use the map README build commands for full VIS, navigation and BC7/ASTC caches.
The build tools embed penetration metadata after lighting and update objective
hashes. A hand-compiled MAP must also run the embedding step to retain this
feature. Rebuild the internal base-asset archive after changing map assets.

Release 0.19v additionally checks an authored exit against the actual collision surface before continuing a bullet. Clipped/merged BSP cover that disagrees with its brush metadata fails closed; the engine itself is unchanged.
