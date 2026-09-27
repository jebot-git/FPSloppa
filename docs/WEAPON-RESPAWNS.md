# Weapon respawn timing

Updated 2026-09-26. Map weapons now return **5 seconds after a successful
collection**, except in **Team Deathmatch, where they return after 30 seconds**.
The server owns the deadline and replicates availability to every player.

## Quake III reference and adopted rules

id Software's [g_main.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_main.c)
defaults `g_weaponRespawn` to 5 and `g_weaponTeamRespawn` to 30.
[Pickup_Weapon in g_items.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_items.c)
selects the slower value only for `GT_TEAM` (Team Deathmatch). CTF uses the
ordinary value. This is a weapon timing policy, not a blanket timer for all
pickups. Quake III also permits map-authored timer overrides.

FPSloppa adopts those defaults and extends the 5-second rule to KOTH, Freeze Tag
and Assault. These extensions are FPSloppa decisions, not claims about stock
Quake III modes. All three weapon presets use the same mode-based timing.

| Mode | Previous ordinary / slot-8 timer | New timer for every map weapon |
| --- | --- | --- |
| Deathmatch | 30 / 60 s | 5 s |
| Team Deathmatch | 30 / 60 s | 30 s |
| Capture the Flag | 30 / 60 s | 5 s |
| King of the Hill | 30 / 60 s | 5 s |
| Freeze Tag | 30 / 60 s | 5 s |
| Assault | 15 / 30 s | 5 s |

The old slot-8 exception affected the BFG, Quake lightning gun and UT99 Redeemer
equally. It is removed: powerful weapon access follows the same timing rule as
other weapons. This increases BFG/Redeemer availability as well as ordinary
weapon availability; live playtesting should assess the resulting balance.
Assault no longer applies an additional multiplier to the shared timer.

Weapons remain available at match start. A successful collection starts the
timer; returning to an unavailable pickup cannot reset it. A respawned owned
weapon can refill ammo. Full players leave supplies available. Existing
weapon-stay pickups retain their separate behavior. Death drops never respawn.

Ammo, health, armour and bonuses retain their existing 30-second timers.
Instagib, Instafreeze and Chainsaw Circus continue to disable map collection.
TF/Titanball class rules continue to prevent weapon acquisition and remap weapon
entities to ammunition where applicable. Match resets and Assault role swaps
still restore pickups immediately.

## Map audit

The shared timer in `deathmatch/arena.gd` applied to all maps. Inspection of the
48 available manifest BSPs found 306 deathmatch-enabled weapon placements and
no weapon entities with `wait` or `random` overrides. No BSP edits, cache rebuilds
or pickup reordering are necessary.

| Available map group | Maps | Weapon placements | Slot-8 placements |
| --- | ---: | ---: | ---: |
| Base Quake-source DM (`qsrc_dm1`–`qsrc_dm7`) | 7 | 43 | 5 |
| Base CTF | 6 | 31 | 4 |
| Base KOTH | 4 | 24 | 2 |
| Assault, including Tiny variants | 4 | 56 | 0 |
| TF, Titanball and Chainsaw Circus | 9 | 0 | 0 |
| Optional LibreQuake | 13 | 103 | 10 |
| Optional community DM | 5 | 49 | 6 |
| **Total** | **48** | **306** | **27** |

Forty further manifest entries have no BSP in the local base/optional asset
directories and were not individually audited. They use the same runtime policy
when installed. The [machine-readable audit](validation/weapon-respawns-2026-09-26.json)
lists inspected files, SHA-256 hashes, counts and unavailable map IDs.

## Verification

`deathmatch/tests/weapon_respawns.gd` feeds actual BSP entities through the map
pickup mapper, then authoritative collection and respawn for each supported
mode/preset. It verifies unavailable items cannot be claimed twice, no early
respawn, exact deadlines, unchanged non-weapon timers and fixed-loadout exclusion.
Synthetic cases additionally cover every relevant mode with ordinary and slot-8
weapons. The audit passes 44,926 checks.

Existing pickup lifecycle tests verify shared contention, visibility, ammo
refills and Assault role swaps on the loaded Frigate/HiSlop maps. Mode weapon
policy and death-drop regressions also pass. The pickup network test checks one
server and two clients, including the 5-second weapon/30-second supply deadlines
and replicated disappearance/reappearance. The rebuilt dedicated-server package
passes its automated checks.

Run the audit with Godot 4.7.2 from the repository root:

```sh
godot --headless --xr-mode off --path . --script res://deathmatch/tests/weapon_respawns.gd
```

These are source changes and a local validation build; the live server has not
been deployed or restarted as part of this change.
