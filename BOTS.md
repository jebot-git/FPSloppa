# Practice bot AI

Practice bots use the normal server movement, weapon, pickup, damage, TF ability,
and objective code. The AI selects inputs and goals; it does not grant equipment,
teleport actors, heal directly, or advance objectives itself.

The [AI balance follow-up](docs/AI-BALANCE-FIXES.md) documents profile-aware
equipment acquisition, coordinated CTF pushes and carrier screens, KOTH access
adjustments, spawn-overlap prevention, and the validated water/low-ceiling exits.

## Decisions and teamwork

- Health, armor, ammunition, and weapons are scored against the bot's actual
  inventory. Unusable supplies are ignored. Bots can time a pickup respawning
  within three seconds, and teammates avoid reserving the same local supply.
- Visible enemies are prioritized by distance, flag possession, and teammates'
  delayed reports. Losing sight leaves a three-second last-known position;
  hidden enemies do not continuously update it. TF disguises and cloak remain
  effective. Visible incoming projectiles trigger a checked lateral dodge.
- Bots evaluate damage, spread, range, ammunition and projectile speed from the
  actual weapon/profile/class data, including UT alternate fire. They lead projectiles,
  maintain fighting distance, and check teammate firing lanes and splash safety.
  Low-health or outnumbered bots evaluate nearby positions that block enemy fire.
  A 240–440 ms reaction interval, limited acquisition field of view, small aim error,
  smooth delta-based turning and irregular strafing make combat less mechanical.
  Charged UT rockets release in short salvos and cancel if a teammate blocks the lane;
  Quake bots avoid underwater lightning discharge.
- Team roles divide attacking and defending. CTF/TF bots return carried flags,
  touch-return dropped flags in CTF, guard timer-returned friendly flags in TF,
  intercept enemy carriers, and escort friendly carriers.
  Team DM bots assist engaged allies; Freeze Tag bots seek teammates to thaw;
  KOTH bots hold the current hill.
- Assault attackers pursue forward checkpoints in order and then the active
  console or destructible objective. Defenders spread around the active site.
  Distant objectives retain priority on large maps such as HiSlop. A visible
  defender does not automatically interrupt fire against a destructible objective.

### Team coordination

All seven team modes share a small, match-local coordinator:

- Bots relay an observed target at most once per 0.9 seconds. Delivery takes at
  least 350 ms and reports expire after 3.5 seconds. Reports contain the observed
  position, not a live reference to the enemy's location. Respawning, changing
  team, death and freezing invalidate relevant reports. Allies can investigate
  a report and concentrate fire when they personally see the target. Perception
  still respects walls, field of view, cloak and TF disguises.
- Healthy bots can cover an injured ally, a flag carrier, or a bot committed to
  thawing, healing, repairing or operating an objective. Cover positions have a
  firing lane toward a seen/reported threat and are separated from the protected
  ally. Duplicate support assignments are discouraged. Carriers keep capture
  priority; escorts follow to either side and behind rather than occupying the
  carrier's position.
- Bots leave health, armor, weapons or ammo for a nearby, visible teammate with
  substantially greater need, including human teammates. An offer lasts four
  seconds, and an ignored offer cannot renew for another six seconds. The bot
  voluntarily declines incidental collection during that window; humans and
  opponents remain unrestricted. Death, team/respawn changes, moving away or
  satisfying the recipient's need ends the reservation. A more desperate bot
  can override courtesy. Flag passing itself is not added: existing flag rules
  are preserved, with supply sharing and carrier cover providing the cooperation.
- A minority defensive role can wait at partial cover overlooking an objective
  or a reported contact. Ambushers watch the approach, crouch while waiting and
  engage on their own visual contact. Each ambush has a seven-second budget and
  a cooldown, so unanswered ambushes do not become permanent camping. Suitable
  cover is required; engineers retain their building assignments.
- Human teammates receive occasional team-only contact, covering and supply
  callouts, limited to one per team every 15 seconds. Bot peers are excluded
  from network RPC delivery.

Reports, reservations and ambushes are bounded and expire. Geometry sampling
runs at the existing planning cadence; weapon aiming stays at physics rate.

## Movement and routes

The planner compares reachable navigation routes for its six best candidate
objectives. Ordinary walking routes use the map's cached or runtime-baked navmesh.
Map teleports, ballistic launch pads, and lifts add directed connections. A bounded
background pass checks hull clearance for jumps and controlled drops across navmesh
boundaries. Vertical pads include checked air-steering routes to nearby roofs.
Assault uses denser boundary sampling so mandatory routes through small passages
are not lost in the uniform sample. Links wait for the region to synchronize.
Bots reconsider blocked goals after a temporary penalty, and invalidate routes
and target memory after respawn or teleport. A separate progress window survives
replanning and small collision jitter; a stuck bot backs out toward checked ground.
This recovery can step off a safe low ledge without forcing a respawn or position.
If an upward probe detects a low slab during recovery, the bot briefly crawls
to release a bridge/underpass snag using the normal stance and collision rules.

Movement and aiming run every physics frame. Perception and TF ability decisions
run five times per second; goal planning runs approximately once per second. Bots use full running input,
release/press jumps for bunny hopping, steer and brake in the air, step through the
shared physics, crouch or crawl under obstacles, swim vertically, and surface-jump.
They check landing ground and known damage volumes before crossing a ledge.

Healthy, armored bots with spare rockets can choose a short raised shortcut in
the Doom ruleset when walking is unavailable or entails a large detour. Takeoff
requires overhead clearance, no nearby teammates, and no carried flag; it spends
one rocket and normal self-damage. Air control brakes toward the landing.

## TF abilities

Medics aim at injured or burning teammates before healing. Engineers build a
sentry and dispenser near their defensive assignment and approach damaged friendly
structures to repair them. Scouts save sprint for travel; snipers focus for a
lined-up distant shot; heavies brace during nearby combat while avoiding a slowdown
on flag returns. Spies disguise or cloak during travel and keep an active cloak.
Soldiers and pyros throw at suitable ranges with friendly splash checks. Demomen
retain pipes until an observed enemy enters their blast radius.

## Validation and scope

The extended match harness covers all ten modes, Doom/Quake/UT weapon profiles,
all 17 bundled layouts and TF Ironspan, with eight bots plus a spectator. This is
extra test load, not a change to the in-game hosting limit. Separate weapon trials
verify actual damage from every combat slot and real translocator use.

Run with Godot from the project root:

```sh
godot --headless --xr-mode off --path . --script res://deathmatch/tests/bot_navigation.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/bot_tactics.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/bot_movement.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/bot_traversal.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/bot_assault.gd
godot --headless --xr-mode off --fixed-fps 60 --path . --script res://deathmatch/tests/bot_weapons.gd
godot --headless --xr-mode off --fixed-fps 60 --path . --script res://deathmatch/tests/bot_humanization.gd
godot --headless --xr-mode off --fixed-fps 60 --path . --script res://deathmatch/tests/bot_teamplay.gd
godot --headless --xr-mode off --fixed-fps 60 --path . --script res://deathmatch/tests/bot_underpass.gd
python3 deathmatch/tests/run_bot_soak.py --label current --seconds 300
```

The tests cover decisions and actual ability/damage results, collision-based
movement including rocket jumping, short DM/TDM/TF/AS matches, and an attacking
squad reaching HiSlop's first console. Traversal metrics are written to
`test-results/bot-traversal.json`.

Route optimization is bounded and based on available navigation and recognized
map entities. It is not a guarantee of the globally fastest route on every custom
BSP. Jump/drop discovery is capped at 96 links and two candidates per physics frame.
Unusual scripted movers or long trick jumps may still require authored navigation.
UT bots can throw and use a translocator along a clear, useful route with enough
landing clearance; they never use it in Assault or while carrying a flag. Deliberate
shock combos and guided Redeemer tactics remain future improvements. Bots remain
practice-only. These headless checks do not substitute for a subjective VR playtest.

See [the extended test report](docs/BOT-SOAK-REPORT.md) for measured behavior,
coverage, diagnostics and remaining limits. Use `--project /path/to/isolated/copy`
when another build is modifying native plugins in the working project. A fresh
`--label baseline --snapshot-ai` preserves AI scripts for subsequent comparisons;
use a complete runtime copy when native libraries may also change.

The subsequent [team coordination report](docs/BOT-TEAMPLAY-REPORT.md) covers
shared sightings, support positions, supply offers, ambushes and team-mode reruns.
