# Native-code performance study — 2026-09-28

Implementation follow-up: [native acceleration, packet packing and integrated measurements](NATIVE-ACCELERATION.md). The measurements below describe the investigation before implementation.

Selective C++ rewrites could provide useful CPU headroom on both client and server. The best client candidate is the complete avatar pose solve/interpolation path. The best server candidate is a batched projectile update, followed by packet construction. A wholesale rewrite is not justified by these measurements, and porting only the hit-test arithmetic would barely affect the projectile fixture despite a large isolated speedup.

This study adds profiling tools and an experimental standalone C++ kernel. **No production game code, update rates, LOD policy, controls or networking protocol changed.** Results are in [the measurement receipt](validation/native-performance-2026-09-28.json). Client figures reuse the [same-day, post-optimization rendered measurements](validation/frame-smoothness-2026-09-28.json), not an older baseline.

## Measured opportunities

| Area | Observed cost | Assessment |
| --- | --- | --- |
| Client: nearby avatar pose solve and interpolation | 1.72–1.82 ms/frame for 16 avatars | First native pilot; recurring work on the presentation thread |
| Client: distant avatars under current XR policy | Pose scope 0.68–0.72 ms/frame | Smaller but useful target without extending LOD |
| Server: entire projectile helper | 3.52–3.54 ms/tick, uninstrumented internally, 16 actors and up to 523 plasma projectiles | Largest measured simulation candidate; port a batch, not individual math calls |
| Server: spatial grid build and candidate lookup | 0.54–0.55 ms/tick, instrumented | Include with projectile batching; do not replace the existing broad phase with a full scan |
| Server: exact player hit tests in this plasma fixture | 0.023–0.024 ms/tick, instrumented | Low priority alone; broad phase already does its job |
| Server: packet construction | 3.90–3.93 ms per snapshot, instrumented; 1.30–1.31 ms amortized per 60 Hz tick | Worth optimizing, including its algorithm before a port |
| Server: compact player-record encoder within that packet work | 0.67 ms per snapshot; 0.22 ms/tick | A smaller subset; bulk serialization/compression is already native |

Costs overlap: hit tests and world sweeps are inside trace, trace is inside projectile updates, and record encoding/compression are inside packet construction. **Do not add all table rows together.** Pose timing includes calls into Godot; it is not exclusively interpreter time. Native skeleton update, skinning and rendering are not eliminated by a port.

### Client: move the whole pose operation

The current [pose solver](../deathmatch/avatars/pose.gd) combines two-bone IK, coordinate transforms, dictionary lookups, repeated bone queries and pose writes. [Remote interpolation](../deathmatch/avatars/pose_blend.gd) also walks arrays/dictionaries and applies bone transforms every rendered frame. C++ should own cached bone indices/rest transforms and reusable numeric buffers, solve from one input snapshot, and apply the resulting pose in a single extension operation per avatar. Retain the existing solve cadence and render-rate interpolation. Keep current local headset/controller poses immediate.

A line-for-line port which continues making many dynamic calls and rebuilding dictionaries will retain much of that overhead. Quaternion interpolation and Godot's skeleton operations already execute native implementations; the opportunity includes removing interpreted loops, temporary containers and repeated lookups around them.

For scale, **if** an integrated port made the entire measured nearby pose scope 3–5× faster, it would save about **1.18–1.42 ms/frame** at this 16-avatar load. The absolute ceiling for eliminating that scope is about 1.77 ms. These are conditional calculations, not measured native-client results or promised FPS gains. Distant XR pose savings under the same assumption would be about 0.47–0.56 ms. GPU-bound frames may show little FPS change, although reducing CPU work can help CPU-bound frames meet the presentation deadline.

The client fixture uses three shared VRMs, eight full-body/face and eight head/hands tracked avatars, half speaking, with springs off. It has no live match or headset runtime. The synthetic XR camera selects policy only. A client pilot still needs actual headset CPU/p95/p99 measurements and pose parity checks.

### Server: batch projectile state and preserve authority

The fresh baseline at 16 actors measured simulation tick p50 **6.68–6.74 ms**, p95 **8.10–8.32 ms**. Snapshot building is timed separately. The internally instrumented runs were slower: p50 **7.66–7.73 ms**, p95 **9.12–9.49 ms**. Their projectile scope increased to 4.14–4.21 ms. Timer wrappers, packet work/cache effects and uncontrolled clocks affect these numbers; the difference is not a native-code regression or a reliable overhead subtraction.

In the detailed runs, `_trace` occupied 2.52–2.54 ms/tick. Its `world_fraction` portion was 0.59 ms; player-body math was only 0.024 ms. The remainder includes mode checks, dictionary access, query setup, additional native rays and result construction. There were 118,190 world sweeps but only 9,112 player-body tests over 360 ticks. The existing spatial grid and zero-rewind fast path are already implemented.

A useful native boundary would take a tick-local array of player/projectile state, perform movement, candidate lookup and body math in batches, and return ordered collision results. Preserve serial/life checks, relative-motion sweeps, fresh-shot semantics, thin-wall cover, ties, damage order and authoritative tick frequency. World queries must retain the current physics timing. Do not move damage callbacks or live scene objects onto arbitrary worker threads.

The baseline projectile helper averages about 3.53 ms/tick. As an illustrative bound, a **2× speedup of that complete helper** would save about 1.76 ms/tick. The 23× arithmetic result below cannot be applied to the helper: engine queries and gameplay work remain. This fixture uses a small synthetic collision environment with bots disabled; complex BSP maps, hitscan bursts, explosions and other loadouts can have different bottlenecks. It does not establish a player-capacity multiplier.

### Server/client networking: fix redundant work before translating it

The original server fixture has no remote peers, so `_send_snapshot()` skips `replication.packets()`. Its roughly 1.3 ms snapshot p95 **does not measure packet encoding**. The new disposable fixture forces the real packet construction path without sending to remote clients.

At 16 actors it measured 3.90–3.93 ms mean packet construction per 20 Hz snapshot, and total snapshot p95 7.30–7.62 ms. At eight actors with neutral VR poses, packet construction averaged 2.39 ms/snapshot and total snapshot p95 was 4.22 ms. These include instrumentation and exclude actual remote transport; VR here means four neutral transforms, not a full body/face tracking payload. Tick and snapshot p95 values cannot be added to obtain a combined p95.

[Replication](../deathmatch/network/replication.gd) duplicates a candidate batch and serializes/compresses it again for each appended record to check its size. The 16-actor runs made **44,937 pack calls for 120 snapshots**, roughly 374 per snapshot. Native `var_to_bytes` and FastLZ already perform the bulk serialization/compression. A C++ caller would not remove this repeated work. First investigate packing fewer trial batches while preserving the 1,100-byte packet budget, independent records and loss recovery.

The [compact codec](../deathmatch/network/codec.gd) still recursively walks values and writes individual fields in GDScript. A native bounded writer/reader could help larger VR payloads and server fan-in, but the measured desktop player encoder is only 0.67 ms/snapshot across all 16 players. Client input encoding, server input decoding and full-tracking payloads were not measured here. Preserve exact wire bytes, length/depth/node limits, malformed-packet rejection and object-deserialization restrictions. Do not infer a client codec saving from server snapshot totals.

## Native arithmetic experiment

An optimized standalone C++ translation of the production rounded-box sweep processed the same 30,000 inputs as GDScript:

| Implementation | Median batch time | Contacts |
| --- | ---: | ---: |
| Existing GDScript `box_fraction` | 22.519 ms | 10,797 |
| Experimental C++, `g++ -O3`, contraction disabled | 0.964 ms | 10,797 |

The kernel was **23.36× faster**, with zero hit/miss mismatches and zero measured fraction error on this corpus. Inputs include misses, crossings, initial overlaps, stationary and axis-parallel segments, alternating ray and radius-0.15 sphere sweeps. One warmup and five timed passes were used; output checksums prevent removal of repeated work by the compiler. The C++ port uses float vectors, double scalar calculations and a fixed-size stack buffer instead of a dynamic cut array.

This is a **standalone kernel/data-layout comparison**, not a GDExtension or release-game A/B test. It excludes extension calls, buffer conversion, physics queries, skeleton writes and gameplay. It compares the installed Fedora Godot runtime against optimized native code and uses one fixed box size, not every gameplay edge case. Its purpose is to establish that substantial arithmetic speedups are plausible. A production port still requires broad differential testing, especially boundaries, NaNs/infinities, large coordinates and all stance volumes.

## Integration and priorities

Use **C++ through a small GDExtension with official godot-cpp bindings**. Godot loads these shared libraries without rebuilding the engine. C can implement the arithmetic kernels through the same C ABI, but C++ bindings simplify engine integration; this study provides no reason to expect C itself to outperform equivalent optimized C++. See [GDExtension](https://docs.godotengine.org/en/stable/engine_details/engine_api/gdextension/what_is_gdextension.html) and [godot-cpp](https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/about_godot_cpp.html).

The repository already ships native plugins and a [bHaptics native build script](../tools/build_bhaptics_native.py), so this is an extension of an existing release requirement. A new library still needs Linux x86-64, Windows x86-64 and Android ARM64 builds, debug symbols, CI, packaging and crash diagnostics. Pin the bindings/API baseline and match engine floating-point precision. For this Fedora/custom engine, generate and validate its extension API rather than assuming an upstream binary match. Keep a GDScript reference/fallback during rollout.

Recommended order:

1. **Client pilot:** native pose solve plus interpolation/application, with persistent buffers. Aim for at least 0.5 ms/frame improvement in the 16-avatar fixture and lower headset p95/p99, without altered poses, controller latency or LOD. This threshold is a proposed acceptance criterion.
2. **Server pilot:** batched projectile updates and candidate grid. Aim for at least 1 ms/tick improvement in the 16-actor stress case, then test representative maps/loadouts, bursts and live remote clients. Compare identical recorded inputs and collision/damage sequences.
3. **Network optimization:** reduce repeated trial packing in the existing implementation; then reassess whether a native compact encoder/decoder is worth its maintenance and security burden.

Keep menus, settings, match rules and ordinary gameplay orchestration in GDScript. Weapon construction and clip spikes have already received targeted caching/slicing fixes, so they are not first-choice rewrite targets. Bot perception/planning may deserve a later study, but this fixture deliberately disables bots and cannot justify a native AI rewrite. Navigation queries, physics, rendering and existing native secondary animation are not accelerated merely by switching caller language. Godot makes the same distinction in its [CPU optimization guidance](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html).

Start single-threaded to isolate language/data-layout gains. Later parallelism should use immutable inputs and independent output buffers; accessing the active scene tree is not generally thread-safe. See [Godot thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).

## Reproduction and limitations

Run from the repository root:

```sh
python3 tools/native_study/run.py
```

Requires the project imports/assets, Godot and g++. The runner generates instrumented copies under ignored `test-results/native-study/`, executes probes sequentially, uses temporary game settings/data under `/tmp`, and writes `results.json`. It does not load the C++ experiment into the game. Each server probe runs 360 ticks, with 120 excluded from tick/snapshot percentiles; helper means include warmup. Two uninstrumented 16-actor baselines bracket two instrumented packet runs and one eight-actor VR-pose run.

Machine: i7-12700 / Arc A770; Godot 4.7.2 Fedora; GCC 16. No controlled CPU clocks, release export, Android device or headset timing. Existing fixture shutdown warnings (13 ObjectDB instances and five resources) occur in both baseline and instrumented runs and are retained in the receipt. Final runs have no script errors. No shipped native implementation or measured end-to-end native speedup is claimed.
