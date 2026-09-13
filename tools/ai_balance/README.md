# Priority-ordered AI balance trials

Follows `docs/AI-COMPETITIVE-BEHAVIOUR-STUDY.md`: navigation on qsrc_dm3,
KOTH Alichar, CTF Crownreach, Assault Frigate, TF Vesper, then CC/IF.
These are exploratory AI trials, not human competitive balance certification.
No production movement, weapon, objective or map values are changed.

Use an isolated project copy, including current runtime assets and Godot import
cache. Copy these `.gd` harnesses into its `tools/ai_balance/` directory. Do not
share writable/hard-linked code or map assets with an actively edited checkout.
The runner records and checks the isolated AI/movement/mode/map/navigation inputs.
A new label preserves previous evidence. Run each phase serially, in this order:

```sh
python3 tools/ai_balance/run.py --project /tmp/fpsloppa-ai-balance-20260912 --label priority-20260912 --phase nav
python3 tools/ai_balance/run.py --project /tmp/fpsloppa-ai-balance-20260912 --label priority-20260912 --phase koth
python3 tools/ai_balance/run.py --project /tmp/fpsloppa-ai-balance-20260912 --label priority-20260912 --phase ctf
python3 tools/ai_balance/run.py --project /tmp/fpsloppa-ai-balance-20260912 --label priority-20260912 --phase as
python3 tools/ai_balance/run.py --project /tmp/fpsloppa-ai-balance-20260912 --label priority-20260912 --phase tf
python3 tools/ai_balance/run.py --project /tmp/fpsloppa-ai-balance-20260912 --label priority-20260912 --phase cc_if
```

`--resume` skips completed, successful runs and retries failed ones. `--seconds`
is for harness calibration only; final balance trials use their declared lengths.
The runner bounds each child to 480 wall-clock seconds and reaps it before starting
the next. Fixed 60 Hz simulation is accelerated; no remote host or network players
are used. Timings are isolated local script/physics observations, not WAN or
headset performance measurements.

Eight production bots use ordinary movement, inventory, damage and objectives.
Navigation prepares before gameplay starts. Seeds are reset immediately before
fresh spawns. Paired rounds exchange the same bot IDs between red and blue; they
do not geometrically mirror the level. Threaded physics still prevents a claim
of exact determinism. Observer and initial admission time are excluded.

- qsrc_dm3: three seeds at each reported trouble spot, free AI and controlled
  navigation-goal trials. Only initial fixture placement is forced; no teleports,
  health or equipment grants occur during a trial. Floor and capsule-clearance
  probes accompany navigation reachability and real traversal. An absent route
  is recorded as a skipped guided trial, not a successful traversal.
- KOTH/CTF: two seeds, both roster orientations, 600 simulated seconds each.
  KOTH records actual empty/contested/uncontested time and ownership intervals.
  CTF records approach proximity, flag takes and closest straight-line distance
  to home while carrying; that distance is descriptive, not route completion.
- Assault: two seeds and both roster orientations, six-minute initial attacks,
  followed by the production timed return leg. Stop on match completion or 735
  seconds. Checkpoint/stage transitions, role, water use and death equipment are
  recorded separately from combat. Water use alone does not prove an alternate
  entrance was completed.
- TF: balanced, scout-heavy attack and heavy/support mixes, identical on both
  teams, with one seed and both orientations, 300 seconds per round. Class mix
  is set before initial spawns, avoiding class-change suicides. Damage is broken
  out by class and divided by active class exposure only in the analysis.
- CC/IF: two seeds, 300 seconds. IF also swaps team rosters. Hunger, environment,
  self damage and voluntary deaths are separated from opponent combat. IF
  freezes, successful thaws and team wipes come from authoritative match events.

Equipment/death records retain actual owned weapon IDs and ammo. Analysis recomputes
basic ranged inventories by profile: Doom/Quake IDs 0–2; UT99 IDs 0, 2 and starting
translocator 11. Acquired Bio Rifle 1 counts as additional ranged equipment. This
metric is inapplicable to TF classes and fixed-loadout CC/IF. The recorder's raw
ID≤2 death flag and active-time counter are historical diagnostics, not the
profile-aware analysis. In particular, do not use that counter for UT99.
Class exposure uses approximate quarter-second samples; per-active-minute damage
is descriptive, not an accuracy measurement or controlled class comparison.
Approach deaths use a 12 m proximity threshold in analysis, not an assertion of
line of sight or a completed route. Historical three-minute and new ten-minute
scores are not directly comparable win-rate samples.

Generate the durable report with `python3 tools/ai_balance/summarize.py`.
After the full matrix finishes, run `python3 tools/ai_balance/verify.py` to check
declared durations, event/score consistency, raw hashes and runtime integrity.
`passed` in a trial status means the harness completed without runtime errors and
its guarded inputs stayed unchanged. It does not mean that mode is balanced.
Supplementary runtime hashes are in `docs/validation/ai-priority-runtime-inputs.json`.
Supply audits use `supplies.gd` against the same isolated project; they check
navigation and capsule clearance, not physical traversal under combat.
