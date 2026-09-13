# Networking implementation and validation — 12 September 2026

The application protocol has been upgraded while retaining Godot ENet. The implementation follows the [networking review](NETWORK-STACK-REVIEW.md): partition replication, protect input edges, add timestamped interpolation, pace bulk transfers, then improve diagnostics and address fallback. Clients and servers must both use **`fpsloppa-34-partitioned-state`**. Older protocols receive the existing version-mismatch rejection.

## Changes

1. **Independent state records.** Player motion, compact tracked poses, projectiles and world state are batched into application packets of at most 1,100 bytes. Each entity/control record has a sequence and map epoch. A missing packet leaves other entities usable; there is no requirement to assemble all pieces of a snapshot. Membership tombstones reject stale departed entities and prune cached histories. Unchanged control state refreshes at least once per second and immediately after admission. Oversized individual mode records use separate reliable channel 7. Normal updates use unordered unreliable channel 1 with per-record ordering.

   Player records use a bounded binary codec, float32 positions and normalized int16 quaternion components. Sparse world state uses Godot's native value encoding, with object deserialization disabled. Quantization applies to rotations; positions are not reduced to a coarse map grid. The existing gameplay snapshot interface and demo format remain in use. Receivers get copies because TF processing rebases timers in mode dictionaries.

2. **Jump delivery.** A new press is numbered, repeated until acknowledged, deduplicated by the server, and expires locally after 250 ms. Spawn/teleport serials prevent replay across lives. Sampling every physics tick preserves brief physical/button presses between 30 Hz input transmissions. Holding jump still swims upward; ordinary jumping still requires a new press. Frozen/dead/spectator actions cannot accumulate jumps for later playback. Normal input packets use the compact codec, a 1,100-byte packet bound, an 8 KiB decoded bound and a per-peer decode rate limit. The older command RPC remains for existing diagnostic fixtures; removing that compatibility entry point is a separate hardening task.

3. **Remote interpolation and prediction diagnostics.** Remote bodies keep at most twelve timestamped samples with a measured 75–150 ms delay. Teleports and respawns reset their history. Missing data holds the latest known position instead of projecting through walls. The lag-compensation view timestamp cannot advance beyond received state. Local headset/controller tracking is not buffered. Existing acknowledged historical-state prediction remains enabled; this change does **not** implement deterministic input replay.

4. **Shared map/model pacing.** Both services use one 4 MiB/s scheduler—the former combined ceiling—with gameplay and voice charged first. A peer is capped at 1 MiB/s and receives a share based on active downloaders. Increasing RTT reduces its download rate. The combined outstanding window is 64 KiB, including disk reads in flight; partial grants respect its remaining space. Disk/metadata work remains on the existing worker. Verified BSP/VRM files and downloaded map scene caches are published through a sibling temporary file and rename, preventing readers from opening a partially copied canonical cache entry.

5. **Admission and telemetry.** Five-second summaries include replication byte/packet totals, sequence gaps, interpolation delay, arrival age, prediction corrections and bulk-transfer counters. Map loading tells connected clients to pause command transmission before the synchronous server load, avoiding a burst of obsolete commands during that pause. Hostname resolution keeps up to four valid addresses and tries alternatives within one bounded connection deadline. Successful transport or cancellation clears pending alternatives. It uses Godot's [queued multiple-address resolver](https://docs.godotengine.org/en/stable/classes/class_ip.html#class-ip-method-get-resolve-item-addresses); no synchronous DNS was added to the frame loop.

The console package also excludes client surface/atmosphere rendering scripts and avoids eagerly loading client-only filtering/death-pose resources. TF player defaults are initialized before the first class snapshot, fixing an admission-time AI lookup of a missing `tf_class` key.

## Validation

The authorized remote machine ran an isolated console test server on UDP 7777. **Sixteen actual Godot clients** stayed connected through DM, TDM, CTF, KOTH, IG, IF, FT, CC, TF and Assault. This was fifteen bot-controlled clients plus one recording spectator; seven clients supplied synthetic full-body/finger/face poses. TF used Quake rules and Assault used UT99 rules. Each mode ran for 20 seconds after admission, or 35 seconds for TF/Assault, without a lobby transition. All sixteen processes exited zero with no client runtime errors. This is a transport/mechanics regression, not a balance assessment or a live-headset test.

The spectator recorded **5,582 valid frames over 262 seconds**, covering all ten modes and sixteen peers. Two additional clients with empty caches downloaded TF assets and entered the match after approximately **24.2 and 41.5 seconds**, receiving different totals of 21.2 and 38.1 MB. The seventeenth-client rejection was checked during the preceding full-capacity run. The test server and monitor were stopped afterwards; UDP 7777 was confirmed closed.

Local regression coverage includes:

- Packet bounds, malformed headers, Unicode, pose precision, loss/reordering, stale epochs, membership removal and late packet recovery.
- Lost jump press/release, acknowledgements, expiry, respawn protection, swimming hold, interpolation bounds, bandwidth fairness, queue limits and concurrent atomic publication.
- Local prediction, Q3 movement, stairs, water, physical crouch/swimming, movement timing and melee.
- ENet shooting/respawn/spectating; CTF/KOTH/TDM state; TF physical actions; crouch/prone replication; Frigate objectives; voice and team radio/chat routing.
- Weapon-wall clearance and close-floor rocket jumping; UT99/Assault and Quake/TF weapon variants.
- A real 14.2 MB VRM upload, server relay, validation and cache rejoin; BSP download/validation with two clients; queued DNS, alternate-address admission and cancellation.
- Combat at 100 ms RTT, ±10 ms jitter and 2% configured datagram loss: pistol 7/7, rail 3/3, plasma 12/12 and rocket 7/7 fixture hits, with cover protection checks passing. These controlled hit counts are regression assertions, not public-match accuracy predictions.

The final client-only address fallback and interpolation timestamp clamp were checked after the full-capacity run; the clamp also passed the impaired-network combat test. The later strict accounting of in-flight download reads passed the queue tests and repeated local map/VRM transfers. The console package was rebuilt after these changes. The full-capacity server pack was `d9a5d6c75ac2817b5319d2c74cf2ddf28b1cdb3590b46dec26c6fba4d75ba7a7`; the cold-download run used its subsequent revision. Build hashes and results are retained in [structured validation](validation/network-stack-upgrade.json).

## Measurements and limits

| Synthetic state | Old aggregate median | New aggregate median | New largest routine packet | New encode p95 |
|---|---:|---:|---:|---:|
| Eight desktop players | 2,080 B | 1,616 B | 1,100 B | 0.785 ms |
| Sixteen desktop players | 2,548 B | 1,988 B | 1,098 B | 1.020 ms |
| Eight full-body VR players | 6,242 B | 5,093 B | 1,100 B | 1.253 ms |
| Sixteen full-body VR players | 10,424 B | 9,090 B | 1,098 B | 2.035 ms |

These are compressed application payloads, excluding transport overhead. The sixteen-VR fixture saves about 13% of aggregate bytes and avoids one large fragmented motion update. Its encoder is **more expensive** than the former single native serialization/compression operation (old p95 0.122 ms). A first all-custom implementation cost 4.495 ms p95; native encoding of sparse records reduced that to 2.035 ms. This is a delivery/recovery improvement with an explicit CPU cost, not a claim that every networking operation is faster.

During 266 seconds sampled at full capacity, server CPU median was **62.8% of one core**, p95 72.7%; RSS ranged **116.6–128.9 MiB** across maps. There were five threads, normally seven open descriptors, and zero reported orphan nodes. Sampled physics time was 16.38 ms median and 21.47 ms p95, so the server still needs CPU headroom. A 148 ms process sample confirms that synchronous map changes can still hitch.

The final run recorded **zero kernel UDP socket drops**, versus 109 during the initial implementation run, concentrated at map changes. Scenes and schedules differ, so this is supporting evidence for the command pause, not a controlled transport-speed comparison. The observer's measured interpolation delay was 84.7 ms median and 93.2 ms p95. Application sequence gaps remain measurable and must not be equated with raw WAN packet loss.

The live run sent 29,185 batches in the sampled interval, including **80 oversized records**, maximum 1,439 bytes, on the separate reliable path. Large TF/objective records should be subdivided further if their frequency grows. There are no acknowledged delta baselines or visibility-based replication yet. Sixteen synthetic full-body players still imply roughly 2.9 MB/s of state egress to sixteen recipients before overhead.

Further work should prioritize profiling snapshot construction and TF/objective records, followed by deterministic prediction replay with collision/impulse fixtures. Owner-only inventory/acknowledgements, reduced distant pose rates, more detailed channel/queue telemetry, sustained capped/burst-loss tests and IPv6 WAN tests remain useful follow-ups. HTTPS asset mirrors, relay services and DTLS were not introduced. No transport replacement is needed to benefit from the changes delivered here.

Several headless test tools retain a one-instance ObjectDB shutdown warning; no leak-free claim is made from this short run. Earlier diagnostic runs also exposed mismatched evolving assets, the shared-cache failure and a test harness that copied rendering caches into a full `/tmp`. Frozen inputs, atomic writes and smaller isolated test assets addressed those failures. One malformed line from an older client journal was excluded before selecting the final session. No new Android or real-headset validation was performed.

## Reproduction and artifacts

Run `python3 tools/network_study/validate_upgrade.py unit` and `... network` for the bounded local fixtures. Use `--case weapon_variants_network --variant quake` for the second ruleset. `tools/network_study/upgrade_sizes.gd` needs the retained review payloads/demos. Remote runners intentionally target the authorized staging host and require its test configuration and SSH RCON tunnel; they are not production deployment scripts.

Raw evidence is under `test-results/network-upgrade/`, with the final demo in `remote/match.fpsdemo`. The console-only build is `Builds/NetworkTestServer/FPSloppaServer.x86_64` plus its matching PCK/assets. No release was committed, pushed or published by this task.
