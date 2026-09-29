# Remaining native optimization options — 2026-09-29

Implementation follow-up: [avatar preparation and bot AI](NATIVE-AVATAR-BOTS.md). The candidate costs below precede these ports.

Implementation follow-up: [native compact codec and shared hitscan history](NATIVE-NETWORK-REWIND.md). The measurements below describe the investigation before those two changes.

There are still useful selective C++ opportunities after the [implemented avatar/projectile changes](NATIVE-ACCELERATION.md). The strongest shared client/server candidate is the bounded compact codec. For client frame time, finish batching avatar pose preparation. For DE servers, batch historical hitscan state; for populated bot servers, target AI steering and decisions.

This investigation changes only profiling tools and documentation. It does not change production behavior, packet formats, update rates, LOD distances or animation cadence. Full measurements and source hashes are in [the receipt](validation/remaining-native-study-2026-09-29.json).

## Measured candidates

| Candidate | Current measured cost | Recommended native boundary | Priority / effort |
| --- | --- | --- | --- |
| Compact network writer and reader | Full-VR 16-player snapshot: compact encoding **1.42 ms**, decoding **1.57 ms**, inside total generation/receive costs of about **1.74/1.79 ms** | One bounded encode/decode call per value or record, with reusable buffers | High, medium effort; benefits clients and servers |
| Historical hitscan state | Eight rays with 100 ms rewind: about **1.59 ms** instrumented; **1.03 ms** in the three history helpers | Find history interval once, interpolate position/height/yaw together, reuse an immutable snapshot for a burst | High for DE/hitscan servers, medium effort |
| Remaining avatar pose preparation | **0.94–1.06 ms/frame** outside existing native helper scopes, for 16 nearby avatars | One per-avatar solve operation with cached indices, transforms and persistent interpolation buffers | High for client CPU headroom, higher effort |
| Bot steering, combat and planning | AI **3.18 ms/tick** with 16 bots; steering **1.07**, combat **0.69**, planning **0.53**, perception **0.40** | Batched actor inputs, persistent brain state and native decision kernels; keep authoritative application synchronous | High for bot servers, higher effort and behavior risk |
| Pickup candidate filtering | **0.56 ms/tick**, 16 bots and 25 map pickups | Spatial candidate filtering first; native overlap batch if still material | Medium, low/medium effort |
| Morph composition / tracking interpolation | About **0.27 / 0.18 ms/frame**, 16 nearby avatars | Cached numeric channels and a batch transform update | Secondary client work; combine with avatar port |

These are **current costs, not promised savings**. Nested scopes overlap. The network compact-codec timings come from an instrumented companion run; total network timings come from the production-path probe. Server scopes include wrapper overhead and engine calls. A rewrite cannot eliminate the native physics, skeleton or rendering work inside a scope.

## Networking: finish the compact codec

The packet envelope already uses native `var_to_bytes`, `bytes_to_var` and FastLZ. The remaining [compact codec](../deathmatch/network/codec.gd) recursively traverses Variants and writes/reads fields through `StreamPeerBuffer` in GDScript. It is used for player records and client inputs. Full body/face poses make it considerably more expensive than the earlier desktop-only measurements suggested.

For 16 fully tracked players and 32 shots, production generation averaged **1.741 ms/snapshot**, receive **1.786 ms**, and final state assembly **0.164 ms**. The mean payload was 3,141 bytes across 3.05 packets. Compact encode/decode accounted for about 83%/88% of the respective instrumented totals. In contrast, a 523-projectile desktop snapshot spent only **0.51/0.63 ms** in the compact codec: much of that workload lies elsewhere in replication. Porting the compact codec alone will not remove dense projectile packet costs.

A full body/face pose by itself measured **60.6 µs encode**, **60.9 µs decode**, **34.3 µs validation**. Compression took **2.2 µs**, decompression **0.5 µs**. At 16 clients × 30 inputs/second, pose decoding alone corresponds to about **0.49 ms per 60 Hz server tick**, averaged over arrivals. This excludes the command envelope and is a workload extrapolation, not a measured live-network tick.

Illustratively, doubling compact-codec speed would save about **0.71 ms per full-VR snapshot generation** and **0.79 ms per client snapshot receive**, plus about **0.24 ms/tick** in the above pose-decoding fan-in. These are conditional estimates; a native pilot must establish actual gains. Client packet-arrival savings occur in bursts, not on every rendered frame.

Retain exact tags, quantization, field order, bounds, malformed-input rejection and no-object decoding. Use differential byte/round-trip tests and malformed-packet fuzzing before switching paths. Keep the existing extension/fallback arrangement. Validation can be a later native batch; do not weaken it to obtain a timing improvement. Moving compression to a worker is low priority at these payload sizes.

## Hitscan: eliminate repeated history construction

[_trace_reference](../deathmatch/arena.gd) calls three history helpers for every ray. Each builds current player data and traverses the same history to obtain positions, heights or yaw. An eight-pellet shot can repeat this work 24 times. The existing native trace handles current-state standard modes, while nonzero rewind still takes the reference path.

The controlled 16-target fixture measured **0.11 ms/eight rays** through the existing current-state native path, **0.46 ms** through the current-state GDScript path and **1.59 ms** with 100 ms rewind. The three rewind helpers accounted for **1.03 ms per eight-ray batch**. Current and historical paths have different work; their ratio is not a measured native rewind speedup.

First combine history extraction and interpolation. Share the result across a shot's rays, then feed it to a native batch trace using the existing body geometry and world-query code. An eightfold reduction in the observed history-only work would save roughly **0.90 ms per eight-ray burst**, conditional on equivalent batching costs. A GDScript algorithm change may capture much of this benefit before the native port.

Keep life serials, teleport rejection, angle interpolation, rewind limits, thin-wall cover, ties and headshots identical. Snapshot reuse needs a clear lifetime: do not cache mutable player state across deaths, respawns, teleports or unrelated authoritative shots. Special-mode structures, vehicles and Tribes traces still require their own measured/validated extension before enabling this everywhere.

## Avatars: widen the existing boundary

With native helpers enabled, the nearby pose scope is **1.47 ms/frame** for 16 avatars. Existing native calls occupy about **0.41–0.53 ms**. The remaining **0.94–1.06 ms** includes target selection, coordinate conversion, reference-bone queries, cache/interpolation preparation, container work and other engine calls. It is an opportunity envelope, not a pure interpreter measurement.

Move that orchestration into a per-avatar native object with cached topology and reusable target/pose buffers. Avoid replacing each small expression with a separate extension call. Preserve immediate local tracking, remote interpolation, resets, death transitions and current solve cadence. If the remaining scope became twice as fast, the nearby saving would be roughly **0.47–0.53 ms/frame**; a pilot must verify this alongside pose parity and headset timing.

Tracking interpolation costs about **0.18 ms/frame**, morph composition **0.27 ms**, and gait **0.11 ms**. Native morph composition is useful as a follow-up, but Godot still has to apply changed blend shapes. Floor raycasts average only **0.002 ms/frame**, so porting or scheduling those differently is not justified here.

The existing LOD transition modifier adds **0.13 ms nearby / 0.17 ms far away**. This is bookkeeping inside the current policy, not a case for extending LOD distances. It is secondary to pose preparation. The repeated near block has 10 full-detail and six medium-tier avatars because of existing hysteresis; the initial near block has 16 full-detail avatars. Far XR-policy pose cost is about **0.60 ms/frame**, with roughly **0.28 ms** already in native blend application. Do not apply nearby savings estimates to that case.

## Bots, pickups and lower-priority work

The real `qsrc_dm1` bot fixture spent **3.18 ms/tick** in AI. All navigation `path()` calls together cost **0.15 ms/tick**; navigation ray helpers cost **0.20 ms/tick**. The path helper includes native pathfinding, so replacing Godot's navigation engine is not supported by this evidence. Start with steering and combat/perception loops, gather shared player facts once per tick, and retain current decision frequencies and random/visibility behavior. A twofold improvement of the entire AI scope would save **1.59 ms/tick** at this load, but this requires a broader pilot than porting one arithmetic helper. This short DM fixture does not establish costs in DE, TF, Tribes or long-running matches.

Pickup scans cost **0.56 ms/tick**. A spatial grid or cached nearby candidates can reduce repeated checks while leaving eligibility, ownership and ammo callbacks in GDScript. Benchmark that algorithm change before committing to a native pickup system.

Movement took **1.81 ms/tick**, of which **1.27 ms** was already in `move_and_slide`; the step helper took another **0.38 ms**, including engine collision queries. A wholesale movement rewrite has a small remaining CPU ceiling in this fixture and substantial prediction/physics risk. History recording itself was only **0.056 ms/tick**, melee **0.16 ms**. Neither is a leading isolated port.

Special projectile callbacks, explosions, map triggers, audio and effects remain potential mode-specific candidates, but this study does not provide measured gains for porting them. Likewise, an engine module, custom physics implementation, SIMD rewrite or multithreaded scene updates is not justified by these results. Godot documents that calls into engine functions execute at the same speed regardless of scripting language; the opportunity is interpreted work and data flow around them. The active scene tree is not generally thread-safe. See [CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) and [thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).

## Reproduction and limits

```sh
python3 tools/native_study/remaining.py --network
python3 tools/native_study/remaining.py --network --codec-scopes
python3 tools/native_study/remaining.py --avatars
python3 tools/native_study/remaining.py --server
python3 tools/native_study/remaining.py --server --reference
```

Run sequentially. The generator writes disposable instrumented copies under `test-results/remaining-native`; logs/JSON stay there. Settings and user data use isolated `/tmp` locations. Avatar profiling requires a display, server profiling a local ENet socket. The reference switch removes instrumentation, **not** the already implemented native acceleration.

Measurements use Godot 4.7.2 Fedora, i7-12700 and Arc A770, with current native libraries. Avatar runs have 16 avatars, three VRMs, eight full-body/face and eight head/hands, half speaking, springs off, 360 frames per block and reversed scenario order. They do not use an actual headset. Network probes exclude transport and scene application. Server profiling covers 600 measured ticks after warmup on one map, with 16 bots plus a spectator; it excludes snapshot packing/transport and the engine's separate physics step. The ray fixture is a separate synthetic workload, not measured DE match traffic. OS/GPU clocks are uncontrolled.

The probes completed without script failures; existing ObjectDB/resource shutdown warnings remain. No Windows/Android performance conclusion or total-game FPS improvement is claimed. Retain the GDScript paths for each future pilot, measure integrated p95/p99 under representative traffic, and validate correctness before broadening the native scope.

The instrumented bot run averaged **6.46 ms/tick**, p95 **9.47 ms**. The separate uninstrumented control averaged **6.81 ms**, p95 **10.16 ms**. Run-to-run simulation/clock variation exceeds any clean timer-overhead estimate; do not subtract these totals or present their difference as a speedup. Uninstrumented eight-ray timings were **0.106 ms native current-state**, **0.425 ms GDScript current-state**, and **1.494 ms GDScript rewind**. The retained avatar and server runs were executed sequentially.
