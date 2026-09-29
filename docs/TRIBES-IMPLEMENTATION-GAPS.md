# Starsiege Tribes implementation audit — updated 29 September 2026

Scope: classic **Starsiege: Tribes CTF**, compared with the current FPSloppa
source. This is an implementation inventory, not a claim of retail-engine
compatibility. The [original manual](https://www.the-flet.com/dynamix/t1/TribesManual.pdf)
(equipment and vehicles, pp. 40–50; sensors and PDA, pp. 51–57) and the
[pinned community base scripts](https://github.com/shayk-siege/t1.41-base/tree/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server)
provide the reference. The community scripts are not authenticated retail source.

## Missing systems

| System | What remains |
|---|---|
| Vehicles | Scout, LPC/HPC, purchasing, piloting, passengers, damage/repair and theft now work. Autonomous bot pilots/transport tactics, dedicated seated avatar poses and vehicle input prediction remain. See [vehicles](ST-VEHICLES.md). |
| Commander/PDA | First pass includes terrain map, coverage circles, voluntary hierarchy, move/attack/defend orders, acknowledgements and waypoints. Teammate camera, repair orders, objective briefing and richer selection remain. See [command controls](ST-COMMAND.md). |
| Fixed defence fidelity | Fusion, mini-fusion, ELF, missile and manual mortar turrets, manual control and large pulse sensors now work. Powered equipment shields and original disable thresholds now work; retail-engine timing/heat fidelity remains. Stonehenge uses two fusion turrets at project sockets, not verified stock placement. |
| Complete base infrastructure | Multiple generators/solar sources, individual power links, equipment shields/thresholds and distinct station fixtures now work. Command terminals open the PDA, and Raindance vehicle pads provide purchases; full commander fidelity remains incomplete. Stonehenge retains its referenced inventory/generator placement. |
| Artillery coordination | Beacons, authoritative shared laser designations, blocked-arc checks and mortar/grenade aiming markers now work. Bots can designate, place beacons and use shared mortar targets; reliable coordinated artillery tactics still need match iteration. |
| Inventory recovery | Backpack/ammo/weapon transfers, stored surplus in ammo packs, partial corpse inventory recovery and repair-patch map pickups now work. Recovery uses compact cases and conservative salvage credit; headset ergonomics remain untested. |

## Implemented, but incomplete or adapted

| Area | Current implementation and remaining work |
|---|---|
| Bot team tactics | Situational assignment now handles stolen/dropped flags, escorts, visible pressure, generator recovery and replacement of dead specialists. Healthy teams release more attackers. Bounded coordinated pushes, temporary approach commitments, failure memory across respawns, wider escorts and basic carrier standoffs are now present. The [offence/defence pass](ST-OFFENCE-DEFENCES.md) adds downhill carrier exits, guarded flag passing, deliberate disc jumps, mortar support and all seven deployable plans/replacement. Learned optimal ski routes, synchronized designation and reliable contested captures remain incomplete. |
| Ski/jet navigation | Continuous skiing, walking on slow uphill approaches and staged tower flights use ordinary physics/energy. All 16 integrated unopposed captures pass (143–178 seconds), plus 19 physical routes. The steps 1–3 20-minute contested test ended Red 1–2 Blue with 20 pickups and a 120.2 km/h peak; scores occurred around 245, 817 and 1083 seconds. This demonstrates later captures by both teams, not a reliable competitive capture rate. The final construction-only deck fixes additionally pass both real Medium build routes and are in the newer Vulkan live match. See the [receipt](validation/st-parity-1-3-2026-09-28.json) for source boundaries and sampling limits. |
| Sensor network | Deployed pulse/motion sensors, cameras and jammers share contacts and feed remote turrets. The HUD has world-occluded contact markers and a contact count. Powered medium and large fixed sensors and a shared desktop/VR detection/jam status are present. The PDA now displays sensor ranges and team-filtered contacts. |
| Remote equipment | Seven deployable types are functional: turret, inventory station, ammo station, pulse sensor, motion sensor, jammer and camera. Camera viewing uses a bounded video panel; fixed turrets now have manual aim/fire through a separate desktop/VR panel. Deployed cameras and turrets now support exclusive remote aim/fire. The revised stations, turrets and deployables share the current ST art design. Headset ergonomics and maximum-population performance have not been playtested. |
| Movement and combat fidelity | Class mass, energy, thrust, weapons and damage profiles follow the documented reference. Skiing uses Godot capsule contacts, not the original engine's micro-bounce behaviour. Collision, blast falloff, hit detection and directional walking retain adaptations. Physics/weapon parity is not bit-exact. |
| Economy and power | Finite team reserves are the default; infinite buying energy is optional. Roster contribution limits prevent reconnect farming. Emergency spawn equipment and an unlimited repair-pack recovery rack are adaptations. Disabled generator housings retain their cover geometry. |
| Maps | Stonehenge and Raindance are dedicated ST maps. Their BSP29 terrain, interiors and finite invisible boundaries are reconstructions. The original mission library and terrain engine are not included. |

## Already present

- ST teams, CTF flag pickup/capture/return, thrown/dropped flags, death/disconnect
  handling, scores, capture/time limits, votes, server configuration and demos.
- Light, Medium and Heavy, recognisable team-coloured bodies retaining avatar
  heads/hands, armour health, intrinsic jets and a shared personal energy pool.
- The personal arsenal, five permanent backpack types, grenades, proximity
  mines, repair kit, repair gun, equipment favourites and station purchases.
- Base generator damage/repair, independent inventory-station and fixed-sensor damage/repair, and power-dependent base resupply/scanning.
- The seven [deployables](TRIBES-DEPLOYABLES.md), with authority-side placement,
  team limits, durability, repair, independent remote reserves and replication.

Current priority is reliable contested bot captures, carrier escape and effective
coordinated offence. Vehicles and a first PDA/remote-control pass were subsequently requested and
implemented separately; they do not establish reliable bot captures. Local ST tests must produce their first capture within
600 game seconds or terminate automatically; a later capture cannot qualify a
failed run. See the [capture reliability follow-up](ST-CAPTURE-RELIABILITY.md).

See [research and navigation](ST-CTF-RESEARCH.md), [mode rules](ST-TRIBES.md)
and the [validation receipt](validation/st-deployables-tactics-2026-09-27.json).

Current steps 1–3 implementation and validation: [offence, construction and fixed defences](ST-OFFENCE-DEFENCES.md).

Current steps 4–6 implementation and adaptations: [power, targeting and inventory recovery](ST-FIELD-SYSTEMS.md).
