# AI balance follow-up: fixes and validation

Completed the follow-up to [the priority study](AI-PRIORITY-BALANCE-TESTS.md): 18 final eight-bot matches, **103.3 simulated match minutes**, plus focused movement, equipment, mode and map tests. The [verified receipt](validation/ai-balance-fixes.json) contains per-match results, source hashes, navigation traces, equipment routes and limitations. [Reproduction instructions](../tools/ai_fixes/README.md) accompany the harnesses.

## CTF: equipment and coordinated attacks

The old equipment predicate treated UT99's starting translocator, slot 11, as an upgraded combat weapon. It also undervalued the Bio Rifle in slot 1. Bots now inspect the actual weapon profile, ignore melee and utility equipment for this decision, and require ammunition for at least three shots. CTF and KOTH bots give useful weapon detours enough priority to compete with distant objectives. Pickup reservation and exposure penalties still apply; flag carriers retain their return objective.

CTF attackers now rendezvous at a navigable point along their attack route. The first arrival waits at most three seconds; two nearby teammates can release the push sooner. A release lasts 18 seconds. Dropped flags and carrier returns bypass this gathering step. A carrier receives a close escort and a teammate screening seven metres ahead along the return route; the home defender keeps its role. These decisions use map knowledge and friendly positions, with the existing perception rules for enemies.

Four ten-minute Crownreach matches used UT99 rules, seeds 7129 and 9137, and paired roster swaps:

| Seed / mirror | Red–blue | Flag takes | Weapon pickups | Basic ranged equipment at death |
| --- | --- | --- | --- | --- |
| 7129 / 0 | 0–0 | 15 | 68 | 194 / 258 |
| 7129 / 1 | 0–0 | 25 | 69 | 192 / 257 |
| 9137 / 0 | 1–0 | 11 | 69 | 190 / 257 |
| 9137 / 1 | 0–0 | 10 | 70 | 193 / 258 |

Across the same 40-minute matrix, flag takes increased from **4 to 61**, captures from **0 to 1**, and weapon pickups from **6 to 276**. Basic-loadout deaths fell from 1042/1048 (99.4%) to 769/1030 (74.7%). The longest carrier episode increased from 1.95 to 9.50 seconds; the largest reduction in distance to home increased from 8.60 to 63.52 metres. Takes include recovering dropped flags, so they are not all fresh penetrations of the enemy base. Capture episodes agree with the authoritative score.

This is a meaningful improvement in acquisition and objective activity, but one capture in 40 minutes remains low throughput. The next balance question is carrier survival and ammunition along the return route. These trials do not justify reducing defender damage or declaring Crownreach balanced for human play.

## KOTH: equipment access and usable starts

All four shipped KOTH maps were audited. Baseline physical approaches reached the hill from 36/45 team starts: five Solstice starts and four Hyperborea starts failed the 20-second traversal budget. Solstice also had a super shotgun whose pickup position failed a standing-capsule clearance probe. The remaining maps' pickup capsules were clear, but many useful weapon routes lost to the hill objective's priority.

Solstice and Hyperborea now each have eight physically surveyed starts, four per team. Team assignments minimize differences in measured approach time, elevation and horizontal centroid. Solstice's obstructed shotgun moved to a nearby clear position. The BSP edits change point entities only: all non-entity lumps and BSPX payloads, including geometry, textures, collision, visibility and lighting, were verified unchanged. The source generator reads the same authoritative [balance configuration](../tools/koth/balance.json), and scene caches were refreshed.

Paired five-minute Doom-rule matches, seed 7129:

| Map | Baseline scores, mirrors 0 / 1 | Final scores, mirrors 0 / 1 | Baseline → final weapon pickups, both matches |
| --- | --- | --- | --- |
| Solstice Crown | 0–259 / 6–233 | 32–136 / 58–105 | 31 → 84 |
| Torture Crown | 45–19 / 43–36 | 52–44 / 38–48 | 13 → 39 |
| Hyperborea Crown | 121–40 / 116–25 | 48–26 / 36–31 | 7 → 39 |
| Alichar Crown | 20–49 / 13–44 | 65–67 / 88–34 | 7 → 99 |

Final physical traversal passed **37/37 starts**: Solstice 8, Torture 12, Hyperborea 8 and Alichar 9. All **224 spawn–weapon combinations** had a navigation route to the weapon and onward to the hill, plus clear pickup capsules. The scoring-circle floor, standing clearance, stock map menus and explicit custom-map lists passed the KOTH validator. The 37 physical approaches also passed again against the current shared workspace after concurrent presentation-cache changes.

Solstice's blue advantage is smaller but remains in both trials. Hyperborea's red advantage is much smaller; Torture and Alichar trade wins. These paired samples are exploratory, not human win-rate estimates. Equipment reachability and acquisition improved on every map; tactical safety under enemy fire is a separate property.

## IF: why engagement stopped

A fresh five-minute baseline reproduced eight freezes and two thaws, with the last mode event at 40.57 seconds. Position and contact traces exposed living bots at **Y = 16,063.46 metres**, above the playable map. Coincident respawns caused mutually overlapping player capsules to form rising stacks during penetration recovery. The existing player-platform mask check alone did not prevent this overlap case.

Spawn placement now checks live logical actor positions before the physics server has synchronized the new transforms. If the selected position is occupied, it searches bounded nearby floor positions with world-capsule clearance and hazard rejection. Authored spawn yaw is preserved. Ordinary lifts still carry players; the fix does not teleport stuck bots during play.

| Seed / mirror | Red–blue rounds | Freezes | Thaws | Last mode event | Longest mode-event gap |
| --- | --- | --- | --- | --- | --- |
| 7129 / 0 | 9–3 | 86 | 18 | 299.72 s | 16.17 s |
| 7129 / 1 | 3–10 | 86 | 18 | 299.97 s | 16.17 s |
| 9137 / 0 | 4–5 | 79 | 24 | 294.73 s | 17.88 s |
| 9137 / 1 | 5–4 | 79 | 24 | 294.73 s | 17.88 s |

All final IF trials lasted 300 seconds. Maximum sampled height stayed below 8.68 metres. Round events agree with scores. The reproduced multi-minute quiet period disappeared; this does not imply that every short tactical pause is a bug. A new regression repeats simultaneous eight-player spawns across six cycles and checks bounded height, alongside weapon-profile and empty-ammunition cases.

## Assault: water entrance and full matches

Frigate's underwater intake and harbor escape were tested separately with direct ordinary movement inputs and AI steering, using normal player physics and map water volumes. Initial placement and intermediate destinations are diagnostic fixtures; no movement boost or equipment grant is used. All four cases passed before and after the changes:

| Route / control | Final travel time | Time in water |
| --- | --- | --- |
| Intake / direct input | 8.58 s | 5.03 s |
| Intake / AI | 4.38 s | 1.80 s |
| Harbor escape / direct input | 3.43 s | 1.17 s |
| Harbor escape / AI | 2.05 s | 0.80 s |

Two final mirrored Frigate matches completed both legs normally with the six-minute initial attack budget. First attacks completed in 45.43 and 46.20 seconds; the return attacks reached stage 1 and ran out of the shorter time to beat. Both scores were 1–0. The full Frigate regression passed. Natural attackers still did not select the alternate water entrance in these matches, so the water fixtures establish physical usability, not its tactical value under fire. Objective health remains unchanged.

## DM3: disconnected spawn and water-exit recovery

The qsrc_dm3 navigation bake now uses 0.1 m cells, retaining the 0.4 m radius and 1.7 m height. Bounded jump/drop discovery prioritizes boundary edges near player starts. This exposes exits from the small raised-spawn island. AI movement also skips the initial path point when it is merely the projection above the actor's feet, and maintains a low stance while crawling out from under a slab. An unreachable strategic goal under a low ceiling can initiate the existing bounded recovery movement instead of resetting to an idle hold.

With the same guided harness and seeds 7129, 9137 and 12011, the baseline raised spawn had no strategic route and all three guided attempts were explicitly skipped. The final bake offered 43 reachable destinations, and all three guided bots arrived in about 3.0 seconds. The water exit had 42 routes in both versions, but baseline bots never reached shore within 60 seconds. Final arrivals were **14.92, 15.47 and 14.92 seconds**. All six final free-planning trials also left their initial stuck areas. The guided harness retains normal replanning and recovery, changing only the selected strategic destination.

## Validation and delivery

Nine focused production suites passed: new balance regressions, navigation, objective roles, tactics, weapons, movement, player platforms, IF rules and Frigate. Baseline/final traversal runners passed their evidence checks. Spawn/equipment, objective-role and player-platform suites also passed against the current shared workspace. The current role suite includes 19 checks, with explicit coverage of the rendezvous timeout, immediate two-bot release, carrier screen, and carrier/dropped-flag bypasses. The final matrix guarded all runtime GDScripts, project settings and selected BSP/navigation inputs against changes during each case.

Harness maintenance during the investigation included creating a missing weapon-test output directory, replacing removed optional-map names in the IF fixture, and updating the KOTH validator to wait for its actual navigation query snapshot and include production jump/drop links. Stock catalog checks now exclude modified imports, which are intentionally allowed in other modes. A transient unrelated filtering parse error in the first snapshot was synchronized from the already-fixed workspace before baseline collection. Failed setup attempts are excluded from gameplay comparisons.

The local base-assets archive was rebuilt. The receipt verifies the changed BSPs, navigation resource and scene caches against both the archive and its manifest. Concurrent workspace changes to connection handling, default TF state and presentation caches were preserved; the tested spawn function still matches exactly, with the integration checks above covering the current workspace. No release was published by this task.

The serial final matrix ran on Godot 4.7.2 at 60 Hz, with eight production bots and ordinary authoritative movement/combat. Other isolated diagnostics overlapped in wall time, so timing measurements are not performance benchmarks. The paired roster swaps are not independent statistical samples. No WAN, headset, human competitive-balance or frame-time claims are made.
