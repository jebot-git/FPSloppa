# Remaining native opportunities after the ST merge — 2026-09-29

The earlier native work is incorporated into the ST-enabled main checkout. The next substantial opportunities are ST-specific bot steering and combat processing. Two algorithmic improvements should precede further C++ ports: eliminate repeated navigation queries and stop scanning every projectile for planted mines on every trace. Remaining shared avatar work is useful but smaller.

This investigation changes profiling/validation tools and documentation only. It adds ST bot parity to the standard avatar/bot validator; it does not change gameplay, firing cadence, movement substeps, protocol, LOD policy or native libraries. See the [machine-readable receipt](validation/native-current-st-study-2026-09-29.json).

## Integration audit

Audited main at `4902896149a53c6424aa2148b35e1e7a0f55d9b5` against the prior-main checkpoint `07f727c`, using common base `8b19bd959e7dbf17cba1b201bb9f55d448f87614`. All **183 incoming paths are present**: **166 byte-identical**, **17 changed during ST integration**, **zero missing**. Presence alone is not semantic proof: the changed runtime paths were also reviewed, and focused native/gameplay suites were rerun. The [original integration report](ST-MAIN-INTEGRATION.md) records the larger merge and network regression.

| Earlier work | Status in ST-enabled main |
| --- | --- |
| Avatar preparation, pose math, capture/blending | Shared native solver remains active. ST armour binds to the original animated skeleton; runtime armour meshes register with the shared visibility/LOD machinery. |
| Common bot perception/combat/steering | Native common perception/combat retained, including ST carrier jet-energy reservations. ST steering deliberately dispatches to its specialized GDScript controller. |
| Projectile processing | Native iteration and candidate grid retained. ST definitions dispatch to their specialized ballistic/impact callbacks. |
| Standard native trace | Deliberately gated off for ST/Tribes loadouts: vehicle hulls, mines, deployables, beacons and station damage/repair must participate. Enabling the standard-mode path directly would discard behavior. |
| Compact codec, packet grouping, shot-history reuse | Shared implementations retained. Snapshot encode/receive probes passed with current ST state. |
| Smooth local weapons, muzzle/tracer origin, feedback, controls and settings | Shared main changes retained alongside ST PDA/vehicle/equipment input ownership. CS/DE-specific recoil/reload/defusal rules retain their intended mode scope. |
| Aztec, Train and Nuke fixes | Incoming map/runtime assets and manifest integration retained. |

Linux client, Linux dedicated server, Windows and Android native library hashes and source receipts are current. This verifies existing builds, not new cross-platform performance testing. The only native-source differences from prior main are the ST combat correction and its cached names. No missing integration was found requiring a gameplay patch in this investigation.

## Measured server costs

Sixteen bots, seed 9400, 300 warmup ticks plus 1,200 measured ticks at 60 Hz on each ST map. Timed simulation includes authoritative gameplay and history recording, excluding separate engine physics stepping, snapshot transport and client application. The control runs load production scripts with all native helpers enabled.

| Production control | Mean simulation | p95 | p99 | Shots over the run |
| --- | ---: | ---: | ---: | ---: |
| Stonehenge | 10.48 ms/tick | 26.32 ms | 48.64 ms | 13 |
| Raindance | 9.83 ms/tick | 34.69 ms | 48.44 ms | 0 |

These short opening samples expose planning spikes, not representative firefights or capture performance. Scoped runs are slower because of instrumentation. Do not subtract their totals from controls to claim a speedup.

| Fine instrumented scope, inclusive | Stonehenge | Raindance | Implication |
| --- | ---: | ---: | --- |
| Bot planning | 4.20 ms/tick | 4.35 ms/tick | Main source of periodic spikes; includes the rows below. |
| Walking navigation wrapper | 2.81 | 3.00 | Almost entirely existing engine calls. |
| Engine closest-point query | 1.26 | 1.05 | Repeated with the same start while evaluating multiple goals. |
| Engine path search | 1.54 | 1.94 | A C++ wrapper cannot remove this work. |
| Specialized ST steering | 2.12 | 1.72 | Best sizeable remaining AI port boundary; includes rays and nested controllers. |
| ST terrain route search | 0.69 | 0.85 | Includes route attachment/rays; overlaps planning. |
| ST movement | 2.76 | 1.83 | Includes support and move collision queries. |
| Engine ground-support probes | 1.61 | 1.09 | 64 probes/tick for 16 actors at the existing substep cadence. |
| Engine move-and-collide | 0.40 | 0.16 | Already engine work. |

**First reduce navigation duplication.** `bots.plan()` evaluates up to 18 candidates, normally stopping after six once a valid choice exists. Each walking query repeats the same start-point projection. Reuse that validation within one synchronous planning call, and consider short-lived exact-query reuse keyed by navigation-map iteration, origin, goal and traversal layer. Retain the existing terrain-first policy for long ST trips. Budget/stagger expensive plans only after checking carrier deadlines, obstacle recovery and reaction behavior; unchanged average work can still cause long ticks when plans coincide. Do not confuse the measured 2.8–3.0 ms with attainable C++ savings.

**Then batch ST steering and route arithmetic.** `steer_route` and `precision_steer` have about 1.05–1.08 ms/tick combined self time after instrumented children are excluded; this still includes uninstrumented helpers/engine calls. A useful boundary gathers actor/brain/route inputs once, runs lookahead, braking, pitch/yaw, energy and obstacle decisions, then writes ordinary inputs. Port route graph costs/search alongside it only if profiling still warrants that work. Preserve route order, random draws, carrier reserve rules, ski/jet decisions and emergency recovery. Require native/reference comparisons plus the existing ST route, ski, obstacle and carrier fixtures on both maps. This is a candidate cost envelope, not a promised saving.

**Movement is secondary.** With engine support/move scopes excluded, `simulate` self time is about 0.29 ms/tick on each map; other helpers add work, but collision dominates. Investigate reusing a completed substep's support result at the next substep when position/velocity/contact conditions are unchanged. Keep the 120 Hz substeps and authority/prediction agreement. A wholesale native movement rewrite is not justified by these samples.

## ST projectiles: fix candidate work before widening the native boundary

The separate sustained-fire fixture uses 16 stationary heavy-armour shooters, plasma/chaingun/disc at their actual firing cadences, parallel empty lanes, replenished ammo/energy, 300 warmup and 600 measured ticks. It retains the real ST fire, projectile, expiry and trace code. It produced 550 shots, a mean of 85.92 live projectiles and peak 90. Native and fallback runs had matching counts and final-state hashes. This is a controlled load, not a measured live match; it exercises no player impacts, mines, occupied vehicles or deployables.

With the shared native projectile loop active, update averaged **3.47 ms/tick**, p95 **3.75 ms**. The fallback averaged **3.64 ms**, p95 **3.95 ms** in a separate single run. The common native loop is working, but specialized callbacks dominate. This small single-pair difference is not a robust speedup estimate.

Extra instrumentation attributes about **3.01 ms/tick** to the specialized trace. Sphere world-query handling is about **0.40 ms**, with only **0.11 ms** in the overlap/cast engine calls in these empty lanes. The rest includes query allocation, script orchestration and special-object checks. Dense geometry changes that split.

`tribes/combat.trace_mines()` scans **every live projectile for every trace**, rejecting anything that is not a stuck mine. A further scoped run measured **1.32 ms/tick in this scan alone, with zero mines**. Consequently ordinary non-mine fire pays approximately quadratic candidate work. Maintain a collection of stuck mines, optionally spatially indexed, and trace only those candidates. Preserve same-tick mine sticking/removal, chain explosions, reset/disconnect cleanup and nearest-hit ordering. This algorithmic correction should precede a native ST collision port; a C++ translation of the full scan would preserve its bad scaling.

After that correction, remeasure. A useful native follow-up could reuse shape/query objects and batch the common body/world trace while applying the existing ordered ST extensions. Preserve radius sweeps, initial overlaps, cover rejection, moving targets, owner grace, grenade/mortar arming, mine chains, turret guidance, vehicle damage/repair and callback mutation order. Keep the current trace gate until those cases have differential coverage. Existing standard-mode projectile parity alone cannot justify enabling native trace for ST.

## Shared client and network opportunities

The existing rendered avatar fixture uses 16 avatars, three VRMs, eight full-body/face and eight head/hands, half speaking, springs off, six reversed-order near/far blocks of 360 frames. It measures shared avatar work, not ST armour rendering or a headset.

- Nearby eye/expression processing: **0.33–0.34 ms/frame**, including **0.20 ms** morph composition/application.
- Tracking interpolation: **0.13 ms/frame**.
- Nearby pose: **0.83–0.85 ms/frame**, already dominated by native preparation/capture/blend plus scheduling. The previous preparation port remains active.
- Gait: about **0.09 ms/frame**; LOD bookkeeping is small. No case here for extending LOD distance.

The next shared client native pilot is **cached facial-channel composition plus remote tracking interpolation**, using persistent numeric buffers and one batch call per avatar. Preserve local immediate tracking, eye/mouth clamping, dead-state behavior and changed-only blendshape writes. The roughly **0.46–0.48 ms/frame combined eye/tracking cost is an upper envelope**, including engine work. Even halving it would save only around 0.23–0.24 ms in this fixture; do not promise another large avatar-preparation gain.

Current bot-only ST snapshots measured roughly **0.41–0.45 ms assembly**, **0.47–0.52 ms packet generation**, and **0.45–0.50 ms receive/flush** per sampled snapshot, using the native codec. These timings include nested profiler overhead and exclude network transport/application. They contain no full-body VR inputs, so they do not replace the [full-VR network validation](NATIVE-NETWORK-REWIND.md). Further native snapshot/pose validation should follow representative full-VR fan-in profiling; compression and a wholesale network rewrite are not leading recommendations from this sample.

The DM comparison workload's instrumented pickup scan remains about **0.50 ms/tick**. Spatial candidate filtering is still a reasonable shared-server improvement before considering a native pickup loop; ST maps have no equivalent map pickups in these runs.

## Recommended order

Implemented follow-up: [ST query batching, native steering and avatar channels](NATIVE-ST-BATCHES.md), including rendered 16/32-avatar comparisons and remote two-map authority/projectile measurements. The measurements below remain the pre-change study.

1. Reduce repeated ST planning queries and isolate planted mines from general projectiles. These address avoidable work and spikes without depending on a language rewrite.
2. Native ST steering/route arithmetic, with behavior parity and two-map validation.
3. Native facial composition and remote tracking interpolation for a smaller shared client gain.
4. Reprofile specialized ST projectile traces after mine indexing; only then decide on the wider native collision/ballistics boundary.

Do not prioritize a new navigation engine, whole movement/physics rewrite, broad scene-tree multithreading, further LOD distance changes or a wholesale GDScript conversion on this evidence.

## Reproduction and limitations

All **24 focused suites passed**, including 1,041,991 checks reported in structured results (some suites report individual assertions instead). Coverage includes all eight native parity suites, ST movement/arsenal/targeting/equipment/inventory, frame smoothness and render interpolation, controller tracking, buy-wheel selection, CS recoil/reload, defusal VR, dropped weapons and shared hit/haptic feedback. `native_st_bots` is now included in `validate_avatar_bots.py` by default. Python compilation and `git diff --check` pass.

Two initial harness setup failures were corrected and rerun: ST inventory requires the graphical synthetic VR rig, and equipment validation expects an output directory. Their initial logs remain in the receipt; neither was a gameplay defect. The validator now selects that rig and prepares the suites' literal report destinations.

```sh
python3 tools/native_study/study_current.py --audit
python3 tools/native_study/study_current.py --prepare
python3 tools/native_study/study_current.py --server --map ctf_stonehenge
python3 tools/native_study/study_current.py --server --map ctf_stonehenge --control
python3 tools/native_study/study_current.py --server --map ctf_raindance
python3 tools/native_study/study_current.py --server --map ctf_raindance --control
python3 tools/native_study/study_current.py --projectiles
python3 tools/native_study/study_current.py --projectiles --fallback
python3 tools/native_study/study_current.py --avatars
python3 tools/native_study/study_current.py --checks
```

Run sequentially, with no concurrent builds/tests. Generated instrumented dependency copies and logs live under ignored `test-results/native-current-study`; config/data are isolated under `/tmp`. The generator now includes the finer engine/mine scopes, so a fresh run has more instrumentation than the initial broad profiles retained in the receipt. Scope self time excludes instrumented children, **not all engine work**. Nested scope costs must not be added together.

Godot 4.7.2 Fedora, i7-12700, Arc A770. OS/GPU clocks are uncontrolled. Server tests need a loopback socket; avatar and ST inventory tests need a display. The inventory test uses synthetic controllers with `--vr-test`, not an OpenXR ergonomics test. Windows/Android receipts do not establish device performance. Existing ObjectDB/resource shutdown warnings and intentional malformed-codec diagnostics are distinct from assertion failures.

The previous 600-second ST runs ended 0–0 on both maps. Capture reliability remains unresolved; these performance probes do not change or validate that outcome. No new headset frame-time or total-game FPS claim is made.
