# TB — TITANBALL prototype

TB uses all nine TF classes and their Quake loadouts, including TF health, armour, class selection and abilities. The mode identifier is `tb`. Select **TITANBALL → Ashfall Boulevard** in the normal hosting menu, or use the local playground below. The map and mode are available for playtesting; human balance and Quest testing remain pending.

**Ashfall Boulevard (`tb_ashfall`) is a compiled Quake BSP29 map**, with editable brush source and texture WAD in [maps/Ashfall](../maps/Ashfall/README.md). The 300 m winding route runs through a sealed ruined city. Buildings, ground-floor passages and solid rear walls line both sides throughout; the playable area ends at those walls. The nominal 26 m street now has 42 shoulder cover groups (8 wrecks, 28 rubble piles and 6 broken walls), a clear central robot route, sidewalks/access towers, two 13.2 m high overpasses and increasingly fortified positions near the defender base. All tests now load this same BSP through the normal map importer.

## Test it

From the project directory, with Godot available on PATH:

```sh
godot --path . --xr-mode off --rendering-method mobile --rendering-driver vulkan --script res://tools/ba2/gameplay/playground.gd
```

Approach the ladder underneath the belly and jump to board. Successful boarding restores the pilot to their class's maximum health and locks voluntary exits for three seconds. After that, release the boarding jump and jump again to dismount; Use/E also dismounts. Death, disconnect and other forced ejections bypass the lock. In VR the existing Use action or physical ability gesture dismounts; headset testing has not been performed for this prototype. The test harness starts a local practice session without combat bots; automated tests supply targets for the cannons.

## Payload rules and defensive progression

**Red attacks; Blue defends.** Attackers must pilot the robot along the route to Blue's base. Defenders cannot board it and can stop its progress by killing or dislodging the pilot. A pilot changing to the defending team is ejected. A replacement cannot board until the empty robot has stopped and its belly ladder has redeployed. The server awards one round point to Red on delivery, or to Blue when time expires. The result, role instructions and objective progress appear in the HUD and replicate to clients.

After each checkpoint clears, subsequent attacker respawns move forward. Living attackers stay where they are. There are four sheltered spawn positions per group, on both sides of the lane:

| Group | Route location | Activation |
| --- | --- | --- |
| Initial attackers | 0 m | Round start |
| First forward attackers | 72 m | First checkpoint cleared |
| Second forward attackers | 172 m | Second checkpoint cleared |
| Defenders | 300 m, at their base | Entire round |

Forward bays sit 8 m behind their checkpoint and about 18 m off the route centre, outside the robot's path. Coloured cover blocks direct fire from the approach while leaving lateral exits. There are six invulnerable universal engineer dispensers, usable by either team: one in the attacker hangar, one at the defender base, and two around each checkpoint (one on its approach side and one beyond it). The checkpoint stations sit near route distances 70/96 m and 170/196 m. These restore health, armour and ammunition at normal engineer-dispenser rates. There are no natural pickups or implicit proximity-to-spawn resupply in TB. A new round returns attackers to the initial group.

The ruined-city layout supplies low street cover and connected ground-floor ambush spaces, high crossings near 88 m and 198 m with switchback ramp towers, and paired 4.2 m defensive positions at 236 m and 278 m. The defender base has a heavy frontage and short reinforcement paths. This progression is a design intent. Autonomous bots board, escort, intercept and use resupply. Soldiers and demomen contest twelve authored firing positions on the overpasses and accessible fronts of the defensive platforms, using ordinary navigation and combat; exploratory 6v6 results are recorded in [the bot study](TITANBALL-BOT-BALANCE.md). Human competitive balance remains unmeasured.

## Preparation

Every round starts with **60 seconds of preparation**, excluded from the match clock. Attackers begin in a closed hangar. Defenders can prepare outside while narrow firing slits allow shots in both directions; even a prone player capsule cannot cross them. The side/rear walls and roof prevent bypassing the gate. Attackers may board during preparation, but the robot stays parked until the gate opens. Players, weapons and engineer abilities continue to simulate during preparation. Restarting restores the closed gate, dispensers and full preparation period.

## Timer and checkpoints

The active match always starts with **10:00**, after preparation. Host arguments, dedicated server configuration and mode changes cannot change that starting duration. The host minutes control is locked for TB; other modes retain their configurable timers. Restarting or rotating the map clears checkpoint awards and restores 10:00.

Two visible gates sit at **80 m and 180 m** along the robot's route. Each grants **+3:00 once per round**, giving a maximum total budget of **16:00**. The server waits for a conservative 10 m rear/animated-footprint clearance: the robot's route origin must reach 90 m and 190 m respectively. Player crossings do not count. Pilot death, replacement, robot reset and repeated crossings cannot farm an extension. HUD progress and checkpoint awards replicate to clients; clients cannot grant time.

The earlier 0.45 m/s would cover only 216 m in eight piloted minutes. At 0.8 m/s the robot has 384 m of cruise travel available in that occupancy budget. Earlier checkpoint placement also accommodates a late start: eight minutes idle leaves 120 seconds to clear the first gate, requiring about 113.5 seconds at the new speed including acceleration.

Actual 60 Hz controller simulations on the compiled BSP route, including acceleration, braking, collision checks and boarding/exit, measured the following elapsed times **after the preparation gate opens** (add one minute for wall-clock time from round start):

| Piloting pattern | First gate cleared | Second gate cleared | Arrive and halt | Time remaining |
| --- | --- | --- | --- | --- |
| Continuous | 1:53.5 | 3:58.5 | 6:17 | 9:43 |
| 30 s piloted / 30 s idle | 3:26.5 | 8:06.5 | 12:29 | 3:31 |
| 5 s piloted / 5 s idle | 3:43.5 | 7:53.5 | 12:27 | 3:33 |
| Eight minutes idle, then continuous | 9:53.5 | 11:58.5 | 14:17 | 1:43 |

This gives margin for approximately half-time occupancy on a clear route. Obstacles still consume match time. An unearned extension cannot revive an expired round: a nine-minute idle start correctly loses at 10:00 before clearing the first gate. Reaching and stopping at the route endpoint awards attacker victory. Expiration awards defender victory; neither result can be overwritten by a late objective event.

## Robot behaviour

- Approximately 10 m tall. The ladder hangs from the original belly, ending 8 cm above ground, with no added cabin, platform or deck.
- Only one living, non-spectating attacker can reserve the cockpit. The server grants boarding, teleports the pilot and retracts the ladder in one operation.
- Empty robots remain parked. Boarding accelerates to 0.8 m/s over two seconds. Dismounting, death or disconnect brakes to a halt over two seconds and redeploys the ladder. Obstacles stop movement; a clear route permits restarting. An open route brakes at its endpoint.
- Distance is approximately **47.2 m in the first minute from rest**, then **48 m per minute** at cruise, assuming a clear route. Cruise speed is 2.88 km/h. The original 2.52 m stride now takes 3.15 s at cruise; distance-based playback preserves foot placement.
- Heavy mechanical stomps follow the four authored foot contacts, with three original sound variations featuring deep ground impact, crushed asphalt and a short baked reverberant tail, positional attenuation and wall muffling. Cruise impacts occur every 0.7875 seconds; cadence follows acceleration/braking and stops when travel stops. Source and rebuild notes: [BA-2 SFX](../deathmatch/audio/ba2/SOURCES.md).
- The baked gait follows distance travelled. The torso steers within **±7.5°** relative to the route-facing chassis at up to 6°/s, preserving all baked leg poses. Automatic cannon acquisition and impacts use the same **15° total route-facing lateral arc**, without adding another cone on top of torso rotation. The cockpit monitor camera follows that torso heading. Cannons retain X-only hinges, a 6°/s elevation rate and ±45° elevation; they cannot swivel independently around corners.
- Four invulnerable cannons have **no HP or destruction state**. Each uses the engineer sentry's 12 damage and 0.5 s shot interval, with **60 m range** (increased from 36 m for distant suppression). They respect team, disguise, cloak, invulnerability and world occlusion checks. They fire automatically while manned.
- Cannon impacts have a **1.25 m splash radius**, with linear damage falloff, normal armour/invulnerability/friendly-fire rules and cover occlusion. Direct hits still deal 12 damage and are excluded from the splash pass. Acquisition extends by the existing splash radius past the 7.5° lateral boundary so an impact at the boundary can catch a nearby edge target. Small impact flashes use the existing replicated effects channel.
- While the robot actually advances, a **5 m radius crush zone** covers its four-foot footprint and belly ladder. It instantly kills and gibs defenders, including cloaked/disguised spies and temporarily protected defenders. Attackers and the pilot are exempt. The zone is limited to 1.8 m above the route ground and respects walls, so it does not hit elevated or below-floor players. It remains active during unmanned braking, but never during preparation, standstill or blocked movement. Defenders in the zone cannot body-block a leg to halt the robot. The same swept zone destroys Blue sentries, dispensers and settled thrown charges, including during unmanned braking. Charges are removed without a damaging detonation. Red equipment, neutral map resupply stations and airborne projectiles retain their ordinary behavior; walls and height limits still protect deployables.
- Ammunition is unlimited. Each side has one shared heat meter for its two linked cannons. A volley adds 12.5 heat once, including when only one barrel has a clear shot; at 100 heat both barrels lock. Eight uninterrupted volleys can fire 16 rounds per side. Cooling is 25 heat/s per pair while idle or overheated, with restart at 25 heat. The two sides cool and lock independently. These heat values are provisional tuning.
- The pilot is forced to the **fist** (slot 0, using the fist definition/art rather than the Quake axe) and cannot switch weapons. Personal firing and independent movement remain suppressed. The previously equipped weapon, armour amount and armour tier are saved and restored on exit, death ejection or reset; inventory and ammunition are preserved.
- Pilots have **permanent 200 armour**, using the existing tier-2 absorption rule. Armour is restored to 200 after every hit, while health damage persists. A 40-damage hit therefore removes 20 health and leaves 200 armour; this is protection, not invulnerability.
- Direct bullet/beam and projectile impacts on the round hull damage its current pilot. Explosions also damage the pilot when their projectile struck the hull or their origin touches its actual collision surface (4 cm numerical tolerance). Nearby splash, melee, burning and environmental damage do not pass through to the pilot. Normal friendly-fire and wall-occlusion checks still apply; authoritative forced deaths retain their bypass. Cannons and legs remain invulnerable and do not forward direct hits. The hull is not a headshot target, and an empty hull has no player damage recipient. Enemy bots and sentries can recognize an occupied hull.
- Death immediately ejects the player beneath the body, frees the cockpit and restores the saved equipment. The robot then brakes normally. A blocked landing can reject voluntary exit; forced death ejection always releases the pilot.

## Cockpit and monitor

The complete robot exterior stays visible to outside players. The local pilot uses the **existing BA-2 cockpit prototype's console, chair, joystick geometry and cyan monitor HUD**, now shared runtime components rather than a separate replacement design. Gameplay cannons remain automatic engineer sentries; the isolated prototype still retains its manual joystick/firing experiments.

The private cabin is excluded from other cameras. The pilot camera can draw only the closed cabin; its only outside view comes from the forward camera's monitor texture. Looking backwards or leaning outside the cabin does not expose the map directly. Normal camera masks and environment are restored on exit/reset.

The HUD is composited **inside the monitor viewport**, over the camera feed: pilot health, permanent 200 armour, preparation/match time, distance remaining to the goal along the route, cleared checkpoints, speed, exit instructions, and two shared cannon-pair heat/venting bars. It uses actual local/replicated gameplay state. The monoscopic feed is 768×432 at up to 30 updates per second, active only for the local pilot. No additional real-time cockpit light is used in gameplay. Native Vulkan captures verify live health/heat changes on the screen; readability, comfort and performance in Quest remain to be checked.

## Validation

`tools/ba2/gameplay/tests.gd` covers class/loadout policy, boarding ownership, movement, range, damage, heat, target exclusions, dismount, death/disconnect, reset, route endpoint/obstacle handling and ordinary sentry behaviour. `pilot_tests.gd` additionally covers permanent armour, fist locking, saved equipment, body damage, blast and projectile contacts, target recognition and death ejection. `pair_heat_tests.gd` checks shared volley charging, partial cover, paired lockout and independent sides; `contact_tests.gd` exercises real Quake/UT/Doom direct projectiles, surface versus nearby explosions, ordinary-player splash, shared weapon racks and armour absorption. `timing_tests.gd` checks timer locks, mode transitions, reset/rotation, rear clearance, duplicate/late award rejection and full-route duty-cycle simulations. `payload_tests.gd` checks boarding roles, actual forward respawns, spawn clearance, delivery/timeout results and reset behaviour. `cannon_crush_tests.gd` checks direct/splash separation, narrow-angle assistance, friendly fire and cover, 60 m suppression range, moving crush hazards and stationary/elevated safety. `city_tests.gd` checks the preparation boundary, stationary piloted robot, closed hangar, two-team resupply and restart. `tools/titanball/acceptance.gd` checks compiled BSP route/spawn clearance, closed sides, firing slits, ambush spaces and navigation to both overpasses. `run_network.py` runs a real ENet server and two clients making concurrent boarding claims, weapon-switch attempts and jump exits, followed by replicated death ejection, checkpoint time awards, forward spawns and delivery victory. `run_render.py` captures native Vulkan views and checks shell visibility, 18-bone animation, cannon axes, ladder state, checkpoint placement host timer controls, cockpit privacy, live monitor HUD and disabled feed while inactive.

- [Compiled BSP acceptance](../test-results/titanball/acceptance.json)
- [Preparation and shared resupply](../test-results/ba2/gameplay/city.json)
- [Monitor feed with live damage/heat](../test-results/ba2/gameplay/cockpit_feed_heat.png)
- [Payload and layout results](../test-results/ba2/gameplay/payload.json)
- [Timing and checkpoint results](../test-results/ba2/gameplay/timing.json)
- [Gameplay results](../test-results/ba2/gameplay/results.json)
- [Pilot protection and ejection results](../test-results/ba2/gameplay/pilot-results.json)
- [Network results](../test-results/ba2/gameplay/network.json)
- [Render results](../test-results/ba2/gameplay/render.json)
- [Middle defence](../test-results/ba2/gameplay/defence135.png), [final crossfire positions](../test-results/ba2/gameplay/defence235.png), [defender base](../test-results/ba2/gameplay/defence285.png)
- [Corridor overview](../test-results/ba2/gameplay/corridor.png), [first checkpoint](../test-results/ba2/gameplay/checkpoint1.png), [second checkpoint](../test-results/ba2/gameplay/checkpoint2.png)
- [Parked exterior](../test-results/ba2/gameplay/parked.png), [walking exterior](../test-results/ba2/gameplay/walking.png), [belly ladder](../test-results/ba2/gameplay/ladder.png), [pilot view](../test-results/ba2/gameplay/cockpit.png)

Native captures use Vulkan Mobile on an Intel Arc A770 at 1280×800. They are visual checks, not Quest performance measurements. Godot reports ObjectDB/resource-use cleanup messages at test shutdown; no runtime script errors occur in the final passing runs. The legacy full Fortress test has outdated pre-Quake loadout assertions, and the older HiSlop sentry fixture assumes three map sentries; focused current sentry checks and the 38-check weapon-mode policy suite are used here.

The robot uses approximate collision envelopes and a level route, without terrain IK or limb-to-wall simulation. The compiled BSP, source WAD and cached navigation are included in the workspace and base-asset packaging selection. No executable/APK release was built or published, and no Quest test is claimed. Combat balance has not yet been measured with human teams; the current map is an experimental playtest layout. See [model credits](../deathmatch/vehicles/ba2/SOURCES.md) and the earlier [walk animation report](BA2-WALK.md).

## Objective-aware bots and comparative playtests

Bots now assign a nearby attacker to board using the ordinary jump/ladder input,
keep a seated pilot in place, and choose a replacement after death. Other
attackers escort ahead and to either side of the robot. Defenders intercept the
public route position, watch the robot, favour a visible pilot as a combat target,
and steer away from the foot envelope while retaining safe elevated positions.
All combat still requires normal perception and line of sight. Bots consider the
actual universal dispensers for recovery; normal TF spawn resupply is not assumed
on TB. Nearby weapon upgrades take priority over routine escort/interception in
the optional classless test fixture.

The [6v6 simulation harness](../tools/titanball/simulation/README.md) runs and
records native live-view TF/Quake rounds, with objective, combat and boarding
telemetry. UT/Doom comparisons are historical experiments; the current runner
and normal hosting both enforce TF classes and Quake weapons. See the
[earlier comparison report](TITANBALL-BOT-BALANCE.md) for the retired trials.

The [boarding and recorded TF rerun report](TITANBALL-BOARDING.md) covers full-health boarding, the three-second voluntary-exit lock, ladder-gated replacements, and the endpoint restart correction.

The [coverage and cover study](TITANBALL-COVERAGE-R6.md) documents the 15° arc, crush gibs and Blue deployable destruction, revised BSP cover, thinner gate, and recorded 6v6 rerun.
