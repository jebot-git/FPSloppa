# Bot aim adjustment — 14 September 2026

Bots previously used a small, periodically replaced position error (roughly half a degree), read the target's live position every combat frame, and shared the same projectile lead factor. This made distant stationary opponents nearly certain hits with accurate weapons.

Combat aim now has smoothly varying drift, modest individual precision differences and changing focus during an engagement. Motion increases error slightly. Bots track their last perception sample with an imperfect velocity estimate between updates, and have individual turn-response and projectile-lead factors. Reaction time is refreshed on a new acquisition. Close-range error is reduced so bots remain dangerous nearby.

The adjustment applies to ranged combat against opponents. Objective interactions, navigation, teammate support and deliberate rocket-jump aiming keep their existing paths. Weapon spread and human input are unchanged. The aim helper adds no raycasts, draws random values only when selecting a new drift segment, and bounds catch-up work after a long idle period.

## Controlled comparison

Eight seeded bot profiles faced stationary or laterally strafing targets at 5, 20 and 40 metres. Each trial allowed two seconds to acquire the target, then sampled its firing line for twelve seconds. The measurement uses the game's real shot origin and hitbox trace, with a zero-spread ray. It measures aim coverage among firing opportunities, not full-match weapon accuracy or a measured human skill level.

| Target | Previous coverage | Adjusted coverage |
| --- | ---: | ---: |
| Stationary, 5 m | 100% | 100% |
| Strafing, 5 m | 51% | 51% |
| Stationary, 20 m | 100% | 92% |
| Strafing, 20 m | 50% | 38% |
| Stationary, 40 m | 100% | 57% |
| Strafing, 40 m | 53% | 30% |

Against the stationary 40 m target, individual bot results ranged from 44% to 71%, with variation within each engagement as well. Bots continue taking firing opportunities; the reduction is not implemented by arbitrarily dropping shots. Smooth-turning and frame-rate consistency checks pass.

## Reaction timing

Before this adjustment, the firing delay was randomly chosen between 240 and 440 ms when a bot brain was created. It stayed the same across target acquisitions. Perception is polled every 200 ms, so that delay was already only one part of the time from an opponent appearing to the first shot.

The current delay is 280–520 ms and is drawn again for each new target or acquisition after more than 600 ms out of sight. A brief interruption while tracking the same opponent retains the existing reaction clock. Aiming alignment can delay firing further. This is a modest slowdown and adds variability rather than imposing a long, fixed pause on every shot.

`deathmatch/tests/bot_reaction.gd` measured actual first shots over 240 trials: ten seeded profiles, twelve appearance phases within the perception interval, and targets directly ahead or 75 degrees to the side. Observed delay was **283–700 ms, median 517 ms**. All trials passed the 280–1,000 ms engagement bounds. The test uses an unobstructed target and a ready weapon; reloads, occlusion and other gameplay conditions can take longer. No additional slowdown was indicated by this result.

As context, Jiang, Kundu and Claypool's [CHI PLAY study of player response times](https://web.cs.wpi.edu/~claypool/papers/reaction-time/paper.pdf) found responses around 325–350 ms in its browser tasks, with appreciably longer responses as decision complexity increased. These are not measurements of VR combat acquisition, and the authors caution about absolute browser timing. They support allowing variable perception and decision delays, not prescribing one exact human-equivalent bot setting.

## Gameplay and performance checks

Weapon trials across Doom, Quake and UT, plus existing humanization, tactics, teamwork and objective-role regressions passed. Four 90-second, eight-bot matches on qsrc_dm6 completed without script/runtime errors: before/after runs for Doom and Quake. Bots kept moving, collecting equipment and fighting. These short matches are smoke tests, not evidence of universal mode balance.

Median full physics-tick time was 1.79 → 1.85 ms for Doom and 1.79 → 1.79 ms for Quake on this machine; the corresponding 95th percentiles were 3.51 → 3.77 ms and 3.62 → 3.56 ms. Match paths diverge, so these figures do not isolate the aim helper's cost or establish headset performance.

The reproducible aiming fixture is `deathmatch/tests/bot_accuracy.gd`; it accepts a JSON argument with `output` and `expect_variation: true`. Optional `ai_script` loads a baseline AI snapshot for comparison. Local snapshots, measurements and full logs are retained in ignored `test-results/bot-accuracy/`. Some scene teardown tests emit the existing ObjectDB warning. Updated Linux and Windows test candidates remain unpublished; Windows execution is unverified.
