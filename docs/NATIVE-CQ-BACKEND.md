# Native CQ backend prototype

The voxelspace branch now has a server-capable `FPSBackend` GDExtension alongside the existing `FPSCodec`. This is an implementation of the first native/threaded stages in the [backend assessment](validation/voxel-battle/vps-20261013/BACKEND-THREADING.md), not a replacement physics engine or a claim of sustained 64-player support.

## Implemented paths

- Native swept anatomical hit volumes, cover-axis selection and head classification. The anatomy is initialized from the same 101 one-centimetre stance entries as the GDScript reference, including prone limbs; collision dimensions and thin-wall cover semantics are unchanged.
- Native conservative projectile target grid with stable actor order, swept movement bounds, overflow fallback and safe handling of nonfinite/extreme coordinates. Exact world/cover queries and damage still execute on the authority thread.
- A typed, time-trimmed native history ring with life serial and teleport guards, producing positions, heights and wrapped yaws together. The ring retains the existing 300-ms rewind rule, with a bounded 256-frame safety cap. Explicit fixture histories and the reference implementation remain usable.
- Native tracked-pose validation and room-scale request math. The same head/hand bounds, transform checks, optional offhand pose and height clamp are enforced. Capsule movement and scene changes remain synchronized on the authority thread.
- Native observer/target range filtering used by the 10-Hz spotting scan. LOS confirmation and shared spotted timers stay on the authority thread. Small batches remain serial because the 64-player filtering benchmark was slower with workers.
- Asynchronous snapshot encoding on a dedicated encoder thread. Frozen record batches can also use a small persistent native compute pool. Results merge in original record order; compression, delta-cache decisions and packet sizes retain the existing wire contract. RPC fanout and statistics are applied on the authority thread.
- Snapshot transmission targets admitted players, excluding transport peers still completing asset readiness.

## Thread and queue ownership

`FPSBackend` has a lazily created bounded compute pool (default four workers, maximum ten). Pure range filtering copies inputs to independent native arrays; workers write distinct output slots. Its default threshold is 8,192 pair operations. For snapshot encoding, the encoder owns a deep copy of the entire job. Compute workers only read frozen network values and produce private byte buffers; they do not access scene nodes, mutable resources, physics spaces or live gameplay dictionaries. Snapshot batches use workers from 64 records onward.

Each replication service has its own encoder and delta cache. At most two snapshot jobs may be outstanding, counting queued, running and completed jobs. Busy queues skip a submission rather than accumulating latency; later snapshots contain current state and sequence gaps are supported by the existing protocol. Completions carry a replication generation, map epoch, source clock and sequence. Reset joins the encoder and discards pending/completed work before restarting its state. Destruction joins all worker threads.

The authority polls completions each physics tick. This currently adds approximately one tick of snapshot delivery age (33.3 ms median in the 32-player test). This tradeoff must be included in client latency evaluation. Worker time, transport time, snapshot age and queue-busy counts are separate profiler fields, so asynchronous work cannot disappear from the report merely because it left the authority callback.

## Build and package

From this worktree:

```bash
python3 tools/build_gameplay_native.py --server --container -j 8
python3 tools/frontier_vps/package.py \
  --template ~/.local/share/godot/export_templates/4.7.2.stable/linux_release.x86_64 \
  --output /tmp/cq-native-release
```

The existing Ubuntu 22.04 toolchain image produces a portable Linux server library. The builder generates `fps_native.gdextension` pointing to `libfpsloppa_native.server.so` for this build. Package creation requires a current build receipt, verifies the source/library hashes and rejects GLIBC requirements newer than 2.35. The package activates FPSCodec/FPSBackend and places the loose library beside the executable at its manifest path, with a release checksum entry. TwoVoIP remains included for the current server's voice classes.

The default client native build also registers FPSBackend while retaining FPSPose. `FPS_SERVER=ON` excludes skeleton, facial and finger bindings. This separates reusable gameplay acceleration from avatar-rendering dependencies; this task validated the portable Linux server build, not Windows/Android client builds.

## Reference switches

- `--gdscript-backend`: disables native hit/grid/history/pose/range paths and async snapshots.
- `--gdscript-codec`: keeps the reference network codec; async native encoding is disabled too.
- `--gdscript-network-packing`: keeps reference packet packing and disables async snapshots.
- `--gdscript-pose-validation`: retains the branch's reference pose validation independently of other acceleration.
- `--sync-snapshots`: uses synchronous replication, retaining the selected native math/codec.
- `--native-workers 1`, `2`, `4`, etc.: selects compute workers, clamped to 1–10. One worker executes batch work serially; the dedicated snapshot encoder can still run asynchronously.

To select the entire reference backend:

```text
--gdscript-backend --gdscript-codec --gdscript-network-packing --sync-snapshots
```

If the extension is absent, normal source launches keep the GDScript paths. Frontier release packaging now deliberately requires the native server build so an intended native release cannot silently omit it.

## Reuse in the main branch

Carry over `backend.h/.cpp`, registration/build changes, runtime discovery, the explicit reference helpers, projectile grid integration, history integration and replication queue APIs as one change. Initialize anatomy from that branch's `hit_body.gd` rather than hardcoding cosmetic model proportions. Keep generation/epoch handling, bounded ownership and shutdown with the asynchronous queue. The method API takes network values, positions and primitive flags; it does not depend on jungle rendering or the class menu.

The native pose whitelist is intentionally UT99-only: it rejects full-body, eye and face tracking keys. For a VRM-enabled main branch, retain its reference validator (the independent `--gdscript-pose-validation` switch is provided) or extend the native validator and differential tests to that branch's contract before enabling it. Do not transplant this whitelist unchanged.

Import `native_backend.gd` and retain differential tests against that branch's references. Run its existing hitbox/cover, projectile, lag, room-scale, movement and network tests before enabling the paths by default. Review the additional snapshot age against its interpolation and lag-compensation policy. Package the correct platform library; a server-only extension does not supply FPSPose for a VRM-enabled client.

The room-scale fixture in this branch was updated to stop touching a retired full-body `rig.tracking` member. Its physical headset, capsule alignment, wall blocking, weapon rebasing and turn/HUD checks pass with the native math.

## Scope still requiring work

CharacterBody movement, world raycasts/casts, terrain collision and gameplay commits remain on the authority thread. Native acceleration does not parallelize these engine calls. Native full CS/Quake controller integration, parallel world queries, distance-based replication, turret-specific candidate integration and bot planning are future stages requiring measured benefit and their own correctness tests. No physics backend/thread setting was changed.

The 64-slot configuration remains explicitly unsupported. See [validation and performance results](validation/voxel-battle/native-backend-20261013/REPORT.md).

## Network service under simulation overload

Dedicated authorities now poll multiplayer on the main thread before each active physics step, in addition to the ordinary idle-frame poll. This prevents physics catch-up batches from leaving reliable ACKs unserviced for eight simulation ticks. Linux native authorities also request a 4 MiB UDP receive buffer on their own bound ENet socket. `network_receive_buffer` logs the actual before/after sizes and the operation result; the kernel can clamp the request. No system-wide settings or privileges are changed. This socket operation is independent of native simulation acceleration, but currently uses the native runtime and is therefore skipped with `--gdscript-backend`.

For controlled regressions, `--network-poll-idle-only` disables the extra physics poll and `--network-default-buffer` disables socket tuning. Keep both absent in normal deployments. `tune_udp_buffer(port, bytes)` only inspects the process's own UDP sockets and returns `available:false` when unsupported or absent. Carry the physics poll and socket tuning/logging into main together; increasing timeouts alone leaves the network starvation intact.

See [64-connection drop investigation](validation/voxel-battle/network-drops-20261014/REPORT.md). Connection capacity and sustainable simulation frequency are separate acceptance criteria.

## Collision replacement assessment

CQ now exposes CS movement exclusively; its server toggle and replicated Quake selection are retired. See [CS-only collision design and OpenNova source review](CQ-COLLISION-REWRITE.md) for a proposed complete gameplay collision service, map export, threading boundaries and benchmark gates. This is a design assessment; the existing collision backend remains active.
