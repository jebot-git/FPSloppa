# Tribes deployables

ST supports seven purchased backpack deployables. The existing inventory wheel
has **DEPLOYABLES** and **SENSOR NETWORK** pages. The former selects a pack for
the normal purchase/refit transaction; selecting it alone does not grant it.

| Pack | Price | Team limit | Service/detection range |
|---|---:|---:|---|
| Remote turret | 350 | 10 | 30 m; travelling 80 m/s energy bolts |
| Remote inventory | 3,200 | 5 | Local inventory pad; 3,000 reserve |
| Remote ammo | 2,500 | 7 | Local resupply pad; 2,500 reserve |
| Pulse sensor | 125 | 15 | 200 m; line of sight; jam-sensitive |
| Motion sensor | 125 | 15 | 50 m; moving targets; not jam-sensitive |
| Remote jammer | 225 | 8 | 80 m friendly pulse-detection suppression |
| Camera | 100 | 15 | 50 m detection cone and friendly video feed |

Light cannot carry the turret or either station. Medium and Heavy can carry
all types. Limits are per team. Turrets also enforce close and area spacing
limits; all equipment rejects obstructed or overlapping placement. Stations,
turrets, pulse sensors and jammers require reasonably level support. Cameras
and motion sensors accept wall mounting. A wall camera points away from its
mounting surface, with its render origin outside the lens housing.

## Controls and authority

Desktop: aim at a surface within 3 m and press the existing **Use** action.
VR: take the pack control at the offhand chest attachment, hold grip, aim the
offhand at the surface, and press its trigger. The weapon stays in the dominant
hand. The attachment uses the existing tracked hip/chest frame and mirrors for
left-handed players. A green model previews valid local placement. Invalid
placement retains the pack. Successful placement consumes it and removes its
trade-in credit without refilling jet energy.

The authority checks life/pose/request guards through the existing equipment
interaction, plus origin reach, line of sight, actual BSP collision, surface
normal, player clearance, playable bounds, armour and deployment limits.
Fixtures become active after one second. They take weapon/blast damage, honour
team damage rules and accept friendly repair-gun fire. Destruction frees the
team's deployment slot. Late join, snapshots and demos carry their state.
Network protocol: `fpsloppa-59-st-deployables`.

## Services and sensors

Remote stations work without the base generator and spend their own finite
reserve, even when team buying energy is unlimited. Remote inventory preserves
the user's armour class and cannot purchase another inventory/ammo station.
Both remote station types replenish ammunition and repair kits. They do not
provide the fixed inventory pad's automatic armour repair.

Sensors scan at 5 Hz. Pulse detection requires line of sight; motion detection
requires movement. Personal and remote jammers suppress pulse detection.
Cameras use a viewing cone and line of sight. Friendly sensor contacts can let
a remote turret target a stationary enemy; its own detection otherwise needs
movement. Turrets still require line of sight and launch real projectiles.

The sensor wheel lists up to four cameras per page and a contact count, keeping
at most eight sectors. The camera feed is 512×288 at at most 10 updates/second.
Desktop uses a panel; VR uses an offhand panel without moving the headset view.
Use/Escape closes it. Death, team change, camera destruction, menus and mode
changes also close it. Contact markers are depth-tested in the main view.

Bot maintenance specialists can buy and place two defensive remote turrets per
team while the base and flags are secure. Placement uses the same world checks
as player deployment. Bots now repair damaged friendly deployables and attack
visible hostile turrets; siege bots also attack other remote equipment. Wider
placement planning for stations, sensors, cameras and jammers remains future work.

## Sources, assets and limits

Prices, limits, armour restrictions and numerical equipment behaviour were
checked against the pinned [community base item scripts](https://github.com/shayk-siege/t1.41-base/tree/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items).
These are not authenticated retail sources. General behaviour is described in
the [original manual, pp. 44–52](https://www.the-flet.com/dynamix/t1/TribesManual.pdf).
Durability uses the same `.66 → 100 HP` normalization as the personal arsenal.

Models and seven icons are original project geometry/vector art. Native mesh
parts share three material groups, with separate aimable turret/camera heads;
there are no added skeletal/spring-bone costs. Icons are imported as mipmapped
compressed textures. The remote turret reuses existing Tribes blaster audio.
No external retail assets were copied. Models remain a simple first pass.

The video panel, contact display and shared remote service volume are practical
adaptations, not the original commander interface. The separate
[fixed medium sensor network](TRIBES-INFRASTRUCTURE.md) is operational; fixed
turrets and player-controlled turrets are absent. Desktop rendering, rules and
ENet replication are checked; physical headset usability and a full deployment
limit stress test remain unverified.
