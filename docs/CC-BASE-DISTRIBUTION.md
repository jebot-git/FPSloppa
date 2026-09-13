# Base map selection and CC rebuilds

12 September 2026 · Godot 4.7.2 · ericw-tools 0.18

The base DM, IG, FT and TDM selection is **Quake DM1–DM7**, under `qsrc_dm1`–`qsrc_dm7`. IF inherits IG's maplist. Base CC now contains only four new LibreQuake derivatives. At the owner's request, CTF uses the six existing CTF Studies maps. KOTH, current TF and full-size Assault keep their dedicated maps.

Original LibreQuake arenas move to the optional **LibreQuake Expansion**, combining lqdm1–lqdm13. The eight former base maps are tested in the requested four modes; the five extras retain their prior geometry/spawn checks. Previously bundled community DM conversions are retained outside base staging too. **Nothing filters or deletes user imports, and explicit server maplists keep their entries and ordering**, including optional maps or intentional cross-mode choices. Existing editable maplist files are preserved on asset installation. Fresh distributions receive the new defaults.

## Evidence used to choose CC layouts

- The retained 0.10v live analysis (`test-results/live-session-analysis.json`, source `serverup.log`) has 97 CC health samples, up to five players. It records **31 fatal chainsaw events and 32 hunger deaths**, with one environmental death. Typical ping was 28 ms, but the p95 was 244 ms; this is not a controlled map-only or hit-detection experiment.
- Previously replayed demo `2026-09-11T20-30-08.fpsdemo` contains 5,700 Hyperborea/CC frames plus 493 Basement/FT frames. Its summary is retained in `test-results/live-demo-analysis.json` and `docs/validation/live-0.10v/demos.json`. This identifies actual human play on Hyperborea, but does not provide a reliable miss denominator or prove that every hunger death was caused by map size.
- The earlier five-minute Basement/CC bot recording has **33 chainsaw kills and 34 hunger deaths**, with a long-pause metric of about two seconds after the AI fixes. See `docs/BOT-SOAK-REPORT.md` and `test-results/bot-soak/current/lqdm7-cc-doom.json`.
- Psychofuge previously supported sustained KOTH combat and short navigation pauses; Ghost Quarter had functional FT navigation. Neither has a human CC sample in the reviewed logs. They were selected as promising layouts, then measured with new CC baseline matches, rather than presented as already proven human CC maps.

The design inference was to reduce time spent seeking opponents and awkward vertical detours while retaining places to evade/parry. CC drains three health per second and replenishes health through chainsaw damage: isolated or excessively distant starts make finding an opponent disproportionately important. Weapon range, drain rate, healing and damage were left intact.

## Actual remodels

| New map | Source | Geometry and layout work |
|---|---|---|
| Hyperborea · Blood Court | lqdm3 | Temple court retained; distant eastern arena removed. Horizontal court size reduced to 87.5%, height retained. Broad dry crossings join the irregular court; side paths remain. A first candidate kept too much surrounding map and had worse hunger results, prompting the bounded court revision. |
| Psychofuge · Saw Pit | lqdm4 | Wider central bridge beside lava, an additional passing lane, and a return ramp. Some peripheral lava remains, so hazard deaths are still possible. |
| Ghost Quarter · Butcher's Walk | lqdm6 | Connected raised walkways and a return ramp into the lower court, shortening the route between nearby opponents on different levels. |
| Boomstick Basement · Meat Grinder | lqdm7 | Direct lower-to-upper ramp and landing, preserving flanks around the original rooms. |

All have sixteen dry, grounded, standing-capsule-clear starts. Every start has a complete route to every other start; longest measured spawn routes are about 29–33 m. Pickups unused by CC, ambient entities and selected collision-free ornaments are removed. Added surfaces use the source map's floor materials and the existing Makkon substitution dictionary. Textures retain original donor miptex records. Original/adapted source maps, licences, hashes and a used-texture-only WAD ship under `maps/CC/`.

The final cached-map counts show reduced scene overhead:

| Map | Mesh instances before → after | Scene nodes before → after | Triangles before → after |
|---|---:|---:|---:|
| Hyperborea | 161 → 2 | 278 → 27 | 26,006 → 5,361 |
| Psychofuge | 612 → 285 | 735 → 370 | 14,920 → 15,033 |
| Ghost Quarter | 29 → 17 | 161 → 122 | 23,139 → 22,205 |
| Basement | 26 → 22 | 233 → 159 | 15,078 → 15,382 |

These are geometry/scene counts, not measured GPU draw calls. New ramps add some triangles; reducing nodes and material/ornament instances is the main optimization outside the trimmed Hyperborea court. Hyperborea's navigation mesh carries a finer edge-merge rasterization setting to avoid two synchronization warnings from closely spaced edges; other maps retain their existing behavior.

## CC match comparison

Same eight-bot harness, seed 7129, Doom rules, 180 simulated seconds per map. No bot damage, navigation or teleport shortcuts were added.

| Source → remodel | Chainsaw kills | Hunger deaths | First chainsaw kill |
|---|---:|---:|---:|
| Hyperborea | 17 → 23 | 19 → 19 | 29.6 → 11.8 s |
| Psychofuge | 21 → 27 | 13 → 17 | 18.5 → 11.1 s |
| Ghost Quarter | 20 → 30 | 17 → 17 | 11.1 → 26.4 s |
| Basement | 13 → 33 | 25 → 15 | 15.4 → 4.6 s |
| Total | **71 → 113** | **74 → 68** | — |

All final matches completed without script errors; longest sampled unintended pauses were about two seconds. These single-seed comparisons support increased combat activity, not universal improvement: Ghost Quarter's first kill was later and Psychofuge had more hunger deaths. No competitive balance or 16-player headset performance claim is made. CPU timings are retained in raw reports but some runs overlapped other validation work, so they are not used for a speedup claim.

## Distribution and compatibility validation

- Seven Quake maps passed spawn, collision, water, mover and teleporter traversal checks. DM6's earlier swimming failure came from simultaneous water probes entering a submerged teleporter and telefragging. Water probes now isolate hydrodynamics; teleport behavior is separately tested. Production swimming and Quake map geometry were unchanged.
- Every base Quake map ran with eight bots in DM, IG, FT and TDM for 45 simulated seconds: 28 cases.
- Each of the eight former bundled LibreQuake maps ran the same four modes for 45 simulated seconds from optional-map paths: 32 cases. This is compatibility coverage, not a long-match balance study. No new four-mode coverage is claimed for lqdm9–lqdm13.
- All six CTF Studies passed native spawn/flag checks, both-direction capsule walks and a one-minute eight-bot match. The checks include actual take/drop/capture rules. Five brief matches ended without a team capture; Skyfracture scored 3:0. Passing these checks does not mean equal team balance.
- Menu, lobby, vote, imported-map hosting and explicit custom-list ordering checks passed. One initial test teardown crashed while imported-map navigation was still baking; the test now waits for that asynchronous work before rotating/freeing the test arena. Its rerun passed. The pre-existing one-instance ObjectDB shutdown warning remains.
- Dedicated-server/RCON checks verify configured capacity, selected subsets and map/mode changes.
- Two additional dedicated-server/RCON cases verify that a global `sv_maplist` overrides stock files, a specific `cc_maplist` overrides that global list, and switching to DM preserves the global rotation in order. Receipt: [validation/cc-config-precedence.json](validation/cc-config-precedence.json).

Durable receipt: [validation/cc-distribution.json](validation/cc-distribution.json). Raw logs: `test-results/cc/`. Tools: `tools/cc/`, `tools/map_base_selection.py`, `tools/package_librequake_expansion.py`. The base-assets builder excludes optional BSPs/caches and validates exact base rotations. The optional ZIP contains no stock maplist filenames and therefore does not replace personalised/default lists on extraction.

Local asset archives are refreshed for this change. No client/server executable build, commit or publication was requested.
