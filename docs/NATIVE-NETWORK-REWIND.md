# Native compact codec and shared hitscan history

Implemented the first two recommendations from [remaining native options](REMAINING-NATIVE-OPTIONS.md): a native compact network codec and shot-local history extraction feeding native historical traces. Packet format, compression, update rates, damage order and weapon behavior remain unchanged. Both features retain GDScript reference paths.

## Measured results

Measurements use the current portable Linux client library and Godot 4.7.2 Fedora on the i7-12700. Network runs use reference/native/native/reference ordering, after all builds finished. Values below average the two runs' means.

| Workload | Reference | Implemented | CPU reduction |
| --- | ---: | ---: | ---: |
| Full-VR snapshot generation, 16 players + 32 shots | 1.757 ms | 0.368 ms | 79% |
| Same snapshot, client receive/decode | 1.816 ms | 0.304 ms | 83% |
| Desktop snapshot generation, 16 players + 523 shots | 2.562 ms | 2.051 ms | 20% |
| Same desktop snapshot, receive/decode | 2.198 ms | 1.535 ms | 30% |
| Full body/face pose encoding alone | 64.6 µs | 5.9 µs | 91% |
| Full body/face pose decoding alone | 64.1 µs | 6.4 µs | 90% |
| Eight rays with 100 ms rewind, including history preparation | 1.537 ms | 0.167 ms | 89% |

The full-VR snapshot contained the same **3,141 bytes / 3.05 packets on average** in every run. Byte and packet counts were also unchanged in the other scenarios. Client state assembly (`flush`) is separate from receive/decode: about 0.157 ms reference and 0.125 ms native in the full-VR runs. It was not rewritten; variation/cache effects in that scope should not be counted as a separate optimization.

For the eight-ray workload, **sharing history alone with GDScript tracing** reduced cost to 0.553 ms, about 64% less than reference. Using the existing native trace with historical state reduced it further to 0.167 ms. Native p95 was 0.194–0.219 ms versus reference 1.719–1.777 ms. Each measured burst includes constructing its history context, not just tracing against a precomputed cache.

These are focused CPU measurements, not total client frame time or live server capacity. Network probes exclude transport and scene application; the ray fixture is synthetic, not a recorded DE match. Native VR-client encoding/decoding was measured with full tracking data, but no headset timing, Windows runtime or Android runtime performance is claimed. OS clocks are uncontrolled. Raw results and source/build hashes are in [the validation receipt](validation/native-network-rewind-2026-09-29.json).

## Implementation

### Compact codec

[FPSCodec](../addons/fps_native/src/codec.cpp) implements the existing bounded Variant writer/reader in C++. [The GDScript API](../deathmatch/network/codec.gd) dispatches raw encode/decode to it when available; packet headers and FastLZ compression remain unchanged. Snapshot envelopes still use Godot's existing native serialization. Each codec operation owns its scratch storage, so calls do not share mutable read/write state.

Wire tags, little-endian scalar fields, zigzag integers, UTF-8 strings, transform quaternion quantization and dictionary insertion order are preserved. The decoder retains the existing byte, node, depth and container limits, allowed dictionary key types, transform checks, rejection of trailing/truncated data, and prohibition on object/resource decoding. The port does not replace the format with unrestricted Variant deserialization. Application-level pose/input validation remains in place.

`encode_reference` and `decode_reference` preserve the prior GDScript implementations for differential testing. Start the game with `--gdscript-codec` after Godot's `--` separator to select them globally. Missing native codec classes also fall back automatically.

### Historical hitscan

[LagCompensation.sample](../deathmatch/lag_compensation.gd) finds the historical interval once and interpolates position, stance height and yaw in one actor pass. Arena and experimental/CS pellet loops create one context per synchronous shot. CS penetration passes the same context through successive cover layers.

The native projectile trace now accepts this historical state for supported modes. Live dead/spectator flags and life serials are checked on every ray; damage is still applied in the original order between pellets. A life change invalidates that actor's historical row and uses current state, matching the reference behavior. Contexts are local to a shot, not persistent caches across ticks or players. Teleport rejection, rewind limits, angle interpolation, cover checks, headshots, ties, map contacts and current world geometry are retained.

Modes with structures, mounted hulls or Tribes-specific tracing retain their complete GDScript trace, which can also consume the shared history context. The standalone railgun's existing piercing path remains unchanged. `--gdscript-rewind` restores per-ray historical extraction/reference tracing; `--gdscript-projectiles` disables native projectile/tracing helpers while retaining the history batching improvement. The original `_trace_reference` call with no context remains available for direct parity comparisons.

## Verification and delivery

New checks passed:

- **15,248 codec checks:** exact encoded bytes, decoded values, scalar boundaries including signaling-NaN float32 conversion, Unicode/StringName values, generated nested values, limits, truncated/trailing payloads and arbitrary malformed bytes.
- **16,850 history/trace checks:** combined history versus the three original helpers, missing fields, serial mismatches, teleport rejection, native/reference historical contacts and normals, live death/spectator/life changes and newly joined actors.
- **10 integrated firing checks:** CS and Doom shotgun shots use one history extraction across their pellets.
- Existing native avatar/projectile parity, packet packing, replication, lag reliability, CS accuracy and penetration, cover, hit detection, projectile ordering, combat and fortress tests passed. Relevant combat/lag/replication tests also passed with native codec and projectile helpers disabled.

Real loopback ENet server/shooter/target/spectator tests passed with native codecs. Mixed-codec runs also verify both directions: reference server/native clients and native server/reference clients. Existing fixture ObjectDB/resource shutdown warnings remain; malformed-byte tests deliberately exercise UTF-8 error reporting. No final validation run has script failures.

Portable Linux client/server, Windows x86-64 and Android ARM64 libraries were rebuilt and source-hash checked. Windows imports remain KERNEL32/msvcrt; Android LOAD segments retain 16 KiB alignment. A separate console-server package was exported and audited, then started on loopback with its server library mapped. Codec parity also passed against that server-only library in an isolated development harness. The console template intentionally disables development script/path overrides, so the harness uses the Fedora engine; the console executable itself received a normal host-start smoke test. Existing release packages were not replaced or published.

```sh
# Codec/history parity and relevant regressions, plus paired network benchmarks:
python3 tools/native_study/validate_network_rewind.py --bench

# Repeat only the paired network measurements:
python3 tools/native_study/validate_network_rewind.py --bench-only
```

Logs and JSON are written to `test-results/native-network-rewind`. Server tests need local socket access. Builds use the commands in [native acceleration](NATIVE-ACCELERATION.md); all release targets require the rebuilt library receipts.

## Responsiveness cost and native decision — 30 September 2026

The movement/weapon follow-up was measured on **Intel N95, Godot 4.7.2, Linux headless, GDScript fallback**. These results are not comparable to the i7/native measurements earlier in this document. Two sequential runs were collected; timings below are the range of their medians. The source probes and complete results are retained in [the validation receipt](validation/responsiveness-2026-09-30.json).

| Scope | Reference case | Updated case |
| --- | ---: | ---: |
| Build/pack a tracked input | 0.187–0.192 ms | 0.531–0.532 ms, typical history/trigger traffic |
| Same input, compressed payload | 588 B median | 760 B median; 844 B maximum |
| Saturated input: 30 edges/sec, no acknowledgements | — | 2.242–2.255 ms; maximum **1,100 B** |
| Encode 16 full-body actors + 32 projectiles | 3.772–3.890 ms | 5.538–5.718 ms |
| Same snapshot, compressed total | 3,777 B median | 4,252 B median; no oversized player records |
| Six-tick delayed movement reconciliation | — | 0.105–0.133 ms median; 0.663–0.749 ms p95 |
| Flame trace with 16 players | One ray: 0.116 ms | Five rays + deduplication: 0.625–0.637 ms |

Input reference means the synthetic command without the new movement/trigger history; the probe isolates that payload contribution and does not measure the complete input frame or all existing action annotations. Snapshot reference omits the added replay/shot-outcome fields. Network timings include packing/compression, not ENet, receiver application or rendering. Flame timings include world/body queries and target deduplication, not damage, rewind, effect rendering or transport. At the 0.12 s cycle, its extra tracing costs roughly 4.2–4.3 ms of CPU per second per continuously firing pyro in this fallback fixture. Sixteen concurrent pyros would multiply that workload; this is not a measured whole-server capacity estimate.

The first implementation's synthetic snapshot median was 7,348 bytes. Compact replay-state encoding reduced it to 4,252 bytes, about 13% above the reference payload. Historic avatar-only tracker channels were removed, and bounded packet packing fixed the original saturated-input overflow. Flame coverage still emits one visual/RPC per shot rather than five. The movement fixture initially replayed on every snapshot; checking the complete saved movement state reduced this to **11 replays and 203 confirmations**, preserving zero settled position error after stairs, a wall, two jumps and an authoritative impulse. Replay is capped at 32 steps to bound recovery work.

Retained static memory in the input probe was approximately 16.8 KB reference, 26.0 KB typical and 47.8 KB saturated, including the measurement arrays. These are live-memory deltas, **not allocation counts or leak measurements**. Histories remain bounded: four transmitted movement samples, eight trigger events, 180 prediction samples, 64 pending presentation reservations and 256 presentation identities/counters.

**Native decision:** retain these state machines in GDScript. The main extra work is repeated serialization and engine collision queries; simply translating the small queues would not remove it. The existing `FPSCodec` and historical `FPSProjectiles` trace paths are the appropriate native implementations to use first. The new payloads use their existing supported Variant types and require no new C++ API. Matching-state replay avoidance and compact payloads produced useful improvements before adding a native boundary.

**Historical limitation, superseded by the native follow-up below:** an existing-extension build was attempted using the repository's pinned, checksum-verified godot-cpp bindings, but this environment has neither CMake nor a C++ compiler. No new native binary or untested C++ port was produced, and no native speedup is claimed for the new workload. Rebuild the existing extension on a configured build host, rerun these probes with and without `--gdscript-codec`, and profile actual headset frame times before considering a new port. A future port would need batched persistent state and reference/native parity tests; `CharacterBody3D` collision work already executes in the engine's C++ implementation.

Reproduce the focused probes with Godot's `--headless --xr-mode off --path . --script` and:

- `res://tools/native_study/responsiveness.gd`
- `res://tools/native_study/responsiveness_flame.gd`
- `res://deathmatch/tests/movement_replay.gd`

Use `res://deathmatch/tests/responsiveness_protocol.gd` for 721 bounded-input/round-trip checks, including rapidly changing tracker orientations. The separate functional tests and real ENet results are recorded in the receipt. Rendered GPU cost, motion-to-photon latency and physical-headset comfort remain unmeasured.


## Native responsiveness follow-up — 30 September 2026

The Linux client and dedicated-server extensions now build locally using an isolated GCC/CMake toolchain extracted under `/tmp`. No system packages were installed. Both source-hash receipts passed verification, and the server-only library passed an isolated codec/packing smoke test. These are local development binaries, not portable release builds; Windows and Android were not rebuilt in this follow-up.

[Native network packing](../addons/fps_native/src/network_packing.cpp) adds three coarse operations to `FPSCodec`: batched mixed snapshot record encoding, bounded snapshot packet packing, and input encoding/compression with overflow pruning. Batching reduces per-record GDScript/C++ calls. The input path copies only when an oversized command needs pruning. Scratch state is local; source commands remain unchanged. The existing 1,100-byte budget, wire bytes, record order, compression, and normal/large packet channels are preserved.

Dispatch checks method availability so older extensions retain the reference packing path. `--gdscript-network-packing` selects reference packing while retaining the native codec; `--gdscript-codec` selects the full reference codec/packing path. Gameplay prediction and weapon state machines remain in GDScript. TF flame tracing still uses its structure-aware reference path.

Sequential ABCCBA runs on **Intel N95 / Godot 4.7.2 / Linux headless** compare the same updated workload. Values are the mean of two run medians:

| CPU scope | GDScript fallback | Existing native codec | Native codec + new batching/packing |
| --- | ---: | ---: | ---: |
| Snapshot: 16 full-body actors + 32 projectiles | 5.345 ms | 0.945 ms | **0.802 ms** |
| Typical tracked input build/pack | 0.516 ms | 0.0675 ms | **0.0675 ms** |
| Saturated tracked input build/pack | 2.212 ms | 0.291 ms | **0.275 ms** |

Snapshot cost is about **85% lower than fallback**, with **15% further reduction beyond the existing native codec**. Typical input cost is about **87% lower than fallback**, attributable to enabling the existing codec; the additional native packing loop gives no measured typical-input gain. The small saturated-input difference needs more controlled measurement before treating it as a separate improvement. Native snapshot p95 was 0.983–1.033 ms. Snapshot median stayed 4,252 bytes; typical input median stayed 760 bytes, and saturated input stayed within 1,100 bytes. Retained-memory deltas were unchanged.

The new differential suite passed **3,242 checks**, covering exact input bytes, immutable source data, overflow rejection, mixed record encoding, random/compressible snapshots, channel boundaries and malformed packing requests. Existing codec (15,248), packing (6,335), acceleration (51,311), rewind (16,850), integrated firing (10), and responsiveness protocol (721) checks passed. Replication, weapon variants, CS, flame coverage and movement replay also passed. Real ENet Doom/Quake server/client runs passed all eight scenarios per mode, including dropped/delayed rocket triggers and buffered fire. Existing shutdown ObjectDB warnings remain; no script errors occurred.

Reproduce the comparison with:

```sh
python3 tools/native_study/compare_responsiveness.py --godot /path/to/godot
# Requires the rebuilt extension:
godot --headless --xr-mode off --path . --script res://deathmatch/tests/native_responsiveness.gd
```

The [validation receipt](validation/native-responsiveness-2026-09-30.json) retains all six benchmark results, build/source hashes and functional/network results. These are serialization CPU fixtures, excluding transport, scene application and rendering. They do not establish headset frame-time or motion-to-photon improvements.


## Recipient replication and special-trace assessment — 30 September 2026

The [recipient replication follow-up](NETWORK-STACK-IMPLEMENTATION.md#cosmetic-prediction-and-recipient-replication--30-september-2026) adds native `snapshot_records` batching to the existing codec. Linux client and dedicated-server libraries were rebuilt and source-hash checked; the server-only harness now also verifies recipient privacy. The new GDScript reference/native paths match exact packet bytes and cadence state. Common control/projectile packet groups can be reused across peers; personal player/inventory groups remain separate.

On **Intel N95, Godot 4.7.2, Linux headless**, sequential ABCCBA comparisons used 16 fully tracked players on a 25 m grid, 32 projectiles and eight recent firing outcomes per player, at 30 snapshots/second. Figures are the mean of two run medians; the reference personalization path still uses the existing native compact codec.

| Scope, all 16 recipients | Shared broadcast control | Personalized GDScript policy/packing | Personalized native policy/packing |
| --- | ---: | ---: | ---: |
| CPU per snapshot | 0.747 ms | 6.753 ms | **4.433 ms** |
| Total outgoing snapshot payload | 64,464 B median | 32,648 B median | **32,648 B median** |
| Payload p95 | 64,736 B | 51,240 B | **51,240 B** |

Personalization reduces median payload by **49%**, but increases CPU by about **3.69 ms per snapshot** versus one shared broadcast in this fixture. At 30 Hz that is approximately 111 ms of additional CPU per second, an extrapolation rather than measured whole-server utilization. The native batch reduces personalized CPU by **34%** versus the equivalent reference policy/packing. Native p95 is 5.924–6.073 ms. Pose refreshes still produce larger periodic packets; median savings must not be treated as uniform bandwidth or frame-time improvements. These numbers exclude transport, receiver application, rendering, and large special-mode objective state.

Cosmetic flight stepping measured **12 / 60 / 320 microseconds median** for 1 / 6 / 32 simultaneous cosmetics (p95 13 / 69 / 361 microseconds). Warm node creation medians were about 0.14–0.16 ms in the larger samples; first creation was 1.49 ms. Shared visual-helper setup took 28 ms cold in this probe, so graphical clients now prepare that helper during map loading. Construction samples are few and include engine resources; GPU/shader compilation is not measured. The bounded cosmetic loop remains GDScript: its measured steady cost is small and its collision/mesh work already runs in native engine APIs.

### Impact of broadening native tracing (item 6)

A benchmark-only prototype combines the existing native world/body trace with the current TF structure scan. It does **not** change `_native_trace_allowed`. Five-ray TF bursts against 16 actors gave the following ranges of run medians:

| Synthetic structures | Current complete reference path | Native bodies + reference structures prototype |
| --- | ---: | ---: |
| 0 | 0.629–0.646 ms | 0.222–0.224 ms |
| 16 | 0.796–1.007 ms | 0.382–0.409 ms |
| 64 | 1.234–1.496 ms | 0.758–0.763 ms |

The fixtures found no target/position differences for their five sampled rays, but they exclude mounted hulls, moving structures, rewound damage sequences, shootable map triggers and all Tribes overlays. These results establish an opportunity, not production equivalence. The remaining structure loop becomes a larger share as structure count grows; batching structure geometry/candidate filtering is preferable to many small extension calls.

A feasible staged implementation is:

1. Add live structure geometry to a shot-scoped native context, retaining nearest-hit ordering, cover, radius expansion and structure identifiers. Recheck live state after every pellet, since an earlier hit may destroy a structure.
2. Add mounted-hull contact attribution and mounted-player exclusion. The current reference uses real physics contact identity, including unsafe sweep fractions and overlapping-wall rejection; a body-only native trace cannot reproduce this merely by opening the mode gate.
3. Extend and validate Tribes vehicles, mines, deployables, beacons, fixed defences, base assets and shields/station overlays, preserving trace order and damage routing. These have different target identities and lifetimes.
4. Require reference/native parity across geometry, life changes, destruction, rewind, thin cover and real mode matches before enabling each mode; measure integrated tick p95/p99 afterward.

Gameplay consequences of an incomplete port include shooting a mounted pilot as an exposed body, losing structure damage, incorrect cover/ties, or bypassing a shield. The production gate remains unchanged. No custom physics rewrite or multithreaded scene mutation is justified by these measurements.

Full measurements, build hashes and successful functional/network results are retained in the [validation receipt](validation/recipient-replication-2026-09-30.json). These are local Linux builds; portable Linux, Windows and Android release binaries and physical-headset performance still require separate validation.


## Native special tracing and packing rollback — 30 September 2026

**Current state:** special-mode native tracing is enabled; production personalized replication is reverted in favor of one shared broadcast. The earlier recipient experiment and gated-prototype sections are historical.

`FPSProjectiles.trace` now handles the complete special-mode dispatch order. TF structure capsule intersections run in C++, preserving nearest/tie behavior and structure identifiers. Mounted BA2 pilots are excluded from ordinary body hits; the existing physics contact routine supplies hull attribution, including its unsafe-fraction and overlapping-wall behavior. World/map-trigger handling retains its original position in the trace. Tribes vehicle, mine, deployable, beacon and station/base-asset/fixed-defence overlays run synchronously in their original order through their existing callbacks. Those callbacks and damage rules remain GDScript; the world/body/TF-structure kernels are native. This avoids substituting approximate body targets for existing mode geometry.

Structure and mounted-player membership are read live per ray. There is no cross-shot cache of targets that can survive destruction, dismounting or respawn. The original GDScript trace remains available through `--gdscript-projectiles`. Extensions lacking `trace_structures` retain the previous restricted mode gate automatically.

Sequential comparisons on **Intel N95 / Godot 4.7.2 / Linux headless**, using five rays against 16 actors, measured:

| Fixture | Reference median range | Native median range |
| --- | ---: | ---: |
| TF, no structures | 0.607–0.669 ms | 0.268–0.270 ms |
| TF, 16 structures | 0.775 ms | 0.259–0.260 ms |
| TF, 64 structures | 1.171–1.294 ms | 0.307–0.309 ms |
| ST, 16 deployables + 4 scouts + 8 beacons | 0.971–0.973 ms | 0.578–0.585 ms |
| ST, 64 deployables + 4 scouts + 8 beacons | 1.295–1.307 ms | 0.905–0.908 ms |

That is about **58–75% lower TF trace CPU** and **30–40% lower ST trace CPU** in these fixtures. ST's remaining geometry callbacks become the larger share with many deployables; their current behavior is preserved. These are focused queries without damage application, transport or rendering, not complete game-frame measurements.

Personalized packing was re-examined with native policy/encoding, common-datagram reuse and separate preparation/compression scopes. Its steady median remained **4.558–4.615 ms**, versus **0.767–0.771 ms** for shared broadcasting. The diagnostic fresh-cache batch spent about 4.02 ms in per-recipient preparation/encoding and 1.51 ms in packing; these are a separate fresh-cache workload and must not be added to the steady-state measurement. Further improvement would require a different replication layout, rather than simply moving more loops to C++. Given the explicit frame-time priority, production now uses the shared path and restores its higher bandwidth usage. The older diagnostic sender/native helper remains callable only from study/tests.

Validation includes native/reference structure sweeps, full trace fields/positions/identities, rewind, destruction between rays, mounted hull attribution and body exclusion, pilot death/dismount, all three Tribes vehicle types, mine/deployable/beacon ordering, generators, base assets, fixed turrets and shootable map areas. Existing native collision and rewind suites pass, as do TF combat/flame, weapon/demo, CS, movement replay and packing checks. Real ENet Doom/Quake rocket regressions and cosmetic-node handoff pass after the rollback. Linux client and dedicated-server libraries were rebuilt and source-hash checked; the isolated server harness checks the structure trace as well as codec behavior.

The broader authored-map AS/ST/TB harnesses could not run: AS requires an external BSP argument, and this checkout has no compatible arenas for the other selected harnesses. The synthetic mode tests exercise the real callbacks and actual BA2 physics hull. Full-map gameplay, headset timing, Windows/Android runtime behavior and portable release binaries remain separate validation work. Existing one-instance ObjectDB shutdown warnings remain.

Reproduce the special trace checks with `res://deathmatch/tests/native_special_trace.gd` and the CPU comparisons with `res://tools/native_study/special_trace.gd` and `res://tools/native_study/recipient_replication.gd`. Run benchmarks sequentially without a concurrent build or game test. Full results and source/build hashes are in [the validation receipt](validation/native-special-trace-2026-09-30.json).
