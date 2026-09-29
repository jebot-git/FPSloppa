# ST query batching and native avatar channels — 2026-09-29

Implements the next steps from [the post-merge native study](NATIVE-CURRENT-ST-STUDY.md): reduce navigation/mines candidate work, move the hot ST corridor/precision steering kernels into C++, and batch facial composition/remote tracking interpolation. Reference paths remain available. Firing rates, movement substeps, animation/LOD cadence and the network protocol are unchanged.

[Machine-readable validation receipt](validation/native-st-batches-2026-09-29.json) contains all 32 retained comparisons, suite results, source/build/package hashes and final host verification.

## Changes

- **Planning queries:** a context lives for one synchronous `bots.plan()` call. It reuses start-point validation and exact paths keyed by origin, goal and traversal layers. Navigation-map RID/iteration changes invalidate the context. Cached paths are duplicated on storage/retrieval so callers cannot corrupt later queries. No state persists across planning ticks.
- **Mine candidates:** an insertion-ordered mine collection replaces full projectile scans in traces and blast chains. Airborne mines stay indexed because blasts can damage them; traces still require the live `stuck` flag. Spawn, end, snapshot removal, round/map reset and disconnect maintain the collection. Recursive explosions skip candidates already removed by another explosion.
- **Native ST steering:** `FPSBots.st_route` batches corridor advancement/lookahead, braking, energy/lift decisions and movement input preparation; `st_precision` handles indoor/landing approach inputs. World ray queries reuse the existing native query object. Objective/tower selection, route graph search, avoidance, ski safety and recovery callbacks retain their existing ordering and script ownership. The standard native projectile trace remains gated off for ST's specialized collision semantics.
- **Native avatar channels:** expression/blink/mouth bindings are compiled into persistent channel lists. A native batch composes weights, applies the existing caps and writes changed shapes only. Mesh instance IDs are resolved safely so destroyed models are skipped. Remote head/hand/weapon/body interpolation runs in a separate native batch; immediate first-person tracking and reset/death ownership stay in GDScript.
- **Dedicated packaging:** the turret view now loads lazily, like the commander view. Console packaging excludes those client views and wrist-display resources. This prevents concurrent client wrist UI work from becoming an eager dedicated-server dependency.

The optional-extension behavior remains: missing/older native methods select their GDScript implementations. Linux client, Linux dedicated-server, Windows x86-64 and Android ARM64 libraries have matching build receipts.

## Rendered 16/32-avatar comparison

Local Godot 4.7.2 Fedora, i7-12700, Arc A770; 1440×900, vsync off, three VRMs, half full-body/face tracking and half head/hands, half speaking, springs off. Each run has six 360-frame blocks in near/desktop-far/XR-policy-far/reversed order, with warmup. Two native runs are bracketed by two reference runs for each actor count. Reference disables only the new channel/interpolation batches; all earlier native optimizations remain enabled.

The table averages the first nearby block across the two runs per implementation. Those blocks use full-detail avatars; the second nearby block retains the existing LOD hysteresis and is recorded separately.

| Avatars | Mean frame, reference → native | Mean improvement | p95 frame, reference → native | Facial composition CPU, reference → native |
| --- | ---: | ---: | ---: | ---: |
| 16 | 7.210 → 7.085 ms | 1.7% | 7.958 → 7.782 ms | 0.247 → 0.130 ms (47.5%) |
| 32 | 13.646 → 13.409 ms | 1.7% | 14.492 → 14.518 ms | 0.485 → 0.267 ms (44.8%) |

The 32-avatar p95 is effectively unchanged/slightly worse in these samples; the result is a small mean CPU/frame gain, not a general tail-latency claim. Rig scope fell from 0.672 to 0.663 ms at 16 avatars and 1.270 to 1.225 ms at 32. Eye scope includes morph composition, so do not add them. GPU rendering, other pose work and engine scheduling remain outside the new batch. These are desktop render measurements; the synthetic XRCamera policy blocks are not headset rendering or human VR tests.

## Remote authority and projectile comparison

The authorized remote Linux host has two AMD EPYC vCPUs and about 2 GB RAM. Its two existing game servers were terminated with explicit authorization. Tests use an isolated package/directory, loopback-only ephemeral ports and a reference–native–native–reference sequence for each map/count. The installed server directories/configurations were not updated.

Authority runs use 16 or 32 bots, seed 9400, 300 warmup plus 1,200 measured ticks, on Stonehenge and Raindance. Timed work is `_server_tick` plus history recording. It excludes separate engine physics stepping and client transport/application; these are bot-heavy authority tests, not 32 human VR clients. Cold setup/planning, whole-process CPU/RSS and host CPU steal are recorded separately.

Reference disables the new planning context, mine collection and ST steering kernels together; earlier native common AI, projectiles and codec remain active. Integrated simulations can diverge from small numeric differences: the Stonehenge 32-bot native runs fired 52 shots versus 76 in each reference run. Same seed/count/duration does not mean identical work, so integrated timing differences are observations rather than an exact isolated-kernel speedup. Differential steering tests compare matched states separately.

Each cell averages the two corresponding runs; p95 columns average each run's percentile, rather than pooling samples.

| Map | Bots | Mean authority tick, reference → native | Mean reduction | p95 tick, reference → native |
| --- | ---: | ---: | ---: | ---: |
| Stonehenge | 16 | 20.185 → 18.509 ms | 8.3% | 51.386 → 44.069 ms |
| Raindance | 16 | 18.930 → 17.798 ms | 6.0% | 65.984 → 58.635 ms |
| Stonehenge | 32 | 46.397 → 41.749 ms | 10.0% | 109.550 → 93.972 ms |
| Raindance | 32 | 39.827 → 36.391 ms | 8.6% | 162.515 → 137.911 ms |

This two-vCPU host remains unable to sustain a 16.667 ms / 60 Hz authority budget for these bot workloads: even the 16-bot means exceed it, before separate engine/transport work. The 32-bot runs substantially exceed it. Peak process RSS across remote runs was 262.8 MiB and measured host steal stayed at or below 0.151%; low observed steal does not control all VM scheduling/frequency variation. The 25-second simulated matches all finished 0–0 and do not resolve the previously observed capture issue.

The sustained-projectile test uses real weapon cadences with replenished inventory, parallel empty firing lanes and 300 warmup/600 measured ticks. It compares only mine indexing while retaining the common native projectile loop in both variants. Counts, peak population and final-state hashes must match. It does not cover firefight geometry or occupied special objects; correctness of those paths remains covered by gameplay tests.

| Shooters | Mean projectile update, full scan → mine index | Reduction | p95 update, full scan → mine index | Measured shots / peak projectiles |
| --- | ---: | ---: | ---: | ---: |
| 16 | 9.853 → 5.356 ms | 45.6% | 13.486 → 7.625 ms | 550 / 90 |
| 32 | 21.514 → 9.294 ms | 56.8% | 26.342 → 12.951 ms | 1,145 / 182 |

All four runs at each count have identical shot counts, peak/mean populations and final-state hashes (16: `4243520320`; 32: `4018854013`). These lanes contain no mines: the gain measures removal of futile per-projectile candidate scans, with actual mine correctness checked separately. The remaining 5.4–9.3 ms update cost means specialized collision/ballistics batching is still worth investigating under representative occupied geometry; the current evidence does not justify enabling the standard trace shortcut for ST.

All 24 remote runs completed. Final executable/PCK/native-library hashes match the staged package receipt. No benchmark or original game-server processes remain running. The isolated package/results are retained for reproduction; installed game servers remain stopped and their binaries/configuration were not changed.

## Validation

New tests compare complete brain/player/team/RNG output for 720 ST steering cases, avatar interpolation and actual blendshape values across three VRMs, changed-only writes, legacy-cache invalidation, dead state and freed meshes. Query tests compare fresh/cached paths, caller mutation, asynchronous navigation-map invalidation, mixed projectile traces, same-tick mine landing/removal and recursive blast/reset behavior.

All **34 focused suites passed**, with **1,710,218 checks reported in structured results**. The new steering test contributes 656,785 checks across 720 cases; avatar channels add 31,236 checks and query batching adds 121. The standard native avatar/bot validator includes the new suites. The focused [ST batch validator](../tools/native_study/validate_st_batch.py) also runs existing real-map skiing, rolling-launch, obstacle, route, carrier/capture, targeting and frame-smoothness tests with representative fallback reruns. Passing these tests does not establish competitive ST capture reliability; that earlier issue remains separate.

The remote benchmark package freezes the unrelated command/turret UI scripts at the pre-wrist revision to keep the matrix constant. Those scripts do not execute in these headless tests. The final current-source console package is validated separately with the lazy-loading/exclusion fix. Early setup attempts and a preliminary local avatar run overlapping the final package upload are excluded from retained comparisons. Existing fixture shutdown ObjectDB/resource warnings are recorded separately from assertion failures.

The final current-source dedicated package passed an eight-second production-entry smoke run: loopback-only, Raindance, four bots, Tribes loadout/ST mode, no script errors and exit status 0. An initial smoke attempt used invalid config syntax and exited before hosting; the corrected config passed. Python compilation, current-source checks for all four native build receipts, and `git diff --check` pass.

## Reproduction

```sh
python3 tools/native_study/validate_st_batch.py
python3 tools/native_study/compare_st_batch.py --kind avatars --output test-results/native-st-batch/local-avatars
python3 tools/native_study/compare_st_batch.py --kind server --output test-results/native-st-batch/local-server
python3 tools/native_study/compare_st_batch.py --kind projectiles --output test-results/native-st-batch/local-projectiles
```

Run profiles sequentially without builds/tests on the same machine. Data/settings are isolated under `/tmp`. Default counts are 16 and 32, with two native runs bracketed by two reference runs. Logs, JSON, memory/CPU measurements and hashes are retained per run. `--counts`, `--maps`, `--ticks`, `--warmup` and `--order` allow smaller smoke tests.

For a fresh dedicated package built by `tools/build_console_server.py`, use `package_st_batch.py --manifest test-results/console-server-package/pack.json --output <package-directory>` to add the benchmark entry scene and map/navigation assets. The console runtime disables CLI script/path overrides, so run its adjacent PCK with:

```sh
python3 compare_st_batch.py --kind server --runtime ./FPSloppaServer.x86_64 --project . --packaged --output results/server
python3 compare_st_batch.py --kind projectiles --runtime ./FPSloppaServer.x86_64 --project . --packaged --output results/projectiles
```

Diagnostic flags are `--reference-nav-queries`, `--reference-mine-scan`, `--gdscript-st-steering` and `--gdscript-avatar-channels`. The earlier broader fallback flags still work. Cross-build success establishes compilation, not Windows/Android device performance. No release deployment or headset frame-time claim is made.
