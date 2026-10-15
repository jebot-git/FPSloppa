# Adaptive 60/30 Hz CQ experiment — 15 October 2026

This adds an opt-in dedicated native CQ mode targeting **64 players first**. It starts at 60 Hz, falls back to 30 Hz under sustained pressure, and returns to 60 Hz only after sustained headroom. Production deployment and its defaults are not changed.

Enable it with `--cq-native-authority --cq-adaptive-tick`; use `set sv_cq_maxclients "64"` in an isolated server configuration to admit the full target. Existing configured supported capacity remains 32 total; native team/squad defaults remain 32/8. Adaptive fixture arguments reject populations above 64. This experiment does not promote 64 to a supported production capacity.

## Final measurements

Both final capacity cases passed population, clock, delivery, diagnostics and workload gates. All 64 players stayed admitted, with zero malformed frames, unexpected disconnects, command-queue overflows and projectile-pool saturation.

| Case | Rate behavior | Callback p50 / p95 / max ms | Accepted/offered | Min complete frames | Shots |
|---|---|---:|---:|---:|---:|
| Normal, v4 | 60.002 Hz throughout; no fallback | 3.635 / 10.203 / 17.557 | 99.908% | 2,330 | 3,306 |
| Pressure, v3 | 60→30 at 0.759 s; 30→60 at 55.275 s | 3.970 / 20.683 / 31.125, mixed rates and injected delay | 99.724% | 2,260 | 3,275 |

Transition times are measured wall seconds after warm-up. The pressure case spent 54.633 simulated seconds at 30 Hz and 65.383 at 60 Hz, ending at 60 Hz. Its average tick count rate of 46.343 Hz is expected for that mix. Simulation/wall-time ratios were 1.000039 normal and 0.999981 pressure. Each peer offered at least 7,201 measured inputs; all four classes fired in both cases.

During the pressure case, callback p95 was 25.110 ms for 30 Hz ticks (33.333 ms budget) and 10.001 ms for 60 Hz ticks (16.667 ms budget). These include the temporary injection. The normal maximum callback exceeded the 60 Hz budget briefly; no hard deadline guarantee is implied.

Normal physics interval p95/max was 23.319/30.253 ms; pressure mixed-rate interval p95/max was 37.560/49.604 ms. Average simulation rate and callback headroom do not eliminate scheduling jitter.

Post-bind server process CPU averaged 44.57% of one core normally and 37.20% under the sleep-injection/fallback mix; peak RSS was 442.55/442.42 MiB. These samples include admission and warm-up and exclude cold map construction and client CPU. The blocked-time injection is not a CPU-load comparison. Full derived figures are in `comparison.json`.

The normal and pressure manifests identify the **same native library** (`8c11a52d…bfbcdd4`). Normal uses a later fixture freshness guard described below; governor/native code is identical.

The cases run sequentially alongside the live service on the same 12-vCPU Ubuntu 24.04 VPS as the [fixed-rate experiments](../capacity-128-60hz-20261015/REPORT.md). Each has eight warm-up seconds and 120 measured seconds, real Jolt and authored jungle collision, 11 capture sites, eight parked vehicles, four classes and synthetic tracked poses/reload gestures. Clients send at 60 Hz even while authority falls back to 30. Each client process holds four peers; all 64 peers must be admitted.

Normal finite ammo/damage rules apply. Fire is aimed upward, AI and driving are absent, and no headset/rendering or WAN load is measured. Snapshot publication remains 20 Hz. The wrapper caps outer frames at 120 FPS; tick-interval jitter is reported separately from callback cost. These are steady-population tests, not lethal matches or a soak test.

The pressure case adds a **test-only 14 ms sleep per server callback during the first 16 measured wall seconds**. It tests the governor's response to blocked callback time, not an equivalent amount of CPU computation. Production CQ never reads or applies this delay option. Per-rate callback distributions include the injected delay; they are not normal-load performance estimates.

## Policy and transitions

| Condition | Action |
|---|---|
| Start of an adaptive authority instance | 60 Hz |
| Half-second window: at least 25% of callbacks exceed 16.67 ms, or simulated/wall ratio is below 0.85 | Emergency request for 30 Hz |
| Two consecutive two-second windows: callback p95 above 15 ms, or simulated/wall ratio below 0.92 | Request 30 Hz |
| At least 30 seconds at 30 Hz, plus ten consecutive two-second windows with p95 below 11 ms and ratio at least 0.98 | Request recovery to 60 Hz |

The governor has bounded sample storage and separate pressure/recovery thresholds. Isolated callback spikes do not meet the overrun-share condition. The wall-time ratio catches sustained delay outside the measured callback; this is not a hard realtime scheduling guarantee. Actual transitions commit during idle processing, outside physics, with the native step and engine physics rate changed together. The adapter retains its owner-thread, matching-rate, once-per-physics-frame checks.

The saved `tick_window_p95_us` and `tick_window_simulation_ratio` are the last completed **two-second** window, not the emergency half-second decision context. An emergency transition can therefore retain low warm-up values in those fields. The exact emergency decision samples are not exported in this prototype.

Core time now advances in integer units of 1/60 second rather than `tick × current_step`. A rate change cannot rewind time or double elapsed gameplay time. Snapshot construction uses the same independent 20 Hz clock phase. Publishers check the native snapshot tick rather than recomputing a rate-dependent cadence. Tick IDs remain monotonic identifiers.

The resident fixture sends an explicit server simulation timestamp with its fragments and uses it for rewind input. Full CQ clients already project CQA2 mode simulation time; their production wire format does not change. Inputs, cooldowns, projectiles, class effects and rewind history retain seconds-based timing. Synthetic client animation/gestures stay paced independently of the server's current rate.

## Checks and provenance

Native tests passed **262,163 checks**, including default fixed-rate replay, mixed 60→30→60 clocks/cooldowns/gravity, off-boundary snapshot phase preservation, marginal-pressure hysteresis, emergency overload, recovery residence and invalid samples/rates. Four Python tool tests cover PCK preservation, owned-socket readiness and rejection of invalid adaptive capacity/pressure options, and precise classification of the existing experimental-capacity warning without hiding errors. The dedicated CQ script passes the local headless XR-off parse check. Source-tree fixture parsing encountered an inherited font-import/cache dependency; exported-package execution supplies the imported assets and tests the actual fixture.

The isolated `adaptive-20261015-complete-release` is derived from the installed `20261014-cq-vehicle-respawn` package, with branch `ba5924f` plus these changes. It preserves deployed assets and the executable, substitutes the newly built native library, CQ host and fixture/QA scripts, and records all replacements in `cq-server.patch.json`. This is an experimental derivative, not an untouched production-binary benchmark. The native library was built with the same unprivileged GCC 13 toolchain and pinned bindings used previously. All 50 native build source hashes match the local files; see `native-source-verification.json`.

The new build-only `authority_tick.h` is included in that source receipt. It is not added to the original pack's registered source entries; the compiled library contains its governor. No system package or production library was replaced. Per-case release manifests, telemetry and raw logs are retained.

## Earlier attempts retained

`adaptive-20261015-64-normal` used a 12.5 ms pressure / 10 ms recovery threshold. It passed delivery and clocks but spent most of the run at 30 Hz: fallback at 6.054 measured seconds and recovery at 84.888. This motivated thresholds closer to the 60 Hz budget.

`adaptive-20261015-v2-64-normal` used the final 15/11 ms marginal thresholds without the emergency path. It held 60 Hz for two minutes with 9.905 ms callback p95.

`adaptive-20261015-v2-64-pressure` **failed**: the four-second marginal path switched down at 4.199 seconds and recovered at 54.737, but one peer disconnected. Remaining clients' fixed-64 roster validator then rejected 63-player frames. Its bad-frame counts and failed gates remain in the evidence; this was not a valid full-population capacity pass. The emergency path was added to shorten severe overload exposure. A successful rerun alone cannot prove the original disconnect's precise cause.

The superseded intermediate pressure run was stopped for rebuilding and is not counted as a measurement. The successful pressure run uses v3. The final normal check uses v4, which has the identical native binary plus a snapshot freshness guard in the publishers. The CQ integration bundle adds only the QA scene-loader/teardown corrections. Native source/binary checksums distinguish that fixture fix from a governor change.

`adaptive-20261015-v3-64-normal` held 60 Hz but failed the strict validator with one rejected startup frame per peer. The publisher could send an existing snapshot constructed before the last actor joined. The final publisher requires `snapshot_tick == current_tick`; a native regression demonstrates the pre-barrier stale-roster state and the fresh full-roster frame. Earlier failed gates are retained rather than reclassified as passes.

## Actual CQ integration

`adaptive-20261015-arena-clean` passed through normal full CQ admission at an explicitly configured 64-slot adaptive server. The server reported `physics_hz: 60` and `adaptive_tick: true`. The desktop QA client fired 17 shots and observed grenades, NVG, death/gib, respawn, squads, team switching and jetpack, with no functional failures or unexpected diagnostics.

The existing experimental 64-slot capacity warning is preserved in raw logs and recorded separately as expected; it is not removed from the game. The helper only accepts that known warning with an explicit 64-slot configuration, and a tool test ensures errors are never hidden.

The first full-client attempt (`adaptive-20261015-arena`) passed those gameplay checks but failed strict diagnostics during shutdown because of the release engine's RPC-cache disconnect issue. The QA wrapper now detaches every RPC root before transport reset, as the resident load wrapper already does. The clean rerun has zero such errors. This fixes QA teardown; it is not validation of the normal menu-disconnect path. The final integration bundle differs from v4 only in the QA scene-loader/teardown branch; its native governor and gameplay code are identical.

The packaged entry now supports `--authority-arena-client`, reusing the existing full arena QA client. `run_adaptive_arena.py` launches an isolated adaptive server and that client through normal admission, production CQA2 decoding/presentation and gameplay actions. This complements the 64-peer resident fixture; it is not a rendered headset test or a 64-player full-presentation capacity test.

## Reproduction

Run the capacity cases separately against a prepared isolated bundle:

```sh
python3 tools/frontier_vps/run_capacity_case.py --bundle /isolated/adaptive-release --output /new/64-normal --players 64 --hz 60 --adaptive-tick --seconds 120 --port 27979
python3 tools/frontier_vps/run_capacity_case.py --bundle /isolated/adaptive-release --output /new/64-pressure --players 64 --hz 60 --adaptive-tick --adaptive-load-delay-us 14000 --seconds 120 --port 27989
python3 tools/frontier_vps/run_adaptive_arena.py --bundle /isolated/adaptive-release --config /isolated/loopback-server.cfg --output /new/arena --port 28009
```

## Final service check

Recorded checks retained live PID **1652607**, start time **06:10:23 UTC**, active/running state and `NRestarts=0`. The live executable/release remains `20261014-cq-vehicle-respawn`. The runners never suspended/restarted that service or changed its configuration, release symlink or firewall. No adaptive test server/client processes remain. See `adaptive-20261015-final-health.json`; SSH's temporary authenticated control connection was closed after collecting evidence.
