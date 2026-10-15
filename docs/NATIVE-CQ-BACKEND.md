# Native CQ backend prototype

The voxelspace branch has both the incremental `FPSBackend` acceleration and an opt-in resident `FPSAuthority` CQ implementation. The resident path now owns the CQ gameplay pipeline; see the [current authority contract](../tools/authority_core/README.md) and [completed CQ/VPS validation](validation/voxel-battle/resident-cq-complete-20261014/REPORT.md). The incremental-path descriptions below record the earlier architecture. The live service has not been switched, and 64-player support remains experimental.

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
- `--gdscript-snapshot-preparation`: retains the original snapshot assembly,
  CQ class/reload projection and record submission while keeping the other
  native simulation and codec paths enabled. Use this for snapshot-only A/B runs.
- `--native-snapshot-rows`: experimental C++ scene-property reader. Thin
  GDScript sampling is faster locally, so this reader is not the default.

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

## Earlier incremental backend scope

For the incremental backend, CharacterBody movement, world raycasts/casts, terrain collision and gameplay commits remain on the authority thread. The later resident authority implements CS controller rules, terrain queries, turret gameplay and prototype bot decisions in C++, retaining Jolt scene operations on the owner thread. Quake movement is outside the CQ contract. Parallel world queries and distance-based replication remain optional investigations requiring measured benefit and their own correctness tests.

The 64-slot configuration remains explicitly unsupported. See [validation and performance results](validation/voxel-battle/native-backend-20261013/REPORT.md).

## Network service under simulation overload

Dedicated authorities now poll multiplayer on the main thread before each active physics step, in addition to the ordinary idle-frame poll. This prevents physics catch-up batches from leaving reliable ACKs unserviced for eight simulation ticks. Linux native authorities also request a 4 MiB UDP receive buffer on their own bound ENet socket. `network_receive_buffer` logs the actual before/after sizes and the operation result; the kernel can clamp the request. No system-wide settings or privileges are changed. This socket operation is independent of native simulation acceleration, but currently uses the native runtime and is therefore skipped with `--gdscript-backend`.

For controlled regressions, `--network-poll-idle-only` disables the extra physics poll and `--network-default-buffer` disables socket tuning. Keep both absent in normal deployments. `tune_udp_buffer(port, bytes)` only inspects the process's own UDP sockets and returns `available:false` when unsupported or absent. Carry the physics poll and socket tuning/logging into main together; increasing timeouts alone leaves the network starvation intact.

See [64-connection drop investigation](validation/voxel-battle/network-drops-20261014/REPORT.md). Connection capacity and sustainable simulation frequency are separate acceptance criteria.

## Snapshot preparation rewrite

Snapshot encoding was already native and asynchronous; its input preparation
still ran on the authority. The default dedicated path now samples scene state
on the authority and passes one complete snapshot to `submit_snapshot_state`.
That method validates the envelope, checks the existing two-job limit, and
deep-copies the capture once before returning. It does not give a worker live
nodes, mutable actor state or unowned dictionaries.

For ordinary dedicated CQ replication, `match.snapshot()` captures the five
class/reload/spot/lock/charge source dictionaries as internal metadata instead
of constructing and copying every `cp:` record first. After freezing, the encoder
projects the existing public class and reload fields in C++, expands the record
layout and encodes/compresses the records. Projection references only the
encoder-owned frozen values. The internal source metadata is removed before
record encoding and membership enumeration; it is never a network field.

The packet codec, independent record layout, ordering, delta refresh policy,
sequence and epoch rules, RPC channels and packet budget are unchanged. No
protocol bump or client update is required for this server optimization. Queue
completion age remains visible alongside worker time; moving work off the
authority must not conceal added encoding time or backpressure.

Listen servers, recording/automatic recording, district gateways, synchronous
replication and explicit reference mode retain complete public snapshots.
Recording is checked before capture so deferred metadata cannot be written to a
demo. The new network fixture verifies captured class records and absence of
internal metadata; it does not establish compatibility of the legacy demo
playback validator with every CQ/jetpack field.

`prepare_class_records` also supplies a native public snapshot projection when
deferral is unavailable. Its default clones mutable children, preserving the
existing snapshot ownership contract. The unused clone of all class states that
was immediately erased from the common CQ snapshot is avoided on the new path.

`snapshot_preparation.cpp` contains both the pure data projection and the optional
scene reader. The latter and snapshot submission reject calls from a thread
other than the backend's owner. The encoder's `snapshot_records` method touches
only frozen network data. The original record-array submission API remains
available for reference mode and existing callers.

Tests include exact full-state, record and packet-byte comparisons, producer
mutation immediately after submission, ACK life resets, physical magazine
fields, ordnance, movers, queue bounds, malformed deferred inputs, owner-thread
guards and a real dedicated-server/client exchange. Run:

```sh
godot --headless --xr-mode off --path . --script deathmatch/tests/snapshot_preparation.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/native_backend.gd
```

Run `snapshot_network.gd -- server` and `-- client` in separate processes on
test UDP 28820. Both tests are included in the deployable collision/runtime
regression bundle. Reuse in main requires the generic native queue/layout code;
the internal CQ class-source capture is needed only if that branch carries the
same class/reload schema. Preserve its ownership checks and reference switch.

## Collision replacement assessment

CQ now exposes CS movement exclusively; its server toggle and replicated Quake selection are retired. See [CS-only collision design and OpenNova source review](CQ-COLLISION-REWRITE.md) for a proposed complete gameplay collision service, map export, threading boundaries and benchmark gates. This is a design assessment; the existing collision backend remains active.

Measured results, packet equivalence, regression evidence and the rejected compact
capture experiment are recorded in the [snapshot preparation report](validation/voxel-battle/snapshot-preparation-20261014/REPORT.html).

### Opt-in player-state / input / fanout experiments

The next authority migration is available as an ordered comparison suite in
[tools/player_simulation/README.md](../tools/player_simulation/README.md).
The new `player_simulation.cpp` owns a per-arena persistent roster, typed timer
fields, event consumption and the scalar input projection. Its commits remain at
the existing player iteration points; script-side combat/reloads continue to be
imported before timer advancement. This intentionally preserves serial gameplay
ordering while migration is incomplete. It is not a second physics simulation.

`--native-player-state`, `--native-input-state`, `--native-snapshot-fanout` and
`--native-snapshot-buffers` are independent experimental switches, all off by
default. The fanout retains normal/large RPC channels and admission filtering.
The immutable snapshot handoff retains bounded queuing and reconstructs private
Godot containers on the encoder, with a deep-copy fallback for typed containers.
Full packet/state differential and real ENet tests accompany both paths. The
prepared Jolt bundle includes the authority runner; use `--authority-experiments`
for its complete gameplay regression run.

The [14 October authority experiment report](validation/voxel-battle/authority-rewrite-20261014/REPORT.md)
records 23 passed prepared regression stages and ten passed local 32/64-client
smoke cases. These short runs do not establish sustained VPS performance gains;
all new switches remain off by default.

The [full VPS comparison](validation/voxel-battle/authority-rewrite-vps-20261014/REPORT.md)
passed all ten 120-second cases with the production service suspended, then
verified restoration through public client admission/snapshots. The cumulative
buffer stage achieved 28.90 Hz at 64 clients versus 28.35 Hz for the reference;
none sustained 30 Hz under fine attribution. Small native bookkeeping/input/
fanout ports did not demonstrate a throughput benefit. All switches remain
experimental and off by default pending isolated, repeated comparisons.

## Resident authority rewrite (separate test host)

The selected larger migration keeps Godot transport and scene integration while moving authority into a host-independent resident C++ core. The implementation and reproduction instructions are in [tools/authority_core/README.md](../tools/authority_core/README.md). Unlike the earlier Dictionary helpers, this path retains typed simulation state and advances the roster through one native tick boundary.

The initial infantry-only fixture has been superseded by the [complete resident CQ implementation](validation/voxel-battle/resident-cq-complete-20261014/REPORT.md), including tracked reloads/poses, classes, abilities, vehicles, CQ scoring and integration with actual client admission/prediction/presentation. Both ends require protocol `fpsloppa-cq-frontier-18-resident1`. Enable the dedicated server explicitly with `--cq-native-authority`; production defaults remain unchanged.

## Pre-live native-port assessment — 14 October 2026

No additional native gameplay port is identified as a prerequisite for a controlled, human-only, monolithic CQ live test at the supported 32-slot ceiling. The resident core owns persistent typed state and bypasses the legacy script simulation/history/snapshot loops. Godot admission, asset transfer, votes, scene lifecycle and client presentation are intentional host responsibilities. Jolt movement/collision and authored navigation already execute through engine APIs; another language wrapper would not remove their engine cost.

The remaining optimization targets are movement/Jolt and the script adapter's compression/RPC fanout. In the recorded 32-player normal VPS case these averaged 1.6831 ms and a 0.8914 ms residual respectively, with callback p95 5.147 ms against a 33.33 ms simulation interval. The residual is not a measured transport-only scope. Attribute compression, payload slicing, per-peer enqueue and work outside the callback before proposing a further port. At 64 stress clients the callback p95 was 16.375 ms, but this loopback synthetic workload does not establish supported WAN or lethal-match capacity.

Remaining deployment gates are integration validation rather than missing C++ kernels:

- Stage matching client/server protocol and a source-matched portable server extension; explicitly enable resident authority and disable the lobby (`sv_lobby 0`). Keep an isolated test endpoint and rollback package.
- Produce and audit the intended platform client artifacts. This checkout passes `require_build('linux', server=True)` and the GLIBC 2.35 ceiling, but `require_build` fails for Linux, Windows and Android client targets because a library or its receipt is absent. The tested Linux headless clients use the installed server-profile extension; they do not validate distributable client libraries or device builds. This is build/package verification work, not evidence of a missing gameplay port.
- Exercise rendered desktop/headset prediction, physical reloads, room-scale movement and frame assembly over WAN, including packet loss, late join and reconnect.
- Run a lethal mixed infantry/vehicle round through incapacity/revive, destruction, CQ victory/restart and map rebuild. Existing deterministic/functional coverage and upward-firing load peers do not replace that round.
- Keep bots disabled for the first human trial. The native planner is a prototype, not legacy AI parity; the four-bot smoke proves navigation displacement, not populated combat/capture reliability or capacity. Validate those separately before enabling bot fill.

District workers, waiting lobbies, legacy non-CQ modes, VRMs and full-body/face tracking are outside this branch's resident CQ contract. They require separate migration only if the live test is expanded to include them. Additional small bookkeeping ports and twelve-core parallelization are not prerequisites for this trial.

Fresh local assessment checks passed: 909,456 standalone checks; 592 Jolt adapter, 16,817 VR/reload, 15,506 terrain and 603 entity checks; a ten-second 32-client tracked jungle smoke; actual headless desktop/tracked arena admission and presentation integration; and a four-bot/600-tick authored-navigation smoke. Both arena clients fired 17 shots and passed the tested death/respawn, team, grenade, NVG and jetpack paths. The bot smoke recorded 91.67 m maximum displacement and seven maximum current-life shots, retaining 19 authored-navmesh warnings. This does not establish reliable bot capture/combat behavior. Test outputs are under `/tmp/cq-port-audit-20261014` and `/tmp/cq-port-audit-arena-20261014`. Local suites overlapped, so their timings are not used as performance evidence. No live service was contacted or changed during this assessment.


## VR interaction port continuation — 14 October 2026

The previous live-test feedback is implemented in the current worktree. The
resident authority now consumes authored CQ muzzle/reload anchors and typed
CS-style recoil state. Local tracked hands, headset-relative equipment,
chest/hip grip holsters, physical reload affordances, virtual stock, persistent
optic zoom, use/boarding routing, static-building streaming, tank visual origins,
coloured names and ambience-only audio are integrated. Human admission includes
class/skin/loadout and calibration confirmation before authoritative deployment.
The calibration submenu contains a separate local avatar/controller preview.

The VR-interaction continuation used protocol `fpsloppa-cq-frontier-19-vr-interactions`. The deployed
64-slot resident1 session is unchanged by this code continuation. See the
[host/control contract](../tools/authority_core/README.md) and
[validation report](validation/voxel-battle/vr-interactions-20261014/REPORT.md).

The subsequent allied-transport continuation requires paired client/server
protocol `fpsloppa-cq-frontier-20-transports`. It adds four six-pod unarmed carriers,
with native allied admission, driver handover, passenger tracking and jump exits.
This candidate is also undeployed. See the
[transport report](validation/voxel-battle/ground-transport-20261014/REPORT.md).

NVG exposure and proximity equipment cues were revised on 14 October 2026. Native C++ retains direct-source gameplay glare; bounded GPU spots handle transient flashes. The client uses existing accepted state for quiet NVG/cloak cues. See [validation](validation/voxel-battle/nvg-exposure-20261014/REPORT.md).

The subsequent squad/deployment candidate requires `fpsloppa-cq-frontier-21-squads`. Native CQ enforces four squads of eight per team, explicit safe POI/buddy deployment and transport passenger allocation. A clickable tactical map displays ownership and squad positions; single/double radio press selects squad/team. This candidate is undeployed. See [validation and remaining live checks](validation/voxel-battle/squads-deployment-20261014/REPORT.md).
