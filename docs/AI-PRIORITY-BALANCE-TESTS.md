# Priority-ordered AI balance tests

Status: complete — 24 / 24 mirrored/seeded match trials, 149.9 simulated match minutes.

The requested order is qsrc_dm3 navigation → KOTH Alichar → CTF Crownreach → Assault Frigate → TF Vesper → CC/IF. Tests use eight production bots, 60 Hz fixed simulation, and an isolated copy of runtime code/assets. No balance values were changed. The [machine-readable receipt](validation/ai-priority-balance.json) preserves exact inputs, full navigation diagnostics, summaries and limitations. Raw logs and equipment-at-death records are in `test-results/ai-balance/priority-20260912`.

## 1. qsrc_dm3 navigation

- raised_spawn: 0 navigation routes to 57 candidate spawn/pickup destinations (those within 3 m are excluded); projection (-24.0, 6.200001, -16.0).
- water_exit: 42 navigation routes to 57 candidate spawn/pickup destinations (those within 3 m are excluded); projection (2.5, -5.8, -42.24).

Guided trials retain normal movement/physics and force only the chosen goal. Free trials use the production planner. Initial placement is a diagnostic fixture. Inspect the per-seed endpoints and clearance probes in the receipt; a valid navigation route alone is not proof of a usable swim-to-shore route.

The raised spawn has no complete strategic navigation route. Free exploration escaped in one of three seeds, while two remained on the platform. All three guided trials were explicitly skipped because no route exists. At the water exit, all three guided trials remained approximately 5 m below the chosen shore goal despite a complete navigation path; free exploration escaped in one seed. Repair the local bake/connectivity and validate the vertical shore transition before changing global movement. Nearby capsule probes do not establish a usable doorway aperture or complete swim route.

## 2. KOTH Alichar

| Trial | Score red–blue | Basic-loadout deaths / all deaths | Weapon pickups | Max observed stall (s) |
| --- | --- | --- | --- | --- |
| 02-koth-default-7129-m0 | 29–85 | 470/476 | 6 | 2.0 |
| 02-koth-default-7129-m1 | 25–83 | 474/481 | 7 | 1.0 |
| 02-koth-default-9137-m0 | 27–99 | 461/469 | 9 | 1.0 |
| 02-koth-default-9137-m1 | 18–80 | 467/472 | 5 | 1.0 |

Hill occupancy: empty 1.2%, contested 68.0%, red 8.2%, blue 22.5%.
Deaths within 12 m of the hill: 1893. Mean uncontested streaks per round: 1.05s, 1.00s, 1.11s, 0.97s.

Blue won 4/4 rounds, including swapped rosters. 1872/1898 deaths (98.6%) occurred with only basic ranged equipment. This flags a side-dependent bottleneck in these AI trials; it is not a human win-rate estimate.

The supply audit found navigation and clear pickup capsules on all 72 spawn–weapon routes; only 3 cost at most 1.5× the direct hill route. Reachability alone therefore does not establish useful equipment access. Next: compare side-route equipment and approach coverage in an experimental variant, with human confirmation before changing the hill radius.

## 3. CTF Crownreach

| Trial | Score red–blue | Basic-loadout deaths / all deaths | Weapon pickups | Max observed stall (s) |
| --- | --- | --- | --- | --- |
| 03-ctf-default-7129-m0 | 0–0 | 264/266 | 2 | 1.0 |
| 03-ctf-default-7129-m1 | 0–0 | 261/262 | 1 | 2.0 |
| 03-ctf-default-9137-m0 | 0–0 | 262/263 | 1 | 1.0 |
| 03-ctf-default-9137-m1 | 0–0 | 255/257 | 2 | 1.0 |

Flag approaches (unique lives within 12 m): 9; takes: 4; captures: 0. Carrier closest-to-home measurements are retained per run.

1042/1048 deaths (99.4%) retained only starting ranged equipment. All 64 spawn–weapon routes passed navigation and pickup-clearance checks; 62 cost at most 1.5× the direct flag approach.

Carrier episodes lasted 0.70–1.95s; the greatest reduction in straight-line distance to home was 8.60 m. Rocket-launcher owners had these rocket-ammo counts at the take: [2, 0]. Owning a weapon therefore does not establish sustained ammunition access.

Confirmed source issue: the frozen `deathmatch/bots.gd` uses weapon IDs above 2 as its better-equipment predicate. UT99 starts with translocator ID 11, which suppresses the nearby new-weapon boost; Bio Rifle ID 1 also receives the lower unowned-weapon value. This contradicts a combat-equipment interpretation of the rule. Its contribution to failed captures remains a hypothesis. Next: compare a profile-aware equipment predicate and ammo acquisition using the same matrix before reducing defender strength or shortening the map.

## 4. Assault Frigate

| Trial | Score red–blue | Basic-loadout deaths / all deaths | Weapon pickups | Max observed stall (s) |
| --- | --- | --- | --- | --- |
| 04-as-default-7129-m0 | 1–0 | 38/46 | 10 | 1.0 |
| 04-as-default-7129-m1 | 0–1 | 40/46 | 13 | 2.0 |
| 04-as-default-9137-m0 | 0–1 | 27/36 | 11 | 3.0 |
| 04-as-default-9137-m1 | 1–0 | 35/46 | 15 | 1.0 |

04-as-default-7129-m0: 0.0s leg 1, stage 0, checkpoint 0; 13.9s leg 1, stage 0, checkpoint 1; 49.9s leg 1, stage 1, checkpoint 1; 61.8s leg 1, stage 2, checkpoint 1; 69.8s leg 2, stage 0, checkpoint 0; 84.5s leg 2, stage 0, checkpoint 1; 131.6s leg 2, stage 0, checkpoint 1. Attacker water time 0.0s across 0 lives.

04-as-default-7129-m1: 0.0s leg 1, stage 0, checkpoint 0; 12.5s leg 1, stage 0, checkpoint 1; 51.0s leg 1, stage 1, checkpoint 1; 88.5s leg 1, stage 2, checkpoint 1; 96.5s leg 2, stage 0, checkpoint 0; 111.7s leg 2, stage 0, checkpoint 1; 155.9s leg 2, stage 1, checkpoint 1; 167.1s leg 2, stage 2, checkpoint 1. Attacker water time 0.0s across 0 lives.

04-as-default-9137-m0: 0.0s leg 1, stage 0, checkpoint 0; 11.9s leg 1, stage 0, checkpoint 1; 34.0s leg 1, stage 1, checkpoint 1; 67.4s leg 1, stage 2, checkpoint 1; 75.4s leg 2, stage 0, checkpoint 0; 88.9s leg 2, stage 0, checkpoint 1; 113.7s leg 2, stage 1, checkpoint 1; 138.0s leg 2, stage 2, checkpoint 1. Attacker water time 0.0s across 0 lives.

04-as-default-9137-m1: 0.0s leg 1, stage 0, checkpoint 0; 14.8s leg 1, stage 0, checkpoint 1; 63.4s leg 1, stage 1, checkpoint 1; 73.8s leg 1, stage 2, checkpoint 1; 81.9s leg 2, stage 0, checkpoint 0; 96.5s leg 2, stage 0, checkpoint 1; 121.1s leg 2, stage 1, checkpoint 1; 155.7s leg 2, stage 1, checkpoint 1. Attacker water time 0.0s across 0 lives.

All 4 full matches finished normally. First attacks completed in 61.8–88.5s against a six-minute budget; 2 return attacks completed inside the time to beat, and 2 timed out. Wins split 2–2 between red and blue. This does not reproduce an objective that is impossible to complete with the intended attack budget.

No attacker water exposure was observed. These matches compare natural equipment acquisition but do not exercise the alternate water entrance. Retain objective health; a separately guided alternate-entry traversal and then tactical comparison remain needed.

## 5. TF Vesper

| Trial | Score red–blue | Basic-loadout deaths / all deaths | Weapon pickups | Max observed stall (s) |
| --- | --- | --- | --- | --- |
| 05-tf-balanced-7129-m0 | 6–4 | N/A | 0 | 1.0 |
| 05-tf-balanced-7129-m1 | 6–1 | N/A | 0 | 1.0 |
| 05-tf-attack-7129-m0 | 4–4 | N/A | 0 | 1.0 |
| 05-tf-attack-7129-m1 | 4–6 | N/A | 0 | 2.0 |
| 05-tf-heavy-7129-m0 | 3–4 | N/A | 0 | 2.0 |
| 05-tf-heavy-7129-m1 | 4–4 | N/A | 0 | 3.0 |

Flag approaches (unique lives within 12 m): 115; takes: 123; captures: 50. Carrier closest-to-home measurements are retained per run.

Both teams use the same composition within a round. These are composition-specific behavior checks, not one class mix competing against another. Capture credit follows the observed carrier episode. Combat excludes voluntary, environmental, self and friendly damage.

| Class | Opponent combat damage | Approx. active bot-minutes | Damage / active minute | Captures |
| --- | ---: | ---: | ---: | ---: |
| engineer | 9062 | 37.30 | 243.0 | 0 |
| heavy | 2276 | 18.88 | 120.5 | 4 |
| medic | 7365 | 56.15 | 131.2 | 17 |
| scout | 4184 | 55.25 | 75.7 | 17 |
| soldier | 16832 | 56.60 | 297.4 | 12 |

Retain specialization. Per-active-minute damage remains affected by class roles, encounters and approximate exposure sampling; it does not justify a class nerf.

## 6a. Chainsaw Carnage

| Trial | Score red–blue | Basic-loadout deaths / all deaths | Weapon pickups | Max observed stall (s) |
| --- | --- | --- | --- | --- |
| 06-cc-default-7129-m0 | — | N/A | 0 | 3.0 |
| 06-cc-default-9137-m0 | — | N/A | 0 | 2.0 |

Damage categories: {'combat': 27942, 'hunger': 12569}. Hunger and environment are excluded from opponent-combat efficiency.

Hunger accounts for 31.0% of all recorded damage. Use opponent combat alone for weapon comparisons; report hunger separately as mode pressure.

## 6b. Instagib Freeze Tag

| Trial | Score red–blue | Basic-loadout deaths / all deaths | Weapon pickups | Max observed stall (s) |
| --- | --- | --- | --- | --- |
| 06-if-default-7129-m0 | 1–0 | N/A | 0 | 3.0 |
| 06-if-default-7129-m1 | 0–1 | N/A | 0 | 3.0 |
| 06-if-default-9137-m0 | 3–4 | N/A | 0 | 18.3 |
| 06-if-default-9137-m1 | 4–3 | N/A | 0 | 18.3 |

Freezes: 164; successful thaws: 72; scored freeze rounds: 16. These are authoritative events, not inferred from damage.

Ordinary damage totals are not a useful activity measure for this mode. Use the recorded freeze, rescue and scored-round events; successful thaws establish that rescue behavior occurred, not that every reachable rescue was attempted.

06-if-default-7129-m0: last freeze/thaw/round-score event at 40.6s, followed by 259.4s without another such event; 28 shots in total. Planner recorded 4348 unreachable-goal attempts in 9981 route queries (repeated attempts, not unique locations).

06-if-default-7129-m1: last freeze/thaw/round-score event at 40.6s, followed by 259.4s without another such event; 28 shots in total. Planner recorded 4348 unreachable-goal attempts in 9981 route queries (repeated attempts, not unique locations).

06-if-default-9137-m0: last freeze/thaw/round-score event at 283.3s, followed by 16.7s without another such event; 173 shots in total. Planner recorded 743 unreachable-goal attempts in 10776 route queries (repeated attempts, not unique locations).

06-if-default-9137-m1: last freeze/thaw/round-score event at 283.3s, followed by 16.7s without another such event; 173 shots in total. Planner recorded 743 unreachable-goal attempts in 10776 route queries (repeated attempts, not unique locations).

Long event-free intervals are an engagement/recovery concern. Inspect failed qsrc_dm6 routes and rescue access before treating these trials as healthy sustained play. Team-colored roster swaps on this deathmatch layout can reproduce identical spatial play; they are not independent evidence.

## Reproduction and integrity

See [the harness instructions](../tools/ai_balance/README.md) and [supplementary runtime inventory](validation/ai-priority-runtime-inputs.json). Trials ran serially in the requested phase order against a private project copy; fixed inputs were checked after every trial. Successful harness status establishes execution and input integrity, not healthy balance. The [final verification receipt](validation/ai-priority-verification.json) checks coverage, durations, event/score consistency and unchanged runtime inputs. Calibration runs are excluded. Raw result hashes are included in the receipt.

## Interpretation limits

Basic ranged loadout is recomputed from recorded inventories by profile: Doom/Quake allow IDs 0–2 (including melee); UT99 allows 0, 2 and the starting translocator 11, but excludes the acquired Bio Rifle 1. It is not a TF or fixed-loadout strength metric. Raw active-time ID≤2 counters are retained only as diagnostics and are not used for UT99 equipment conclusions. A 12 m approach/death threshold is proximity, not line of sight. Class damage per active minute depends on encounters, roles and survival; it is not a weapon-accuracy estimate. Navigation/capsule supply audits are not live tactical-safety certification. Longer round scores should not be compared directly with the study’s three-minute totals. No movement, objective-health, capture-radius or class nerfs were applied.
