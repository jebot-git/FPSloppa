# Converted-map traversal audit

Run: 2026-09-11 06:47 UTC. Godot 4.7.2, Linux headless physics, current working tree based on `f7f8073`.

Completed 24 maps; 23 passed the sampled runtime checks. Coverage: 558 spawn capsules with settling/jumping/directional movement, 140 liquid samples, 179 doors, 52 lifts, 32 teleport triggers and 18 push triggers.

All BSPs stayed in their existing local directories. No AD, original TF or ThreeWave BSPs are included in source changes. Per-map hashes, source paths, entity identifiers, coordinates, collision observations and engine logs are in `test-results/converted-traversal/`.

## Checks and limits

- Actual character physics exercises spawn settling, jump input, directional motion, swimming, downward strokes, surface exits and dry-state reset. Surface-exit cases require an unobstructed capsule sweep and sufficient air above the water. Low ceilings are recorded as geometry constraints, not failed swimming.
- Every imported door is opened through production proximity activation, checked at the open endpoint and returned closed. Collision probes use actual trailing brush surfaces, offset slightly from the triangle plane, and check that they move and return. Earlier probes are reset so swimming cannot leave a door open at the start of its test. This does not prove every room-to-room route is usable.
- Lifts run through the production arena tick, with standing passengers through ascent and descent. A nine-point surface search distinguishes real lift support from the static floor below it.
- Teleport tests physically overlap imported Areas, then check authoritative destination, spawn serial and destination capsule clearance. Adjacent portals are approached from a point touching only the intended trigger. Push triggers must apply velocity.
- Fresh brush collision alignment is checked before deliberately restoring legacy identity transforms; runtime repair must then pass the physical checks. This exercises both fresh imports and compatibility with old scene caches.
- This is a headless physics audit, not a full-match route playtest or VR rendering/performance test. Portal artwork, animation and headset presentation are not visually certified.

## Fixes found during testing

1. Rotated brush collision did not receive the inverse entity rotation applied to its visible mesh. This displaced collision on `angle -1` lifts and other angled brushes. The importer now aligns both; the runtime also repairs existing caches. Before the fix, all four lifts in ThreeWave ctf2m2 and all eight in ctf2m5 failed the passenger test.
2. Teleport destinations omitted Quake’s 27-unit upward adjustment before converting to player feet coordinates, causing solid overlaps at several ThreeWave destinations. The adjustment is now applied. The behavior is defined in [id Software’s original teleport destination function](https://github.com/id-Software/Quake/blob/master/QW/progs/triggers.qc#L414).

## Compatibility that remains simplified

The 16 AD conversions contain static `func_wall` / `func_illusionary` geometry but no active doors, lifts or teleport triggers. Their conversion readmes explicitly say gates and single-player scripts were removed. Passing movement checks does not restore those features.

TF and ThreeWave doors use proximity opening; secret doors use a single slide rather than Quake’s two-stage movement. Lifts use a timed cycle. Original button/trigger target chains, secrets and map-specific team access logic are not interpreted. These are compatibility limitations, even where physical movement passes. Unsupported entity details remain in each JSON report.

## Per-map results

| Map | Spawns | Water samples | Doors | Lifts | Teleports | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| ad_arena_ad_ac | 16 | 12 | 0 | 0 | 0 | Pass |
| ad_arena_ad_akalakha | 15 | 1 | 0 | 0 | 0 | Pass |
| ad_arena_ad_chapters | 13 | 0 | 0 | 0 | 0 | Pass |
| ad_arena_ad_crucial | 16 | 0 | 0 | 0 | 0 | Pass |
| ad_arena_ad_dm1 | 16 | 1 | 0 | 0 | 0 | Pass |
| ad_arena_ad_dm5 | 16 | 12 | 0 | 0 | 0 | Pass |
| ad_arena_ad_e1m1 | 16 | 0 | 0 | 0 | 0 | Pass |
| ad_arena_ad_e2m2 | 16 | 12 | 0 | 0 | 0 | Pass |
| ad_arena_ad_e2m7 | 16 | 12 | 0 | 0 | 0 | Pass |
| ad_arena_ad_metmon | 16 | 4 | 0 | 0 | 0 | Pass |
| ad_arena_ad_mountain | 16 | 0 | 0 | 0 | 0 | Pass |
| ad_arena_ad_obd | 16 | 4 | 0 | 0 | 0 | Pass |
| ad_arena_ad_s1m1 | 16 | 0 | 0 | 0 | 0 | Pass |
| ad_arena_ad_scastle | 16 | 0 | 0 | 0 | 0 | Pass |
| ad_arena_ad_zendar | 16 | 0 | 0 | 0 | 0 | Pass |
| ad_arena_start | 9 | 3 | 0 | 0 | 0 | Pass |
| tf_original_2fort5 | 88 | 11 | 12 | 2 | 0 | Pass |
| tf_original_well6 | 32 | 12 | 26 | 6 | 0 | Pass |
| threewave_ctf2m1 | 37 | 12 | 16 | 4 | 12 | Pass |
| threewave_ctf2m2 | 47 | 12 | 9 | 4 | 4 | Pass |
| threewave_ctf2m3 | 34 | 2 | 22 | 0 | 3 | Pass |
| threewave_ctf2m4 | 30 | 11 | 8 | 20 | 0 | Investigate |
| threewave_ctf2m5 | 26 | 7 | 28 | 8 | 5 | Pass |
| threewave_ctf2m6 | 19 | 12 | 58 | 8 | 8 | Pass |

## Outstanding failures

- `threewave_ctf2m4`: Lift passenger stopped by overhead map geometry: 0
- `threewave_ctf2m4`: Lift passenger stopped by overhead map geometry: 1
  Lift `*28` at `[-29.0, -2.97000002861023, 44.0]`: requested travel 8.50 m; rider rose 7.10 m; overhead capsule sweep allows 83.2% of travel. The actor hits map geometry while the platform continues; a full standing ride is not certified.
  Lift `*25` at `[29.0, -2.97000002861023, -44.0]`: requested travel 8.50 m; rider rose 7.10 m; overhead capsule sweep allows 83.2% of travel. The actor hits map geometry while the platform continues; a full standing ride is not certified.

## Reproduction

`python3 tools/validate_converted_traversal.py` runs all available retained conversions. `--match threewave_ctf2m2` selects one map. Run `python3 tools/report_converted_traversal.py` afterward to regenerate this report. Requires the locally retained BSPs and Godot 4.7.2; it does not download or republish assets.

Related regressions: `deathmatch/tests/quake_movement.gd`, `deathmatch/tests/water.gd`, and `python3 deathmatch/tests/run_network_tests.py --bsp` (local ENet server and two clients on the base LibreQuake map; this network smoke test is separate from the converted-map physics sweep).
