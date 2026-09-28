# CS 1.6 map and bot tactics study

Study date: 2026-09-27. Scope: the five maps in `maps/de_maplist.txt`.
This extends the [map fidelity audit](DE-MAP-FIDELITY.md) and the existing
[cover restoration](CS16-PENETRATION.md). It follows the Tribes study's pattern:
record references and limits, implement a bounded adaptation, then retain
repeatable tests and a compact validation receipt.

## Evidence and interpretation

The video review sampled the first two minutes of four YouTube videos at
10-second intervals, with local contact sheets. These are selected visual
observations, not a complete match analysis or timing measurement. Video-only
excerpts, metadata and contact sheets are local, ignored study artifacts in
`test-results/cs16-study/`; they are not packaged with the game. No captions
were available for the Dust2 clip. Highlight and trick compilations select
unusual successes; they cannot establish how often a tactic works.

| Source | Evidence used | Limit |
|---|---|---|
| Dave Johnston, [Making of Dust2](https://www.johnsto.co.uk/design/making-dust2/) | The original designer explains connected routes, choke-defining arches, raised B platform, window and angled crates. | Design account and 1.6 overview, not a coordinate-accurate blueprint. |
| Pro Gamers, [Best Pro Plays on Dust2](https://www.youtube.com/watch?v=cZcAfKtbJAY), sampled 00:00–01:50 | B-site views at 00:10–00:30 and 01:20–01:50 show separate tunnel/door angles and box cover; 00:50–01:10 shows short-side corner fighting. | Montage; preserve separate approaches rather than copying aim or timing. |
| Pro Gamers, [Best Pro Plays on Nuke](https://www.youtube.com/watch?v=zg1pF-4n_vc), sampled 00:00–01:50 | 00:10–00:30 shows room thresholds; 00:40–01:10 and 01:30 show the upper-site hut/wall and high/low sightlines. | Visual evidence for compartmentalization, not exact hut dimensions. |
| Pro Gamers, [Top 20 tricks on Inferno](https://www.youtube.com/watch?v=eovfGE14QNA), sampled 00:00–01:50 | 00:20, 01:10 and 01:30 show apartment interior thresholds; 00:30–00:50 shows layered crate and wall cover. | Boosts and exploit-like peeks are not introduced. New room shoulders are an authored adaptation. |
| Pro Gamers, [Top 25 tricks on Train](https://www.youtube.com/watch?v=jBxiEhh2fyg), sampled 00:00–01:50 | 01:00–01:10 exposes parallel cars and under-car visibility; interior sequences show corners and changes in height. | Does not establish exact car coordinates or warrant new boost mechanics. |
| Guoguodi, [Counter-Strike FAQ v1.07](https://gamefaqs.gamespot.com/pc/429818-counter-strike/faqs/20859), 2003, §8.1 | Describes Dust2 choke risks, flanking and simultaneous A approaches. | Contemporary player guide with older material retained; weapon claims were not used as constants. |
| WOODENSTICK, [de_aztec strategy guide](https://gamefaqs.gamespot.com/pc/429818-counter-strike/faqs/34776), 2005 | Distinguishes bridge, water and doors, advocates entrance coverage after planting and guarding dropped bombs. | Its A/B naming differs from some references; use project site indices and spatial landmarks. |
| MAV, [Train planting guide](https://counterstrikeadvance.blogspot.com/2015/05/bomb-planting-guide-in-detrain.html), 2015 | Relates a plant to teammates' viewing angles and describes high/low-ramp post-plant coverage. | Community advice; exact plant coordinates were not copied. |
| [CS 1.6 map-callout guide](https://steamcommunity.com/sharedfiles/filedetails/?id=913388004), 2017 | Existing overview reference for the authored maps. | Callouts do not prove a route is physically traversable in this engine. |
| [What Were Tactics Like in 1.6?](https://www.reddit.com/r/GlobalOffensive/comments/1td658v/what_were_tactics_like_in_16/), 2026 discussion | Firsthand recollections discuss defaults, splits, fakes and coordinated entrances, including Train. | Retrospective accounts disagree; no single formation is treated as universal or statistically optimal. |

Inference across these references: recognizable scenery is insufficient if all
bots choose the same shortest route, stand at the objective marker, or converge
on the same interaction. Route choice, the angle a defender watches, and
reachable cover matter together. This is the rationale for the changes below,
not a claim that the new bots reproduce professional CS 1.6 teams.

## Implemented layout changes

| Map | Geometry and tactical application |
|---|---|
| Dust2 | Retain the preceding cover/door restoration. Add long/short A and tunnel/mid B attack profiles, plus long, stairs, tunnel, doors and window holds. No further brush changes were justified by this sample. |
| Nuke | Enclose the existing hut beneath its roof with thin timber sides and two standing-height doorways. Previously its room volume was unioned into the larger A room, leaving the roof without the intended side occlusion. Preserve lobby and outside A routes, and ramp/garage approaches to lower B. |
| Inferno | Add two staggered apartment wall shoulders and lintels. Preserve a central walkable passage and balcony route while adding clearing corners. A attacks split mid/apartments; B retains the banana approach rather than inventing a new connector. |
| Aztec | Extend the west canal ramp run from 320 to 512 reference units and add a level turn around the fixed gate leaf, with an opening in the bridge rail at the landing. The former ramp was too steep for baked navigation. Bridge and canal attackers can now reach B through distinct approaches. Keep bridge, canal and doors as separate tactical features. |
| Train | Reverse the upper-hall stair rise toward the B ramp and add the missing elevated floor. The nested room volume had not supplied that floor inside the larger lower corridor. Verify the continuous upper approach in both directions. Preserve existing under-car geometry and main/ivy A alternatives. |

These are original editable brushes using the project's existing materials.
Distances, room proportions, movement and access remain FPSloppa adaptations.
The study does not authenticate the earlier reference BSPs as Steam originals.

## Implemented bot behavior

`deathmatch/bot_ai/defusal.gd` keeps DE planning separate from other modes.
The editable plan coordinates live in `tools/classic_de/tactics.py`; generated
runtime profiles live in `deathmatch/maps/defusal_tactics.json`.

- Team rank and round select stable attack lanes; each bot advances through
  checkpoints. An 18-second stalled-checkpoint bound releases it toward the
  site. The bomb recovery runner resumes the objective instead of restarting
  its opening route. Round/life identifiers prevent stale route progress.
- CTs divide between sites and use distinct grounded positions looking toward
  their assigned entrances. They retain normal perception, reaction and aim.
- One bot recovers a dropped bomb while teammates cover it. Navigation path
  length chooses the runner, avoiding a nearest-in-3D mistake on Nuke's floors.
- One planned defuser approaches a planted bomb while other CTs cover. Selection
  considers navigation travel and a small kit preference. Active interactions
  keep their lock, dead workers are replaced immediately, and a human or nearby
  bot can still begin defusing through the existing authority rules.
- Post-plant guard choices require a view of the bomb and a compatible floor;
  otherwise they use the existing local defense-position search. Guards face
  the bomb. Threats still interrupt planting/defusing and restore weapon use.
- Profiles match compiled BSP SHA-256, including renamed copies. Unknown hashes
  fall back to the original general site/defense logic instead of applying stale
  map coordinates. No hidden enemy position is consulted by this planner.

The site choice still follows the existing round-based A/B plan. Coordinated
utility lineups, timed multi-lane executes, fake calls, adaptive site choices,
team economy, ladder/boost tactics and save decisions are not implemented here.
Existing flash/smoke behavior and CS shooting rules remain in their own systems.
Defusal still uses this project's wire/key interactions, not retail CS timers.

## Reproduction and validation

After a layout rebuild, bake navigation, refresh tactics, then refresh render
caches. The full VIS builders update map/objective hashes and ballistics data.
For example:

```sh
python3 tools/classic_de/build.py --compiler-dir /path/to/ericw-tools/bin --map nuke
godot --headless --xr-mode off --path . --script tools/classic_de/bake.gd -- nuke
python3 tools/classic_de/tactics.py
godot --headless --xr-mode off --path . --script tools/de_texturing/prepare.gd -- de_nuke_rebuilt

godot --headless --xr-mode off --path . --script deathmatch/tests/defusal_tactics.gd
godot --headless --xr-mode off --path . --script tools/classic_de/verify.gd -- de_nuke_rebuilt
godot --headless --xr-mode off --path . --fixed-fps 1000 --script tools/defusal/bot_soak.gd -- cs16-after
```

The tactical regression checks all five profiles against the installed geometry,
including navigation between lane checkpoints, clear/grounded holds, route
progress, lane splitting, worker ownership/death, bomb recovery and hash rejection.
Map verification walks routes in both directions with the actual fighter and
checks new occluded/open sightlines. Regenerate the base archive before release
packaging; this work updates source-tree runtime assets.

Results and remaining limitations are recorded in
[the validation receipt](validation/cs16-map-tactics-2026-09-27.json).
The seed-controlled 6v6 soak measures task completion and objective behavior;
it is not a balanced competitive tournament or a VR comfort test.

<!-- generated study results -->

## Measured results

Targeted regression and map checks: **1095 passed**. Both runs completed all 30 rounds (60 total).
The table counts half-second samples with more than one living bot pursuing the defuse job, not the number of simultaneous physical defuses.

| Map | Planted rounds, before → after | Multiple defuse-job samples, before → after |
|---|---:|---:|
| de_dust2_rebuilt | 5 → 5 | 109 → 0 |
| de_nuke_rebuilt | 1 → 4 | 13 → 0 |
| de_inferno_rebuilt | 5 → 3 | 86 → 0 |
| de_aztec_rebuilt | 2 → 5 | 51 → 0 |
| de_train_rebuilt | 1 → 2 | 19 → 0 |

Plant frequency changes in both directions; these measurements do not establish better competitive balance. The full receipt also records roaming samples, spawn exits, hashes and source receipts.

The additional penetration audit still reports five Dust2 exit/collision mismatches on its unchanged BSP. All four maps rebuilt here pass that audit. These are recorded separately; the overall broad regression status is not reported as all-green.

Native verification captures: [Nuke hut](../test-results/classic-de/de_nuke_rebuilt/study-hut.png), [Inferno apartments](../test-results/classic-de/de_inferno_rebuilt/study-apartments.png), [Aztec canal](../test-results/classic-de/de_aztec_rebuilt/study-canal-ramp.png), [Train upper hall](../test-results/classic-de/de_train_rebuilt/study-upper-hall.png).

## Visual follow-up: decoration corrections

The matched camera gallery exposed two decoration issues, corrected after the
original study validation above. Inferno's first apartment partition moved from
plan coordinate 496 to 515, clearing the window's complete 489–508 trim bounds.
The generator now rejects partition/lintel overlaps with facade decorations.
Dust2's low A-site sandstone course moved from an internal room overlap at 150
to the actual outer wall at 110. Collision probes verify the old location is
empty and the new location has wall backing. Both maps have rebuilt BSPs,
navigation and desktop/mobile render caches, with updated objective/tactics hashes.

[Before/after gallery](../test-results/de-study-comparison/index.html) ·
[All-map comparison sheet](../test-results/de-study-comparison/comparison-sheet.jpg).
The four study maps use pre-study geometry reconstructed by reversing only the
study edits. Dust2 uses an archived actual BSP from before the trim correction.
Camera transforms, field of view and rendering settings match within each pair;
the gallery includes source hashes and labels this distinction. These images
show geometry changes, not bot behavior.

[Follow-up validation](validation/weapon-decals-map-corrections-2026-09-27.json)
is separate from the original 60-round study receipt. The earlier study's
statement that Dust2 geometry was unchanged applies to that study run, before
this visual follow-up.
