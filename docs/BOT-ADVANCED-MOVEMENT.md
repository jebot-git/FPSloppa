# Bot weapon jumps

The bot planner now recognizes Doom and Quake rocket jumps and UT99 impact-hammer (piston) jumps. Previously only Doom rockets were eligible. It considers these for nearby raised goals when an ordinary route is unavailable or costs more than 25 metres. Routes remain conservative: 1.5–4 m ascent, 1–5 m horizontal distance, safe ground, landing capsule clearance, generous headroom and capsule samples of the blast arc. These are local shortcuts to known goals, not a complete search for multi-stage trick-jump routes.

Rocket attempts require at least 90 HP, 25 armour, two rockets and the actual launcher in the class inventory. Piston attempts require 75 HP and the hammer. Water, fixed-loadout modes, objective carrying, occupied cockpits, observed enemies and teammates within six metres prevent setup. Attempts have a six-second retry interval. The hammer uses normal primary-fire charging for about 1.55 seconds, followed by jump and release. A newly observed threat, loss of support or other unsafe condition cancels the charge through normal blocked input. Planning and stuck recovery do not interrupt intentional charging; air control brakes toward the landing.

Bots use ordinary movement/fire inputs and authoritative weapon damage, ammunition, cooldowns and impulses. Human blast/jump mechanics were not changed. Quake grenade jumping remains unchanged, following the user's instruction that it already works and that later implementation inquiries should be disregarded. No timed grenade-jump bot routine was added.

## Validation

`deathmatch/tests/bot_movement.gd` passes real physics takeoffs and landings on a three-metre raised platform for all three supported combinations, including planner selection, health/ammo restrictions, water, fixed modes, ceiling clearance and interrupted piston charging. Each attempt fires once. Observed apex heights were 9.76 m (Doom rocket), 10.18 m (Quake rocket) and 9.37 m (UT piston); these are fixture measurements, not newly assigned abilities. Piston release occurred at 1.567 seconds. Existing bunny-hop and prone-clearance checks pass.

Bot tactics, objective roles, all weapon combat trials and the translocator traversal checks also pass. Logs: `test-results/bot-advanced-movement.log` and `test-results/advanced-bot_*.log`. An initial weapon-test wrapper timeout was too short for the fixture's roughly four minutes of simulated combat; the completed rerun used a 360-second bound. The initially requested `bot_objectives.gd` path did not exist; the actual `bot_objective_roles.gd` fixture passes.

Changes are local and unpublished. The remote TB session described in `REMOTE-TB-VR-20260914.md` ran the earlier AI pack while these changes were developed.
