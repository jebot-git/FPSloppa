# Native CQ projection and remote interpolation — 2026-10-16

## Implemented

`FPSCodec.project_authority_frame()` now projects the decoded CQ frame into the existing scene/prediction compatibility API. It handles class/progression choices, magazines and reloads, locomotion and input ACKs, spotting/designation, incapacitation/revival, utility entities, objective and combat timers, vehicles and their seat occupants, aircraft, grenades and projectile definitions. Vehicle occupants are collected in one player pass rather than scanning every player for every transport. The source frame is not modified.

`FPSRemoteInterpolation` owns typed native sample histories, each bounded to 12 entries, plus jitter estimation, adaptive render delay, render clock and underrun accounting. It implements life/teleport resets, stale-sample rejection, hold-at-latest behavior and shortest-path yaw interpolation. Snapshot rows enter in one batch and remote body transforms are applied in one native call. The normal interpolation path does not build per-body sample dictionaries or call back into fighter scripts. Missing-history fallback retains the previous target/target-yaw smoothing. Local player, headset/controller tracking and local prediction are excluded.

The scripted adapter retains diagnostic getters and an explicit reference implementation. Departures/visibility changes use `erase()` and map/disconnect reset uses `reset()`; exported history dictionaries are diagnostic copies. Reference switches: `--gdscript-cq-presentation` and `--gdscript-interpolation`.

Scene membership, authoritative player-state application, local reconciliation dispatch and cosmetic event execution remain scripted. This is another P1 increment, not completion of the native client port. Existing dictionary/array compatibility still dominates snapshot projection; a future typed state-to-scene boundary should remove that intermediate representation.

## Measurements

Final isolated synthetic run on development Intel N95, Godot 4.7.2, release Linux GDExtension. Means of 500 body-update batches and 60 projections per path, after stopping the isolated integration server. These are CPU operation timings, not rendered frame times or capacity tests.

| Operation | Players | GDScript reference | Native | Result |
| --- | ---: | ---: | ---: | --- |
| Remote sample + engine body updates | 64 | 214.65 µs | 13.37 µs | 16.1× faster |
| Remote sample + engine body updates | 128 | 411.44 µs | 27.02 µs | 15.2× faster |
| Complete CQ compatibility projection | 64 | 2.700 ms | 2.705 ms | Effectively unchanged (+0.2%) |
| Complete CQ compatibility projection | 128 | 5.400 ms | 5.138 ms | 4.9% lower |

The projection port is enabled for native ownership/parity and the next typed state extraction; it does not currently provide a substantial speedup. The measured interpolation gain removes about 0.20/0.38 ms per body-update batch for these 64/128-body fixtures. It is not a 15× game-FPS improvement. The interpolation timing excludes snapshot ingestion; its functional tests cover batched ingestion separately.

## Validation

- `deathmatch/tests/native_client_presentation.gd`: **106 checks passed**. Exact native/reference projection parity with CQA2/CQA3 at 1/4/64/128 players, all winner states, timer rebasing, vehicle occupancy, progression and magazines, designation, injection/incapacitation, empty/missing optional entities and unchanged source frames. Invalid role, missing frame and nonfinite origin rejected.
- `deathmatch/tests/native_remote_interpolation.gd`: **13,211 checks passed**. 200 frames of native/reference transform and clock comparisons over 64 remote bodies; reordered packets, respawn/life resets, teleport, angular interpolation, missing-history fallback, preserved pitch/roll, untouched local player, bounded histories, erase/reset and batched ingestion with per-entity timestamps and membership filtering.
- Existing `deathmatch/tests/network_delivery.gd`: passed with native interpolation and again with `--gdscript-interpolation`.
- Existing CQ-only compression policy: **472 checks passed**. PvE remains raw and CQ compressed in synchronous and worker paths.
- Full gameplay client against the standalone server, using `tools/authority_core/arena_driver.gd`: **desktop and simulated tracked runs passed with no script errors/warnings**. Both observed deployment, shooting (17 shots each), grenades, NVG, death/gibbing/respawn checks exposed by the fixture, squads, team change/presentation, jetpack and destruction enabled. The tracked run additionally observed transmitted poses. The fixture's `dead`/`gibbed` observations do not separately prove medic revival mechanics.
- Steady local prediction maximum error: **0.153 m tracked / 0.067 m desktop**, zero steady resets. Overall maxima during the action/death/team-switch sequence were 1.278 m / 1.686 m with zero resets; these are not steady movement errors.
- Two additional tracked native clients overlapped the desktop integration run: both admitted and active, **880 validated frames**, zero rejects/disconnects, about 20 snapshots/sec and 53 ms maximum snapshot gap. This exercised live remote membership/poses alongside the full desktop client; it is not a 64/128-user load run.
- Main arena parsed with `--check-only`, build/source receipt verified and `git diff --check` passed. CMake and SCons include the new modules. The extension is installed atomically as a local Linux artifact; Windows/Android and real-headset validation were not run.

The isolated server used loopback port 27932 and was stopped after validation. No live VPS service changes. Final logs, integration JSON and machine-readable [results](results.json) are included here.
