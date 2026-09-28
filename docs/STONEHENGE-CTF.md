# Stonehenge Tribes CTF stations

Select **ST — TRIBES / Stonehenge**. The BSP29 map contains
two team-owned inventory pads in each bunker and eight team drop points facing
the exits. Respawns choose a clear team point; the existing flag positions and
ski routes are unchanged.

Walking within 1.5 m of a friendly pad opens the inventory automatically.
Desktop **B** and the VR dominant-hand weapon wheel also open it. Leaving the
pad closes station access. The authority rejects enemy, distant, obstructed,
dead, spectator and intermission purchases. Standing on the roof above a pad
does not grant access. The shared TF class panel can save armour/weapon/pack
favourites anywhere; Stonehenge requires buying them at a station.

## Equipment and reserves

- Respawn equipment: Light armour, blaster, chaingun (100 rounds), disc launcher
  (15 discs), repair kit and no backpack. Intrinsic jets recharge at 8/s;
  buying an energy pack raises this to 11/s. The disc is selected on spawn.
- The finite team reserve starts at 5,000 for its first slot and receives
  another 5,000 whenever its active roster exceeds its previous maximum for
  that match. Six players therefore contribute 30,000 before purchases.
  Disconnects, respawns and replacing an occupied roster slot do not mint
  another contribution. A new match resets the contribution counters.
- Each Light spawn kit costs 700. If the reserve cannot cover it, the remaining
  balance is charged and the complete baseline kit is still supplied. Its
  trade-in credit is capped at the amount actually paid, preventing free kits
  from generating energy when returned to a station.
- Reserves gain 700 every 30 seconds and cap at 700,000. They are separate from
  personal jet/weapon energy. The bank, inventory and paid trade credit are
  authoritative and replicated to owners, spectators and demos.
- A purchase exchanges the carried armour, guns, pack, remaining ammunition
  and unused repair kit for the selected loadout. Only the difference is
  charged; trading down refunds the difference to the same team. Missing/spent
  ammunition has no refund. Unaffordable purchases leave current gear intact.
- Refits preserve armour-condition percentage and remaining personal energy.
  They cannot instantly heal or refill jets by repeatedly selecting equipment.
- While standing at a station with supply available, armour repairs at 8 HP/s.
  Every half-second the station buys up to 20 bullets, 5 plasma rounds, or 2
  discs/launcher grenades/mortar rounds/hand grenades at their existing item
  prices, and replaces a used repair kit for 35. Mines are filled by a loadout
  purchase. Both terminals share their team's bank.

## Map boundary and assets

The playable box is **x/z −350…350 m, y −24…320 m**. Four invisible solid walls
sit two metres inside the sampled terrain, with a ceiling and buried floor.
These are ordinary swept physics collisions on the authority and clients;
they work with skiing, jets, other loadouts and replay playback. Navigation
is clipped to the same box. No visible enclosing wall is rendered.

The map remains BSP29, 10.6 MB, with unchanged terrain geometry and embedded
mipmapped textures/lighting. Raw, BC7 and ASTC scene caches were regenerated.
The station rails, console and pad are small original runtime meshes over the
existing brush alcoves. Adding them as world brushes exceeded BSP29's node
limit, so they are kept outside the BSP partition tree.

## References and limits

Station ownership, walk-in inventory, resupply, repair and trade-ins follow the
[Tribes manual, pages 50 and 58](https://www.the-flet.com/dynamix/t1/TribesManual.pdf)
and the pinned community [base station scripts](https://github.com/shayk-siege/t1.41-base/tree/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/stations).
The baseline equipment follows [playerspawn.cs](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/game/playerspawn.cs).
The [energy constants](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/game.cs)
support finite reserves but default to **Infinite** in that distribution.
ST offers `sv_tribes_infinite_energy 1` for unlimited reserves. Its default finite economy uses roster maxima
instead of repeat join grants, and supplies an emergency spawn kit.

Station placement fits the existing reconstructed bunker interiors; it is not
an exact conversion of the retail interior meshes. In ST, both generator
housings now take damage and can be repaired with a repair pack; offline base
power disables inventory service and purchases. See [ST](ST-TRIBES.md) for
rules, physical item controls and remaining limits. Remote stations, turrets,
sensors, jammers and cameras are now [deployable](TRIBES-DEPLOYABLES.md).
Fixed base defences and the commander interface remain absent.

Validation scripts: `deathmatch/tests/tribes_stations.gd`,
`deathmatch/tests/tribes_stonehenge.gd`, `deathmatch/tests/tribes_demo.gd`,
`tools/run_tribes_network.py`. Results and station/menu captures are under
`test-results/stonehenge-ctf/`.
