# TITANBALL: lateral coverage, street cover and stomping

Ashfall Boulevard now has a 15° lateral robot aiming arc, shoulder rubble and wrecks, a recessed hangar gate, gibbing crush deaths, and stomp destruction of Blue deployables. The native recorded 6v6 test and two additional seeds use the same final BSP and runtime sources.

## Changes

The torso turns up to **7.5° either side of the route heading**, at the existing slow 6°/s rate. Cannon acquisition and impact endpoints use that same route-centred arc, preventing torso yaw from stacking with a second lateral cone. The cockpit monitor camera follows the torso. The cannons still have X-only elevation hinges, ±45° elevation, 60 m range, 12 damage per barrel, a 0.5 s volley interval and one shared heat reservoir per pair. Their existing 1.25 m splash can catch targets just beyond the lateral boundary. They remain automatic sentries; no manual weapon control was added.

The inspected runtime before this change actually used ±3° authored body sway and a ±4° cannon tolerance, rather than ±5° for both. The new limit is a shared constant. The view applies the torso turn while preserving the original global leg poses. A regression exposed accumulated hip-position drift because the optimized walk clip omits constant position tracks; resetting those hip poses before sampling fixes that accumulation.

Moving crush damage now explicitly gibs defenders and places its effect above the ground. The same swept **5 m radius / 1.8 m ground-height** zone destroys Blue sentries, dispensers and settled thrown charges. It operates during occupied motion and unmanned braking, subject to wall occlusion. No damage occurs during preparation, standstill or obstructed motion. Red equipment and neutral map resupply remain intact. Settled charges are removed with a cosmetic destruction effect, without detonating their damage; airborne projectiles retain normal behavior. Destruction is authoritative and disappears on network replicas.

The BSP adds **42 cover groups: 8 wrecks, 28 rubble piles and 6 broken walls**. They use the existing industrial metal, masonry and rubble textures, alternate between street shoulders and leave the robot's central route clear. The 1.2 m thick gate lies inside its 2 m wall pocket, recessed 0.4 m on each face. Preparation, firing slits, gate opening, six shared stations and checkpoint locations retain their existing rules.

After the matches, the cockpit monitor gained **`TO GOAL … m`**, showing remaining distance along the winding route to one decimal place, alongside checkpoint count. It updates from current robot progress and clamps at zero after arrival. Native captures verify the start, a 0.32 m remaining case and completion. This HUD-only addition does not change the recorded combat results.

The map was rebuilt with full VIS, extra4 coloured light, one bounce and baked dirt/AO. Full-resolution mipmapped **BC7 and ASTC4** caches, uncompressed fallbacks, texture-dictionary cache aliases, the map catalog SHA and default sky association were refreshed. No real-time lights or fog were added.

## Navigation correction

The first short attempts exposed Godot path-query errors while bots projected destinations onto disconnected new scenery tops. Those attempts were stopped and excluded from all combat results; their logs and partial recordings remain in `test-results/titanball/simulation/coverage-r6-aborted-navigation/`.

Ashfall's baked navigation now retains the connected street/ramp component and excludes disconnected roof and wreck-top islands as walking destinations. This changes navigation only, preserving the physical cover and ordinary player movement. Acceptance verifies that **all sixteen spawns, six stations, twelve tactical high-ground points and all four overpass ramp routes remain connected**. The corrected short probe and completed headless rounds produced no path-query errors. Human players can still jump onto physical cover; bots do not select disconnected scenery tops as walking goals.

## Test conditions

Six attackers versus six defenders, TF classes and Quake weapons only. Each team has one scout, soldier, demoman, medic, heavy and engineer. The 300 m route uses one minute of preparation, a ten-minute active timer and two three-minute extensions after rear clearance at 90 m and 190 m. Successful boarding heals to class maximum, voluntary exit is locked for three seconds, replacement waits for the deployed ladder, and permanent 200 armour absorbs direct hull contacts. Nearby splash remains excluded. No new armour, damage, speed, heat, resupply or class changes were made for these trials.

The baseline is the corrected **R5 native recording, seed 7129**. The new primary recording uses seed 7129, native Vulkan Mobile on Intel Arc A770, 30 fps video and 2× simulated speed. Additional seeds 7130 and 7131 run headlessly at 4×. All gameplay steps remain 1/60 second. The additional seeds are robustness checks, not paired baseline trials. The defective R4 endpoint outcome is excluded.

These are autonomous bot matches: no test-driven aiming, movement, boarding, damage or respawns. Telemetry includes exact handoffs, class-maximum boarding events, damage/contact/gib flags, paired cannon volleys, deployable destruction, body yaw and actual high-ground occupancy. Rendering load and movie writing make these runs unsuitable as VR performance measurements.

## Results

**Defenders won all three new trials**, stopping the Titan at 299.68, 297.72 and 286.41 m. The new primary run missed delivery by **0.32 m**. This points to a defender advantage at the final approach for these bots and this class roster; it does not establish a human-team win rate or a large advantage across the whole map.

| Measurement | R5 baseline, 7129 | R6 native, 7129 | R6 headless, 7130 | R6 headless, 7131 |
| --- | ---: | ---: | ---: | ---: |
| Result | Attackers | Defenders | Defenders | Defenders |
| Distance | 300.00 m | 299.68 m | 297.72 m | 286.41 m |
| Active time | 14:35.18 | 16:00 | 16:00 | 16:00 |
| CP1 / CP2, active seconds | 151 / 348 | 179 / 389 | 157 / 341 | 170 / 386 |
| Boardings | 95 | 100 | 88 | 98 |
| Pilot duty | 44.0% | 39.5% | 39.1% | 37.9% |
| Mean / median pilot tenure | 4.05 / 2.55 s | 3.79 / 2.40 s | 4.27 / 2.57 s | 3.71 / 2.65 s |
| Cannon kills | 29 | 43 | 41 | 45 |
| Cannon logged health damage | 4,049 | 5,805 | 5,175 | 5,266 |
| Cannon damage / occupied second | 10.51 | 15.30 | 13.78 | 14.49 |
| Cannon share of defender deaths | 22.8% | 29.3% | 27.5% | 31.0% |
| Attacker / defender deaths | 183 / 127 | 207 / 147 | 209 / 149 | 214 / 145 |

**Combat efficiency improved.** In the matched native run, cannon kills rose from 29 to 43 (+48%), and damage per occupied second rose from 10.51 to 15.30 (+46%). The latter controls for the longer match: it is not simply a larger total from playing longer. Direct damage events per fired round rose from 65.3% to 73.8%; 897 rounds were fired. Cannons produced 6.80 kills per occupied minute, versus 4.52 previously, and 0.43 cannon kills per pilot death, versus 0.31. Two volley events reached the overheat cap; one additional-seed run had one, the other none. Heat is not the main limitation in this sample. Damage figures are post-armour logged health damage and may include overkill; huge crush damage is excluded from efficiency totals.

**Pilot survivability did not materially improve.** The primary mean and median slipped slightly; pooling all three new rounds gives 286 observed cockpit tenures, mean 3.91 s and median 2.55 s. Every tenure ended in pilot death. All boardings healed to class maximum and applied the three-second exit lock; 63 of the primary run's 100 pilots died during that lock, which blocks voluntary exits rather than granting invulnerability. Three primary episodes lasted under one second. No non-contact damage reached a pilot. Shotgun/nailgun fire and direct rockets remained the main lethal attacks.

**The final section favors defenders.** In the primary run, mean pilot tenure fell from 6.76 s before CP1, to 4.49 s between checkpoints, to 2.52 s in the final 110 m. Both teams physically used high ground: approximately 538 attacker and 644 defender bot-seconds in the primary run, with 19 and 15 high-ground kills respectively. The additional runs recorded 26–27 defender high-ground kills. These are sampled occupancy measures, not merely assigned AI goals.

The final-metres stall was **not the old endpoint restart defect**. At 299.34 m, the next pilot took over at simulated time 980.62 s, accelerated normally and died 0.65 s later; a further pilot took over at 1001.98 s, accelerated and died after 1.13 s. Both were scouts. The final robot position was 299.68 m after braking. Before those attempts, one pilot-to-pilot gap lasted 83.87 s. Samples show attackers repeatedly dying or approaching from the forward spawn/high-ground routes while the ladder was deployed; no sampled occupied robot was stuck in the old parked endpoint state. Replacement access and the long last approach matter alongside pilot HP. These bot travel/selection behaviors limit how directly this result transfers to coordinated human teams.

The new cannons provide useful suppression, but cannot by themselves keep a pilot alive under focused hull fire. Since cover, navigation and aiming changed together, this study does not isolate the contribution of each. No further armour, damage or timer tuning was applied after the results.

The stomp destroyed **five Blue pipe charges** across the three matches (3 / 1 / 1). No engineer building happened to be underfoot in these matches, and no defender entered the lethal footprint. Blue sentry/dispenser destruction and player gibs therefore have direct fixture, native visual and network coverage rather than a natural-match kill example.

[Full recorded match](../test-results/titanball/simulation/coverage-r6-tf-7129.mp4) · [Comparison figure](../test-results/titanball/simulation/coverage-r6-analysis.png) · [Detailed combat and pilot measurements](../test-results/titanball/simulation/coverage-r6-analysis.json) · [Match integrity checks](../test-results/titanball/simulation/coverage-r6-summary.json)

The video plays at 2× match speed; use 0.5× playback for normal timing. The last two minutes of video contain the final-base pressure and replacement gaps.

## Validation and evidence

- **303 focused gameplay/bot checks passed**, covering boarding, pilot protection, hull-contact damage, ladder restrictions, endpoint restart, timing, lateral bounds, leg poses, cannon splash/heat, defender gibs and Blue deployables.
- **80 real ENet assertions passed** across the server and two clients, including concurrent cockpit claims, crush gibs and Blue sentry destruction. The fixture now keeps broadcasting the final unreliable snapshot until both clients acknowledge completing their checks, avoiding premature server teardown.
- **39 BSP acceptance checks passed**, including robot collision clearance at every 0.5 m of the route, at −7.5°, 0° and +7.5° torso yaw, and the navigation checks above.
- Native Vulkan captures passed cockpit/HUD/isolation, complete robot shell, cannon direction, ladder, recessed gate, gib pieces and removal of the Blue sentry's visual.
- Each new full match passed **26 integrity checks**, including the 7.5° bound, boarding healing/lock, high-ground use and absence of the endpoint deadlock.
- Both compressed texture variants retain source resolution, mipmaps, baked light/glow images and filtering behavior. The final BSP SHA is `f770cb803e46fb5bff353d4f31d8b1a08a73d712109c44675c06000fd6bf8649`.

Known fixture shutdown ObjectDB/resource cleanup messages and native MultiMesh interpolation warnings remain. No runtime GDScript failures occur in the final passing tests. This is a desktop visual and bot study; human-team balance and Quest performance remain unmeasured.

[Distance-to-goal monitor](../test-results/titanball/coverage-r6-evidence/cockpit_feed_distance_to_goal.png) · [Street wreck](../test-results/titanball/coverage-r6-evidence/street_wreck.png) · [Rubble cover](../test-results/titanball/coverage-r6-evidence/street_rubble.png) · [Recessed gate](../test-results/titanball/coverage-r6-evidence/hangar.png) · [Blue sentry before stomp](../test-results/titanball/coverage-r6-evidence/blue_sentry_before_stomp.png) · [Gibs and destroyed sentry](../test-results/titanball/coverage-r6-evidence/crush_gibs.png)

[Gameplay receipt](../test-results/titanball/coverage-r6-evidence/regressions-r6.json) · [BSP receipt](../test-results/titanball/coverage-r6-evidence/acceptance.json) · [Lateral regression](../test-results/titanball/coverage-r6-evidence/lateral-results.json) · [Deployable regression](../test-results/titanball/coverage-r6-evidence/deployable-crush.json) · [Network receipt](../test-results/titanball/coverage-r6-evidence/network.json) · [Native render receipt](../test-results/titanball/coverage-r6-evidence/render.json) · [Texture cache checks](../test-results/titanball/coverage-r6-evidence/assets.json) · [Validation receipt](validation/titanball-coverage-r6.json) · [Sources used by the matches](../test-results/titanball/simulation/coverage-r6-source-hashes.json)

## Reproduce

```sh
python3 tools/titanball/simulation/run.py --name coverage-r6 --speed 2 --record
python3 tools/titanball/simulation/run.py --name coverage-r6 --seed 7130 --speed 4 --headless
python3 tools/titanball/simulation/run.py --name coverage-r6 --seed 7131 --speed 4 --headless
```

Use a different `--name` to preserve these recordings. The comparison tools are `check_results.py`, `analyze_combat.py`, `analyze_high_ground.py` and `analyze_coverage.py` under `tools/titanball/simulation/`. Raw AVI, encoded MP4, minute screenshots and JSON telemetry are retained locally. No executable/APK release or GitHub publication is part of this change.
