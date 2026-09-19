# TITANBALL balance revision — 19 September 2026

The route is now **350 m**, with checkpoints at **80 m and 230 m**. Only the middle leg gains distance: **80 / 150 / 120 m**, previously 80 / 100 / 120 m. The first approach and final approach retain their lengths.

## Boarding and movement

- Voluntary cockpit exit is locked for **10 seconds** after each successful boarding. Death, disconnect and forced cleanup still eject immediately. The existing cockpit countdown uses the replicated lock.
- Acceleration and braking each take **5 seconds**, up from 2 seconds. Cruise speed remains **0.8 m/s**.
- After an empty Titan fully stops, its ladder remains retracted for another **3 seconds**. Every replacement pilot must wait for deployment, including after a death. Initial round-start boarding remains immediately available.
- Armor is unchanged and verified: the cockpit supplies permanent 200 tier-2 armor. Eligible hull hits lose `floor(damage / 2)` to armor; health receives the remainder. Thus a 120-damage rocket contact costs 60 HP, while 121 raw damage costs 61 HP. Armor is restored for each hit. Small arms and nearby explosions without hull contact remain excluded.

## Initial Ashfall balance layout

Two stronger S-bends around the checkpoints interrupt long corridor sightlines. Eight new 6 m balconies, paired on both sides, have two ramp approaches and low firing cover. Their route positions are 46, 134, 179 and 215 m. The two 13.2 m overpasses retain their elevated crossings and now have wider switchback ramps. All twenty tactical firing positions are connected to the navigation mesh.

The existing 42 street-cover groups remain. Six shared dispensers and sixteen spawn positions have standing clearance and connected navigation. Forward attacker spawns are at 72 and 222 m; the second bay sits 15 m off the route center to avoid balcony access. The defender base moves to 350 m. Checkpoint time awards still require rear clearance, at 90 and 240 m, and still grant three minutes each.

![Route comparison](../test-results/titanball/balance-2026-09/route-layout.png)

Rendered checks: [first checkpoint](../test-results/titanball/balance-2026-09/checkpoint-80.png), [second checkpoint](../test-results/titanball/balance-2026-09/checkpoint-230.png), [side balconies](../test-results/titanball/balance-2026-09/side-balconies.png), [overpass access](../test-results/titanball/balance-2026-09/overpass-access.png).

## Unopposed controller timing

Measured with the actual 60 Hz controller, compiled map collision, boarding restrictions, checkpoint awards and endpoint braking. Times exclude the one-minute preparation period. Timers remain ten minutes plus two three-minute extensions.

| Piloting pattern | First rear clearance | Second rear clearance | Delivery and full stop | Remaining |
| --- | --- | --- | --- | --- |
| Continuous | 1:55.0 | 5:02.5 | 7:22.5 | 8:37.5 |
| 30 seconds on / 30 off | 4:05.0 | 10:27.5 | 15:30.0 | 0:30.0 |
| 15 seconds on / 15 off | 3:40.0 | 9:49.3 | 14:40.0 | 1:20.0 |
| Six minutes idle, then continuous | 7:55.0 | 11:02.5 | 13:22.5 | 2:37.5 |

A nine-minute idle start expires before the first checkpoint. Replacements near the endpoint still finish and stop without overshoot or a restart deadlock.

## Autonomous 6v6 results

| Trial | Winner | Active time | Final progress | CP1 / CP2 cleared | Pilot duty | Boardings | Red / Blue deaths |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Before, seed 7129 | Attackers | 10:58.5 | 300 / 300 m | 2:09 / 4:45 | 58.0% | 40 | 107 / 103 |
| Revised, seed 7129 | Attackers | 15:42.0 | 349.99 / 350 m | 2:37 / 8:05 | 49.0% | 44 | 142 / 163 |
| Revised, seed 7130 | Defenders | 16:00.0 | 349.42 / 350 m | 2:33 / 8:02 | 48.5% | 45 | 154 / 167 |

The matched seed took **4:43.6 longer**, leaving **18 seconds** for the attacker win. The second seed expired **0.58 m short**. Both teams physically occupied new balconies and fought from them: logged health damage originating at the new positions was Red/Blue **183/568** in seed 7129 and **266/409** in seed 7130. Combined, the trials exercised all eight new balcony positions.

These results show a much tighter delivery margin for this bot roster. Two revised rounds do **not** establish a 50% human win rate. The geometry and timing changes were tested together, so their individual contributions are not isolated. Every recorded pilot departure was caused by death; the ten-second voluntary-exit restriction is covered by focused input tests, not bot behavior. Neither new trial encountered an occupied endpoint restart deadlock.

All simulation integrity checks pass, including actual combat on both teams, high-ground occupancy and damage, exclusive attacker boarding, configured exit locks, hull-contact-only pilot damage, and the hidden ladder during movement and stationary redeployment delay. See [comparison metrics](../test-results/titanball/balance-2026-09/comparison.json) and raw trials: [before 7129](../test-results/titanball/simulation/tb-balance-before-tf-7129.json), [revised 7129](../test-results/titanball/simulation/tb-balance-after-tf-7129.json), [revised 7130](../test-results/titanball/simulation/tb-balance-after-tf-7130.json).

![Autonomous bot route progress](../test-results/titanball/balance-2026-09/comparison.png)

The dotted lines mark rear-clearance distances: 90 m shared by both layouts, 190 m for the old second checkpoint and 240 m for the new second checkpoint. Delivery occurs at 300 m before the revision and 350 m afterward.

## Validation and reproducibility

The focused runs recorded **372 passing checks** across boarding, pilot equipment/health, hull damage eligibility, timing, replacement ladders, endpoint restart, objective rules, map acceptance and real ENet replication. The network run used one server and two clients. The map acceptance sweep covers 701 half-meter route positions with both torso yaw limits; all twenty vantages, sixteen spawns and six stations are navigable. Logs and counts are in [validation.json](../test-results/titanball/balance-2026-09/validation.json).

The BSP, source MAP, navigation, raw scene, BC7/ASTC4 caches, texture aliases, sky registration, map catalog, and internal base-asset archive were rebuilt. The initial balance-layout BSP SHA-256 was `1c85fcf72bdaffeae36b143e3e61d95519d8269651e8c0e7b7c10c7928746a0b`. [Asset integrity](../test-results/titanball/balance-2026-09/asset-integrity.json) verifies all nine Ashfall runtime files in the archive against the workspace. Texture compression retains the baked lighting and geometry. Four Vulkan renders were inspected; headset performance was not measured.

Reproduce the bot trials with:

```sh
python tools/titanball/simulation/run.py --headless --speed 4 --seed 7129 --name tb-balance-after
python tools/titanball/simulation/run.py --headless --speed 4 --seed 7130 --name tb-balance-after
```

These are autonomous 6v6 rounds with matching TF rosters (Scout, Soldier, Demoman, Medic, Heavy, Engineer on each team), Quake loadouts, ordinary navigation/combat, fixed 200 HP cockpit and no pilot regeneration. The pre-change trial used seed 7129. Its process loaded the old scripts and BSP before edits began; the old harness recorded the BSP hash at completion after the disk file had changed. Its metadata is corrected to the preserved original manifest, with the originally reported result and an explanatory note retained. The runner now records the hash before loading the match.


## Follow-up layout: linked middle overpass and final approach

The current map adds a third crossing at **179 m**, in the extended middle leg. Its **13.2 m deck** clears the Titan and connects directly to the existing **6 m balconies on both sides** through two switchback ramp flights each. The map now has **24 tactical positions**. A gentle final bend leaves the route at **350 m** and retains checkpoint distances **80 / 230 m** and leg lengths **80 / 150 / 120 m**. A collision ray confirms that this bend blocks the ground-level second-checkpoint-to-base sightline.

Resupply markers now use explicit actual route distances, avoiding the legacy geometry author's stretch conversion. Their positions are **0 / 70 / 104 / 215 / 246 / 348 m**: one at each base and a pair flanking each current checkpoint. All six have floor, standing clearance and connected navigation, and every station was exercised with both teams to verify health, armor and ammunition restoration. Existing valid station positions were retained.

The authored brush planes use nine decimal places to avoid precision loss at long-route world coordinates. The compiled map is sealed. The refreshed BSP, navigation, raw/BC7/ASTC4 caches, catalog, sky registration and local base-asset archive share SHA-256 `8363abb19e2a591e84134db0f3eecd504d423481ed689d35eec73009c89409e3` for the BSP. See [asset verification](../test-results/titanball/balance-2026-09/layout-r2/asset-integrity.json).

Validation covers the full Titan sweep, both balcony-to-overpass paths without descending to the street, all high-ground/spawn/station navigation, dispenser behavior, full-route controller timing and a server with two ENet clients. The network harness retries its same-sequence initial claim on the game's unreliable input channel, retaining the frozen-authority concurrent-boarding check. [Validation counts](../test-results/titanball/balance-2026-09/layout-r2/validation.json).

Rendered views: [middle overpass](../test-results/titanball/balance-2026-09/layout-r2/middle-overpass.png), [left connection](../test-results/titanball/balance-2026-09/layout-r2/balcony-link--1.png), [right connection](../test-results/titanball/balance-2026-09/layout-r2/balcony-link-1.png), [final approach](../test-results/titanball/balance-2026-09/layout-r2/final-approach.png), [second-checkpoint resupply](../test-results/titanball/balance-2026-09/layout-r2/resupply-215.png).

![Current route, overpasses and checkpoint resupply](../test-results/titanball/balance-2026-09/layout-r2/route-layout.png)


### Footprint crush adjustment

The subsequent foot-area adjustment expands the horizontal crush radius from **5.0 to 5.5 m**. Tests exercise players at 5.25 m and 5.75 m on both sides, and the same boundary for enemy deployables. Vertical limits, wall occlusion, team exclusions and the moving-only requirement are unchanged. The stopped-Titan tests now wait through the revised five-second braking interval. The full recorded layout-r2 match was already running when this tweak was requested and uses the earlier **5.0 m** radius; the 5.5 m change is verified separately by the focused crush suites.


### Complete recorded match at 2×

The revised-map autonomous **6v6** match (TF classes, Quake weapons, seed 7129) ran through the full **16:00 active time**, plus the 60-second preparation. **Blue defenders won at 349.76 / 350 m**, approximately **0.24 m short** of delivery. Rear-clearance checkpoints triggered at **2:53** and **7:36** active time. There were **42 boardings**, **47.8% pilot occupancy**, and **178 / 174 Red / Blue deaths**. Both teams physically used three of the new middle-overpass firing positions. All **26 simulation integrity checks passed**. One recorded round is a functional playtest, not an estimate of human win rates.

[Full 2× match video](../test-results/titanball/simulation/tb-2x-layout-r2-20260919-tf-7129.mp4) · [match checks](../test-results/titanball/balance-2026-09/layout-r2/match-checks.json) · [raw results](../test-results/titanball/simulation/tb-2x-layout-r2-20260919-tf-7129.json) · [result frame](../test-results/titanball/balance-2026-09/layout-r2/match-result.png).

Approximate video timestamps: **0:30** hangar opens, **1:57** first checkpoint clears, **3:18** Titan reaches the new middle overpass, **4:18** second checkpoint clears, **5:12** final approach, **8:30** result. As noted above, this recording predates the final 5.5 m crush-radius tweak.

The finished video is **8:33.2**, H.264 **1440×900 at 30 fps**, with synchronized AAC audio. Its complete video/audio decode passed, the final result screen was inspected, and its duration matches the full match at exactly 2× plus the result hold. [Video verification](../test-results/titanball/balance-2026-09/layout-r2/video-validation.json).
