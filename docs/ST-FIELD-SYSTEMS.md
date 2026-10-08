# ST parity steps 4–6 — power, targeting and recovery

Implemented on 28 September 2026. These extend the [offence and fixed-defence pass](ST-OFFENCE-DEFENCES.md). The runtime uses protocol `fpsloppa-62-st-field-equipment`; older Tribes demo states remain readable. This is an independent adaptation, not bit-exact retail-engine compatibility.

## Base power and equipment

Static equipment disables at 50% accumulated damage and is destroyed at 75%; destruction sets its remaining health to zero. Repair must cross back above half health before service resumes. Deployed pulse/motion sensors and jammers use their explicit 80%/100% thresholds. Other remote equipment uses the static defaults. Disabled remote equipment remains repairable and counts toward its team limit until destroyed.

Powered fixed turrets and pulse sensors have energy shields. Shield strength is `.03` original damage units per energy, with grenade ×.5, mortar ×.25 and blaster ×2 modifiers. A turret shares its capacitor between its shield and weapon. Fixed sensors hold 100 energy and recharge at 10/second; turret recharge follows its existing type. Unpowered or disabled equipment cannot shield or recharge. Remote turrets explicitly have no shield, matching their script override. Stations and generators have no added shield.

Map entities accept `power_group` (default `base`) or comma-separated `power_sources` naming generator `targetname`s. A consumer needs at least one enabled, same-team matching source; explicit source links take precedence over groups. No cross-team connection is permitted. This maps the original engine's hierarchical power groups into BSP entity attributes.

| Entity | Service / geometry |
|---|---|
| `info_tribes_generator` | Existing BSP generator housing; 300 HP approximation retained. |
| `info_tribes_solar` | Native panel housing; 1.0 original durability. |
| `info_tribes_portable_generator` | Native power housing; 1.6 original durability. |
| `info_tribes_inventory` | Armour/equipment refits, priced resupply and gradual repair. |
| `info_tribes_ammo` | Priced ammunition and kit resupply, without armour refits or station healing. |
| `info_tribes_command` | Use opens access to the current sensor/camera/turret menu. Full commander orders/PDA remain a separate step. |
| `info_tribes_vehicle` | Powered, damageable station infrastructure. The subsequent [vehicle passes](ST-VEHICLES.md) add Scout, LPC and HPC purchases/spawning on Raindance. |
| `info_tribes_repair_patch` | Touch pickup healing `.125 × 100/.66` HP; 30-second respawn adaptation. Full-health players leave it available. |

Station, sensor and turret markers use the same power attributes. Maximum source count is 32; replicated fixed asset limits remain bounded. Stonehenge retains its current two generators, four inventory stations and two fixed sensors. No extra ammo/command/vehicle station or solar source is inserted into the map without a placement reference. New station/source combinations are covered by physical fixtures. Bot repair priority now considers all sources and the actual outage threshold.

## Artillery coordination

Target beacons cost 5 energy each at inventory stations. Players carry three, or thirteen with an ammo pack. Placement requires a clear static surface within three metres and real reach/LOS; there are at most forty beacons per team. They have `.1` original durability, stop designating when disabled, can be repaired, and can be destroyed by ordinary hits or unobstructed blasts.

Firing the existing targeting laser publishes its actual authoritative trace endpoint to teammates. Designations expire on release, weapon change, death, life or team change, blocked input, a fresh miss, or missed updates. The sustained laser consumes 15 energy/second at the existing .2-second trace cadence and requires five energy to fire. Its existing free tool grant is retained as an adaptation.

With the grenade launcher or mortar selected, a friendly target diamond and an aiming ring show a solution using the actual muzzle, launch speed, gravity and inherited player velocity. Both low and high arcs are checked against world geometry; the fuse's arming time also applies. The cue supplies aim information, without redirecting the projectile or changing player aim. Markers update at 10 Hz and display at most eight nearest team targets. Only one collision-checked aiming solution is calculated per update; head/view direction and selection hysteresis choose its target. Desktop and VR share the cues. Ordinary ammunition, fire cycles and friendly blast checks still apply.

Heavy support bots can use shared designations for mortar fire. Nearby support bots briefly paint exposed equipment when a mortar teammate is available; cappers/escorts can buy and place beacons near the opposing base without interrupting a flag return. These are bounded heuristics, not synchronized competitive artillery teams.

The [main/native integration check](ST-MAIN-INTEGRATION.md) adds real-input and
four-process ENet coverage. Target labels now retain readable angular size at
artillery distances, and the aiming ring is centred separately from its caption
to preserve its ballistic direction.

## Recovery and transfers

The inventory wheel's **Field Equipment** page contains repair-kit use, backpack/ammo/weapon drops, beacon placement and beacon buying. Drops are available away from a station. A dropped ammo pack stores only the ammunition and beacons above the armour's normal capacity and removes those exact counts from its owner. Re-equipping the pack restores its actual contents, subject to receiver capacity; excess or incompatible items remain in the world.

Death leaves a recoverable inventory case with all carried personal guns, rounds, kit, pack and beacons. It replaces the ordinary single equipped-weapon drop for the Tribes loadout. Different players can recover portions, obeying armour weapon limits and pack restrictions. No armour is looted. Corpses last 24.5 seconds; manual drops last 30. Up to 128 inventories are retained. Pickup checks physical distance, world LOS and life eligibility; repeated pickup/transfer requests cannot duplicate contents. Salvage does not increase refundable team-energy credit. This conservative economy adaptation avoids ammo pickup/refit currency loops.

In VR, the offhand grip grabs the pack control at the tracked chest. Trigger keeps its existing activation/deployment function. Swing and release an unused pack control to drop/share the pack; a gentle release returns it. Pull ammunition from the offhand hip with the offhand trigger, then release to transfer it. This uses the existing hip/lean attachment frame, checked physical poses and request sequence/life validation. Desktop users use the same field wheel actions. Nearby depleted bots can choose useful loot instead of an unnecessary trip to base.

## Sources and limits

Mechanics were independently implemented from pinned references:

- [TribesRebirth StaticBase defaults](https://github.com/AltimorTASDK/TribesRebirth/blob/1105fd0890c19c13f816b91e51b9cf0658ffc63c/program/code/staticBase.cpp), [power propagation](https://github.com/AltimorTASDK/TribesRebirth/blob/1105fd0890c19c13f816b91e51b9cf0658ffc63c/program/code/gamebase.cpp), and [sustained image energy](https://github.com/AltimorTASDK/TribesRebirth/blob/1105fd0890c19c13f816b91e51b9cf0658ffc63c/program/code/playerInventory.cpp).
- [Static shape shields](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/staticshape.cs), [beacons](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/misc/beacon.cs), [ammo packs](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/packs/ammopack.cs), [corpse item transfers](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/game/player.cs), and [repair patches](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/misc/repairpatch.cs).

These are community repositories, not authenticated retail releases. Source hashes are in `test-results/st-tribes/parity456/references/sources.json`. Native beacon, recovery-case and power-panel meshes use project materials; no retail artwork is included. Recovery uses compact cases rather than lootable animated corpses. BSP power groups replace engine object-group inheritance. The subsequent [vehicle passes](ST-VEHICLES.md) add Scout, LPC and HPC; Scout/Shrike bots now buy and pilot aircraft; transport tactics remain deferred. Live desktop/Vulkan and synthetic tracked-pose validation do not substitute for headset ergonomic testing.

Validation is recorded in [the receipt](validation/st-parity-4-6-2026-09-28.json). The new focused test is `deathmatch/tests/st_parity456.gd`; production ENet and graphical tests extend the existing Tribes suites.

The 13 validation scenarios passed **669 checks**. A 20-minute contested 6v6 soak ended **Red 1–1 Blue**; both teams captured, with shared designation, beacon deployment, mortar fire and partial inventory recovery observed. The receipt identifies the final focused fixes made after that soak started. A fresh visible Vulkan preview uses the recorded final gameplay sources.

The subsequent [equipment artwork pass](ST-EQUIPMENT-DESIGN.md) replaces placeholder
station/turret/deployable geometry with reference-led Blender assets and updates
Raindance sensor fixtures and generator alignment.
