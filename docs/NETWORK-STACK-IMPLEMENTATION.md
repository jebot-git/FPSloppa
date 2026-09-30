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

## Responsiveness follow-up — 30 September 2026

Historical protocol for this section: `fpsloppa-69-responsive-combat`. This section supersedes the earlier prediction and decoded-input limits above; ENet channels and the 1,100-byte datagram budget remain in place.

- Trigger delivery now retains up to eight independently numbered presses, including the offhand and alternate trigger, with the press's aim and rendered-world timestamp. Receipt and firing outcomes are separate. Readiness buffering is 120 ms, with the existing 250 ms rocket allowance retained. Queue expiry, life changes, blocked input, weapon changes and rejected attempts cannot leave an indefinitely armed tap.
- Local shot presentation uses `(life, trigger, ordinal, hand, weapon)` identities, shared ammunition reservations and shared primary/alternate cooldowns. Accepted effects and snapshots can arrive in either order. A predicted effect suppresses only its matching echo; an unpredicted accepted effect still plays. CS physical chamber/reload checks gate prediction; only the first round of a burst is speculative. Damage, impacts and projectiles remain authoritative.
- Four recent physics commands are redundantly transmitted at 30 Hz. The server consumes at most one queued command per physics tick, acknowledges simulation rather than packet arrival, and never acknowledges an unsent future command. It holds movement when a packet has not arrived. Durable jumps are scheduled against their command sequence and recover once if their history entry is lost. Historical poses retain only gameplay tracking, including the hip tracker. Packet packing sheds optional tracking/history redundancy when necessary instead of sending an oversized command the server would discard. The bounded decoded-input allowance is now 16 KiB.
- The owner restores the acknowledged movement state and replays subsequent collision, stance, room-scale and jetpack commands at a physics boundary. Matching position, velocity, height and hidden simulation state skip replay entirely. History is capped at 180 samples and a single correction at 32 replay steps; a larger recovery resets prediction. Movement sounds are suppressed during replay. Tribes retains its existing specialized replay path. Replay uses current collision geometry and recorded water context; it does not rewind moving world geometry.
- Remote bodies interpolate at render frequency, with a monotonic playback cursor and 0.9–1.1 playback-rate adjustment as the buffer fills or drains. Buffer exhaustion still holds the last received state. Local headset/controller tracking stays immediate. The generic engine interpolation is disabled on those already-interpolated remote actors.
- Connection diagnostics include trigger expiry/overflow, playback underruns, confirmations and replays. Replay state uses a compact positional wire representation; demo capture excludes transient prediction bookkeeping and retains the established event schema.

Validation includes command loss/reordering/life changes, cadence at 60/72/90/120 Hz, exact effect deduplication and ammunition reservations, collision replay through stairs/walls/jumps/server impulses, water/crouch behavior, CS combat and gestures, tracked muzzle clearance, and demo round trips. The actual two-process rocket fixture now transmits movement history: all eight scenarios passed in both Doom and Quake, including dropped initial trigger packets, six-tick delays, moving jumps and a buffered cooldown tap. The separate UDP proxy fixture passed at 100 ms RTT, ±15 ms jitter and 2% loss; it validates hits/projectiles/cover, not the complete owner replay path.

The existing full defusal VR integration fixture could not start because this checkout lacks a compatible installed defusal arena. Its CS gestures and shoulder-stock behavior have separate passing coverage. Headless fixtures retain the existing one-instance ObjectDB shutdown warning. No real-headset or rendered GPU performance result is claimed. See [the performance follow-up](NATIVE-NETWORK-REWIND.md#responsiveness-cost-and-native-decision--30-september-2026) and [validation receipt](validation/responsiveness-2026-09-30.json).


## Cosmetic prediction and recipient replication — 30 September 2026

Historical protocol for this experiment: **`fpsloppa-70-personal-replication`**. **Recipient personalization was subsequently reverted; see the frame-time decision below.** This supersedes the shared broadcast behavior and protocol identifier above. The host/demo snapshot remains complete; each network recipient receives a filtered projection.

[Cosmetic projectile prediction](../deathmatch/network/projectile_prediction.gd) launches eligible single, uncharged projectiles immediately after the existing local shot/ammunition reservation. It covers Doom rockets/plasma and eligible Quake/UT single projectiles, including gravity-driven grenades. Charged releases, guided projectiles, multi-projectile volleys, CS physical grenades and Tribes-specific firing retain their authoritative launch paths. Each cosmetic uses the existing `(life, trigger, ordinal, hand, weapon)` identity. Spawn RPCs and snapshot ordnance carry that identity, allowing the existing node to transfer exactly once to the authoritative projectile. Position correction is bounded and decays through the existing visual correction path.

Cosmetics never enter the authoritative projectile dictionary, consume additional ammunition, apply damage, bounce, create impact decals or explode. World sweeps stop them at cover. Rejection, death, respawn, weapon changes, menus and map/disconnect cleanup remove them; a 500 ms timeout and 32-node cap bound missing-authority cases. Shared visual buffers are initialized during graphical map loading to move their cold setup cost out of first-shot handling. Demo capture strips the new transport identity and preserves its existing ordnance schema.

Network projections remove other players' core ammo/inventory, cooldowns, replay state and movement/jump/trigger acknowledgements. CS magazine and held-magazine counts, DE funds/notices/grenade quantities, and Tribes ammo/consumables/future loadouts are also withheld. Public class, equipped pack, visible reload/priming state, health, weapon, movement and objective data remain available. Spectators receive public equipment state rather than private inventory HUD data. Recipient caches survive joins/departures of other peers, preserving sequence monotonicity.

Body position/velocity records retain the normal snapshot cadence. Only remote tracked poses are reduced: normal cadence within 20 m, at most 10 Hz beyond 20 m, and at most 5 Hz beyond 40 m. Missing poses retain the last received pose; periodic complete refreshes recover loss. New lives, death transitions, tracking acquisition/loss, teleports and moving into a closer tier force a refresh. Spectators without a valid player viewpoint retain full pose cadence. Local headset/controller tracking is unaffected.

The native `FPSCodec.snapshot_records` operation batches projection, compact replay conversion, shared record encoding and control-state filtering. Identical common control/projectile datagrams are reused across recipients after exact header/record comparison. Each peer owns its cadence/control cache; the shared encoding/packet cache lasts only one snapshot. The GDScript reference path remains available with `--gdscript-network-packing`; older extensions without the method use that reference automatically.

New tests cover exact native/reference personalized packets over 90 updates, private state isolation with shared caches, tracking/life transitions, loss recovery, independent body updates, departure pruning and join sequence continuity. Cosmetic tests cover identity handoff, duplicate authority, rejection, timeout, life/weapon changes, limits, gravity and wall clearance. A real ENet client/server test confirms adoption of the same cosmetic node and authoritative removal. Final Doom/Quake ENet rocket regressions pass all eight cases per mode; codec/packing, weapon/demo, CS and movement-replay suites also pass.

See the [native cost and special-trace assessment](NATIVE-NETWORK-REWIND.md#recipient-replication-and-special-trace-assessment--30-september-2026) and [validation receipt](validation/recipient-replication-2026-09-30.json). Reproduce with:

```sh
python3 tools/native_study/validate_recipient_replication.py --godot /path/to/godot --network --bench
```

The network checks require local socket access. Native parity and special-trace probes require the rebuilt extension. Rendered/headset timing remains unmeasured.


## Frame-time priority: shared snapshots restored — 30 September 2026

Current matching-client/server protocol: **`fpsloppa-71-native-special-trace`**. Production snapshot generation once again encodes and packs **one shared snapshot**, then broadcasts the same datagrams to all peers. Per-recipient caches, private inventory projections and distance-dependent pose throttling are removed from the gameplay path. Inventory/acknowledgement fields and tracked poses are again replicated at their prior shared cadence. Cosmetic projectile prediction and its exact spawn/snapshot handoff remain enabled.

Native codec/batched record encoding and bounded packet packing remain active. The personalized GDScript implementation has moved to `tools/native_study/personal_replication_reference.gd` solely for diagnostic comparison; its native `snapshot_records` helper is not called by production replication. The retained experiment and its old validation receipt do not describe the current wire behavior.

The repeated comparison on Intel N95 measured **0.767–0.771 ms** median for shared encoding/packing, versus **4.558–4.615 ms** for the optimized personalized path (16 tracked players/recipients and 32 projectiles). Shared p95 was 0.993–1.013 ms versus personalized 5.961–6.120 ms. This restores about 3.82 ms of CPU headroom per snapshot in that fixture. Aggregate payload increases back to 65,488 bytes median versus 32,648 for personalization. This deliberately favors CPU/frame-time headroom over bandwidth; no headset frame-rate improvement is inferred from the serialization fixture.

Native special-mode tracing is now enabled by the updated extension. See [implementation and validation](NATIVE-NETWORK-REWIND.md#native-special-tracing-and-packing-rollback--30-september-2026).
