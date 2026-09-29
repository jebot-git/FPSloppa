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
