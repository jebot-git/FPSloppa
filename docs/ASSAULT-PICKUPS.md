# Required mode arsenals and Assault pickup matching

TF uses Quake I; Assault uses UT99. This applies to host/practice, dedicated
configuration and CLI, RCON, lobby results, and mode/map votes. The Host menu
locks its weapon selector for these modes. Switching to an unrestricted mode
restores the server's chosen preference. Contradictory RCON `match` arguments
are rejected. Clients receive the mode/rules before building map pickups.
The compatibility identifier is `fpsloppa-35-mode-loadouts`.

TF converts map weapon entities to corresponding Quake ammunition caches instead
of displaying weapons its classes cannot collect. Small/large Quake ammo boxes
use their appropriate amounts. Class weapons, abilities and resupply remain;
the Pyro's flamethrower consumes cells rather than super-nailgun ammunition.

## Original-map comparison

Placement references are the archived Liandri inventory/location surveys:
[AS-HiSpeed](https://unrealarchive.org/wikis/the-liandri-archives/AS-HiSpeed.html)
and [AS-Frigate](https://unrealarchive.org/wikis/the-liandri-archives/AS-Frigate.html).
These document the retail PC maps. No original Unreal map geometry or artwork
was copied. Coordinates are independently adapted to FPSloppa's rooms.

| Pickup | HiSlop | Frigate |
|---|---:|---:|
| Bio rifle | 0 | 1 |
| Shock rifle | 3 | 2 |
| Pulse gun | 2 | 0 |
| Ripper | 4 | 1 |
| Minigun | 2 | 2 |
| Flak cannon | 2 | 2 |
| Rocket launcher | 4 | 1 |
| Sniper rifle | 1 | 1 |
| Ammunition boxes | 29 | 19 |
| Standard health | 10 | 6 |
| Large health keg | 2 | 1 |
| Body armour | 1 | 2 |
| Shield belt | 2 | 1 |
| Thighpads | 0 | 1 |
| Total implemented pickups | 62 | 40 |

HiSlop supplies the helicopter, train cars, separate defender rooms and upper
routes. Frigate concentrates attacker weapons in its warehouse; the lower ship,
water intake, mess deck and bridge receive their corresponding defensive supplies.
Tiny variants retain the same inventory with placements fitted to compact geometry.
Neither map includes a Redeemer or translocator.

Weapons are separate pickups: Assault no longer bundles sniper with shock or
Ripper with minigun. Assault uses normal shared pickup availability: a collected
weapon disappears for every player and respawns after 15 seconds. A respawned
weapon can replenish ammunition even when already owned; a full player leaves it
available. The Redeemer, if present on a custom map, respawns after 30 seconds.
Assault halves weapon timers only; other modes retain their normal 30/60-second
weapon timers. Bots account for ammunition needs, respawn times and actual
armour quantities when choosing supplies. Swapping attack/defend roles restores
all pickups and clears their timers.

## Deliberate approximations

- Four shared ammo pools remain; boxes identify their intended UT weapon and
  grant its adapted amount. They do not introduce eight independent ammo inventories.
- Armour grants 50/100/150 for thighpads/body/belt using FPSloppa's existing
  protection tiers. This is not UT's layered shield absorption system.
- The keg uses existing megahealth behavior, including the 200-health cap.
- HiSpeed's portable, limited-use jump boots remain represented by the existing
  repeatable jump pads. Additional roof sentries compensate for that shortcut.
- Weapon/ammo/health models and sounds use the existing independently sourced assets.
  Ammo, health and armour retain the existing 30-second respawn behavior.

## Roof entrance defence

Two additional 150-HP sentries flank HiSlop's final-car roof hatch, bringing the
map total to five. They use ordinary sentry aim, range, damage and destruction;
they reset and switch allegiance between attack legs. They are also present in
Tiny. The roof and hatch geometry remain unchanged.

`hislop_roof_guards.gd` compares zero, one and two added sentries on three exposed
roof approaches, with and without armour, on both sizes. This is a scripted
8 m/s route exposure test, not a prediction of human win rates. It also checks
friendly protection, roof occlusion, rocket counterplay and leg reset. See the
validation report for measured damage and the separate bot navigation check.

## Reproduction

`tools/assault_layout_tests/pickups.py` supplies both map generators. For existing
BSPs, `update_pickups.py` replaces only pickup/roof-guard point entities and
verifies all ordinary geometry, textures, collision, visibility, lighting and
BSPX payloads against the pre-change backup. `cache_pickups.gd` updates point
entities and the source hash in existing desktop/Android scene bakes.

```sh
python3 tools/assault_layout_tests/update_pickups.py
godot --headless --xr-mode off --path . --script res://tools/assault_layout_tests/cache_pickups.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/mode_weapon_policy.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/hislop_roof_guards.gd
python3 tools/network_study/validate_upgrade.py network --case weapon_variants_network --variant quake
python3 tools/network_study/validate_upgrade.py network --case weapon_variants_network --variant ut99
```

Results: [mode loadouts and pickup validation](validation/mode-loadouts.json).
