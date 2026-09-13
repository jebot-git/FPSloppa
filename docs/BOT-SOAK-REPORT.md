# Extended bot match report

2026-09-12 · Godot 4.7.2 · Linux headless

All ten game modes were exercised across the 17 bundled layouts and TF Ironspan. The main comparison used 20 five-minute cases per AI revision, with eight bots and a spectator. Focused reruns verified fixes; the final weapon-selection scheduling optimization received another complete 20-case, one-minute sweep. A final low-step recovery refinement added a five-minute BattleF rerun and another assertion. In total, completed match runs covered **367.5 simulated minutes** (accelerated 60 Hz physics).

Every combat slot dealt real damage in 31 controlled Doom/Quake/UT profile-slot trials. These include duplicate/inherited slots, not 31 unique weapons. A separate trial launched and used a real translocator. TF matches rotated class assignments across all nine classes and recorded flamethrower, sniper and sentry damage. **85 assertions plus the traversal and attacking-squad integration tests passed.**

## What the matches exposed and what changed

- Tiny HiSlop could reach checkpoint 1 but never the first console. The missing route was a drop from the middle car’s upper deck into its lower corridor; jumping hits the overhead structure. Controlled drop links, denser Assault boundary sampling and objective-area sampling now connect it. Both objectives and both attacking rounds completed in the five-minute rerun.
- TF bots incorrectly tried to touch-return their own dropped flags. Classic TF uses timed returns. Defenders now guard those flags while attackers continue their objective routes.
- Small collision movements and frequent replanning hid persistent snags. Progress is now measured across replans, with checked backward/sideways recovery and safe descent from low ledges. Translocator destinations need extra wall clearance so bots can walk away.
- Doom slot-based weapon scoring gave Quake grenades and UT shock weapons shotgun-like tactics. Scoring and engagement distance now use weapon/class properties, ammunition, spread, projectile speed and splash safety. Choices run at five Hz; aiming remains at physics rate.
- Bots now use a reaction interval, limited acquisition field of view, small aim error, smooth delta-based turning and irregular strafe intervals. UT secondary fire and short charged salvos are selected where useful; unsafe charged fire cancels when a teammate enters the lane. Quake lightning is avoided underwater.
- Vertical jump pads can supply checked air-steering links to raised landings. Navigation links wait for the region to synchronize. Jump/drop discovery remains bounded to two candidates per physics frame and 96 links. No bot-only teleport, damage, ammunition or objective shortcuts were added.

## Five-minute behavior comparison

“Stationary” means less than 0.4 m movement over a one-second observation window while alive and unfrozen, excluding intentional holds near a goal. It is a warning metric, not proof of a collision bug: aiming, combat and brief route hesitation also count. These are seeded individual trials, not a statistical difficulty/balance study. The table uses the most recent completed five-minute rerun for each case; the JSON receipt links each raw result.

| Map / mode / weapons | Stationary time before → after | Longest pause before → after | Objective result |
|---|---:|---:|---|
| lqdm1-dm-doom | 3.5% → 2.2% | 17.3s → 3.0s | Combat exercised |
| lqdm2-tdm-doom | 5.0% → 3.6% | 4.1s → 5.0s | Team score [37, 39] |
| lqdm3-ctf-doom | 3.5% → 2.5% | 5.0s → 1.0s | Team score [1, 6] |
| lqdm4-koth-doom | 3.5% → 3.1% | 3.0s → 2.0s | Team score [91, 69] |
| lqdm5-ig-doom | 4.5% → 5.7% | 2.0s → 2.0s | Combat exercised |
| lqdm6-ft-doom | 3.5% → 2.4% | 4.0s → 3.0s | Team score [0, 1] |
| lqdm7-cc-doom | 4.8% → 4.5% | 4.1s → 2.0s | Combat exercised |
| lqdm8-if-doom | 6.8% → 6.8% | 3.0s → 3.0s | Team score [7, 10] |
| tf_ironspan-tf-doom | 7.9% → 1.8% | 16.3s → 3.0s | Team score [0, 4] |
| as_hislop-as-doom | 6.7% → 4.3% | 15.2s → 5.0s | Both consoles; score [1, 1] |
| as_frigate-as-ut99 | 2.7% → 2.0% | 2.0s → 2.0s | Both consoles; score [1, 1] |
| dm_lasercade_slop-dm-quake | 2.3% → 2.7% | 7.1s → 3.0s | Combat exercised |
| dm_auhdm2_slop-dm-ut99 | 5.8% → 5.5% | 4.0s → 2.0s | Combat exercised |
| dm_anctomb_slop-dm-doom | 9.0% → 10.0% | 3.0s → 3.0s | Combat exercised |
| dm_anchall_slop-dm-quake | 8.2% → 7.2% | 5.0s → 8.0s | Combat exercised |
| dm_battlef_slop-dm-ut99 | 5.3% → 5.5% | 4.1s → 12.2s | Combat exercised |
| as_hislop_tiny-as-ut99 | 12.3% → 3.1% | 205.3s → 2.0s | Both consoles; score [1, 1] |
| as_frigate_tiny-as-quake | 4.5% → 2.7% | 6.0s → 1.0s | Both consoles; score [1, 1] |
| tf_ironspan-tf-quake | 16.8% → 2.1% | 151.7s → 3.0s | Team score [1, 0] |
| tf_ironspan-tf-ut99 | 28.5% → 2.3% | 28.5s → 2.0s | Team score [0, 2] |

Some route hesitation remains, including an eight-second pause in the longer Anchall trial. A later one-minute BattleF sweep also exposed a 12-second low-step snag, which prompted the checked-jump recovery refinement. The focused rerun still recorded a 12-second pause, so BattleF remains a known navigation limitation. This is not a claim that every corner, scripted mover or custom BSP is solved. Full-size HiSlop, full-size Frigate and both Tiny Assault variants completed their objectives. TF captured under all three weapon profiles; CTF, KOTH, TDM, Freeze Tag and Instafreeze scored through their normal rules.

## Performance and reliability

A separate sequential comparison used the copied runtime, eight bots on LQDM1, 120 simulated seconds per revision, and a 30-second warm-up. Direct measurement around the authoritative arena physics callback gave median **1.680 → 2.399 ms** and p95 **3.636 → 4.940 ms**. This includes bot decisions and ordinary arena simulation; it excludes rendering and engine work outside that callback. It is one local comparison, not a dedicated-server capacity estimate.

The broad runs’ Godot Performance monitor samples include startup outliers and some runs overlapped. They are retained in raw telemetry but are not used as steady-state CPU measurements. Persistent navigation generation is bounded; no engine frame-rate or movement-speed changes were made.

After the first minute, static allocation changed by 0.25 to 0.38 MiB across the selected five-minute matches; the maximum sampled projectile count was 38. These figures include cache population, navigation links and test telemetry, and do not establish leak freedom. The existing one-ObjectDB-instance exit warning also appears in the original baseline.

Two runs stopped with SIGBUS at the same instant that another build replaced the bHaptics native library in the shared workspace. The timing strongly suggests a loaded-library replacement, but there was no crash backtrace to prove the cause. Both scenarios subsequently completed with copied code and native libraries. One earlier candidate run also began during an intermediate script edit and failed parsing; that error was fixed and the case rerun. Final isolated sweeps and regression logs contain no runtime script errors. Test processes have bounded timeouts and are reaped by the runner.

## Reproduce and limits

```sh
python3 deathmatch/tests/run_bot_soak.py --label current --seconds 300
python3 deathmatch/tests/run_bot_soak.py --label focused --case as_hislop_tiny --seconds 300
python3 deathmatch/tests/run_bot_soak.py --project /path/to/copied/project --label isolated --seconds 300
godot --headless --xr-mode off --fixed-fps 60 --path . --script res://deathmatch/tests/bot_weapons.gd
godot --headless --xr-mode off --fixed-fps 60 --path . --script res://deathmatch/tests/bot_humanization.gd
```

Use a new label with `--snapshot-ai` to retain the AI scripts before editing. Copy the runtime too if another task may rebuild native extensions. Raw telemetry is in `test-results/bot-soak/`; the compact durable receipt is [validation/bot-soak.json](validation/bot-soak.json).

Bots remain practice-only. The harness runs normal authoritative mechanics, but has no remote clients, VR rendering or human participants. The human-like changes are behavior design supported by automated observations, not a subjective playtest. Deliberate shock combos, guided Redeemer tactics and unusual custom-map traversal remain future improvements. No build, commit or release was requested or made.
