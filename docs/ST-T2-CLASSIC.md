# Tribes 2 Classic maps and vehicles

The PlayT2 Classic pack is the first additional ST pack. Its 24 entries include
Stonehenge and Raindance, which retain their existing ST implementations. The
other 22 have new `ctf_t2_*` IDs. Katabatic remains available separately, bringing
the base-game ST rotation to 25 maps. All entries are bundled, ST-only, and
enabled by the release-feature gate.

## Map coverage

Acid Rain, Blastside, Broadside, Confusco, Dangerous Crossing, Desert of Death,
Gorgon, Hillside, IceRidge, LakeFront, Magmatic, Ramparts, Rollercoaster, Sandstorm,
Scarabrae, Shock Ridge, SnowBlind, Starfallen, Subzero, Surreal, Titan, WhiteDwarf.

The source catalog is [PlayT2 maps](https://playt2.com/maps). Mission, terrain and
interior inputs come from [exogen/t2-mapper](https://github.com/exogen/t2-mapper/tree/abe5198e5020554fe1f1620231c188d48f00f045),
pinned to `abe5198e5020554fe1f1620231c188d48f00f045`. `tools/t2_classic/sources.json`
records every input path, SHA-256 and size. The source receipt retains the original mission identities and archive
provenance; derived map geometry is not claimed as original CC0 work. The converter reads mission fields without
executing TorqueScript and uses that repository's DIF reader.

The reconstruction preserves metre scale, terrain heights and holes, rotated
and scaled interior collision hulls, flag locations, CTF equipment and water/lava
volumes. Terrain is sampled more densely around bases and source holes. Licensed
materials already used by this project replace original T2 textures. Main
interiors use the source convex hulls; this does not reproduce render-only
interior details. Decorative DTS trees/rocks, forcefields, mission scripting,
source-specific power circuits and original sky artwork are not reproduced.
Stations without a source generator use explicit self-powered circuits. Neutral
stations serve either team. These are playable ST adaptations, not exact T2 ports.

Spawn points are distributed across source spawn areas and checked against the
compiled BSP. Steep or obstructed candidates are moved to capsule-clear floors;
when the immediate area is unusable, another safe part of that team's spawn area
is used. `placements.json` records source-space corrections and replays them on
rebuild. Playable bounds expand where source structures extend beyond the T2
mission rectangle. Vehicle terminals are offset from the physical spawning pad.

## Vehicles and controls

Wildcat, Shrike, Havoc, Beowulf, Thundersword and Jericho are additions to Scout, LPC and HPC. Their native models
and icons are independently constructed geometry in `tools/t2_vehicles/models.gd`.
Their roles follow the [PlayT2 vehicle guide](https://playt2.com/guides); movement
and balance are adaptations to ST, not a copy of Torque physics.

| Vehicle | Energy | Hull HP | Speed | Passengers | Pilot weapon |
| --- | ---: | ---: | ---: | ---: | --- |
| Wildcat gravcycle | 450 | 100 | 70 m/s | 0 | None |
| Shrike fighter | 750 | 150 | 75 m/s | 0 | Direct-hit blaster |
| Havoc transport | 1000 | 400 | 35 m/s | 5 | None |

Use the existing vehicle terminal wheel to buy. Use boards/leaves; Jump ejects.
Movement keys/stick control thrust and strafe. Desktop mouse controls steering;
aircraft use the existing jet binding for lift. In VR, the turning stick controls
yaw and aircraft rise/descent, with its centre holding altitude. Wildcat follows
the terrain automatically instead of flying. Fire/trigger fires Shrike's blaster.
Havoc passengers keep normal personal weapon controls, independently of the pilot.
Only Light armour pilots; all armour classes can ride as passengers. Existing
boarding delay, safe ejection, flag restrictions, repair, damage, team ownership
and friendly-fire policies apply. The shared global cap remains 18 hulls, with
three of any type reserved per purchasing team.

Shrike bolts carry their vehicle kind in snapshots, deal direct damage with no
explosive splash, and use a separate lifetime/speed validator. Legacy Scout
projectile snapshots remain readable. Live protocol is now
`fpsloppa-72-st-classic-vehicles`; peers need matching builds. Beowulf adds a crewed mortar, Thundersword adds a bombardier and tail gunner,
and Jericho adds a deployable mobile inventory base. See `ST-VEHICLES.md` for
seat controls, deployment rules and adaptation limits. Vehicle shields/energy systems and
bot piloting remain outside this implementation.

## Rebuild and validation

Requirements: Python with NumPy, Node 22+ (TypeScript stripping), ericw-tools
0.18.1, and the project's Godot version. Existing Stonehenge/Raindance/Katabatic,
KOTH and CTFStudies WAD inputs provide the materials.

```sh
python tools/t2_classic/sources.py --node /path/to/node
python tools/t2_classic/build.py --compiler /path/to/ericw-tools/bin
python tools/t2_classic/verify.py
```

`--map TITLE_OR_ID` selects one map; `--resume` skips compiled manifests and
`--register-only` refreshes catalog hashes after entity-only changes. Source
fetches, generated `.map`/BSPs and caches are ignored build artifacts, following
the existing ST maps. The recipes, pinned receipts and placements are tracked.
To install elsewhere, rebuild or copy the generated BSPs plus `maps/cache` and
`maps/navigation` artifacts. No publishing or remote deployment is performed.

```sh
./run.sh --headless --xr-mode off --script tools/t2_classic/inspect.gd -- ctf_t2_broadside
./run.sh --headless --xr-mode off --script tools/t2_classic/acceptance.gd -- ctf_t2_broadside
./run.sh --rendering-method mobile --xr-mode off --script tools/t2_classic/preview.gd
./run.sh --headless --xr-mode off --script deathmatch/tests/st_t2_vehicles.gd
GODOT_BIN=/path/to/godot T2_VEHICLES=1 python tools/tribes/test_transports_network.py
```

Physics inspection checks spawn/flag/service support and capsule clearance.
Preparation checks BSP lightmap validity/packing and builds navigation with
inventory/ammo collision fixtures; partition fallbacks resolve overlapping navigation
edges. Match acceptance checks ST selection, team spawns, both teams' actual
flag pickup/capture, powered station service and every vehicle type at every pad.
Route connectivity is a separate stricter check: run `verify.py --skip-prepare
--routes` to include it. Some tall or enclosed bases have disconnected bot
approaches in the current terrain/portal graph; see the [validation receipt](../tools/t2_classic/validation.json) for exact
per-map failures. Eleven maps pass all 16 spawn-to-enemy-flag graph queries;
eleven need further portal/routing work. Human objectives and vehicle stations pass independently.
These checks do not establish competitive balance or long-duration bot quality. Detailed results and screenshots are in `test-results/t2-classic` and
`test-results/t2-vehicles`; the tracked validation receipt summarizes the final
run.

Final validation: 1,222 physics checks and 1,215 match checks pass across all 22
new maps. Vehicle, VR, ST rules and four-process Havoc network regressions pass
386 checks. All BSP catalog/cache hashes match, colored lighting is present, and
prepared navigation meshes have no unresolved overlapping edges. Route-graph
failures are reported separately rather than counted as passing checks.

The Wildcat, Shrike and Havoc now share the existing ST hull atlas and material
conventions: bronze armor, gunmetal framing, recessed vents, team-color panels
and blue engine glow. Face-wide UVs preserve panel continuity across triangles;
mipmaps and anisotropic filtering keep the atlas stable at a distance. Geometry,
mounts and controls are unchanged by this visual update. Rebuild with
`./run.sh --headless --xr-mode off --script tools/t2_vehicles/models.gd` and inspect
six views per vehicle with
`./run.sh --xr-mode off --rendering-method mobile --script tools/t2_vehicles/preview.gd`.
The preview audit checks material surfaces, texture mipmaps and UV bounds.

Full-HD renders of every newly converted ST and DE map are generated by
`tools/map_gallery/render.py`; see `tools/map_gallery/README.md` for the offline
gallery, image packaging and validation workflow.

## Atmosphere

All 22 conversions have individual depth fog colors/ranges derived from their
pinned missions, adapted to the existing three ST maps’ restrained haze. Acid
Rain uses rain; Ice Ridge, Ramparts, Shock Ridge, Snowblind and Subzero use snow. Confusco,
Desert of Death, Gorgon, Rollercoaster and Sandstorm carry windblown dust;
Magmatic has drifting ash. Other maps keep clear air with distance haze and
appropriate wind/coastal ambience. Existing ambient beds crossfade and soften
indoors. Source/adaptation values are recorded in `tools/t2_classic/atmosphere.json`.

Weather uses the existing 512-instance draw and cached 8×8 overhead mask. Each
map supplies its compiled sky-seal height so particles stay above roofs and
terrain. Effects are cosmetic and use no networked physics bodies.

## Interior visibility

Dark interior samples on Gorgon, Desert of Death, Ramparts, Scarabrae and
Snowblind were difficult to read. The imported `ctf_t2_*` maps now clamp the
Quake shader's minimum baked illumination to 0.30. Brighter bake values and
original lightmap samples remain unchanged. Other maps reset this parameter
to zero, including when materials are reused. Fifteen scope/reset assertions
pass; before/after luminance measurements for 40 interior views are recorded in
`tools/t2_classic/interior-visibility.json`. All 22 ST galleries were rerendered.
