# Validation — 12 September 2026

Godot 4.7.2, ericw-tools 0.18, Linux. Four BSP29 maps compiled, lit and baked to scene caches and navigation meshes. Hill renders were inspected from four directions per map.

- Catalog, host selection and mode/lobby vote list: exactly four KOTH remodels. Configured subsets exclude retired entries; entirely retired lists fall back to the new collection.
- Every authored team spawn has a complete navigation route to its hill: 12 starts each for Solstice, Torture and Hyperborea; 9 for Alichar. Both teams have multiple starts.
- All four hill centres have level collision floors at marker height. Eight positions around each scoring circle pass floor and standing capsule clearance checks.
- Fixed hill scoring passes beyond the former movement threshold, pauses under contention and resumes for the other team at the same position. Snapshot and retired config-option compatibility pass.
- Local dedicated server starts on Solstice Crown with the configured two-map subset, preserves a 16-player setting, and passes RCON authentication, allowed mode change and map change checks.

Eight-bot matches, Doom weapon rules, seed 7129, 180 simulated seconds each:

| Map | Team score | Shots | Longest sampled stationary interval |
|---|---:|---:|---:|
| Solstice Crown | 9 : 106 | 1,188 | 3 s |
| Torture Crucible | 36 : 9 | 1,843 | 1 s |
| Hyperborea Tribunal | 60 : 22 | 1,638 | 3 s |
| Alichar Overload | 8 : 29 | 1,651 | 2 s |

All completed without script/runtime errors, both teams scored, and no prolonged navigation stalls were recorded. These short seeded matches are functional checks, not evidence of competitive balance. The existing one-instance ObjectDB shutdown warning remains; it also occurs in the baseline map tools.

Reproduce using `tools/koth/validate.gd`, `tools/koth/rules.gd`, `deathmatch/tests/run_rcon_tests.py`, and `deathmatch/tests/run_bot_soak.py --case koth_solstice --case koth_torture --case koth_hyperborea --case koth_alichar --seconds 180`. Detailed generated results are under `test-results/koth/` and `test-results/bot-soak/koth-remodel/`.

A final Hyperborea repeat checks the horizontal jump-pad velocity adjustment needed by the widened layout. Human VR/16-player balance testing and release publication are not part of these automated checks.
