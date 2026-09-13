# TITANBALL 6v6 experiments

Run `python3 tools/titanball/simulation/run.py --name coverage-r6 --speed 2 --record`
from the project root for the current TF/Quake-only experiment. TB requires TF
classes and Quake weapons in normal hosting and in the current match runner.
Historical classless UT/Doom artifacts are retained for reference; those loadouts
are no longer accepted by the runner. Each round ends on delivery or timeout.

`--seed`, `--seconds`, `--speed 1|2|4`, `--name` and `--headless` allow bounded
follow-up tests. `--record` uses Godot's viewport movie writer at 30 fps and then
encodes H.264/AAC MP4 with FFmpeg. It captures the game, including preparation,
without recording desktop windows. At speed 2 the recording plays at 2× match
speed; use half-speed playback for normal match timing. Raw AVI, MP4 and stream
metadata remain beside the JSON/logs. Recording requires a visible renderer.

A stopped or shortened round is not a victory. Script failures stop the suite;
the per-round wall-clock limit is 30 minutes.

The requested 4× playback uses 240 physics ticks per wall-clock second with an
engine time scale of four. Every gameplay step remains 1/60 simulated second.
Rendering and CPU load can make playback slower than the requested rate; results
use the game's clock, not elapsed wall time. This is not a VR performance test.

## Controls held constant

- Compiled `tb_ashfall` BSP, 300 m route, existing lighting and collision.
- Twelve autonomous bots, six on each team, plus a nonparticipating observer.
- Red attacks, blue defends; same bot IDs and seed in all profiles.
- TF teams each use scout, soldier, demoman, medic, heavy and engineer.
- Full 60-second preparation, 600-second active clock, +180 seconds at each
  checkpoint after rear clearance (90 m and 190 m), unchanged respawns/stations.
- Existing robot speed, acceleration, armour, linked cannon heat/range/splash and crush.
- Revised map: 42 shoulder cover groups, a recessed 1.2 m gate, six universal stations, with one at each base and two around each
  checkpoint; twelve authored high-ground positions guide soldier/demoman support.
- Boarding restores class maximum HP and prevents voluntary exits for three
  seconds. Forced death/disconnect ejection remains immediate.
- No test-driven movement, boarding, target selection, respawns or damage.

`classless.gd` and `rules.gd` are retained historical test fixtures; the current
runner rejects their profiles. They previously disabled TF classes/abilities while preserving robot,
mode and universal dispensers. Normal hosting still requires TF classes and
Quake weapons. Classless players start each life with 100 HP, 100 armour, fist or
hammer, pistol or enforcer, and 50 bullets. Stations restore the same health and
armour ceiling and replenish ordinary ammunition. Personal weapons stay locked
while piloting, as in normal TB.

## Historical classless weapon placement (retired)

The historical contact-r2 layout uses **16 basic weapon racks, 24 advanced weapon
caches and 24 adjacent ammo pickups**. Every spawn point at the three attacker
stages and defender base has a basic rack: UT Shock Rifle or Doom Chaingun. These
use weapon-stay: each player can collect the gun once per life, but cannot farm
ammunition from an already owned rack. Players must physically collect it.

Advanced caches become available when preparation ends at 60 seconds. A separate
seeded RNG distributes eight per route third across alternating street sides and
sheltered rooms. Ammo is about 2 m from its weapon. All 64 positions match between
profiles and have valid navigation routes from the initial spawn. Advanced
pickups use ordinary 30-second respawns and either team can take them.

UT supplies Bio, Shock, Flak, Minigun, Rocket, Pulse and Ripper across the route.
Only one Sniper Rifle remains, in an exposed street cache near route distance
152 m; the former start/end sniper caches now contain Miniguns. Doom supplies
Shotgun, Super Shotgun, Chaingun, Rocket and Plasma. Redeemer, BFG, translocator
and optional Doom railgun are excluded. TF retains its pickup-free map and
universal stations. These placements are runtime test fixtures; the BSP is unchanged.

Historical `live-*` runs used 48 pickups, no basic racks and three UT sniper
caches. Their preparation samples showed only one armed attacker versus six armed
defenders. The revised layout gives all twelve a basic gun before the gate opens.
The contact-r2 rerun also uses linked cannon-pair heat and direct-hull-contact
pilot protection. Armour remains 200 and cannon damage remains 12 per barrel.

## Evidence

Each JSON records one-second player/goal/weapon/health samples, exact pilot
handoffs, pilot/moving/stopped durations, checkpoint state, deaths, weapon damage,
pickup events, placement coordinates and map checksum. PNGs capture the live
window once per simulated minute. New runs additionally record individual damage
events (including pilot/contact/blast status), fired cannon-pair volleys, and
atomic boarding events with before/after HP, class maximum and exit-lock duration.
Current runs also record body yaw, gib flags and destroyed Blue deployables.
Robot direct hits now use TITAN CANNON, separating them from engineer sentries.
Log files record progress and runtime issues. `analyze_combat.py` summarizes
pilot survival and cannon contribution, flagging ambiguity in historical TF logs.
`check_results.py` checks team count, rule/class isolation, preparation, boarding,
replacement, combat and pickup use, then writes a summary JSON and progress plot.
For example:

```
python3 tools/titanball/simulation/check_results.py test-results/titanball/simulation/live-{tf,ut99,doom}-7129.json
```

The focused `objective_tests.gd` regression exercises real bot input/boarding,
pilot death and replacement, preparation, movement, defender crush avoidance,
elevated safety and isolation from other modes. Existing gameplay tests cover
normal class/loadout enforcement and the robot's combat/route mechanics.

The coverage-r6 study records seed 7129 natively and runs seeds 7130/7131 headlessly. This is an exploratory sample, not an estimate of competitive win rate.
Weapon placement, class composition and bot tactics are part of the experiment;
results do not establish human-team balance. Match additional seeds and alternate
class rosters before changing the map, timer or damage around these results.
