# ST bot adaptation — 28 September 2026

Subsequent implementation: [offence, construction and fixed defences](ST-OFFENCE-DEFENCES.md) adds the skills and fixed systems listed as future work in this historical report.

This follow-up addresses repeated midmatch attack and navigation patterns.
It implements bounded coordinated pushes and basic carrier standoffs from the
[parity list](TRIBES-IMPLEMENTATION-GAPS.md). These are project AI decisions,
not a claim of reproducing an original Tribes bot implementation.

## Failure memory and recovery

Attack deaths rotate between three terrain corridors. This preference survives
respawning; life-specific perception and navigation state still reset. Memories
are scoped to a bot and team and clear on map changes or disconnects.

Progress is measured toward the actual objective or a tower launch point,
independently of the planner's waypoint refresh timer. With no meaningful
advance for 35 seconds (60 for Heavy), the bot requests a new route and, where
possible, backs out through a collision-checked terrain corridor for at most
eight seconds. Being at an objective, rallying in place or actively working on
equipment is not treated as a travel failure.

Failed approaches add temporary route costs for 120 seconds. Costs apply only
to that route query and remain soft so the map's only doorway cannot become
permanently forbidden. Failed tower launch points are discouraged for 180
seconds and remembered separately for each armour class. Each memory list is
bounded to twelve entries; objective progress has at most eight watches.
This is failure avoidance, not learned optimal ski racing or disc-jump routes.

Slow grounded teammates can sidestep one another when the world permits it.
The rule does not steer fast or airborne skiers out of their momentum corridor.
Resupply has separate entry and completion thresholds: a bot that retreats
below 55% health continues until at least 85%, with five discs and twenty
chaingun rounds. It no longer leaves the station at the entry threshold only
to immediately return.

## Coordinated attacks and carrier support

Two or three healthy cappers near the same approach can rendezvous on an actual
route. An attacker already within 75 m of the enemy flag continues its attempt.
A gathering phase lasts at most 22 seconds; its first arrival waits at most
five seconds. Two arrivals, a missing partner or a deadline release the group.
The attack window lasts 45 seconds and has a subsequent 15-second cooldown.
Role selection mildly favours keeping participants together. Cappers within
100 m of the enemy flag receive a 55-second approach commitment: optional
maintenance and siege assignments must use another available bot. This prevents
late diversion into the adjacent generator bunker. Failed progress clears the
commitment, and leaving the attack area permits a fresh attempt. Public flag
emergencies still preempt it and cancel gathering immediately. No bot is parked indefinitely waiting
for the rest of its team.

The final tower run and flight now face the flag deck when the bot has no combat
target. Previously the bot could continue looking toward its launch point while
moving backwards relative to that view. Weapon aim is preserved during combat.
Visible enemy equipment above a bot uses the same horizontal bearing principle
as player perception, so a turret can be acquired before reaching the deck.
World LOS, range, rear-field rejection and normal weapon rules still apply.

Carrier escorts choose separate forward screening and trailing positions,
projected onto nearby walkable terrain. Multiple probes handle cliff edges.
If the home flag is missing when a carrier reaches its own base, the carrier
seeks bunker cover. Nearby dropped home flags can be touch-returned directly.
A returned home flag immediately restores the capture objective. The holding
point is cached for twelve seconds to prevent constant pad switching, and
cover selection uses observed/reported threats rather than hidden enemies.

Flag passing, synchronized heavy mortar bombardment, deliberate disc jumps,
full deployable planning and a commander interface remain future work.

## Validation

`st_adaptive_tactics.gd` covers failure memory across respawn, expiration and
armour changes, progress loops, query-local route costs, rally deadlines and
emergencies, carrier holding/recovery, escort separation, resupply hysteresis,
final tower facing and four recorded midmatch positions with real physics.
The fixtures move the player only to initialize each case; recovery uses
ordinary inputs, energy and BSP collision. The sixteen integrated capture
cases and nineteen established physical routes remain required regressions.

The final source passes 204 focused adaptation/infrastructure/tactics/shared
teamplay checks, all sixteen unopposed capture cases (128–193 seconds), all
nineteen physical routes, and four recoveries from recorded midmatch positions.
These checks establish working routes and state transitions, not competitive
capture success against defenders.

The final 20-minute 6v6 soak ended **Red 1–0 Blue**, with eleven flag pickups
by Red and three by Blue. The capture occurred around 140 seconds; no later
capture completed. Five-second samples recorded **one** near-flag capper-to-siege
diversion, compared with **37** in the earlier 15-minute infrastructure run.
The remaining diversion followed a prolonged unsuccessful tower approach;
commitments deliberately expire rather than pinning a bot to an impossible job.
These separate runs are observational evidence, not a controlled statistical
comparison or proof that every cycle is gone.

All twelve bots used all three attack lanes. The run formed seventeen attack
groups and invoked forty-two bounded progress recoveries; peak horizontal
speed was 108.3 km/h. There were no script errors. The low capture rate and
uneven results remain unresolved: carrier escape and coordinated support under
defensive fire need further work. Unopposed capture regressions do not cover
that problem.

`tools/tribes/run_live.py` accepts a seed for repeated 6v6 testing. Its server
records lane choice, recovery counts, wave state and tactic counters, saves
samples every simulated minute and ends cleanly at the match result instead
of following the server into another map. The spectator director tolerates
shutdown of its arena. See the [validation receipt](validation/st-adaptive-tactics-2026-09-28.json)
for completed runs, exact results and remaining limitations.
