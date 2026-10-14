# Jungle spotting, class loadouts, rustling and baked lighting

Implemented on `experimental/cq-voxelspace`. Vulkan Forward+ remains required.

Daytime enemy spotting uses 75 m for non-scouts and 150 m for scouts; night
and NVG acquisition limits are described below.
Authority scans at 10 Hz with head/chest static LOS, team sharing, ten-second
memory and cloak/dead/downed exclusions. Friendly label display retains its
independent 100 m distance.

Open **Player → Class and Loadout**, then select a class. Its loadout page
contains primary, secondary and utility. Changes are stored by the authority
and equipped on the next spawn; they cannot refill the current life. T2
primary and secondary retain level 5/10 unlocks (2,500/5,000 class XP). T1 utilities are shocktroop jetpack, scout recon/cloak, medic injector/health
dispenser and technician repair/ammo dispenser. Scout T2 recon drone unlocks
at level 15 (7,500 scout XP) and replaces cloak activation while equipped.
The existing scout T1 secondary remains its target designator. Reliable requests
validate the requesting peer, class and utility ID. Snapshots carry choices and
the equipped kit. Protocol: `fpsloppa-cq-frontier-7-recon-drone`.

Grass rustling is a 12 m spatial sound, with eight reused voices and three
original CC0 mono noise clips. Each client derives nearby movement from actual
fighter positions, checking grass placement rather than visible LOD instances.
There is no audio RPC traffic or additional grass physics. A 10 Hz coverage
check uses lazily cached 2 m bins in the terrain's resident tiles. Standing
movement brushes every 0.35 m, prone movement every 0.18 m, with a 0.32 s gap;
prone volume is 7 dB quieter. Stationary avatars, teleport jumps, airborne
movement and bare roads do not rustle. Local/server grounding uses actual
collision support; remote grounding uses the replicated state. Desktop and XR
head positions provide the listener. Terrain eviction discards audio bins.

## Class levels and supply balance

Class levels are `floor(class XP / 500)`, starting at level zero. T2 primaries
unlock at level 5 (2,500 XP), and T2 secondaries at level 10 (5,000 XP). Existing
class XP remains separate; selection still applies on the next spawn. The UI
shows class level and level-based unlocks.

Medic/technician box limits are per owner: one starting box through level 9,
two at level 10 (5,000 XP), and three at level 15 (7,500 XP), capped at three.
Deployment cooldown is 30 seconds and persists through respawn/class changes.
After a valid placement passes collision/LOS checks and cooldown validation,
deployment beyond the limit removes the oldest owner box by monotonic ID.
Respawning into a class with a lower limit trims the oldest surplus boxes.
Exhausted boxes are removed, and clients release removed box meshes. HUD status
shows the active box count, limit and deployment cooldown.

Ammo box cost is one unit per non-ordnance round/cell, **300 per full three-charge
launcher pack**, and **100 per replacement shocktrooper HE grenade**. Partial
launcher packs are not granted. Insufficient stock, full inventories, hostile
or incapacitated targets cannot drain boxes. Owner support XP uses actual spent
box units and excludes self-resupply. The box retains its 1,000-unit capacity.
At the existing 20 units/second contact rate, weighted items accumulate private
per-box/player credit, capped at 300; this is discarded on leaving range, losing
LOS, dying or filling the inventory. Full recipients cannot bank credit. Credit
is not added to network snapshots. Health continues at 20 HP/second per box.

Both launcher pack replacements take **6.6 seconds**, three normal 2.2-second
magazine reloads. Physical VR seating must respect the same minimum deadline,
including after holstering/tracking interruptions. Guided launcher's internal
cycling between charges retains its separate 2.7-second timing. Pack replacement
deadlines and readiness continue to replicate through existing reload snapshots.

## Lighting implementation

This is a custom offline irradiance bake for the procedural world, rather than
Godot LightmapGI. All map illumination is baked. No gameplay `Light3D`, realtime
shadow maps, environment ambient/reflection lighting, SSAO or SDFGI is used.
The scene's directional light was removed. Preferences tolerate scenes without
that light. Fixtures are visible emissive artwork, not light nodes.

`bake_lighting.gd` constructs the authoritative terrain, tree trunk and building
collision world. The gameplay boundary walls are excluded from lighting rays.
It ray-tests three sun directions (noon, dusk and dawn), five sky hemisphere
samples and 384 authored warm fixtures (292 hanging/entrance lights and 92 outdoor lamps). The same procedural
sky radiance source generates the visible sky and baked ambient color. An
original eight-stage tropical sky atlas (4096×1024) stores cloud, sun, moon and
star artwork. It is an ordinary PNG, avoiding ImageTextureArray serialization
from Godot's headless dummy renderer, which produced missing/purple textures.
Sky sampling uses explicit direction coordinates aligned with the baked suns.

A 1024² numeric RGBA atlas stores noon direct light, warm night fixtures, sky
visibility and dusk direct light; a second atlas stores dawn direct light in R.
Imports remain lossless and linear, with alpha-border fixing disabled because
alpha is numeric dusk irradiance. Terrain sampling is about 2.76 m per texel.
Structure surfaces additionally carry the RGBA field in CUSTOM0 and dawn in
CUSTOM1 for **110,776 vertices across 33 mesh LODs / eleven sites**. The radar
dish has a bearing column and two yokes connecting its bowl to the tower. Local
roof and dish triangle winding is corrected for outward bake normals.

This approximates sky fill, rather than solving bounced GI. Trunks cast baked
shadows; foliage samples ground light and contributes no precise canopy shadows.
Dynamic avatars, weapons, bridges and hybrid foliage sample the terrain field;
they cast no moving shadows. Interior lighting has its own structure vertex bake.

Runtime blends these baked fields and sky layers; it creates no map lights. The
**20-minute** authoritative cycle passes through these keys, smoothly blending
between them:

| Cycle time | Stage |
| --- | --- |
| 0:00–4:00 | Day |
| 4:48 | Golden hour |
| 5:48 | Dusk |
| 6:36 | Twilight |
| 7:12–12:48 | Night |
| 13:24 | Dawn twilight |
| 14:12 | Dawn |
| 15:12 | Morning |
| 16:00–20:00 | Day, then wrap |

The cycle phase travels in class snapshots independently of the game-clock
offset. Night terrain remains almost black without NVG; building interiors and
entrance vicinity retain warm static light. Emissive weapon artwork, tracers,
reticles and UI remain visible without illuminating the map.

## Night vision and spotting

Spotting acquisition interpolates with the sun light fraction: day 75/150 m
(non-scout/scout), darkest night 15/25 m. With the visor on, darkest night limits
are 50/100 m, rising to the same 75/150 m daylight limits. Existing ten-second
team-shared sightings remain; blindness prevents acquisition, rather than
clearing sightings already shared by teammates.

All classes carry NVG independently of their selected utility. Click the offhand
trigger with that hand above the forehead to toggle; desktop uses **N**. A fresh
trigger edge is required, including after menu use; the head-relative region
follows headset rotation and handedness. The server validates the authenticated
peer, life/map epoch, replay sequence, switch cooldown, fresh tracked pose and
proximity to the latest accepted head/hands. Dead/downed players cannot toggle.
Respawn resets the visor and glare. Compact `nv`/`nb` class snapshot fields carry
activation and the glare deadline, adjusted for each client's clock.

One Forward+ HDR compositor compute pass per eye applies green luminance gain,
animated grain, scanlines and an angular viewing aperture. Standard NVG now uses
roughly 1,400 night gain and 0.4 output intensity, reduced from 6,000 gain with
full intensity. Its 80° diameter aperture fades to black at the rim. Scout NVG
uses about 3,200 gain, 0.65 intensity, reduced grain/scanline contrast and a full view
with a slight vignette confined to the outer edges. Day gain falls with the
lighting fraction. These are renderer settings rather than real photometric gain values.

Each eye reconstructs rays from its own actual off-axis projection. Scanline
phase and angular noise coordinates are shared between eyes; independent pixel
row patterns and eye-randomized noise are avoided. The aperture also uses angular
rays, maintaining its FOV across desktop aspect ratios and XR projections.
Native XR uses each eye's resolved color image; no screen-texture quad is used.
Uniform sets are cached and disabled visors skip the effect. CPU sends settings
through a mutex; there is no gameplay readback of rendered pixels.

Visible muzzle flashes, explosive/flashbang bursts, looking at nearby emissive
fixtures or directly at the sky's sun cause bright visor glare. Events require
world LOS, range and view direction; near muzzle flashes include peripheral
vision. Scout optics remain vulnerable to bright light. Static source scanning
runs at 10 Hz with a 24 m fixture grid, up to two fixture LOS rays plus one sun
ray per active wearer; explosions/muzzles check nearby facing wearers when the
combat event occurs. Fixtures remain baked artwork, not runtime lights.

Existing terrain residency, worker streaming, tree/grass MultiMesh budgets,
LOD distances and culling remain. The playable arena now submits its current
desktop/XR camera to map streaming and culling each frame; formerly the tools
submitted it explicitly while the playable arena omitted that update. Fixtures
use one culled MultiMesh per POI, following structure visibility. Housings, hanging cords, entry brackets, 4.8 m lampposts and 6.5 m floodlight poles are merged into the three existing structure LOD meshes. Outdoor pools have 17–23 m falloff; the forest remains unlit. `light_fixtures.gd` is the shared placement source for geometry, the bake and authoritative NVG glare. Posts stay outside road gates and building footprints; dock lamps sit on the raised dock rather than the water bed. Bake assets total about 5.33 MiB on disk. Sky and numeric atlases occupy 24 MiB uncompressed (16 MiB sky, 8 MiB lighting). Map identity includes the bake
manifest/atlases, sky and lighting source so clients reject mismatched map content.

Rebake after authoring terrain, structure or fixture geometry:

```bash
godot --headless --xr-mode off --path . --script tools/voxel_battle/bake_lighting.gd
godot --headless --xr-mode off --path . --editor --import
```

`-- --meshes-only` intentionally reuses an unchanged terrain atlas; use only
when atlas inputs are unchanged. Geometry hashes reject stale source checkouts.
When reusing in main, package the lighting directory, shader include/surface/
card shaders, project shader globals, bake manifest and meshes; generated paths
in JSON need explicit inclusion in any custom dependency packer. Keep the atlas
import policy lossless with no sRGB hint. Use the existing terrain and structure
factories in the bake so rendered, collidable and illuminated geometry agree.

## Verification

Godot 4.7.2, Intel Arc A770, Vulkan Forward+:

- Spotting tests pass at 75/150 m boundaries, with LOS, memory and cloak cases.
- Class progression, 32-player snapshot budget and integration tests pass.
- All 44 jetpack checks pass with the test harness waiting for the engine tick
  interval to settle after changing 30/60/120 Hz rates; trajectories match the
  isolated pre-change branch baseline. Jetpack movement code is unchanged.
- Feature tests cover class → loadout navigation, XP locks, next-spawn gear,
  utility validation/snapshots, all baked mesh channels, cycle and grass coverage.
- Two-process tests pass utility selection/equipment replication and day/night
  synchronization with a deliberate client game-clock offset.
- Native audio test passes walking/prone emission, stationary/bare-ground/airborne/
  distance suppression and bounded voices. Recorded output peak is 0.0929,
  RMS 0.00590; six events were emitted across the test.
- A playable native smoke test also passes the actual N shortcut, active world
  compositor attachment and a captured player NVG view.
- New native captures cover all eight sky/lighting stages, dish support, dark
  forest, standard/scout NVG and white glare. The PNG atlas loads correctly in
  Vulkan Forward+ with a blue daytime sky.
- NVG tests exercise all range endpoints, dusk/dawn monotonicity, VR gesture
  handedness/head rotation, replay/life/map/stale-pose rejection, glare through
  cover, fixture glare and respawn reset.
- Two-process tests also pass reliable NVG activation and glare deadline
  replication with a deliberate client clock offset. With all 32 visors active
  and glare replicated, normal snapshot records stay within 1100 bytes.

- Native WiVRn-Pro/Meta Quest Pro captures pass for both eyes (2160×2376 per
  eye) with standard and scout filters. The runtime retains OpenXR session/marker
  teardown warnings on exit; no compositor compile/dispatch error was observed.

Current visual artifacts: ignored `test-results/staged-jungle/`. Previous
class/loadout and audio artifacts remain in `test-results/baked-jungle/`.
Native and headless tests retain existing cached-resource/voice teardown
warnings. Image checks are visual validation, not a new frame-time benchmark.

Useful test/preview commands:

```bash
godot --headless --xr-mode off --path . --script deathmatch/tests/cq_jungle_features.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/cq_spotting.gd
godot --xr-mode off --rendering-method forward_plus --rendering-driver vulkan --path . --script tools/voxel_battle/preview_lighting.gd
godot --xr-mode off --rendering-method forward_plus --rendering-driver vulkan --path . --script tools/voxel_battle/test_rustle_audio.gd
```

The jungle preview has a live cycle plus all eight named stage choices and
standard/scout NVG preview choices.

Additional commands:

```bash
godot --headless --xr-mode off --path . --script deathmatch/tests/cq_night_vision.gd
godot --xr-mode off --rendering-method forward_plus --rendering-driver vulkan --path . --script tools/voxel_battle/preview_sky_nvg.gd
godot --xr-mode on --rendering-method forward_plus --rendering-driver vulkan --path . --script tools/voxel_battle/stereo_nvg.gd
```

Supply validation: `deathmatch/tests/cq_supply_balance.gd` covers XP/box boundaries,
exact cooldowns, oldest replacement, atomic pack/grenade costs, depleted stock,
continuous contact and VR pack timing. Integration includes 32 player records
and 96 box records to exercise the new deployment maximum; normal records remain
UDP-sized, with membership using the existing reliable fallback when needed.

POI fixture visual check (11 night views, animated UT99 player, radar day/NVG):

```bash
godot --xr-mode off --rendering-method forward_plus --rendering-driver vulkan --path . --script tools/voxel_battle/preview_fixtures.gd
```

Captures and culling/draw records are written to `test-results/poi-fixtures/`.
Use `-- --site 1` to recapture only the factory. Open the interactive jungle
preview with `-- --poi-night` to start on the radar approach at night; its visor
selector switches NVG off, standard or scout.

Targeting designator lasers show their full world segment at full opacity to
active NVG wearers, for both teams and both visor grades. Unaided enemies retain
the faded segment within 3 m of their eye. Depth occlusion, visor aperture and
glare remain in effect; the laser creates no runtime light and uses the existing
replicated designation endpoints and two shared line meshes. Toggling NVG updates
both segment selection and reused material opacity immediately.

`preview_designator_nvg.gd` verifies the native production draw path with a
distant enemy beam, both visor grades, and NVG removal; captures are saved to
`test-results/designator-nvg/`. The class integration test covers full segment
selection and material opacity changes on the reused mesh.

### Scout T2 recon drone

Select RECON DRONE in scout utility selection, then respawn. The existing Use
binding launches a single pass; T1 scout utility still activates cloak. Utility
selection and level-15 XP validation are authoritative. The 120-second cooldown
starts at launch and survives death, respawn and class changes; returning to T1
cannot clear it. The drone completes its pass if its owner dies or disconnects.
Map/round resets clear flights, marks and warning playback state.

`recon_drone.gd` projects the scout's validated desktop/XR head look onto the
horizontal plane, clips the line through their position against the square map,
and flies from its entry edge to its exit edge at 120 m/s (about 24–33 seconds).
A near-vertical look falls back to body yaw. Altitude stays fixed at 60 m above
the highest terrain sampled along the route, keeping the path straight and clear
of jungle canopy. The model is an 8 m span conversion of surt's CC0 low-spec
fighter: https://opengameart.org/content/low-spec-airspace-fighter . Source,
SHA256, conversion instructions and the original blend are retained under
`deathmatch/models/recon/` and `tools/recon/`.

The server scans at 10 Hz with a swept 100 m ground radius, so fast travel and
large simulation steps do not leave gaps. Living enemy combatants in that ground
corridor are shared with the launching team through the existing name/icon
spotting system for ten seconds after their last detection. Radar ignores night,
roofs, vegetation and cloaking; it reveals the marker without cancelling cloak
or making an invisible body visible. Friendlies, spectators and dead players are
excluded. Each acquired enemy receives one 0.9-second ascending electronic radio
warning per flight and life. Audio uses a single reused local player, equally
audible in desktop and XR. It does not create a world sound that enemies could
mistake for a nearby aircraft. `tools/recon/bake_sound.py` regenerates the original
CC0 PCM warning without external samples.

Snapshots carry `crd:` flight trajectories, `crw:` acquisition warnings and
`crs:` radar deadlines as independent records. Client clock offsets are applied
to launch, expiry, detection and cooldown times. Warning tokens include map epoch,
sequence and player life to prevent repeats and stale respawn audio. Headless
servers do not load the model or sound. Rendered drones use the existing baked
material conversion, no collisions or realtime lights, and distance/frustum
culling; the source's 116 triangles need no further mesh LOD reduction. There is
no drone AI or physics simulation. Flight metadata stays constant while clients
animate it from the shared clock.

Validation:

```bash
godot --headless --xr-mode off --path . --script deathmatch/tests/cq_recon_drone.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/cq_class_integration.gd
# Run server and client in separate processes:
godot --headless --xr-mode off --path . --script deathmatch/tests/cq_recon_network.gd -- server
godot --headless --xr-mode off --path . --script deathmatch/tests/cq_recon_network.gd -- client
godot --xr-mode off --rendering-method forward_plus --rendering-driver vulkan --path . --script tools/voxel_battle/preview_recon_drone.gd
```

Native captures of the aircraft, ground observer and level-15 loadout are in
`test-results/recon-drone/`. Two-process tests verify trajectory, equipped
utility, relative cooldown, shared marks and one warning despite repeated
snapshots. The 32-flight stress test includes 32 warnings, radar records and
cooldowns; individual gameplay records stay under the 1,100-byte UDP budget,
while the enlarged membership list uses the existing reliable fallback. Existing
ObjectDB/resource and native PulseAudio teardown warnings remain in these tools.

For reuse in main, port utility XP gating, the class ability dispatch, spotting
`reveal`/cloak override and the `crd/crw/crs` snapshot paths together with the
recon service/model/audio. Replace the jungle-specific bounds/terrain sampler
with the main map's bounds and height sampling. Keep the server scan independent
of camera residency and foliage culling, and keep the cooldown outside spawn
resets. The preview and network tests are reusable checks for that port.

## Shocktroop T2 airstrike and stationary designators

Shocktroop T2 utility `airstrike` unlocks at level 15 (7,500 shocktroop XP) and applies on the next spawn. It replaces the HE grenade with weapon-slot 8's laser designator; the primary, secondary and existing shocktroop jetpack remain available. Grenade inventory, shoulder throwing visuals and ammo-box grenade resupply are disabled for this kit. Desktop **G** equips the designator (also weapon key **7**); XR players select it with the existing weapon cycle. Hold the normal weapon trigger on a valid target for **five continuous seconds**. The HUD reports targeting progress and remaining cooldown. Invalid/blocked aim, target movement beyond an 8 m aiming tolerance, stale inputs, locomotion, falling/jetpack ascent, release, death or weapon change cancels the sequence without spending the cooldown.

Every designator, including the scout's, requires movement input within a 0.03 deadzone, horizontal physics speed at most 0.15 m/s and vertical speed at most 0.5 m/s, with no jump/swim input. These are authority checks. Validated XR playspace translations already move the capsule through `RoomScale.move_capsule` without modifying physics velocity; these translations and head/hand aiming are deliberately excluded from the motion lock. World-position differencing would incorrectly cancel ordinary room-scale aiming. The laser disappears immediately on loss of valid targeting. NVG still sees the full targeting beam.

Confirmation captures the **initial target and horizontal laser bearing** and starts a **300 s cooldown**, preserved through death and class changes. A bomber approaches from 180 m behind the barrage at 60 m/s, 80 m above the highest sampled terrain along its route. Twelve cluster bomblets fall for two seconds, with impacts **18 m apart at 0.3 s intervals** (198 m corridor, 3.3 s first-to-last impact). The corridor is centered around the initial site; near a map edge it shifts within the playable bounds and reduces spacing only when the available map chord is shorter than the corridor. Bomber visuals continue beyond the last drop. Confirmed strikes survive caller death/disconnect; round/map reset clears them.

Each payload traces vertically onto terrain, roofs, vehicles or players and delivers **300 direct damage**, plus **300 maximum rocket splash** with the existing `300 - distance * 16` falloff (18.75 m radius). Direct victims are excluded from that payload's splash to avoid double damage. Existing splash LOS, team protection, armor, invulnerability, impulses and self-damage rules apply. Repairable vehicles retain their existing splash reduction. Impacts trigger explosion visuals/audio and NVG glare; no dynamic map lights are added.

`deathmatch/conquest/classes/airstrike.gd` contains server targeting, bounded ordered delivery and client aircraft/payload animation. It schedules twelve traces and reuses `variant_combat.blast`, avoiding twelve persistent projectile physics bodies. `classes/match.gd` sends independent `cas:` trajectory and `cap:` targeting records and adjusts deadlines to each client's clock; the existing class record carries the cooldown. Impacts are reliable authority RPCs. Protocol is `fpsloppa-cq-frontier-8-airstrike`. For reuse in main, mount the service, hook designate/tick/reset/death/disconnect, copy the utility/armory/grenade gates, snapshot records and FX RPC, and preserve the validated room-scale distinction.

The requested [X-001 model by Karmabub](https://opengameart.org/content/x-001) is CC0. `tools/airstrike/export_bomber.py` converts 11,988 triangles to **1,438**, one opaque material with vertex-painted metal, canopy and trim, no textures or collisions. Godot generates mesh LODs; shared aircraft frustum/range culling cuts visibility at 1,600 m. The source's extra white vertex layer is removed during export, and `airstrike.prepare_model` explicitly enables vertex colour before conversion to the baked jungle shader because Godot's GLTF importer leaves this material flag disabled. See `deathmatch/models/airstrike/SOURCES.md`.

Validation: `deathmatch/tests/cq_airstrike.gd` covers unlock/loadout/grenade replacement, stationary/playspace rules, interruption, exact five-second confirmation, twelve ordered impacts, cooldown, client clock offsets, real direct/splash damage and cover, reset, mesh budget and material colour. `cq_airstrike_network.gd` is a real two-process localhost test on port 28795 with different clocks and twelve reliable impact events. `cq_class_integration.gd` stress-packs 32 aircraft/targeting/cooldown records alongside existing abilities; only the existing oversized membership record takes the reliable fallback. `tools/voxel_battle/preview_airstrike.gd` captures the production model/payload/FX path and T2 menu in native Vulkan Forward+ at `test-results/airstrike/`.

## Medic T2 healing grenade

`healing_grenade` unlocks at medic level 15 (7,500 XP) and applies on spawn. It replaces the health dispenser slot with **three healing grenades** (utility kind 3 / item 113), retaining the medic's injector and chosen guns. Existing owned medic boxes are removed when spawning with T2, and authority rejects new box deployment. Desktop **G** equips the grenade; press/release the weapon trigger to throw. XR uses the existing offhand shoulder grip and guided swing/release gesture, with validated hand positions, velocity, occlusion, sequence and cooldown. The physical held model, remote hand model and flying model all use the requested asset. Grenades use the normal 1.5 s fuse, bounce/gravity path and 0.6 s throw interval. Ammo boxes refill the three-grenade carry limit using the existing **100 units per grenade** resupply convention. No additional ability cooldown is added.

Detonation creates a **5 m radius** spherical force field for **10 seconds**, with independent pools of **500 healing HP** and **500 energy damage**. Healing runs at **10 HP/s per eligible ally** (half the box's 20 HP/s), caps players at 100 HP, checks world LOS and radius, and shares the 500 HP pool across everyone. It regenerates living allies; it does not revive incapacitated players. Healing XP follows the box's actual-healing credit and cannot accrue from full-health players. Overlapping grenades have their own pools. Healing scans run at 10 Hz with accumulated fractional credit and rotating allocation order; expiry and energy interception remain immediate. Depleting healing leaves the shield active, changing its visual from green to blue. Breaking the shield removes both effects immediately; timeout does likewise.

Only explicit **energy rays** interact with the shield. In the current arsenal that is the scout beam pistol. Projectile energy weapons (carbine, energy assault rifle and burst pistol), physical bullets, rockets, grenades, airstrike payloads and ordnance splash are **not stopped**, as requested. Energy ray intersection is analytic, ordered along the ray and limited to the existing world/player hit, so walls can block fire before it ever reaches a shield. Allies whose shot starts inside their field shoot outward without consuming its energy. Shield damage uses the beam's base damage before armor/headshot scaling; a breaking hit absorbs only the remaining capacity and its excess continues through. Fields do not create physics colliders or dynamic lights.

`deathmatch/conquest/classes/healing_field.gd` owns activation, regeneration, energy-ray absorption, expiry and visuals. `classes/combat.gd` hooks explicit `cq_beam` hitscan weapons only, and now also samples selected grenades in the normal trigger firing path. `classes/grenades.gd` extends the utility inventory to four kinds and reuses the existing authoritative throw simulation for healing grenades. Detonation captures the thrower's team, so deployed fields persist correctly after death/disconnect. The snapshot carries independent `chf:` field records, four-kind grenade inventory and the existing grenade trajectory records; field deadlines and hit flashes adjust to client clock offsets. Protocol is **`fpsloppa-cq-frontier-9-healing-field`**. For main-branch reuse, mount/setup/tick/reset the field service, preserve the medic utility/box/inventory gates and fourth grenade kind, copy the physical/remote model hooks and snapshot receiver, and hook energy rays without adding collision to projectile traces.

All field visuals share one low-resolution sphere MultiMesh draw, no shadows/collision, and a translucent procedural grid with a brief energy-hit flash. The requested [Futuristic Grenade by mrpoly](https://opengameart.org/content/futuristic-grenade) is **CC0**, exported at 18 cm tall with one painted material, **1,000 triangles**, no texture and Godot-generated mesh LODs. Source/rebuild/license details are in `deathmatch/models/healing_grenade/SOURCES.md` and `tools/healing_grenade/export_grenade.py`.

Validation: `cq_healing_field.gd` covers T2 gating/box replacement/capacity, actual desktop press-release and tracked throws, separate pools, rates/teams/radius, allied outward fire, energy capacity/break/excess, timeout, live beam/ballistic/projectile/splash paths, 32 wounded allies sharing exactly 500 HP, snapshots and model budget. `cq_healing_network.gd` uses two real localhost peers on port 28797 with different clocks to check inventory, thrown trajectory, activation, health/energy changes and removal. `cq_class_integration.gd` packs **96 fields** alongside 32 players and other abilities within the existing normal UDP budget; oversized membership alone uses reliable fallback. `preview_healing_field.gd` captures the normal rendering path, empty healing pool with active shield, painted grenade and T2 medic menu in native Vulkan Forward+ at `test-results/healing-field/`.

## Technician T2 autonomous turret

`turret` unlocks at technician level 15 (7,500 XP), applying on the next spawn. It replaces the ammo box with a turret deployer in slot 6, retaining the repair tool and selected guns. Existing technician boxes are removed when spawning with T2, and authority rejects box deployment. Select the deployer through the normal desktop weapon keys or XR weapon cycle and use the normal weapon trigger. Deployment places the turret about 1.6 m along the validated weapon direction. The server checks a fully supported 2 m square footprint, near-level ground, world line of sight, reach and clear space; water, steep slopes, narrow ledges and obstructed locations are rejected. Structure floors use the same checks. Invalid placement leaves the existing turret and cooldown untouched.

Successful placement starts a **120 s cooldown**, preserved through death, respawn and class changes. Only one turret per owner is allowed: placing another after cooldown removes the previous one. A deployed turret persists through owner death and class changes, without an idle timeout, until destroyed, replaced or its **12-shot reserve** is exhausted. Owner disconnect and round/map reset clear it. The turret has **200 HP**, no armor and no replenishment. Existing friendly-fire rules apply. Direct projectile damage is not charged again through that projectile's splash.

Authority scans at **10 Hz** within **100 m**, choosing visible hostile vehicles before infantry, then the nearest eligible target. It excludes friendly/dead vehicles, dead/downed or cloaked infantry and mounted players, and checks world line of sight plus muzzle clearance. The base stays stationary while the gun independently turns and elevates. The prototype fires one straight, non-homing ordnance round every **1.5 s** at the target's current position, with no lead or homing. It reuses weapon 11's projectile and impact simulation: **100 direct damage**, **120 maximum rocket splash**, 5 m radius, 40 m/s speed, no gravity and a 4 s fuse. Each shot consumes only turret reserve, never the player's weapon ammo. The turret disappears immediately after its twelfth shot; already fired projectiles continue normally.

`deathmatch/conquest/classes/turrets.gd` owns placement, stationary collision, scanning, firing, damage and model presentation. `class_arena.gd` dispatches the deployer, traces turret contacts and supplies shot audio/FX and NVG glare. `classes/combat.gd` launches unguided ordnance and routes splash damage; HE grenades also damage turrets. Snapshots carry separate `ctu:` records with owner/team, placement, aim, HP, ammo, target and firing deadlines; the class record carries `turret_ready`. Client clock offsets apply to all deadlines, and clients create/remove matching stationary colliders. Protocol is **`fpsloppa-cq-frontier-10-turret`**. For reuse in main, port the service setup/tick/reset/disconnect hooks, utility gating/deployer model, box replacement, contact/splash damage, shot RPC and snapshot records together. Adapt the map-specific water check; keep placement authority and scanning independent of visual streaming.

The requested [3D Turret by PolygonDan](https://opengameart.org/content/3d-turret-pbr-texture-flat-diff-texture) is **CC0**. `tools/turret/export_turret.py` reduces **2,400 to 1,440 triangles**, exports at 1.4 m height and separates the moving gun from its fixed base. Both parts share one opaque material and a **512² diffuse atlas**, omitting the source PBR maps. Godot-generated LODs, shared range/frustum culling and existing baked-light materials are used; there are no dynamic lights or runtime shadows. The original archive, source attribution and rebuild instructions are retained in `tools/turret/source/` and `deathmatch/models/turret/SOURCES.md`.

Validation: `cq_turret.gd` covers level gating, box replacement, real placement on ground and elevated floors, slope/ledge rejection, cooldown/respawn, vehicle priority, range/cover/team checks, unguided flight, cadence, all twelve shots, replacement, real direct/splash damage, destruction, snapshots, client colliders and mesh budget. `cq_turret_network.gd` uses two real localhost peers on port 28799 with different clocks to check deployment, loadout, cooldown, projectiles, ammo, damage and removal. `cq_class_integration.gd` stress-packs 32 turrets alongside the existing 32-player abilities and 96 healing fields within the normal per-record UDP budget; the membership list retains its existing reliable fallback. Native Vulkan Forward+ `preview_turret.gd` captures the textured production model, independent gun aim and level-15 loadout at `test-results/turret/`. Gameplay regressions for healing grenades, airstrikes, supply balance, jungle features and progression also pass. Existing ObjectDB/resource and native PulseAudio teardown warnings remain.

## POI battery tanks

Two crewed batteries are available at **west ridge relay** and **canyon crossing**, parked on level terrain beside their access routes. Spawn positions are authored in `battery_tank.placements()` and tested against the generated structure geometry and terrain footprint. The tanks can be boarded by any class/team while vacant; the current driver's team becomes the hull's team. Use the normal **Use** button within 4.5 m with clear reach to board, then Use again to dismount onto a checked adjacent floor. There is one driver per tank. Invalid boarding/blocked exits preserve the reservation; input loss stops new firing and slows movement. Death, respawn or disconnect forcibly releases the driver. Destroyed batteries remain unavailable until round reset; no timed respawn is added.

Hull controls are **tank controls**: motion joystick up/down drives forward/reverse, horizontal motion joystick turns the hull; desktop uses WASD. XR explicitly uses the raw motion stick, independent of head-facing locomotion. Forward speed caps at **10 m/s**, reverse at **5 m/s**, acceleration/deceleration at **4 m/s²**, and hull turn at **0.65 rad/s**. A CharacterBody3D with two simple box shapes for the hull and upper battery uses existing world collisions, gravity, floor snap and a 30° floor limit. Map bounds and water are checked before horizontal movement. The weapon hand's validated orientation independently drives battery yaw/elevation; desktop uses mouse aim. No autonomous AI is attached. Drive input cannot move the on-foot capsule or fire infantry equipment while aboard.

The normal player avatar, nameplate, tracked hands and held weapon are hidden while aboard, and the player's infantry collider is disabled. Player damage is rejected through normal infantry hit/splash paths; administrative suicide remains available. A seated **first-person aiming feed** replaces the normal view, adapting main's ST `turret_view.gd` 640×360 SubViewport, 75° camera and FeedHUD crosshair/status. Desktop displays it over a black full-screen view; XR displays the same scope feed on a head-relative private screen, preserving the headset's stereo projection. Weapon-hand orientation controls its sensor. The feed shows hull HP, salvo/reload state and controls. Camera masks/environments are restored and the feed stops on dismount; the arena's `world_view_camera()` streams the same terrain, foliage and structures once per frame from the sensor while seated. No second map or separate streaming cache is created.

Holding the weapon trigger starts **eight non-homing mortar ordnance rounds at 0.15 s intervals**, alternating battery sides. The **30 s reload begins after the eighth round**; ammo is unlimited and does not consume the driver's carried ammunition. A started salvo finishes independently of trigger release, but boarding loss/destruction cancels remaining unfired rounds. Main ST mortar parameters are reused: **sqrt(275×20) ≈ 74.16 m/s**, **20 m/s² gravity**, **0.5 hull velocity inheritance**, **2 s arming**, **0.1 unarmed bounce** and **30 s fuse**. Unarmed shells bounce/rest until arming; armed contact or expiry detonates. Each shell uses normalized ST **152 damage/splash**, 20 m linear splash radius and a 0.3 m sweep. These are server-owned shared projectile records with ordinary impact rendering/audio and NVG glare, not eight rigid bodies.

Technician drivers receive the same style of scout designator assistance as their T1 ordnance weapon: only live allied scout designations, one selected target, low/high mortar solutions checked against world geometry, a world-space arc and aiming cross. The calculation uses the tank's actual launch speed, gravity and inherited hull velocity at 10 Hz; it is a visual aid and does not home shots. Other classes and enemy designations cannot receive this assistance.

Hull health is **100 HP**. Tagged **ordnance does full damage**, HE grenades do **half damage**, and infantry hitscan/energy/ballistic weapons do **zero**. Existing friendly-fire policy applies. Direct projectile/splash attribution avoids charging the same contact twice. Allied technicians can use the existing repair tool on a surviving hull, capped at 100 HP; destroyed tanks cannot be repaired. Moving hulls run over ground troops with incapacitating damage, checking the swept footprint, height and world cover; friendly-fire and spawn protection are honored, seated players are excluded, and run-over damage deliberately enters the existing bleed/revive state instead of gibbing.

`battery_tank.gd` owns placements, reservations, movement, salvos, hull damage, run-over checks, targeting aid and model presentation. `battery_hull.gd` exposes hulls to existing vehicle lock/repair services. `battery_view.gd` owns the local ST-style feed and camera restoration. Independent **`ctk:`** snapshots carry both hulls, crew/life, position/yaw, weapon direction, speed/velocity, HP, remaining salvo and deadlines. Clients offset salvo/reload/shot times to their clocks and reconstruct the same colliders; crew concealment survives ordinary player snapshots. Protocol is **`fpsloppa-cq-frontier-11-battery`**. For main reuse, port the service, map placements, utility-independent Use dispatch, vehicle movement/prediction hook, seated fighter/rig visibility, projectile definition/arming path, damage classification, grenade/airstrike hooks, snapshots and sensor streaming hook together.

The [Tankcar hull](https://opengameart.org/content/tankcar) and [Missile Launcher Tank battery](https://opengameart.org/content/missile-launcher-tank) are CC0. The optimized combined model is **953 triangles**, three opaque materials/draws, with **512² hull**, **256² camouflage-only housing** and **128² original missile** textures. Eight missile tips are deliberately separated from camouflage. It uses Godot mesh LODs, shared distance/frustum policy and baked jungle materials with no dynamic lights or runtime shadows. Source licenses and reproducible conversion are documented in `deathmatch/models/battery_tank/SOURCES.md`.

Validation: `cq_battery_tank.gd` covers two POIs and actual pad/geometry clearance, boarding/exclusivity/exit, crew concealment and protection, real infantry collision/energy damage rejection, half grenade and full ordnance damage, repair, eight shots/reload/unlimited reserve, independent mouse/tracked-hand aim, driving/stale input, physically correct allied designator solutions, run-over incapacitation, snapshots, destruction and round reset. `cq_battery_network.gd` uses two real localhost peers on port 28805 with different clocks for moving hulls, crew collider state, all eight projectiles, reload, damage, dismount and destruction. The class integration UDP-budget stress test and turret, airstrike, healing grenade, supply and jungle-feature regressions pass. Native Forward+ `preview_battery_tank.gd` uses the full map and its physics, captures both textured tanks plus scope/reload/dismount at `test-results/battery-tank/`, and verifies camera restoration. Existing ObjectDB/resource and PulseAudio teardown warnings remain in test tools.

## Light/heavy hover tanks and medic revival pies (2026-10-13)

The shared battery vehicle service now has eight map vehicles: the two original rocket batteries plus **four light and two heavy tanks**. The military base has two light and one heavy, west ridge relay and canopy outpost each have one light, and radar has one heavy. All spawns are on authored level pads and checked against structure/fixture bounds; the canopy tank occupies the clear west side rather than the watchtower footprint. Vehicles share Use boarding/dismount, joystick tank steering, tracked weapon-hand aim, seated avatar concealment, prediction suppression, ST sensor view and sensor-directed terrain streaming. A single service, two simple collision boxes per vehicle and the existing projectile simulation are reused; no vehicle AI, physical shells, lights or runtime shadows are added.

| Vehicle | HP | Forward/reverse | Turn | Magazine | Interval | Reload | Depression/elevation |
|---|---:|---|---|---|---|---|---|
| Rocket battery | 100 | 10 / 5 m/s | 0.65 rad/s | automatic 8-shot salvo | 0.15 s | 30 s | existing unrestricted hand aim |
| Light | 250 | 10 / 5 m/s | 0.65 rad/s | 5 single shots | 1.5 s | 10 s | −2° / +35° |
| Heavy | 500 | 6 / 3 m/s | 0.35 rad/s | 4 paired volleys (8 shells) | 1.5 s | 15 s | −4° / +25° |

Light acceleration is the battery's 4 m/s²; heavy acceleration is 2.5 m/s². Hover gun limits are in the supporting hull frame, including slopes. The shallow depression limits clear the supplied low hulls. The turret turns around its yaw pivot and only barrels pitch. Both new profiles use the stationary technician turret's direct non-homing ordnance definition (100 direct / 120 splash damage, 40 m/s, zero gravity, four-second fuse), with 0.5 hull velocity inheritance. Hold the trigger to fire at the stated interval; releasing it stops further light/heavy shots. A heavy volley checks both barrel paths and projectile capacity before firing, preventing a partial pair. Reload starts on the final shot/volley. Reserves are unlimited and separate from infantry ammunition; remaining rounds and reload survive dismounts. The rocket battery's existing mortar salvo/ballistics and technician scout-designator aid are preserved.

Hover hulls sit **25 cm above the supporting ground/floor**, below the **50 cm maximum**. Server floor queries fit the visual hull to the actual support normal, avoiding a horizontal mesh floating high over a sloped drive collider. Gun pivots and the upper damage collider follow that pose. The drive collider remains grounded and gravity controls falls; airborne vehicles are not snapped down to distant terrain. Rocket hulls use zero added clearance. Replicated support normal and visual height keep remote models and barrels consistent.

All tank profiles take full tagged ordnance, half HE grenade and zero infantry damage. Friendly-fire and spawn protection remain shared rules. Light/rocket run-over incapacitates; heavy run-over immediately kills and gibs, including already incapacitated troops. The existing repair tool now caps repairs at each vehicle profile's health instead of 100 HP: allied surviving vehicles of any supported type regenerate at **30 HP/s**, with the existing short-range physical contact/occlusion checks and actual-restoration XP. Wrecks cannot be repaired.

Living medics see a billboard **pie countdown** over allied incapacitated players within 100 m. The filled sector uses replicated `downed.remaining / BLEED_SECONDS`, so it follows the authority's ten-second revival window and its pause during active injection. The marker respects scene depth, works per eye, shares one quad mesh, and adds no physics or lights. Other classes/enemies cannot see it; revival, bleed-out, death or removal hides/removes it.

Assets: [Futuristic Hover Tanks](https://opengameart.org/content/futuristic-hover-tanks), KillGorack, CC0. The source Light Class is light; source Medium Class is the heavy role. Optimization preserves original camouflage, metal and stripe color networks baked into one mipmapped 512² atlas per model. Light is **702 triangles**, heavy **2,229 triangles**, each three independently movable meshes using one opaque material. Source showcase HDRI/floor/lights/normal maps/glass are excluded. Godot mesh LODs, baked jungle material conversion and shared distance/frustum policy are retained. `tools/hover_tanks/export_tanks.py` reproduces the assets from the archived source blends; `mesh-budget.json` records scale/pivots and triangle counts.

Independent `ctk:` records now include vehicle kind, magazine rounds, visual height and support normal in addition to the existing crew, movement, health and clock-adjusted deadlines. Protocol: **`fpsloppa-cq-frontier-12-hover`**. For main-branch reuse, port the battery service/hull/view and existing vehicle hooks, hover models/import policies, definition tag in class combat, profile health caps and the medic `revival_timers.gd`/shader draw hook together. Existing class snapshots already carry the authoritative revival state, so pies require no additional timer messages.

Validation: `cq_hover_tanks.gd` covers counts, boarding, damage/repair caps, mouse/tracked pitch clamps, magazine counts, paired barrels, reload deadlines/unlimited ammunition, mobility, immediate heavy gibbing, actual 30 HP/s repair tool contact, medic visibility/privacy/time, profile replication, model pivots and a 20° sloping-floor ride-height check. `cq_hover_network.gd` uses two real ENet peers on port 28809 with different clocks to check all eight vehicles, exact round counts, reload timing, pitch/ride height, health, crew release and medic remaining time. Original battery gameplay, class integration and autonomous turret regressions pass. Native Vulkan Forward+ `preview_hover_tanks.gd` captures military/relay/radar/canopy placements, elevation-limited aiming feeds, reload HUDs and 100/50/15% revival pies in `test-results/hover-tanks/`; it verifies view replacement/restoration and timer removal. Existing ObjectDB/resource and PulseAudio teardown warnings remain in the test harnesses.

## Vehicle road mobility, water and crew destruction (2026-10-13)

All rocket/light/heavy vehicles gain **25% forward/reverse speed, acceleration and hull turning** on terrain painted as road. Off-road profiles remain unchanged. `Landscape.is_road` uses the same indexed asphalt widths and 0.9 m access-lane paint boundary as terrain generation; painted center lines count, shoulders do not. The drive point must be within 1 m of the terrain height, preventing elevated structure floors over roads from gaining the bonus. Road exit smoothly returns speed toward its normal limit through the existing acceleration model. No extra road meshes, collision areas or draw calls are introduced.

Water is no longer blocked by an invisible vehicle-driving barrier. After physical movement, the hull's center and four footprint corners are checked against the shared water killzone, using the supporting hull plane. Any submerged contact destroys the vehicle, including an empty vehicle that falls into water. Bridges/floors above the water surface remain safe. A destroyed vehicle has zero health, speed, velocity, magazine/salvo and collision layer; it cannot fire further rounds, be driven, boarded or repaired until the existing round reset.

Combat or water destruction with a player aboard releases the seated camera/avatar/collider state and applies **10,000 bypass destruction damage**, causing immediate fatal gibbing rather than incapacitation. Armor and temporary spawn protection cannot save a destroyed crew. Combat damage/blasts forward attacker IDs for normal kill/XP/team-score attribution; water death is self-attributed. Destruction cannot award duplicate deaths from repeated hits on the same wreck. Existing ordnance/grenade/infantry and friendly-fire filtering still governs whether combat can destroy the hull. Remote clients receive the existing wreck/crew snapshots and reliable gib effects; revived/spawned players retain the ordinary respawn path. Unlocking a replicated dead crew member no longer re-enables their player collider.

Protocol: `fpsloppa-cq-frontier-13-vehicle-surface`. `cq_vehicle_surface.gd` verifies terrain road/access/shoulder-height classification, forward/reverse/acceleration/turn bonuses and original off-road behavior for all three profiles, armored/protected crew gibbing and attacker kill credit, actual authored river immersion, empty wrecks, firing cancellation and bridge clearance. `cq_vehicle_surface_network.gd` uses two ENet peers on port 28811 with different clocks to verify occupied combat/water destruction, fatal gibs, seated/revive state removal, attacker credit and ordinary respawn. Original battery and hover gameplay regressions pass. Validation logs are stored under `docs/validation/voxel-battle/vehicle-surfaces/`.


## Animated attachments, bounded reach and body recenter (2026-10-13)

UT99 guns now attach to sampled hand vertices instead of raw controller origins or a fixed desktop hand approximation. Runtime attachment samples are computed once when the validated model loads; the `.utavatar` format and imported assets do not change. The selected hand vertex has full forearm IK influence, so its CPU attachment interpolates the same native frame samples and solved forearm transform as the vertex shader, including distance fade. Prone rotation applies to the attachment position. Gun aim orientation remains the aiming orientation. Incapacitation clears tracking but retains handedness, so the weapon follows the native downed hand rather than switching hands or floating above the body.

Model upper-arm/forearm lengths and existing elbow/shoulder limits remain authoritative. Hidden first-person bodies continue the local socket/IK update, with controller gloves and gun at that rendered wrist. Controllers still supply orientation and input; reaching farther cannot extend the model's arm. Visible weapons are no longer independently translated for muzzle clearance; existing shot-clearance checks still block obstructed fire. Rendered XR shot origins use the attached hand. Dedicated servers retain a compact native reference reach profile in verified avatar metadata and constrain XR muzzle origin without allocating avatar GPU resources. Their reach calculation uses reference shoulder sockets; cosmetic animated hand positions can differ slightly from those server anchors. Desktop gameplay keeps its crosshair ray.

The jetpack front contact plate is mounted to the midpoint of two animated back-surface samples. It follows the animated torso basis and prone rotation each avatar frame. Class utility kits mount on the offhand shoulder and radios on the mainhand shoulder, mirrored for left-handed players. Carried equipment reuses existing kit/grenade models; deployed boxes/turrets/drone entities retain their world placement. Existing radio grab/trigger and grenade use still work; a grabbed item follows the constrained offhand. The shoulder radio remains visibly holstered when its voice mode is off.

Standing players can hold a steady controller T-pose for 1.1 seconds to recenter their body under the headset and recalibrate standing height. Both controllers pulse on completion. Lower arms before repeating; the detector has a five-second cooldown. Menus, lost tracking/focus, incapacitation and vehicle seating suppress this gesture. Calibration does not derive arm length from controller span. Seated users retain the manual recenter control. The settings tracking page describes the gesture and removes retired full-body/OSC controls and the spring-bone toggle; presentation settings no longer load the VRM spring runtime.

Vehicle drivers default to team radio when their team and voice settings allow it. This selects the channel, not an always-open microphone: existing PTT, voice activation, focus and permission controls still gate transmission. Dismount restores proximity voice. Verified downloaded avatar assets now publish as `.utavatar`, correcting a stale `.vrm` cache suffix and preserving skin/model synchronization.

Protocol: `fpsloppa-cq-frontier-14-avatar-attachments`. Validation: `ut99_attachments.gd` passes 964 checks across all five base models and animated/prone sockets, extreme controller reach, both handedness settings, cleared tracking and calibration latching. `cq_avatar_mounts.gd` checks the actual simulated XR rig, hidden-body updates, glove/gun alignment, shoulder kits, the calibration menu, recentering, GPU-free server reach and driver radio gating. `ut99_ik.gd` passes 62,316 arm cases; `ut99_lod.gd` passes 107 checks; `ut99_avatars.gd` passes 231 checks including network cache publication. Physical interaction, CQ class integration and vehicle-surface regressions pass. Native Vulkan Forward+ front/back captures are in `test-results/ut99-attachments/`; this was a desktop visual and simulated-controller check, not a live WiVRn headset session. Validation logs are archived in `docs/validation/voxel-battle/avatar-attachments/`. Existing CQ fixture resource/ObjectDB warnings remain at shutdown.


## Texture mipmaps and retained physical movement (2026-10-13)

Mipmap generation is the project default for new texture imports. The existing checkout's missing import flags were enabled and reimported: 1,018 images changed, including game, experimental, addon and preview images. `tools/texture_mipmaps/enable_imports.py` can repeat this pass on an older checkout whose ignored `.import` sidecars already exist; then run Godot with `--headless --xr-mode off --editor --path . --import`. A second policy pass reports zero missing flags.

`deathmatch/textures.gd` generates missing runtime mipmaps at texture allocation and terrain upload, with a guard for existing chains and 1×1 images. This covers UT99 frame/skin textures, SVO textures, map previews, light atlases, LibreQuake fixtures, factory textures and the MDL experiment. Streamed terrain arrays, coarse fallbacks and page tables retain matching mip layouts across initial allocation, updates and eviction/reset. Terrain color sampling now uses mipmaps and anisotropic filtering. Numeric height, vertex-frame and tree/page lookup sampling still reads exact level zero; validation checks that generating mipmaps leaves base bytes unchanged. Completed light atlases regenerate their chain after authored base pixels change. Existing authored color-mip/alpha-coverage generation remains intact. SVO resident-byte accounting includes its generated chain. Mipmap chains ordinarily add approximately one third to texture storage; the existing texture sharing, streaming and culling remain in place. Live viewport/render targets retain their independent engine sampling.

Physical crouch and prone remain enabled by default; physical jump remains available as an opt-in control. All three remain in the bindings menu and controller input path. The actual simulated XR fixture verifies crouched/prone authoritative capsule heights and a physically detected jump after real grounded contact. Movement replay validation now permits the retired tracking `assist` field to be absent, while validating its type when present; the updated crouch replay test retains headset height without removed face tracking.

Validation: the native Vulkan Forward+ audit (`tools/texture_mipmaps/validate.gd`) verifies 1,069 imported textures, 55 embedded model/material textures and 11 runtime checks, including an actual streamed upload and a completed light atlas. Physical XR, crouch/prone/water/replay, filter-variant, authored color-mip and UT99 attachment checks pass. Logs are archived in `docs/validation/voxel-battle/texture-mipmaps/`. Additional broad legacy checks encountered unrelated fixtures: `quake_light.gd` references an absent `maps/qsrc_dm6.bsp`, and `map_presentation.gd` fails its Vesper camera geometry assertion. These map fixtures were not changed by this texture/movement work.


### Rocket battery area barrage

The rocket battery locks a nominal terrain impact point when its eight-shot salvo begins. Each rocket receives a separate unguided ballistic trajectory toward one of eight angular sectors inside a **15 m radius** footprint. The radius uses world meters rather than an angular cone, so dispersion does not increase with range. The same spread applies when a technician follows an allied scout laser designation; the laser supplies the center aiming solution and never removes dispersion or adds homing. The helper now accounts for muzzle movement as the barrel turns. Turning the hand during a salvo does not drag its locked impact area.

Normal shots retain the ST launch speed, gravity, hull velocity inheritance, arming, bounce, damage and 30-second reload. Near maximum ballistic range, offsets shrink until reachable. If vehicle movement makes even those offsets unreachable at fixed speed, the fallback preserves a small nonzero bounded offset and adjusts launch velocity for the original flight duration. The footprint describes intended ballistic endpoints: terrain, buildings, infantry and early unarmed impacts can intercept or bounce the existing projectiles. Light and heavy tank shots are unchanged.

The server predicts the nominal map impact once per salvo and solves each rocket once when it launches. No homing or additional per-frame work is added. Existing projectile replication carries authoritative velocity plus the locked center, intended endpoint and flight duration. Protocol: `fpsloppa-cq-frontier-15-battery-barrage`. For reuse, port the battery service changes alongside the shared `ballistics.gd` solver and the existing projectile `launch_velocity` hook.

Validation: `cq_barrage_ballistics.gd` checks 192 elevation, low/high arc, maximum-range and inherited-motion cases plus unreachable fallback. `cq_battery_tank.gd` checks actual eight-round endpoint velocities, bounded dispersion and laser-assisted spread. `cq_battery_network.gd` checks replicated dispersed trajectories with two ENet peers; existing hover and vehicle-surface tests cover unchanged volley, armor, road and water behavior. Logs: `docs/validation/voxel-battle/battery-barrage/`.

### Unified jungle CQ and movement

The frontier's default movement is the CS 1.6 implementation ported from main at `bb5d0b19939ab807186bbb61ca2f1618c0621fe1`. It uses a 250-unit/s (7.8125 m/s) base run speed, analog input, ground friction/acceleration, capped air acceleration, walking, crouching and jump fatigue. CQ prone keeps its existing 18% crawl speed and cannot jump; physical crouch/prone/jump and shocktroop jetpack remain available. CS uses the main branch's flat-ended cylindrical player hull. Other branch modes keep their existing movement.

CQ now uses CS movement exclusively. The Quake setting and RCON movement command have been removed; legacy config entries are ignored, and snapshots cannot switch prediction profiles. New players always use flat-ended CS cylinders. The CS-only protocol revision requires matching clients and server. CS fatigue continues to travel in locomotion snapshots and is corrected against the acknowledged command.

All eleven authored POIs have a **3 m radius, ground-floor capture cylinder** inside a covered room:

| POI | Capture room |
|---|---|
| Town | Town hall |
| Factory | Dispatch |
| Port | West warehouse |
| Military | West barracks |
| Radar | Radar control |
| West ridge relay | Relay control |
| Canyon crossing | Crossing guardhouse |
| River expedition camp | Expedition laboratory |
| Canopy outpost | Outpost storehouse |
| Summit observatory | Instrument lab |
| East ruins | Archaeology shelter |

All start neutral. An uncontested, continuous ten seconds captures a POI, independent of squad size. Both teams present pause capture; leaving resets that team's progress. Capture checks require a living on-foot player, the existing height bound and clear line of sight within the room. Seated vehicle crews, incapacitated players, spectators and actors behind walls cannot capture. Prone players can capture. Owner-colored floor rings and labels show ownership, capture progress and contest state without adding collision, lights or shadows.

Each held POI generates **1 point every 10 seconds**. A capture starts a fresh income clock and grants no immediate points. The owner continues to receive income while contested until ownership changes. An enemy kill awards **one point multiplied by the killer's team's held POIs**; zero held POIs means zero kill points. Suicides and friendly kills award no CQ points. Class XP and individual kill statistics remain separate. The first team to reach **200** wins; a genuinely simultaneous holding-income threshold is a draw. Scoring stops immediately at the result. Match restart clears ownership, capture progress, income clocks and scores. The old frag/time inputs are not CQ victory conditions; the host UI hides them and the HUD shows FIRST TO 200.

`deathmatch/conquest/frontier/points.gd` is a reusable pure rules model. It splits long simulation steps at capture/income boundaries, so a late income event cannot overtake an earlier winner and newly captured POIs receive no retroactive income. `objectives.gd` owns placement, authoritative presence and distance-limited presentation. Ownership/progress/contested/income state uses independent `cqo:` records, keeping each record within the existing packet budget; `cq_points` carries scores/result. The frontier still uses `tdm` as the base implementation's internal team-mode carrier to avoid enabling the incompatible legacy district session. Its scoring, status, round termination and objectives are overridden completely; the dedicated config and administrative status identify it as CQ.

For main reuse, port the frontier rules/objectives and class-match hooks, default actor CS profile, authoritative movement record, CS fatigue prediction/snapshot support, timer hook and host/HUD changes together. `deathmatch/movement/cs16.gd` itself is the main movement implementation. Protocol: `fpsloppa-cq-frontier-16-poi-points`; update clients and server together.

### Unified server deployment assessment

Use `./launch-frontier-server.sh` to start the source-tree headless authority with `tools/voxel_battle/cq_classes.cfg`. The target profile is **32 players, monolithic backend, 30 Hz physics, 20 Hz snapshots, no automatic bots**. `sv_cq_tick_rate` accepts 30 or 60; it changes the dedicated server only, leaving clients at their normal prediction/render rates. Generic/legacy configs default to 60 Hz. The existing district worker arguments/backend are rejected by the frontier, and the older packaged CQ worker export is not a frontier package. For deployment, export/include the frontier scene, its new script dependencies, native networking extension, verified UT99 avatar assets and jungle physics/baked assets.

A unified map does not require worker sub-servers for territory ownership. The existing workers are tied to fixed legacy district origins, portals, handoffs, district collision assets and coordinator capture rules. They cannot simply divide this jungle map. Rockets, tanks, airstrikes, drones, spotting and healing fields can cross hypothetical shard borders, so a new worker design would also need cross-border collision/damage authority, single-owner entities and consistent capture/scoring. Running those legacy workers would add overhead without providing valid frontier simulation.

`tools/voxel_battle/server_capacity.gd` probes the full map at 32 and 64 scripted shooting/moving players, both 60 and 30 Hz, with 3-second warmup and 30 simulated seconds per case. It uses the real class/weapon/projectile/vehicle/objective simulation and map collision, including 90,928 environmental colliders. It measures authority simulation, the projectile subset, snapshot construction and native encoding, engine physics-loop time, process RSS and static allocations. Snapshot traffic is the encoded 20 Hz stream multiplied by player count, including a 64-byte packet allowance; it is a fanout estimate, not measured socket traffic. AI, rendering, live XR, VOIP and cache-miss avatar transfer are excluded. The local host is an i7-12700, not the target VPS. These figures require a soak test on the actual VPS before treating the player count as certified.

The deployment choice is one authoritative process first, with 32 players and 30 Hz. RAM and a 1 Gbps link have substantial expected headroom for this workload; CPU scheduling and single-thread performance are the main uncertainty. Twelve vCPUs do not make one GDScript game loop twelve times faster. Reserve CPU headroom for the OS, network/asset jobs and bursts, and monitor tick p95/p99 and catch-up pressure. Keep the existing asset-transfer budget rather than letting uploads consume gameplay bandwidth. Voice and asset-transfer bursts must be tested separately. The 64-player probe is a stress case, not a raised network capacity limit.

If the target VPS misses the 33.3 ms tick budget, optimize actor movement/collision, class scans and snapshot encoding/interest before rebuilding territory workers. An independent worker could eventually help bot decisions or other pure computations if profiling supports it; world-authority sharding is a larger redesign and should be justified by actual cross-border workload measurements. Current recommendation: **no worker sub-servers for this frontier deployment**.

Validation artifacts and final measured capacity cases are in `docs/validation/voxel-battle/frontier-points/`. The full-map check also found a pre-existing stale bake fingerprint; terrain, sky and all eleven site light bakes were regenerated against current sources, rather than bypassing the stale-bake check.

Final local probe results (milliseconds; MiB for RSS):

| Players / Hz | Authority p50 / p95 | Physics loop p50 / p95 / p99 | Snapshot build p50 | Encode p50 | RSS peak | Snapshot fanout |
|---|---|---|---|---|---|---|
| 32 / 60 | 16.70 / 22.75 | 29.89 / 36.43 / 37.92 | 1.78 | 3.94 | 674.2 | 48.9 Mbps |
| 64 / 60 | 28.59 / 40.88 | 48.98 / 68.93 / 81.82 | 3.13 | 6.98 | 674.9 | 164.1 Mbps |
| 32 / 30 | 15.59 / 21.65 | 28.40 / 32.78 / 34.19 | 1.50 | 3.29 | 674.9 | 41.7 Mbps |
| 64 / 30 | 28.92 / 39.61 | 50.39 / 57.04 / 57.87 | 2.62 | 6.05 | 675.0 | 174.4 Mbps |

The physics-loop figure includes overlapping authority/physics/snapshot work and should not be added to the other columns. At 32 players / 30 Hz, p95 is already close to the 33.3 ms budget and p99 exceeds it. This is a **provisional deployment preset**, not evidence of spare CPU capacity on an unspecified VPS. Both 64-player cases exceed their tick budgets. The warm-cache full-map startup took 7.96 seconds. Large/reliable snapshot fallbacks also occurred frequently under projectile churn; inspect that path and interest filtering during a real network soak test, rather than assuming all traffic remained small UDP packets.


Checks passed: pure capture/scoring rules; all eleven room bounds and standing clearance; LOS/incapacitation/vehicle exclusions; 200-point round termination/reset; real ENet ownership/income/movement/result replication; CS movement and fatigue/jetpack integration; local prediction; existing class packet-budget/ability, physical XR attachment/movement, rocket barrage and hover-tank regressions. Native Vulkan Forward+ screenshots verify ownership/capture progress in the town and factory rooms. Test fixture teardown still reports the known ObjectDB/resource warnings.

## VPS CQ deployment — 2026-10-13

CoreCU completed save-and-exit on the SWGXR VPS, with original persistent state retained. Unified CQ is enabled as `fpsloppa-cq.service` on `87.106.27.237:7777/UDP`, 32 seats at 30 Hz. A full client joined over WAN after the user enabled the provider firewall rule. The 32-player ENet fleet completed at 29.94 Hz; the 64-player live fleet failed to sustain admission/connections. Its isolated full-map simulation reached 24.40 Hz. These tests use scripted movement and synthetic tracked poses, initial magazine firing, no AI and no rendering. See [the measured breakdown](validation/voxel-battle/vps-20261013/REPORT.md) and [deployment/recovery instructions](../tools/frontier_vps/README.md). Test-only service flags were removed.
