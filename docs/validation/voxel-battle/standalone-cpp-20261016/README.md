# Standalone C++ CQ verification — 2026-10-16

The dedicated CQ application and package run without Godot. Tests used the development Intel N95 on Linux; the VPS/live service and i7-12700 were not used.

- Shared native gameplay suite: **919,593 checks pass** (`authority-core.json`).
- Standalone/world suite: **3,110 checks pass** (`world-tests.txt`), including 512 independent terrain/grass reference samples, Jolt ground collision, full-hull room-scale collision, wall breach, support collapse, occupant gibbing, 100 vehicle damage, reset and capture-circle rubble clearance. Maximum sampled height error: 0.000458 m; grass mismatches: zero.
- Real Godot frontend with native transport: desktop and tracked-hand fixtures pass shooting, grenades, NVG, death/gibbing, respawn, squads, team changes/presentation and jetpack. Headless fixtures exercise the actual arena/prediction/projection, without GPU or headset rendering.
- Custom avatar: a 6,270,216-byte derived UT99 container was uploaded, validated off-thread, downloaded byte-identically, and selected. Reconnecting resumed the same server-issued profile token. No token is stored in these reports.
- Voice: valid relay/ping, replay rejection, invalid Opus-format rejection and radio eligibility gating pass (`voice-relay.json`).
- RCON: correct challenge/response HMAC, authenticated status/commands, invalid-password rejection and command bounds pass.
- Package: source/build receipts and every runtime-file checksum verified. No `.gd`, `.pck`, `.gdextension`, scene resources or Godot executable/library are shipped. The executable dynamically loads standard Linux C/math/thread/dl libraries; Jolt, ENet, JSON, hashing and compression are linked into the executable.

The isolated packaged-server run admitted **64 tracked ENet clients for 30 seconds**, with no disconnects, rejected inputs, input overflow or projectile-pool exhaustion. It stayed at **60 Hz**, with **zero fallback transitions**, **4.57 ms mean / 9.31 ms maximum simulation tick**. All 64 received snapshots; the load report separates five seconds of admission/warmup from steady state. This is a loopback server/transport test, not a WAN, GPU, VR headset or long-duration soak result.

The separate 64-bot run filled all four classes and remained at 60 Hz for approximately 15 seconds, firing 683 shots, recording 324 damage events and breaching five wall cells. Navigation reported 139 failed bounded requests out of 889; these include unreachable/ambiguous authored topology and query budgets. This is functional evidence for the native planner, not complete bot tactical parity or a long match assessment.

Migration requires matching `fpsloppa-cq-native-1` clients and server. Legacy Godot-RPC hosts remain available for explicit historical regression fixtures. Native profiles are stored in the server state directory; old host session state is not automatically imported. Windows, Android, WAN latency/loss, target-headset prediction and live deployment have not been validated in this change. The final desktop fixture also measures a six-second settled walking window: maximum acknowledged-state error 0.1712 m, no corrections above the 0.20 m threshold and no hard resets. The full ability/death/respawn run has larger transients; this is not a device-wide prediction guarantee.

The Jolt host is independently implemented; exact CharacterBody movement parity should not be inferred from the shared gameplay core.
