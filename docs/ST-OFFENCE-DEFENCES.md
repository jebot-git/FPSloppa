# ST offence, construction and fixed defences

This pass implements parity steps 1–3: additional offensive bot skills, broader
equipment planning, and functional fixed base defences. It extends the
[adaptive tactics](ST-BOT-ADAPTATION.md); it does not change player movement,
weapon damage or the normal purchase economy to help bots win.

## Offensive play

Flag carriers choose a collision-checked downhill departure from the exposed
flag deck, continuing toward home without stopping at the exit point. Known
threats affect the choice; hidden opponents do not. Escorts prioritise visible
enemies near the carrier. An injured carrier without a repair kit can throw
the flag to a healthier teammate ahead, with ordinary throw velocity, world
collision and touch pickup. The recipient receives a short catch objective.

Heavy offence can choose a firing position overlooking the enemy flag and
support an approaching capper. Mortar aim accounts for elevation, gravity and
inherited velocity, checks the flight arc, and uses observed/shared contacts
or a fixed equipment target. Ordinary ammunition, reload time and friendly
blast checks apply. Equipped Heavy support is retained when some teammates
are dead; home pressure and flag emergencies can still interrupt the job.

Healthy cappers carrying a repair kit can deliberately fire a disc behind
their feet before an uphill launch. This spends real ammunition and applies
normal self-damage and blast impulse. It requires grounded forward momentum,
head clearance, energy and no nearby teammate. It is a bounded heuristic,
not a library of learned competitive disc-jump routes.

## Equipment planning

A maintenance specialist can buy and place two defensive turrets plus a
motion sensor, forward ammo station, pulse sensor, jammer, camera and forward
inventory station. Plans check real ground, clearance, spacing and routes.
Purchases preserve a reserve of team energy and use normal armour restrictions,
prices and pack consumption. Missing/destroyed equipment can be replaced.
Forward stations become resupply candidates; they are not treated as armour
repair stations.

Paid outbound construction has a retention preference. Generator and fixed
station/sensor repairs remain urgent, while a lost elevated turret cannot
indefinitely prevent construction. Failed turret repairs yield for 120 seconds
and can then retry. Tower repair approaches search farther for launch terrain.
Siege bots also choose physical firing positions for exposed fixed equipment.

## Fixed defences

Maps can use `info_tribes_turret` or the existing
`info_tribes_turret_socket`, with `team` 0/1, `angle`, and `type`:

| Type | Automatic operation |
|---|---|
| `fusion` | 100 m; detects stationary exposed enemies; plasma projectiles |
| `mini` | 25 m; local moving-target sensor or shared contact; faster small bolts |
| `elf` | 40 m; beam drains target energy and health |
| `missile` | 150 m; acquires recent jet heat; guided missiles lose guidance when heat/LOS is lost |
| `mortar` | Manual only; ballistic shell and a full-capacitor shot |

All have finite durability, energy, turn response and firing cycles. Generator
power loss disables operation. Real weapon traces and blasts damage them;
friendly-fire settings and repair beams apply. Disabled fixtures retain their
cover geometry. Large fixed pulse sensors are available through
`info_tribes_sensor` with `type=large`: 400 m scanning and 1.5 reference durability.
They share the existing power, LOS and jamming rules.

Stonehenge activates its two existing side-monument sockets as fusion turrets.
This placement is a **project adaptation**: the examined `PB_Stonehenge.mis`
variant has medium sensors but no fixed turret declarations. Other turret
types and the large sensor are supported for map authors and tested in fixtures;
they have not all been added to Stonehenge.

Choose **Inventory → Sensor Network → Base Turrets** to control a friendly,
powered, available turret. Desktop uses mouse aim and the configured fire
binding. VR uses dominant-hand aim/fire and an offhand video panel; the XR
head camera stays attached to the player. Use/Escape, menu opening, death,
power loss or loss of commands releases control. The operator's body remains
vulnerable and cannot move or fire a carried gun while operating the turret.
Claims and commands are checked by the server against owner, map and life.

Protocol is `fpsloppa-61-st-fixed-defences`; server and clients must match.
Older demo states remain readable, with the formerly decorative turret sockets
disabled. New demos retain fixed and remote turret projectile definitions.

## Reference and limits

Numerical values were checked against the pinned community base scripts:
[turrets](https://github.com/shayk-siege/t1.41-base/tree/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/turrets)
and [sensors](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/sensors/sensor.cs).
These are community references, not authenticated retail engine source.
Health/damage retain the existing `.66 → 100` scale. Heat decay, missile turning,
turret orientation and beam ticks approximate engine behaviour. Native meshes
are original project assets; no retail models were copied.

Equipment shields, original fractional disable thresholds, additional power
sources and object-level links remain the next infrastructure parity work.
Target beacons, shared laser designation and the commander/PDA system remain
separate work. Physical route and isolated skill checks do not demonstrate a
competitive capture rate. Headset ergonomics of manual turret control and
maximum-population performance remain untested.

See the [validation receipt](validation/st-parity-1-3-2026-09-28.json) for exact
checks, completed contested results, interrupted diagnostics and limitations.

## Validation results

- 441 focused checks passed across new mechanics, tactics, infrastructure,
  deployables, ST rules, demos, shared teamplay and Vulkan menu tests.
- All 16 integrated unopposed spawn-to-capture cases and 19 physical movement
  routes passed. Both final Medium construction routes complete actual turret
  placement within the plan lease (15 and 67 seconds).
- Real ENet server/player/late-spectator checks passed for control, firing,
  release, durability, equipment and flag replication.
- The completed 20-minute 6v6 test ended **Red 1–2 Blue**, with **20 flag pickups**
  and a **120.2 km/h** peak. Captures were observed around 245, 817 and 1083
  seconds, with no script errors. This run predates only the final construction
  deck selection/landing fixes and later local control-view fixes; those have
  separate checks. The new Vulkan live match includes the construction fixes
  and has placed both teams' turrets.

The contested run logged mortar support, disc-jump attempts, two attempted flag
passes, sensors, a jammer and a forward ammo station. Camera and forward
inventory placement pass the real placement fixture but were not observed in
that contested match. A pass attempt is not counted as a successful catch.
The improved result is one match, not evidence of balanced competitive play.

The subsequent [equipment artwork pass](ST-EQUIPMENT-DESIGN.md) replaces placeholder
station/turret/deployable geometry with reference-led Blender assets and updates
Raindance sensor fixtures and generator alignment.
