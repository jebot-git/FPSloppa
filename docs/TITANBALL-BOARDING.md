# TITANBALL: boarding protection and recorded TF rerun

Status: the corrected full `boarding-r5` recording is complete. The preceding `boarding-r4` recording is preserved as evidence of the endpoint defect it exposed.

## Setup

Ashfall Boulevard, TF classes and Quake weapons, six attackers versus six defenders, seed 7129. Each team has a scout, soldier, demoman, medic, heavy and engineer. The recording uses native Vulkan Mobile on Intel Arc A770, at 30 video frames per second and 2× simulated speed. Gameplay advances at fixed 1/60-second steps. This is a visual/bot study, not a Quest performance test.

The baseline is the completed `stations-r3` recording with the same six universal stations and twelve high-ground points. Both bases have one station; each checkpoint has an approach-side and beyond-checkpoint station. Soldiers and demomen on both teams navigate to the overpasses and defensive platforms. Ordinary TB hosting and the current simulation runner require TF/Quake; UT/Doom trials are retired.

The rerun adds class-maximum healing at successful boarding, a three-second block on voluntary exits, a cockpit countdown, and the cannon elevation/camera corrections described below. Armour remains 200, cannon damage remains 12 per barrel, and the two barrels on each side still share one heat budget. Nearby splash remains excluded from pilot damage. The robot, map geometry, checkpoint spacing, timers, resupply placement and bot tactics are unchanged from `stations-r3`.

## Boarding behaviour

Only a successful, exclusive server-owned reservation heals the pilot. Defenders, out-of-range players, second claimants and repeated requests by an existing pilot receive no heal. The heal is one-time; subsequent damage persists. The lock rejects both Use and fresh jump exits until three seconds have elapsed. A jump held through expiry does not cause an automatic exit: release and jump again. Death, disconnect and forced cleanup still release the cockpit immediately. Saved weapon/armour are restored on exit; health is not rolled back to its pre-boarding value.

The [40-check boarding regression](../test-results/ba2/gameplay/boarding-results.json) covers all nine class health values, failed claims, exact lock expiry, repeated input, death and disconnect. The [cockpit monitor capture](../test-results/ba2/gameplay/cockpit_feed.png) shows the live `EXIT LOCK 3.0 s` indicator.

## Gate and turret findings

The hangar gate exists, blocks movement during preparation and rises 15 metres when preparation ends. A player camera and a spectator camera at the same position inside the hangar both render it correctly. The old chase camera was behind the rear wall: occlusion correctly hid the gate while back-face culling exposed parts of the interior. Moving that observer inside the wall restores the gate. The simulation chase camera now shortens its offset against map collision and disables interpolation on its manually positioned camera. Production occlusion and gate materials are unchanged.

[Gate comparison](../test-results/titanball/gate-diagnosis-r4.png) · [Gate state receipt](../test-results/titanball/gate-camera.json)

The cannon bones were animated, but the authored hinge's local X axis points opposite chassis X. Applying the controller pitch directly made the rendered barrels elevate opposite the firing direction. The view now converts that sign. Native render assertions compare each visible barrel's world-space axis to the controller's firing direction; the model still uses X-only elevation and the existing slow aim rate. This is a visual correction, without a cannon damage or targeting buff.

[Elevation comparison](../test-results/titanball/turret-elevation-r4.png) · [Native render receipt](../test-results/ba2/gameplay/render.json)

## Validation

Before the recorded rerun: 40 boarding, 40 pilot protection, 61 general gameplay, 25 weapon/contact and 10 bot-objective checks passed. Real ENet server/two-client coverage passed 68 checks. Native Vulkan cockpit isolation, HUD, shell, ladder and visible firing-direction assertions passed. The ENet fixture intermittently exhausted its input-rate token bucket during join traffic while the test deliberately froze the authority clock. A reliable client-ready barrier now waits for both clients to stop automatic input; advancing the test clock by 0.25 s allows the existing limiter to replenish before concurrent claims. Two consecutive final runs passed all 71 assertions, without changing production rate limiting. No runtime script errors occurred in the final runs. Known ObjectDB/resource cleanup warnings remain at test shutdown.

The older multi-hit fixtures now restore their deliberately high test HP after boarding, and the cannon-only fixture advances the remaining boarding timer before testing voluntary exit. These fixture changes preserve their damage and movement assertions.

## Results and video

The first boarding-change run (`boarding-r4`) ended at **299.477 m**, recording a defender win at the 16-minute limit. The robot had stopped after a pilot death inside the final braking zone; later pilots could board but the fixed full-speed stopping-distance test prevented acceleration. **This outcome is not a valid balance verdict.** Its combat and boarding measurements remain useful: mean pilot tenure 3.92 s versus 3.02 s in R3, median 2.50 s versus 2.08 s, and under-one-second episodes 2.97% versus 9.09%. All 101 boardings restored class maximum HP and started a three-second lock. Of these, 75 were wounded boardings, restoring 2,631 HP total. Deaths during the lock still forced immediate ejection.

The correction selects a smaller acceleration/braking speed when restarting near the end, based on remaining distance. It preserves 0.8 m/s cruise away from the endpoint. Thirteen endpoint checks now pass, including the exact recorded stop at 299.477 m, other short approaches, and replacement after a pilot death. Six delivery checks failed before the fix. Existing 61 gameplay, 40 boarding and 27 timing checks also pass.

The requested post-match native ladder inspection passed. After either voluntary exit or death, the belly ladder remains hidden during the two-second braking transition, then becomes visible with the boarding prompt once the empty robot is stationary. The ladder also supports reboarding. No ladder logic change was needed. A further 28-check two-player regression verifies that a different replacement pilot, with no personal reboarding cooldown, cannot board or receive a heal during braking. It checks direct claims and jump input after exit, death and disconnect, then successful boarding only after ladder deployment.

[Ladder after pilot death](../test-results/ba2/gameplay/ladder_after_death.png) · [Hidden during braking](../test-results/ba2/gameplay/ladder_death_braking.png) · [Ladder after normal exit](../test-results/ba2/gameplay/ladder_after_exit.png) · [Endpoint regression](../test-results/ba2/gameplay/endpoint-results.json) · [Replacement-pilot ladder regression](../test-results/ba2/gameplay/ladder-results.json)

The clean `boarding-r5` run delivered the Titan in **14:35.18 active time**, with **84.82 seconds remaining**. Checkpoints cleared at 151 and 348 active seconds. There were 95 boardings, a 4.05 s mean and 2.55 s median active cockpit tenure, 2.11% under one second, and 44.0% pilot duty. All 95 boardings restored class maximum HP and applied the three-second lock; 69 wounded boardings restored 2,229 HP. Attacker/defender deaths were 183/127; cannons scored 29 kills and 4,049 logged health damage. This is a single seeded bot result, not a competitive balance finding.

[Recorded R5 match](../test-results/titanball/simulation/boarding-r5-tf-7129.mp4) · [R5 summary](../test-results/titanball/simulation/boarding-r5-summary.json) · [R5 comparison](../test-results/titanball/simulation/boarding-r5-comparison.png)

The subsequent [coverage and street-cover study](TITANBALL-COVERAGE-R6.md) uses this corrected R5 run as its baseline; the defective R4 outcome is excluded.
