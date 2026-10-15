# Resident CQ authority

The experimental CQ server has an opt-in resident C++ authority. Godot retains ENet admission/transport, UTX assets, scene lifecycle, navigation queries and Jolt integration. Enable it on a dedicated CQ server with `--cq-native-authority`. The normal server path remains available; this flag does not modify a live deployment. Both ends require `fpsloppa-cq-frontier-22-live-fixes`.

## Ownership and reuse

The `addons/fps_native/src/authority_*.{h,cpp}` modules, except `authority_world.cpp`, are host-independent C++17. They retain typed player, input, combat, CQ, vehicle, utility and snapshot state across ticks. `authority.{h,cpp}` and `authority_world.cpp` implement the Godot adapter. Standalone tests link the same core. Import the complete source list from this directory's CMakeLists or the addon SConstruct when reusing it in main.

`FPSAuthority` is constructed/configured once per map instance. Cold configuration imports authored terrain/roads/water, capture sites, spawns, lamps, vehicles, avatar reach, class XP and choices. Actor attachment gives the core an identity and exclusive Jolt cylinder. Inputs use authenticated RPC sender IDs and bounded binary packets. Only the core mutates gameplay state; there is no per-tick import/export of authoritative player Dictionaries. Inspection and snapshot Dictionaries are detached diagnostic/client presentation copies.

Advance exactly once per configured physics frame, on the engine owner thread. Production defaults to 30 Hz. The experimental `configure_tick_rate(60)` API must be called before actors or ticks exist, and the engine physics rate must match. The adapter rejects unsupported/mismatched rates, duplicate/out-of-physics advances and foreign threads. Gameplay clocks, integration and cooldowns use the configured step; snapshot construction/publication remains 20 Hz. Scene/Jolt operations remain on that thread. Core phases include native bot planning, input consumption and movement commits, ordered combat/query commits, projectiles/entities, CQ mode and frame publication. This explicit order defines this authority's behavior; it is not a claim of instruction-for-instruction equivalence to the old interleaved script loop.

For the experimental 64-player adaptive mode, add `--cq-adaptive-tick` alongside
`--cq-native-authority` on a dedicated server. It starts at 60 Hz, requests 30 Hz
after two consecutive two-second windows with callback p95 above 15 ms or
simulation/wall-time ratio below 0.92, and recovers only after at least 30 seconds
at 30 Hz plus ten consecutive windows below 11 ms p95 and ratio at least 0.98.
An emergency half-second window falls back sooner if at least 25% of callbacks
exceed 16.67 ms or simulation/wall-time ratio drops below 0.85.
The governor observes the complete host callback (including snapshot fanout), and
wall-time cadence catches sustained work outside it. Pressure reflects an early
headroom threshold, not just ticks that already exceed their budget. This does
not certify a tight 60 Hz schedule or guarantee recovery if headroom is absent.

Rate changes commit in idle processing, outside physics, with the native step and
engine rate changed together. A rate-independent integer 1/60-second clock and
20 Hz publication phase preserve timers, history and snapshot timestamps. Clients
use explicit simulation timestamps rather than dividing tick IDs by a rate.
Existing CQA2 presentation already carries simulation time in its mode section;
no wire-format change is required. Default team/squad limits remain 32/8 (64 total).
Set `sv_cq_maxclients "64"` in the isolated server config to admit the full target
population; the existing supported-capacity configuration remains 32 total.
Without this opt-in flag the existing fixed 30 Hz native path remains unchanged.

The bridge lives in `deathmatch/native/cq_authority.gd`. It bypasses the old gameplay/history/snapshot loops, retains Godot admission, asset downloads, votes and scene navigation, and sends native frames. `cq_presentation.gd` projects them into existing client prediction, model, HUD, tank-camera and effect APIs. `authority_protocol.gd` is an independent semantic decoder; FPSCodec's native validator is used by synthetic load clients to avoid measuring many GDScript decoders in a single process.

## Implemented surface

- CS movement, stance/physical crouch/prone/jump, room-scale rebasing, jetpack, constrained UT99 tracked reach and head/weapon anchors. Quake movement is absent.
- Typed physical reloads, magazines/packs, offhand tools/fire, redundant fire/jump edges, melee sweeps; CQ firearms, guided projectiles, head/body anatomy, rewound hit queries, blasts and fields.
- Damage/armor, incapacity/bleedout/revival, dragging, death/gib feedback, spawn selection, next-life classes/loadouts, XP, supply boxes and weighted resupply.
- CQ capture/income/kill points, rounds/restarts, spotting, day/dusk/night/dawn, NVG/glare, recon, airstrike, grenades/healing fields, autonomous turrets.
- Rocket/light/heavy tanks, scene hull collision, aiming/mortar spread, road mobility, water destruction, damage/repair, run-over, boarding/dismounting.
- Native prototype bots: bounded 5Hz perception, capture goals, steering, weapon lead/reloads and class tools. Existing authored navigation is a host query. This is a new planner, not a behavioral port of every legacy AI feature.

Life generations reject stale inputs/actions and victim identities. A separate stable connection session carries delayed kill credit across respawn; reconnect/reused peer IDs cannot inherit it. Administrative restart resets gameplay without round XP. Map rebuilding preserves cold XP/choices/cooldowns and reconstructs native state. Dynamic native turret bodies are freed by the adapter; authored tank bodies remain scene-owned. Respawn restores standing collision after prone or vehicle death.

## Bounds and wire

Storage bounds are 128 players, 32 queued commands per player and 2,048 projectiles. These are storage bounds, not capacity promises. Inputs expire after 350ms. Invalid commands/overflow do not consume sequence numbers. No unbounded per-tick job queue exists.

Wire scalars are little endian without native struct padding. CQI1 remains the 30-byte fixture input. CQI2 adds bounded validated tracked transforms, room displacement, action flags, rewind time and redundant edge counters (maximum 310 bytes). Reliable discrete actions additionally carry life, map epoch and sequence. Legacy lifeless gameplay RPCs are rejected for native peers.

CQA1 retains 104-byte base player rows. CQA2 appends TLV sections for poses, physical reloads, projectiles, jetpack, classes, CQ mode/zones, boxes, fields, vehicles, turrets, flights, grenades, effects/damage feedback and player extras. See the encoder/decoder for exact layouts. The frame limit is 1MiB. At 20Hz publication over 30Hz (or explicitly experimental 60Hz) simulation, the host compresses once and fans out shared pieces of at most 960 payload bytes. Each client retains only one bounded assembly and publishes complete validated frames. Admission/control use reliable RPCs; input and frame channels are separate.

CQ is the supported mode in this path. Legacy TF/CTF/assault/district worker authority and waiting lobbies are not migrated; native startup rejects enabled lobby mode. VRM and face/body tracking are outside this branch's UT99 scope. Full rendering/XR device behavior still requires interactive testing; headless tracked tests supply synthetic controller poses.

## Reproduce

```sh
python3 tools/build_gameplay_native.py --target linux --server --container -j 8
python3 tools/authority_core/run_arena_suite.py --output /new/real-arena-results
python3 tools/authority_core/run_suite.py --seconds 120 --players 32 64 --cq-core --tracked --jungle-map --output /new/normal-results
python3 tools/authority_core/run_suite.py --seconds 120 --players 32 64 --cq-core --tracked --jungle-map --stress-test --output /new/stress-results
```

The real-arena suite exercises actual asset admission, full client prediction/presentation, desktop and tracked shooting, grenades, NVG, prone suicide/gib/respawn, team change and jetpack. A separate actual-map bot smoke checks navigation displacement. Neither test is a rendered headset test.

The load suite verifies the portable source receipt, compiles standalone tests and golden GDScript references, runs five real Jolt functional suites, then launches separate fixture server/client process groups. It rejects diagnostics, source/library changes, bad frames, disconnects, queue saturation, insufficient workload and low achieved tick rate. Eight seconds of startup warm-up is recorded separately, including ENet throttle telemetry. Both normal finite-ammo and explicitly marked stress (reserve refill/combat invulnerability) workloads are available. Physical magazine/reload rules still apply under stress.

```sh
cmake -S tools/authority_core -B /tmp/cq-authority -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/cq-authority -j 8
ctest --test-dir /tmp/cq-authority --output-on-failure
python3 tools/authority_core/run_sanitizers.py --golden /generated/golden --output /new/sanitizers
```

Use `reference_export.gd` or the full runner to generate golden references. Standalone tests include deterministic 64-player replay, exact GDScript movement/jetpack/anatomy/melee comparisons, independent collision oracle, malformed input/frame mutations, CQ abilities/vehicles, attribution and identity isolation. Sanitizers run the same source without Godot; functional tests separately cover actual Jolt/adapter behavior.

## Interpreting measurements

The fixture can use the real authored jungle collision map, all 11 POIs, eight vehicles and four CQ classes, but has no rendered avatars or production client UI. It is not a lethal full multiplayer match. The real-arena smoke separately covers actual integration.

`callback_us` includes native advance, metrics copying, compression and RPC enqueue. Child categories separate AI, movement/collision, combat/queries, CQ mode and frame encoding; Godot physics, transport polling and scheduling outside that callback are excluded. Percentiles cannot be added. Inspect accepted/offered inputs, sustained shots, projectile/ability counters and per-client frame delivery alongside tick rate. Startup ENet throttling was observed, so warm-up and measured counters are separate.

The current engine-thread design does not claim to use all 12 VPS vCPUs. Parallelizing short pure-state loops may cost more than it saves. Measure the remaining Jolt movement/query work and transport before introducing synchronization. Local fixture results cannot establish VPS capacity or a speedup against a different full-CQ workload. Loopback VPS clients compete for the same CPU and do not validate WAN behavior.

## Portable VPS suite

Release export templates do not expose the editor's `--script` launcher. The packaged frontier entry accepts `--resident-suite` and creates the same fixture through `tools/frontier_vps/resident_driver.gd`. This wrapper detaches completed client RPC roots during the disconnect signal, before the Godot 4.7.2 cache reset, avoiding an engine bound-callback disconnect mismatch. It does not suppress diagnostics or alter authoritative simulation.

Package with `tools/frontier_vps/package.py`, then copy the adjacent binary, PCK, native libraries and release checksums together. Copy `run_resident_suite.py` separately and run on the VPS:

```sh
python3 run_resident_suite.py --bundle /isolated/release --output /new/results --seconds 120 --suspend-service fpsloppa-cq.service
```

Suspension is optional and must be explicitly requested by the operator. The runner verifies release checksums and same-user service identity, checks that no service watchdog is enabled, forks a detached PID-identity guardian, suspends the existing process, and always resumes it in cleanup. It changes no unit, release symlink, server configuration or firewall. Four cases run on loopback UDP 27939: 32/64 finite-ammo, then 32/64 stress. Client processes share the VPS CPU with the server. WAN delivery, rendering and a populated bot battle remain separate gates.

The jungle bot path uses authored ground/road seam links and bounded short-leg queries. It omits the inherited whole-mesh jump-boundary scan; physical player jumping remains supported. Existing authored navmesh edge-merge warnings are retained and counted in bot smoke evidence, rather than globally disabled.

## VR interaction continuation — 14 October 2026

The VR port now keeps local hands and gun anchors in live controller space. Avatar
vertex animation and its anatomical IK remain a remote/preview presentation layer;
they no longer move the local hands, shoulder props or authoritative CQ muzzle.
CQ calibration preserves metre-scale world geometry. Shoulder, chest and belt
attachments follow the tracked headset, including leaning and recentering.

The resident core uses immutable muzzle, magazine, charging-lever and support
anchors generated from the client CQ model manifest. Run
`python3 tools/authority_core/generate_weapon_geometry.py --check` after changing
that manifest. Physical magazine pulls/ejection/insertion retain chambered rounds
and reserve accounting; the local pouch, carried ammo and bounded discarded
magazines visualize the authoritative state. The native recoil state adapts main's
CS recovery, movement/stance bloom, unsupported-long-gun penalty and active
support-hand correction to the CQ arsenal. Secondary pistols require a new trigger
press; CQ burst, salvo, charging and guided-weapon rules remain separate.

A newly admitted human is staged with collision disabled and is excluded from
movement, damage, anatomy/history traces and capture until explicit deployment.
The client first opens class/loadout, skin and calibration preparation. The
calibration submenu includes a private live avatar/controller preview and an
alignment-confirmation button. Selecting a class/equipment before deployment is
applied when the player enters. Confirmed players remain deployed through map
reconstruction; reconnecting requires preparation again. The CQA2 class-state
flags now include staging (bit 8), and reliable action 10 requests deployment.
Both independent frame validators and client projection handle this flag.
Grip presence/value use CQI2 bits 8192/16384; omitted grip retains legacy fixture
behavior. CQA2 class bit 16 marks a released VR weapon. Native combat rejects
released-weapon firing and interrupts reload activity; remote presentation renders
the two owned weapons on the same head-relative mounts used locally.

Default VR controls: grip the chest primary or hip secondary to draw it; release
that grip to return it to the holster. The support grip manipulates magazines and
charging handles and fetches ammunition from the offhand belt pouch. The weapon
hand's reload binding releases the magazine. Move-hand A/X invokes use/boarding.
Thumbstick Y changes supported optic magnification; it no longer cycles weapons.
Mouse-wheel and number-key weapon cycling are disabled for this CQ arena. Virtual
stock is enabled by default and can be toggled in calibration. Raw tracking drives
reloads; cosmetic recoil never feeds back into hand/gesture samples.

VR streaming uses world camera coordinates for both terrain and structures.
Light-tank visuals are centered and grounded from their authored mesh bounds,
without changing collision dimensions. Main's coloured name runs preserve the CQ
class prefix and fixed VR sizing. The soundtrack is disabled for CQ. Original
seamless day/night jungle beds and existing POI environment loops crossfade
locally, with at most two POI beds retained and voice ducking.

See the [validation and remaining live-test limits](../../docs/validation/voxel-battle/vr-interactions-20261014/REPORT.md).

## Allied ground transports — 14 October 2026

The map adds four unarmed LPMAC carriers alongside its eight tanks, two per team.
Their six authored side pods each admit one allied player. The first occupant
drives; the first remaining occupant takes over when the driver leaves or
disconnects. Use beside a free pod boards; jump dismounts through a collision-tested
exit. Driver and passengers cannot fire, throw grenades or deploy combat tools.
Passengers use their normal world/stereo camera through transparent pod windows.
There is no turret, turret collider, ammunition pool or tank scope feed.

The carrier shares rocket-tank speed, reverse, turning, acceleration, road and
ground/water handling. Native fixed-capacity life-bound seats drive passenger
positions and clean up on death, disconnect, team change, destruction and restart.
The final jump/boost edge is consumed by dismounting instead of launching another
on-foot action. The script fallback uses the same authored anchors and controls.

Vehicle kind 3 is the transport. Existing CQA2 class flags bits 5–7 encode
`seat + 1` (zero means unseated; seven is invalid). Player row sizes do not grow.
Client projection reconstructs occupants from player life/vehicle/seat state.
When a native vehicle ID replaces a differently typed local map placeholder, the
client rebuilds its body and model rather than reusing incompatible collision.

The 31,854-triangle model has one 1024 colour atlas and a separate transparent
window surface, with generated mesh LODs. `tools/ground_transport` retains source
provenance and rebuild scripts; its authoring files are excluded by the frontier
packager. Run `python3 tools/ground_transport/generate_geometry.py --check` to verify
the generated C++ anchors against the Blender manifest.

See [transport validation](../../docs/validation/voxel-battle/ground-transport-20261014/REPORT.md).

## NVG exposure and equipment cues — 14 October 2026

Native direct-source glare now uses narrow lamp/sun gaze cones; transient fire and explosions no longer set global blindness. Local GPU rendering adds strongly increased daylight grain and bounded soft flash spots per eye. Quiet short-range NVG/cloak cues follow existing accepted equipment state, without protocol growth. See [validation](../../docs/validation/voxel-battle/nvg-exposure-20261014/REPORT.md).

## Squad deployment — 14 October 2026

Resident native CQ enforces four eight-member squads per team and requires squad membership before deployment. Native actions 11/12 handle squad join and explicit POI, buddy or team-insertion spawning. Humans wait on the deployment map after death; safe terrain, current buddy life, eight-second combat locks and transport passenger capacity are checked in C++. Snapshot section 15 carries bounded squad/combat state. Clickable POI and squad markers share the destination selector. Radio single press selects squad; double press within 0.32 seconds selects team, using native roster permissions. See [validation and limits](../../docs/validation/voxel-battle/squads-deployment-20261014/REPORT.md).

## Class armour — 14 October 2026

Resident native CQ starts shocktroops at 100 armour, medics/technicians at 50 and scouts at zero. Living players within a friendly uncontested POI capture cylinder recharge two armour per second up to their class cap; overlapping POIs never stack. Existing damage absorption applies. See [validation and live deployment record](../../docs/validation/voxel-battle/armour-live-20261014/REPORT.md).

## Experimental capacity probes — 15 October 2026

`run_capacity_case.py` runs one isolated packaged fixture alongside the live service.
It verifies the bundle manifest and waits for the fixture process to own its UDP
socket before starting clients. Map construction is excluded from admission and
measurement deadlines. It never suspends or restarts the live service.

```sh
python3 tools/frontier_vps/run_capacity_case.py --bundle /isolated/release --output /new/128-30 --players 128 --hz 30 --team-limit 64 --seconds 120 --port 27959
python3 tools/frontier_vps/run_capacity_case.py --bundle /isolated/release --output /new/64-60 --players 64 --hz 60 --seconds 120 --port 27969
```

Run these cases sequentially. The default admission limit remains 32/team and
8/squad. `--team-limit 64` explicitly opts this fixture into 64/team and 16/squad;
it does not change production admission defaults or the 128-player storage bound.
This option is separate from the simulation-rate experiment.
`patch_probe_pack.py` derives an isolated Godot v4 pack from a deployed release,
replacing only registered entries and recording original/output/override hashes.
It preserves the deployed assets; it does not publish or install the result.

See the [VPS measurements and scope](../../docs/validation/voxel-battle/capacity-128-60hz-20261015/REPORT.md).

Adaptive 64-player policy and VPS validation: [15 October experiment](../../docs/validation/voxel-battle/adaptive-64-20261015/REPORT.md).
