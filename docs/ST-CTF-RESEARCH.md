# ST CTF research and bot navigation — 27 September 2026

The mode keeps the existing armour, energy and skiing physics. Bots send the same movement and weapon inputs as players; there are no navigation teleports, free energy or bot speed multipliers.

## Evidence and resulting changes

- [Stonehenge Tribes 1 base gameplay](https://www.youtube.com/watch?v=iKdqu940llk), uploaded by sexyzlexy: sampled at 15-second intervals across the 9:45 recording. Elevated flag approaches, the covered deck, dropped flags on slopes and mobile hill combat informed route coverage. This was a sampled visual review, not continuous playback; no numerical rule was inferred from video.
- [GriBBsY's archived beginner guide](https://wiki.tribesdepot.com/wiki/Starsiege:_Tribes/GriBBsY%27s_Beginner%27s_Guide_to_Tribes): role specialisation, equipment favourites, repair packs and recovery after loss of base power. Added a repair specialist and a power-independent emergency repair-pack rack. The rack replaces only an empty backpack, grants no health/energy or refundable credit, and accepts friendly living players within reach and line of sight. Unlimited rack replenishment is this implementation's adaptation.
- [Samuel Bunn's community strategy guide](https://gamefaqs.gamespot.com/pc/132861-starsiege-tribes/faqs/14482): carriers prioritise escape, with escorts, flag defenders and generator attackers. Six-player teams now assign capper, escort, chaser, flag defender, repairer and siege roles. A carrier's return objective overrides purchases and ammo detours. Combat still requires perception and line of sight.
- [Tribes players' route-practice recollections](https://hardforum.com/threads/favorite-tribes-game.1195621/), posts 18 and 21: deliberate ski routes matter for both capture runs and heavy offence. These are tactical recollections, not a source for physics constants.
- [Spoonbot author's documentation](https://github.com/dividebysandwich/tribes_spoonbot): terrain navigation alone is insufficient for interior generators, stations and flags. Added a collision-derived terrain graph with explicit Stonehenge bunker portals. No Spoonbot code was copied.

The numerical rules retain the provenance in [Tribes movement](TRIBES-MOVEMENT.md) and [ST mode](ST-TRIBES.md). Tribes 2, Ascend and Tribes 3 mechanics were excluded.

## Ski controller

The first controller braked for high terrain samples and tried to climb mostly vertically. The revised outdoor controller pursues points ahead on clear corridors, skis downhill from rest, preserves momentum across valley floors, and coasts during descent rather than continuously firing jets. It predicts the approach to rising terrain to time jet-assisted climbs. Covered base portals retain precise local steering and roof recovery. Future ST maps need their own interior portal definitions.

The initial physical route fixture used the real BSP collision, 60 Hz ordinary input and unchanged movement/energy code. It covered both flag routes, station arrival from both flags, eight roof spawn exits and a long downhill corridor. Station success requires the actual inventory activation volume, not approximate proximity. All 13 initial routes passed. The downhill corridor reached 32.72 m/s (117.8 km/h), with no jet burn; this is a steep 158 m descent near the map edge, not a claim that every flag route reaches that speed. Direct flag routes peaked at 62.3 and 73.0 km/h and completed in 89.7 and 69.6 seconds without opponents.

The ten-minute 6v6 combat soak recorded a peak horizontal speed of 107.9 km/h, active combat and generator attack/repair, but no captures (0–0). Contested flag-running still needs improvement. The soak is recorded separately under `test-results/st-tribes/research/ski-six-v-six/`. Isolated route completion is not evidence of successful captures in a contested match.

## Tower recovery, situational jobs and deployables

The follow-up replaces close-range tower hovering with a staged approach.
Bots choose a terrain launch position, recharge while grounded, build running
or skiing momentum, and jet toward the deck. Heavy favours higher launch
terrain and a longer loft. Missed attempts leave the tower and try another
approach. The controller covers flag and nearby construction objectives.
No class receives extra lift, speed, health or energy.

The expanded physical fixture now isolates the actor and resets inputs for
each case. All **19 cases pass**, including recovery from below both flag
towers in Light, Medium and Heavy. These six recoveries take approximately
24–54 seconds; they demonstrate recovery, not fast competitive routes.
The steep descent peaks at 109.0 km/h in this run.

Roles are allocated from living available teammates using travel distance,
equipment, energy and a small retention preference. Flags, power and deaths
invalidate assignments immediately; otherwise they are reconsidered each
second. The nearest suitable defender can become a chaser; two nearby bots
can escort a carrier. Visible pressure can add a second defender, and loss of
power recruits players who can actually obtain/use a repair pack. Healthy
teams release more cappers. Existing equipment is retained during field role
changes. A maintenance bot can buy and place defensive remote turrets through
the same rules as players.

The next ten-minute 6v6 soak exercised role changes in **11 of 12 bots**, up to
three deployed turrets, turret kills and generator attack/repair. It also
ended **0–0**, with no flag carrier in the five-second samples, and peaked at
**75.3 km/h**. The earlier 107.9 km/h result is not the result of this newer
match. Reliable high-speed capture routes and contested captures remain
unfinished. This soak started before the final maintenance tie-break,
Medium loft and camera orientation fixes. Focused checks cover those fixes;
the subsequent live server and Vulkan spectator used that source. That live
match was later stopped at the user's request after continued capture failure.

Validation: 54 tactics/construction checks, 55 deployable checks, 19 graphical
UI checks, 19 real-physics routes, ST/arsenal/station/armour/demo regressions,
and server/player/late-spectator ENet checks. See the
[receipt](validation/st-deployables-tactics-2026-09-27.json) for exact scope and
warnings, and the [gap audit](TRIBES-IMPLEMENTATION-GAPS.md) for remaining work.

## Integrated capture regression

The live match exposed failures that a fixed-path movement fixture did not
exercise. A new `deathmatch/tests/st_bot_capture.gd` fixture starts a single
Light bot with normal spawn equipment, runs its ordinary perception/planning/
steering and real flag rules, and requires an actual capture after taking the
enemy flag. It uses real BSP collision and unchanged personal energy; it does
not teleport, refill, or grant equipment during a run. Each of the sixteen
Stonehenge spawn points is checked separately, without opponents.

The baseline failed to take Blue's flag within 300 seconds from Red's first
spawn; Blue's first spawn completed a round trip in 219 seconds. The fixes
remove repeated nodes in alternate lanes, keep progressing routes instead of
rebuilding them periodically behind a flying bot, reserve bunker precision
steering for interior approaches, preserve recharge/recovery state during
staging, and hand off to final steering upon reaching deck height. Directional
jets now brake airborne arrivals: stick movement alone cannot provide air
control. Takeoff uses forward alignment, and healthy cappers do not detour to
buy an optional backpack. Movement inputs are converted after navigation aim
changes yaw, preserving the intended world-space direction.
The tower arc also allows additional height while still far away, then lowers
the height limit near the covered deck; the previous fixed limit cut thrust
too early on long approaches.

All **16 spawn-to-capture cases**, **19 physical routes**, and **57 tactics
checks** pass. Unopposed round trips take approximately **122–202 seconds**.
Final measurements and test scope are recorded in
[the capture navigation receipt](validation/st-capture-navigation-2026-09-27.json).
These unopposed regression tests established route functionality only; they
did not establish reliable contested 6v6 captures. The subsequently relaunched
live match produced flag takes but again remained 0–0. The next pass below
addresses uphill traction and equipment counterplay.

## Uphill traction and infrastructure follow-up

Slow uphill bots now release ski and use walking traction. Fast coasting is
retained only while useful momentum can carry the climb; downhill acceleration
from rest is preserved. A physical 20-degree slope regression checks all three
armours without jet assistance. All 16 integrated capture cases still pass
(133–190 seconds), as do all 19 physical routes.

The next parity items are [independent station damage/repair, powered fixed
medium sensors and bot equipment counterplay](TRIBES-INFRASTRUCTURE.md).
Repair assignment includes damaged friendly equipment; disabled stations are
excluded from resupply. Bots observe exposed hostile deployables at 5 Hz and
shoot with ordinary ammunition, preserving the flag navigation objective.
A near enemy takes priority. During tower staging, equipment aim is propagated
to the temporary navigation controller so it cannot turn the shot away.

The new protocol replicates fixture durability and scan suppression to owner
and spectator. The shared desktop/VR status adds detection/jam information.
Legacy demo state remains readable. A new 6v6 Mobile/Vulkan live match runs in
`test-results/st-tribes/live-infrastructure/`; the previous 0–0 run's logs remain
in `live-capture-fixes/`. The 15-minute accelerated 6v6 test ended **Red 1–0 Blue**, with six Blue-flag
pickups by Red, one Red-flag pickup by Blue and four deployed turrets destroyed.
Peak horizontal speed was 95.0 km/h. Only Red completed a capture; this remains
a low capture rate and does not prove balanced or competitive attacks. No
friendly deployable repair increase was observed in the five-second match
samples, although the focused repair fixture passes. Final results and scope
are in [the infrastructure receipt](validation/st-infrastructure-2026-09-27.json).

## Midmatch adaptation

The subsequent live match again settled into repeated approaches. In the
preceding 15-minute infrastructure soak, five-second samples showed 41 changes
from capper to another non-emergency job while within 100 m of the flag. The
new 55-second approach commitment prevents optional maintenance/siege tasks
from repeatedly taking over those nearly completed attacks. The new
[adaptation pass](ST-BOT-ADAPTATION.md) adds match-local failed-route and
armour-specific launch memory, bounded attack rendezvous, resupply hysteresis,
carrier screening/holding, and local teammate separation. It also corrects a
final-flight perception problem: tower navigation could leave the bot facing
its old launch point. Elevated equipment acquisition now uses horizontal
bearing plus real LOS instead of rejecting a high turret solely for elevation.

The [new receipt](validation/st-adaptive-tactics-2026-09-28.json) records focused
checks and longer contested tests separately. These tactics are an adaptation;
learned competitive ski routes and reliable balanced capture rates remain
unproven. The current live session is `test-results/st-tribes/live-adaptive-final/`.

The completed final-source 20-minute 6v6 soak ended 1–0 with fourteen flag
pickups (Red eleven, Blue three), one sampled near-flag capper-to-siege
diversion and no script errors. The earlier infrastructure run had 37 of those
specific diversions in fifteen minutes. The only capture was early, around
140 seconds. This demonstrates reduced task churn, not a resolved stalemate:
reliable carrier escape and coordinated support under defensive fire remain
the priority. See the receipt for sampling limits and exact measurements.

## Rendering comparison

Switching only the live spectator from Compatibility/OpenGL to Mobile/Vulkan resolved the reported avatar flicker, confirmed by the user. The authoritative server was preserved for that comparison. See [renderer release policy](RENDERER-SUPPORT.md); future client releases require templates built without OpenGL.

The [steps 1–3 pass](ST-OFFENCE-DEFENCES.md) adds offensive skills, full personal deployable planning and fixed defences. Its separate receipt distinguishes isolated tests from contested results.
