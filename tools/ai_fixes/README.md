# AI balance follow-up harnesses

These tools reproduce the navigation, equipment, CTF, IF and Assault follow-up in
[AI-BALANCE-FIXES.md](../../docs/AI-BALANCE-FIXES.md). Results and hashes live in
`docs/validation/ai-balance-fixes.json`; large raw traces are ignored under
`test-results/ai-fixes/`.

`run.py` executes cases serially with a 480-second wall-time bound per child. Each
case guards all project `deathmatch/**/*.gd`, `project.godot`, and the selected
BSP/navigation resource, plus the external harness. A successful process alone
does not establish balance or physical reachability: `summarize.py` checks the
payload assertions and records remaining limitations.

## Reproduce the retained final projects

Run from the repository root:

```sh
python3 tools/ai_fixes/run.py test-results/ai-fixes/project-v1 final tools/ai_fixes/final-jobs.json
python3 tools/ai_fixes/run.py test-results/ai-fixes/project-nav final-access tools/ai_fixes/access-jobs.json
python3 tools/ai_fixes/run.py test-results/ai-fixes/project-nav final-supply tools/ai_fixes/supply-jobs.json
python3 tools/ai_fixes/regressions.py --resume
python3 tools/ai_fixes/summarize.py
```

Passed cases are preserved. Use a **new output label** for a genuinely new trial;
do not overwrite earlier evidence. The fixed engine path in `run.py` points to the
locally retained official Godot 4.7.2 executable. Set it to an equivalent local
binary when moving the harness elsewhere. The project must contain imported
assets and `tools/ai_balance/*.gd` plus `tools/ai_fixes/guided_ai.gd`, because the
external scripts load those helpers through `res://`.

The retained baseline is `/tmp/fpsloppa-ai-fixes-base`. The frozen final match
project is `test-results/ai-fixes/project-v1`; the separate focused-test project
is `test-results/ai-fixes/project-nav`. These are development snapshots, not
release artifacts. Do not edit a snapshot during a guarded run. For future work,
create a fresh project copy excluding existing test-results and use fresh labels.
The historical summarizer intentionally requires these retained raw files and
the local base-assets archive to verify its receipt.

## What each fixture measures

- `match.gd`: ordinary eight-bot 60 Hz authoritative simulation. Records equipment,
  objective events, and five-second position/contact traces without feeding that
  diagnostic information back into AI decisions. Assault stops at normal match
  completion; other modes run for the declared interval.
- `water.gd`: Frigate intake and harbor escape, direct-input and AI-steered
  variants. Only initial placement and route destinations are prescribed.
- `traversal.gd` / `guided_ai.gd`: free and guided qsrc_dm3 movement. Guided trials
  retain production replanning and recovery. Arrival is measured separately from
  the simulation budget; missing baseline routes are explicitly skipped.
- `koth_access.gd`: physical traversal from every team start to the scoring circle,
  with normal movement and a 20-second per-start budget. Optional `survey` mode
  tests spaced navigation candidates before choosing authored spawn replacements.
- `tools/ai_balance/supplies.gd`: spawn–weapon–objective routes and pickup capsule
  clearance. This is a geometry audit, not a combat-safety test.
- `rebake.gd` / `refresh_maps.gd`: explicit asset mutations used during development;
  do not run them while collecting frozen evidence.
- `tools/koth/validate.gd`: stock catalog/menu, explicit maplist, scoring-circle
  geometry and production navigation checks. It waits for the new region to own
  the query result before inspecting a map, then installs bounded jump/drop links.

The `v1`, `v2`, survey and probe job files are retained diagnostic stages, not the
final result set. Only `final-jobs.json` defines the final 18-match matrix plus
four water-route variants. It uses one KOTH seed with paired rosters, two CTF/IF
seeds with paired rosters, and two full Assault matches.

## Focused regressions and current integration

`regressions.py` runs baseline/final traversal plus `bot_balance`, `bot_navigation`,
`bot_objective_roles`, `bot_tactics`, `bot_weapons`, `bot_movement`,
`player_platform`, `instafreeze`, and `frigate`. Their outputs need the fixture's
`test-results/bot-soak`, `test-results/frigate`, and Assault-layout directories.

Current-workspace integration reruns `deathmatch/tests/bot_balance.gd`,
`bot_objective_roles.gd` and `player_platform.gd` with the same headless 60 Hz
engine, and runs `access-jobs.json` against the repository root under the
`integration-access` label. The integration receipt distinguishes these checks
from the frozen matrix because other task threads continue editing the workspace.

KOTH start coordinates and team assignments are authoritative in
`tools/koth/balance.json`. `tools/koth/build.py` consumes them for a source rebuild;
`tools/koth/apply_balance.py` was used for the entity-only patch, preserving all
compiled non-entity lumps and BSPX data. Its before/after receipt should not be
overwritten by routine validation.
