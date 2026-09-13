# Networking review — 12 September 2026

**Recommendation: retain ENet and improve the replication protocol, input delivery and bandwidth scheduling.** The current evidence identifies application-level weaknesses that a different transport would inherit. A replacement becomes worthwhile if cross-platform relay/NAT traversal, authenticated encryption or transport-level traffic priorities become product requirements.

This review adds diagnostics only. It does not change the production wire protocol, deploy a server or alter gameplay. The working tree includes earlier development; the remote recording predates some of those changes.

The subsequent implementation and live validation are documented in [Networking implementation](NETWORK-STACK-IMPLEMENTATION.md). The measurements below remain the pre-change baseline.

## Evidence and scope

The [previous remote test](REMOTE-ALL-MODES-TEST.md) retained eight players and a spectator across ten modes. Its last 265 seconds showed stable server RSS (125.78–125.91 MiB), median CPU 29.9% of one core and no kernel UDP socket drops. These observations support basic stability, but do not prove delivery quality, sixteen-player VR capacity or absence of WAN loss. Demo gaps include loading transitions and must not be labelled packet loss.

The new audit re-encoded all **13,835 recorded frames** using the current Variant/FASTLZ path. Demos omit two live arguments; the audit restores a timestamp and a placeholder projectile watermark. These are reconstructed payload estimates, not a packet capture, and exclude RPC, ENet, UDP and IP overhead. Synthetic cases use 32 projectiles and either desktop players or validated moving full-body poses with fingers and face expressions. They are stress fixtures, not recordings of sixteen tracked people.

| State | Compressed median | Compressed p95 | Maximum |
|---|---:|---:|---:|
| Recorded DM, nine peers | 2,034 B | 2,552 B | 2,899 B |
| Recorded KOTH, nine peers | 1,895 B | 1,946 B | 1,995 B |
| Recorded TF, nine peers | 2,758 B | 3,947 B | 4,659 B |
| Recorded Assault, nine peers | 2,417 B | 2,521 B | 2,589 B |
| Synthetic eight full-body VR players | 6,242 B | 6,489 B | 6,518 B |
| Synthetic sixteen full-body VR players | 10,424 B | 10,670 B | 10,758 B |

Every recorded mode's median exceeded Godot's 1,392-byte MTU warning threshold. At 20 snapshots/second, the sixteen-player fixture implies approximately **208 KB/s per recipient, or 3.34 MB/s (26.7 Mbit/s) of server egress for sixteen recipients**, before protocol overhead, downloads and voice. This is an extrapolation from the fixture.

The synthetic full-body input command was **1,624 bytes before RPC overhead**. Production input is sent as a Dictionary without the snapshot's FASTLZ wrapper. Compressing that fixture would still produce about 1,290 bytes; a compact pose representation is preferable to relying only on compression.

Local serialization plus compression p95 was 23–55 microseconds for recorded modes and 122 microseconds for the sixteen-VR fixture. This small encode-only benchmark does not include snapshot construction, allocation/GC, socket delivery, client parsing or the remote CPU. It does not justify a network-thread rewrite on its own.

## Measured delivery under loss

The clean run delivered **240/240 updates at every size**. With configured 2% random datagram loss, 100 ms RTT and jitter, complete-update loss increased with payload size:

| Payload | Received | Missed updates | p95 gap between updates |
|---|---:|---:|---:|
| 1,100 B | 233/240 | 2.9% | 75.8 ms |
| 2,098 B | 229/240 | 4.6% | 69.0 ms |
| 6,255 B | 217/240 | 9.6% | 103.4 ms |
| 10,381 B | 202/240 | 15.8% | 103.5 ms |

The proxy actually dropped 93 of 4,178 observed datagrams (2.23%) across both directions, including transport traffic. The 10.4 KB case missed **15.8% of complete updates** and had a 151.8 ms maximum delivery gap despite a 50 ms send interval. This bounded result supports fragmentation reduction; it is not an estimate of loss on the public server. Different seeds and burst patterns will vary. All four role processes exited zero with no script/runtime errors; each retained a one-instance ObjectDB shutdown warning, recorded separately from transport results.

## Architecture worth keeping

`deathmatch/arena.gd` uses authoritative ENet UDP, 30 Hz client inputs and 20 Hz snapshots. Separate channels carry reliable control, snapshots, input, effects, VRM downloads, map downloads and Opus voice. Maps/models have hashes, bounded chunks, acknowledgements and download-before-spawn checks. Disk work already runs through `deathmatch/network/disk_worker.gd`; scene/RPC callbacks remain on the main thread.

Channels isolate ordering dependencies, but all still share the connection and physical link. The pinned Godot 4.7.2 implementation sets `UNRELIABLE_FRAGMENT` for ordered-unreliable traffic: large snapshots normally become multiple **unreliable** fragments, not a reliable retransmission stream. Losing a required fragment prevents reconstruction of that update. Merely changing the RPC to reliable would add stale-state queuing. Sources: [Godot channels](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), [pinned peer implementation](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/enet/enet_multiplayer_peer.cpp), [pinned ENet fragmentation](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/thirdparty/enet/peer.c).

## Prioritized improvements

1. **Reduce and partition replication.** `_send_snapshot()` broadcasts full player rows, inventory, scores, poses, projectiles, objectives, pickups and every player's input acknowledgement to everyone. Introduce a versioned binary schema with quantized relative positions, compact rotations and optional pose fields. Send slow-changing state on change, with reconnect/resync support. Partition motion/pose/projectile updates into independently applicable batches with entity sequence numbers; initially target roughly 1,000–1,200 application bytes per datagram and verify actual wire sizes. Splitting a large snapshot and still requiring every chunk would retain the same loss problem. Add acknowledged delta baselines only after a robust full-state recovery path exists; never delta against a snapshot whose delivery is unknown. [Snapshot compression design](https://gafferongames.com/post/snapshot_compression/).

2. **Make input edges survive loss.** `pending_network_jump` clears immediately after sending one ordered-unreliable command. A lost command can therefore omit an entire jump even though the local prediction already jumped. Send a small redundant history of commands/events, deduplicate by sequence on the server, and acknowledge consumption. Separate the compact gameplay command from larger tracker data so pose fragmentation cannot discard movement intent. Preserve manual press/release semantics, swimming hold behaviour and physical-action cooldowns. Server validation must bound history length, command age, sequence advance and per-peer processing rate; do not simulate arbitrary client-supplied elapsed time.

3. **Improve interpolation and reconciliation.** Remote players currently lerp toward the latest target with `delta * 16`; there is no timestamped jitter buffer. Use a bounded, measured interpolation delay with per-entity snapshots and limited extrapolation. Tie lag-compensation view time to the actual rendered sample. Local prediction already compares against the acknowledged historical state, which is useful, but stores states rather than replayable input/delta history. Evaluate full input replay for collision/impulse accuracy after command delivery is reliable. Test stairs, water, elevators, room-scale movement and rocket jumps together. A render buffer trades some latency for stable motion; it should not delay local headset tracking. [Interpolation design](https://gafferongames.com/post/snapshot_interpolation/).

4. **Give bulk transfers a shared bandwidth budget.** Map and avatar services each allow 2 MiB/s and 256 KiB outstanding windows. Their aggregate allowance can reach 4 MiB/s, independently of gameplay and voice. Use common server and per-peer pacing with gameplay/control reservation, fair download scheduling and limits that react to queue age/RTT. A hash-verified HTTPS asset mirror is an optional next step. It would offload downloads; a conventional HTTP CDN would not relay ENet gameplay. Proximity voice currently fans out to all players; consider distance-based recipient selection with hysteresis while preserving team radio and spectator rules.

5. **Measure delivery and admission explicitly.** Existing join-stage logs, input ages and ENet RTT/loss fields are useful. Add snapshot sequence gaps, delivered sample age, jitter, payload histograms, bytes/second by channel, outstanding download bytes, correction distance and command-edge acknowledgement delay. Aggregate periodically instead of logging each pose or voice packet. ENet's loss statistic and kernel socket drops are not substitutes for application snapshot delivery counts. Join handling currently selects one resolved address; add bounded IPv4/IPv6 fallback and distinguish DNS, transport, protocol, full-server and asset timeout failures. Current evidence does not attribute historical rejected connections to the hosting provider.

RCON already uses nonce/HMAC authentication and defaults to loopback, but is not encrypted. Keep remote administration behind the existing SSH tunnel. Gameplay/voice transport encryption can be evaluated separately: [ENetConnection exposes DTLS configuration](https://docs.godotengine.org/en/stable/classes/class_enetconnection.html), although certificate provisioning and integration still require work. Avoid exposing detailed addresses, credentials, voice content or tracking poses in routine telemetry.

## Replacement options

| Option | Benefit | Suitability here |
|---|---|---|
| Existing ENet + revised application protocol | Preserves working desktop/Quest/dedicated integration; directly addresses measured packet size and input issues | Recommended first |
| Valve GameNetworkingSockets | Encryption, connection statistics, unreliable/reliable UDP and prioritized lanes; NAT traversal facilities | Best candidate for a bounded replacement prototype if those features become required. It does not provide entity compression/deltas, and the open-source library does not automatically supply Steam's relay/auth services. Verify Windows, Linux, Android and console-only packaging before adoption. [Official project](https://github.com/ValveSoftware/GameNetworkingSockets) |
| GodotSteam MultiplayerPeer | Godot integration with Steam networking | Potential optional desktop transport. Its advertised Windows/Linux/macOS support does not establish Quest support. The GitHub repository moved to Codeberg; do not mistake the archived mirror for the current development location. Codeberg could not be inspected through the research tool. [Maintainer's repository notice](https://github.com/GodotSteam/MultiplayerPeer) |
| WebRTC | Data channels and a path toward browser clients/NAT traversal | Requires signaling and potentially TURN infrastructure, plus native extension packaging for this game's native clients. Adds integration work without fixing large state or prediction. [Godot peer](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html), [official native extension](https://github.com/godotengine/webrtc-native) |
| TCP/WebSockets or bespoke raw UDP | TCP simplifies reliable transfer; raw UDP provides full control | No demonstrated benefit for the current shooter. Reliable ordered motion delivery can wait behind loss; bespoke UDP would require rebuilding connection/reliability/fragmentation safeguards. Retain reliable transports for appropriate control/download tasks. |

## Validation before changing the production protocol

Keep today's fixtures as the baseline. Test 8 and 16 actual clients, including realistic VR pose streams, at 20/60/100/150 ms RTT, jitter, 1/2/5% loss, asymmetric links and bandwidth caps. Include simultaneous map/model transfers and voice, late joins, map switches, capacity rejection and reconnects. Track CPU p95, egress, update gaps, input-edge loss and correction distance. Use protocol-version rejection for incompatible clients and test malformed/truncated compact packets and missing delta baselines.

The local transport probe isolates packet fragmentation using a real `ENetMultiplayerPeer`, ordered-unreliable channel 1, four payload sizes at 20 Hz and 240 updates per size. It uses the existing deterministic UDP proxy (seed 4817), once clean and once at 100 ms RTT, ±10 ms jitter per direction and 2% random datagram loss with occasional duplicates. Payloads include a 16-byte diagnostic header, not the production RPC envelope. It does not simulate congestion, real Wi-Fi burst loss, rendering or sixteen concurrent clients. Detailed results are in [structured validation](validation/network-stack-review.json).

Reproduce from the repository root:

```sh
XDG_DATA_HOME=/tmp/fpsloppa-network-study godot --headless --xr-mode off --path . --script res://tools/network_study/snapshot_audit.gd
python3 tools/network_study/transport_probe.py
```

The first command requires the retained remote demo. The second requires its generated payload files and free loopback UDP ports 27787–27789. Raw evidence is under `test-results/network-study/`. Both probe roles are bounded and cleaned up by the runner; the production server is untouched.
