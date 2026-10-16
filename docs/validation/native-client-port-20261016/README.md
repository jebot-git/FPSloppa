# CQ-only snapshot compression and native client protocol — 2026-10-16

## Delivered behavior

Snapshot compression is opt-in for CQ only. Generic replication recognises CQ by `kind == cq` or the class prototype's `class_mode` metadata; explicit `kind == pve` always disables compression. The synchronous reference/native packers, native worker encoder and district gateway share the policy. The standalone authority only supports CQ and retains its existing FastLZ/delta/relevance behavior.

Non-CQ snapshots use raw version-3 envelopes. Receivers accept raw version 3 and existing compressed version 2. Compact player-record encoding is retained; it is a serializer, not compression. Input-packet compression is unchanged. Old generic clients without the new raw-envelope decoder must be updated when used with the changed generic host. Standalone CQ's network protocol is unchanged.

The first client port implements native complete frame decoding and input serialization:

- `client_frame.cpp`: CQA1/CQA2/CQA3, player rows, tracked transforms, physical magazines/reloads, projectiles, jetpacks, classes/progression, objectives, utility entities, vehicles/turrets, aircraft, grenades, events, combat timers and squads. Reuses the existing bounded native frame validator; rejects duplicate entity IDs/sections, including repeated unknown sections. Transport parses the validated frame before publishing/acknowledging it.
- `client_input.cpp`: CQI1/CQI2/CQI3 including optional tracked/offhand transforms, handedness, room movement, physical reloads, held-weapon state, redundant input events, rewind time and swimming. Nonfinite input is rejected.
- `FPSNativeClient.poll()` publishes `event.frame`; the client adapter uses it without another script decode. `FPSCodec` also exposes the decoder/serializer for other callers. Reference methods and explicit `--gdscript-cq-frames` / `--gdscript-cq-input` switches remain for parity checks. Startup detects an outdated native extension and asks for a rebuild.

This is the protocol portion of P1. Dictionary projection and scene/entity state application remain GDScript and are the next native migration. No end-to-end client FPS or PvE capacity improvement is claimed.

## Measurements

Godot 4.7.2, release native extension, development Intel N95. Synthetic fixtures exercise every known section, tracked offhand poses and one physical weapon row per player; these timings are means, not p95 frame times. Forty frame decodes / 4,000 tracked input encodes per path.

| Operation | Reference GDScript | Native C++ | Change |
| --- | ---: | ---: | ---: |
| Decode 64 players, 46,671 bytes | 6.657 ms | 3.222 ms | 52% lower |
| Decode 128 players, 92,623 bytes | 11.923 ms | 7.364 ms | 38% lower |
| Encode tracked/swimming input | 16.69 µs | 8.71 µs | 48% lower |

The native decoder still creates compatibility dictionaries. These measurements do not represent a typed native entity-state pipeline or render timings. Raw PvE snapshots trade compression CPU for more bandwidth: the 64-player/128-projectile synthetic fixture produces 50 raw packets versus 9 compressed CQ packets, all normal datagrams within the 1,100-byte budget. No actual PvE mode is present in this branch to run a representative PvE gameplay load test.

## Validation

- `native_client_protocol.gd`: **221 checks passed**. Exact field parity for versions 1/2/3 at 1/4/64/128 players; truncated payloads, nonfinite values, counts and duplicate sections/players; forward-compatible unknown sections; 64 input flag combinations and byte-for-byte wire parity.
- `snapshot_compression_policy.gd`: **472 checks passed**. Plain PvE, PvE sharing class metadata, class CQ and legacy CQ; synchronous native/reference byte parity, worker policy, raw lengths, decode compatibility and datagram budgets.
- Existing `native_network_packing.gd`: **26,925 checks passed**, independent records preserved, reordered/mixed channels and oversized reliable records.
- Existing `native_backend.gd`: **12,672 checks passed**, including bounded asynchronous queues and existing native/reference behavior.
- Existing `replication_protocol.gd`: passed, including missing-packet delivery and bounded input.
- Standalone real-world transport: **60 frames each** with `row-xor-fastlz-v3` and `full-fastlz`, deployment and movement passed (24.5 m / 28.8 m), and every received native frame matched the reference decoder. Local isolated loopback server on port 27931; no live service changes. These are single-client transport checks, not new 64/128-user capacity runs.
- Client adapter parsed with `--check-only`. Linux release extension rebuilt, installed atomically, source/hash receipt refreshed. CMake and SCons source lists updated. `git diff --check` passed. Windows/Android builds were not run.

Raw outputs are kept alongside this report. All Godot scripts run with `--headless --xr-mode off --path . --script <path>`. Native binary installation remains a local build artifact; rebuild it when using the source changes elsewhere.
