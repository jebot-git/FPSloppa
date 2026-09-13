Pressureworks research and design record — 12 September 2026

This is an original map for FPSloppa's TF implementation, targeting 6v6 and supporting 4v4–8v8. It is not a reconstruction of a Quake map. The current playable BSP uses FPSloppa objective entities; running it in unmodified Quake TF would require a separate entity conversion and validation.

**Evidence studied**

| Source | What was examined | Design consequence |
| --- | --- | --- |
| [John Cook's 2fort5 author notes](https://www.filefactory.org/tf/file/1807) | Separated basement flag and battlement capture; moving spawns away from the flag; spreading defense; resupply choices | Put capture in the pump hall, flag in a deeper vault and spawns in a screened service room. Preserve recovery time after defeating defenders. |
| [Grimm [502]'s original TF mapping tutorial](https://www.bspquakeeditor.com/archive/planetfortress_com_factory/tutor.html) | Team spawns, flag/goal entities and scoring relationships | Explicit team objectives and resupply, with both teams tested through pickup, drop and capture. FPSloppa's native entities replace QuakeC goal chains. |
| [Milisend Persono's Quake TF gameplay review](https://www.youtube.com/watch?v=1FmXIXDOzuQ) | Sampled gameplay frames at 1:40–5:20 and read the English automatic captions | Ramps, galleries, door reveals and contrasting room materials aid navigation. The commentary highlights class and grenade learning difficulties; avoid a layout requiring obscure movement abilities. Captions are noisy, and this is anecdotal evidence rather than competitive balance data. |
| [Clan Postal vs. Hostile Takeover on 2fort5r](https://www.youtube.com/watch?v=n_oWtk01B3E) | Sampled the match video at 0:30–7:50; the uploader describes it as Smoothie's Scout/Soldier/Sniper POV from 11 April 1999 | The frames show exposed bridge approaches, distinct battlements, close corridor encounters and ramped interiors. These support keeping Pressureworks' outdoor crossing and covered base encounters visually distinct. This was visual sampling, not a complete tactical annotation of the match. |
| [Public QWTF Play match archive](https://playqwtf.com/) | Downloaded the 8 September 2026 ff-phantomr MVD; validated all 153,770 packet records through EOF; examined embedded flag announcements | Treat flag extraction and dropped-flag recovery as distinct encounters. Keep alternate entrances usable by slow classes. This modern TF derivative informs pacing, not exact FPSloppa class tuning. |
| [FortressOne map repository](https://github.com/FortressOne/map-repo/tree/e9b4176be5a7be4a7eb072a529aa3df33d413bf6) | Local openfire, bam4 and 2mach1 BSP entities and projected horizontal geometry | Observe the contrast between connected rooms, wraparound lanes and broad central space. Pressureworks uses its own brush geometry and proportions, with a central sightline obstruction and three base entrances. |

The 2fort5 readme recommends 8–24 players and explicitly describes respawn distance, defense concentration and health scarcity as design choices. Pressureworks borrows these principles, not its geometry or one-way door implementation. Two screened walkable spawn exits provide protection through layout; they are not invulnerable spawn rooms.

**Demo evidence and limits**

[demo-evidence.json](demo-evidence.json) records the source URL, compressed-file SHA-256, duration and deduplicated capture timestamps. The recording spans 1,226.021 seconds. Nine Red-flag captures occur in the first portion and seven Blue-flag captures in the second. The first announcement is at 57.129 seconds. This is consistent with alternating attacking sides, but the lightweight reader does not fully decode match state or player trajectories. It does not establish average route time or statistical map balance. The archive's summary highlight counter differs from the announcement count, so the raw demo evidence is retained as the basis for this observation.

The demo, downloaded video, captions and reference BSPs remain local research inputs and are excluded from the map package. No player userinfo, chat transcripts or authentication-like fields from the demo are included in the evidence summary. The reproducible announcement reader is [demo_evidence.py](../../tools/pressureworks/demo_evidence.py); its framing follows [ezQuake's demo reader](https://github.com/ezQuake/ezquake-source/blob/master/src/cl_demo.c).

**FPSloppa-specific decisions**

- Rotationally identical geometry, objectives, eight spawns per team, pickups and resupply. Team paint and lighting distinguish bases.
- A raised turbine crossing plus lower flanks; long shallow ramps keep elevated routes usable by every class. Three base doors feed two separated vault approaches.
- A 128 × 64 m playable footprint, with quarry scenery extending beyond the side retaining walls. The current navigation route from enemy flag to own capture is 105.62 m for either team: approximately 9.0 s for Scout or 17.3 s for Heavy at nominal speed, before acceleration, combat or detours.
- Flag-room cover prevents a direct shot from the yard to the flag. The turbine blocks the central base-to-base sniper line. Roof vessels and overhead pipe gantries provide landmarks.
- One rear resupply station per team, two neutral health pickups and two shell pickups. Class loadouts and Engineer dispensers remain relevant.
- Retain the existing 18 m sentry range. From the tested vault position, the two approaches are about 9.87 m and 17.64 m away. A partition blocks fire into the main hall. The final acceptance test also exercises the production turret's damage, range cutoff and occlusion.
- Use a symmetric navigation mesh as well as symmetric geometry. A plain Recast bake produced different triangle paths on opposite sides; clipping, mirroring and splitting seam edges remove that bias.

Automated traversal, objectives and bot skirmishes provide a playable starting balance. They cannot establish human competitive balance. A first human session should run two 10-minute halves with teams swapped, recording captures, dropped-flag recoveries, spawn deaths and Engineer survival; compare 4v4 and 8v8 afterward. Do not tune the whole game's sentry range from a single match.

**Visual revision**

The material pass replaces most sheet-metal wall cladding with brick, adds timber ceilings and beams, and uses copper for the turbine and round overhead pipes. Cobbles give way to gravel and grass along irregular, flush ground boundaries; faceted quarry rock rises above retaining walls. All 30 original texture records are verified unchanged in the compiled map. The revised BSP, symmetric navigation mesh and player-height previews were rebuilt together. See [STYLE.md](STYLE.md) for material roles and screenshots.

**Final acceptance — this BSP**

The visual revision passed 53 checks, all 64 spawn-to-objective navigation routes and eight physical Heavy walks. Both full returns covered about 105.55 m in 17.33 seconds using normal movement without jumping. Sentry firing, range cutoff and collision occlusion passed.

| Skirmish | Duration | Red–Blue captures | Red/Blue flag pickups (flag colour) | Frags |
| --- | --- | --- | --- | --- |
| 4v4 | 30 s | 0–0 | 1 / 2 | 4 |
| 6v6 | 90 s | 1–0 | 5 / 4 | 32 |
| 6v6, team assignments swapped | 90 s | 1–1 | 3 / 3 | 28 |
| 8v8 | 30 s | 0–0 | 1 / 2 | 8 |

These short skirmishes demonstrate active combat and objective access, not statistical balance. The symmetric geometry, navigation and successful physical returns support the starting layout, but human side-swapped sessions are still needed before calling it competitively balanced. No sentry range increase is justified by these results. See `validation.json` for the exact BSP hash and detailed checks.

The first visual-revision run passed its individual phases but was rejected because arena/bot code changed during execution. The complete acceptance suite was rerun successfully against a stable code fingerprint before packaging.
