# Native client completion plan — 2026-10-16

Current status (2026-10-16): **the standalone CQ server is native; the full client migration is not complete**. Implemented client portions include wire protocols, snapshot projection/interpolation/application, reconciliation, roster/session state, connection/profile/asset-transfer services, bounded avatar input, and now two-hand/stock/swim interaction state, throw preview sweeps and weather/lightning sampling. Retained script scene adapters are still substantial. The phase estimates below are the original audit, followed by delivery evidence; they are not a completion claim.


The CQ authority is already a standalone C++ application (ENet/Jolt, no Godot runtime). The client has native transport, codec, movement, terrain selection, destruction kernels, pose solving, avatar animation and audio kernels, but substantial scene and gameplay orchestration remains in GDScript. This plan completes the client runtime port while keeping Godot's native renderer, OpenXR, resource system and editor. It does not propose another standalone client engine.

This is preparation, not a claim that the remaining port has been implemented. Snapshot compression/relevance changes already in the working tree remain independent. Their successful capacity measurements do not measure client rendering or justify a projected client speedup.

## What benefits from staying in GDScript

| Retained area | Benefit and boundary | Expected performance benefit from porting it |
| --- | --- | --- |
| Menu layout, settings panels, loadout view, bindings editor, avatar picker, calibration page | Fast scene iteration, Control signals, theme/localisation support and inspector access. Present immutable native view state and send commands. Move gameplay decisions, filesystem/network operations and repeated entity polling out. | Usually small; measure open-menu time before prioritising. |
| Scene bootstrap and thin native capability selectors | Godot scene/resource wiring is useful, provided native runtime owns ticks and signals. Production must fail visibly if a required native service is missing. | Small if called once; wrappers must not marshal every entity every frame. |
| Offline map/weapon baking, editor import tools, capture/validation scripts | Tool development speed and readable test oracles. Keep shipped import validation native when processing untrusted/runtime assets. | No gameplay frame benefit for offline-only code. |
| Tests and reference implementations | Differential testing and protocol compatibility. Keep reference implementations outside the production execution path after parity. | No production cost when excluded or disabled. |

The inventory currently recommends retaining 27 UI scripts, 7 existing native adapter scripts, and 786 test/tool scripts, with 288 scripts nominated for native extraction and 48 legacy scripts requiring retirement/shared-code review. These are static classifications across `deathmatch/` and `tools/`, not active CQ counts, completion percentages or CPU shares. Mixed UI files still need extraction; a retained filename is not permission to leave game logic there. Some scripts classified as tools are preview fixtures. Do not ship their runtime dependencies accidentally.

Regenerate the per-file inventory with:

```bash
python3 tools/native_port/inventory.py
```

[The inventory](native-port-inventory.json) records phase, recommendation, line count, literal dependencies, hot callbacks, and conservative static reachability from the normal entry scene and CQ class scene. It follows inheritance/resource literals, including legacy branches. Dynamic loads and resources chosen at runtime require runtime tracing before deletion. No script is safe to delete solely because this scan cannot reach it.

## Port order and effort

Engineering estimates below assume one engineer familiar with this repository, current functionality retained, Linux desktop and VR parity checked, and no redesign. They are estimates, not measurements or delivery commitments. Android/Windows device QA and unknown native API gaps may extend them.

| Phase | Concrete source boundaries | Native destination and result | Estimate |
| --- | --- | --- | --- |
| P1: protocol and client state | `deathmatch/native/authority_protocol.gd`, `cq_presentation.gd`, client half of `cq_authority.gd`, session half of `standalone_client.gd`; active `network/` bridges | Extend `FPSNativeClient` with validated CQA3 parsing and typed frame storage. Add native entity state/application. Eliminate rebuilding legacy snapshot arrays and dictionaries per player. Keep old decoder as test oracle. | 2–3 engineer weeks |
| P2: VR interaction | `deathmatch/vr/rig.gd`, hand input, CQ hands/utility, physical actions, reload, swimming, stock, scopes, vehicle controls; haptics dispatch | Extend `FPSPose`; add native interaction state machine. One tracked sample and one command/output batch per frame. Native body-basis/calibration pose helper reusable by the retained calibration page. | 3–5 weeks |
| P3: entities, presentation and assets | `arena.gd`, `fighter.gd`, active conquest classes/vehicles, avatar lifecycle/cache/import, audio/voice orchestration | Native client session/entity registry owns lifecycle, prediction/reconciliation dispatch, equipment, markers, weapon/projectile FX, cue routing and voice state. Extend existing `FPSMovement`, `FPSAvatar`, `FPSAudio`; native bounded avatar import service. UI receives changed view data. | 4–7 weeks |
| P4: world/environment | Runtime scripts in `tools/voxel_battle/` and `tools/streamed_heightfield/`, map loaders used by CQ | Extend `FPSWorld` and `FPSDestruction` to own streaming schedules, instance commits, vegetation, water/weather/day-cycle presentation and collapse effects. Cook static placements and rubble offline. No physics or renderer calls from arbitrary workers. | 3–5 weeks |
| P5: launcher and services | Launcher installer/updater/store/lease/process, asset download/cache, settings persistence, directory/DNS, voice device settings | Native service APIs for bounded downloads, hashes, path validation, atomic install/rollback, settings and subprocess lifetime. Keep launcher/menu widgets scripted. Audit shared asset/avatar paths rather than duplicate services. | 2–4 weeks |
| P6: production boundary and legacy cleanup | Remaining wrappers/fallback switches, mixed inherited server/mode code, capability receipts/export validation | Require native runtime in release. Retire unused CQ Godot hosts and bot/worker simulation routes only after proving no supported caller. Preserve other modes separately until explicitly scoped in. Test exported packages for accidental scripted simulation fallback. | 2–3 weeks |

Total: approximately **16–27 engineer weeks**, including phase-specific parity work; allow a further **2–4 weeks** for integrated cross-platform/device acceptance. These ranges overlap in responsibilities and must be refined after P1 profiling and extraction. This is a CQ-client estimate. Porting every historical gamemode, district worker and obsolete host is a separate unestimated scope; their code must not be silently called “already native”. The supported CQ server bot simulation belongs to the standalone authority; old GDScript bot modules are legacy/reference paths, not evidence that the native server runs GDScript.

## P1 implementation contract

1. Move the CQA3 parser from `authority_protocol.gd` into a reusable C++ frame decoder adjacent to the existing wire/delta implementation. Validate lengths, entity bounds, enums, finite transforms and version before publishing a frame. Parse complete frames after delta recovery; never publish partially assembled state.
2. Keep wire decoding, ACK baselines and compression owned by `FPSNativeClient`. Feed a typed immutable frame to a native client-state service. Avoid decode → Dictionary → legacy snapshot → Dictionary conversion. A dictionary projection is permitted only for compatibility tests and low-rate UI views.
3. Store player/entity IDs, life IDs, epoch and sequence explicitly. Reset interpolation, caches and pending effects on map epoch, reconnect and life changes. Preserve local-only/full physical state versus remote coarse/near detail semantics, including transitions between relevance tiers.
4. Native state application updates bound engine objects in batches on the main thread. Retain authoritative remote positions separately from render-interpolated positions. Prediction reuses `FPSMovement` and current input sequence/life acknowledgements; never rewrite authority simulation for the frontend.
5. Publish a revisioned HUD/deployment/roster view only when changed. Send input/actions to the native session through typed commands; expose connection/error/progress signals to the scripted menu. Native code must not synchronously call back into entity scripts during its frame loop.
6. Keep the existing full-frame transport fallback for older clients and the explicit >64-player compression policy until separately benchmarked. Do not bundle a wire-format change with a presentation refactor.

## Ownership and module boundaries

Extend the current GDExtension under `addons/fps_native/src/` and its CMake source list; keep shared simulation/protocol code reusable by `native_server/`. `FPSClientSession` now owns connection-scoped membership and frame/life/event decisions; a dedicated interaction service remains future work. Existing registrations are `FPSCodec`, `FPSBackend`, `FPSAuthority`, `FPSWorld`, `FPSMovement`, `FPSDestruction`, `FPSClientPeer`, `FPSNativeClient`, `FPSClientSession`, `FPSClientServices`, `FPSRemoteInterpolation`, `FPSPose`, `FPSAvatar` and `FPSAudio`.

One native session owns entity bindings and reconnect teardown. Scene nodes/resources stay on the Godot main thread; workers process immutable POD/packed arrays with bounded queues and cancellation generations. Resolve engine object handles once when binding an entity, invalidate them on destruction, and avoid C++ string-based `get`/`set` loops that merely reproduce scripted dispatch. The existing native animation path still accesses script properties and needs this ownership cleanup too.

Native data classes and engine calls are different concerns: moving an already native Godot call into C++ does not necessarily make it faster. Shaders remain GPU code. SpringBoneSimulator3D, rendering, audio mixing, physics and OpenXR are native engine functionality; scripted setup of those systems is not their computational implementation. Profile CPU scene dispatch, render thread and GPU separately.

## Acceptance gates

- Capture the current native default and scripted reference where available using identical release build, scene, camera, map/seed and avatar population. Record main-thread p50/p95/p99/max, GPU frame time, allocations, transient memory, and main-thread/native boundary calls. Include 64 players at 30/60 Hz; 128 is the experimental stress case. Server timings are separate.
- P1: decoder fixture parity, malformed/truncated/unsupported packets, all entity types, near/coarse transitions, ACK blackout, reordered/lost packets, reconnect/map/life resets, tracked reload state and existing full-frame fallback. Reuse `tools/standalone_server/transport_smoke.gd`, `snapshot_loss_proxy.py`, and the existing matrix comparisons. Require equivalent decoded state and bounded recovery; zero stale entities/effects after teardown.
- P2: desktop + simulated XR tests, both handedness configurations, rotated/recentered tracking origins, vertical gaze, grab/reload/cooldown and held-weapon melee, swimming, scopes and vehicle input. Validate on real headset before release; simulated tracking cannot establish physical comfort or controller alignment.
- P3: native/reference avatar and interpolation parity, 32/64-avatar render scenarios, LOD/IK transitions, marker LOS/retention, cloaking, projector/muzzle/scope alignment, audio audibility and voice routing. Preserve gameplay outcomes and authority ownership.
- P4: terrain streaming/collision seams, weather changes at most once per game day, NVG lightning, water/shore transitions, collapse integrity/damage/rubble, unobstructed capture circles, removal of attached lamps, and bounded mesh commit/collapse frame spikes.
- P5: corrupt/truncated downloads, cancellation, disk-full/write denial, path traversal, checksum mismatch, interrupted update/rollback, concurrent launch leases and child process cleanup.
- P6: clean packaged Linux, Windows and Android/VR smoke tests; no scripted authority fallback. Reference tests remain runnable but release gameplay cannot silently select them. Export/build receipts include the required native sources and capabilities.

Do not set a promised percentage speedup before profiling. The earlier native snapshot work already showed that C++ property readers can lose to thin scripted sampling; acceptance requires measured improvement or a concrete correctness/ownership benefit, with no unexplained frame-time regression.

## Calibration preview delivered with this audit

The retained calibration page now normalizes its private tracking pose to face the fixed preview camera and retains horizontal UI mirroring. Head/hands/weapons use the same frame; the gameplay pose is untouched. [Validation and render](validation/calibration-facing-20261016/README.md) include 41 transform checks, 25 live-widget checks for each native/reference animation path, and a desktop Forward+ capture. The old broad VR suite has unrelated failures documented there; it is not reported as passing.


## P1 started — native protocol boundary

Implemented the complete CQA1/CQA2/CQA3 client frame decoder and CQI1/CQI2/CQI3 input serializer in C++. The transport publishes a decoded `frame` alongside raw bytes; the frontend consumes it directly. Other protocol callers use native `FPSCodec` methods by default. Reference methods remain available for differential tests with `--gdscript-cq-frames` and `--gdscript-cq-input`. Rebuild the client extension before connecting.

This completes the protocol portion of P1, not native client-state ownership. Compatibility dictionaries, `cq_presentation.gd`, snapshot application, entity bindings and scene dispatch remain the next extraction. No native presentation speedup is claimed yet. [Validation and measured protocol timings](validation/native-client-port-20261016/README.md).

Snapshot compression now opts in only for CQ: standalone CQ remains compressed; generic replication and district gateway use raw snapshots otherwise. Explicit PvE remains raw even if it shares class metadata. Both synchronous and asynchronous packers follow this policy. The updated generic receiver accepts raw envelope version 3 and existing compressed version 2; older generic clients that only understand version 2 need updating. Input packet compression is a separate unchanged codec.


## P1 continued — native projection and interpolation

`FPSCodec.project_authority_frame()` now owns the complete compatibility projection from decoded CQ state: class/progression choices, magazines, locomotion/ACKs, incapacitation/revival, designation, utility entities, vehicle seating, timers, projectiles and bombardment presentation. `cq_presentation.gd` is a native selector plus a retained parity oracle (`--gdscript-cq-presentation`). This removes the scripted projection loop, but still allocates compatibility dictionaries for existing scene receivers.

`FPSRemoteInterpolation` owns bounded typed sample histories, jitter/delay, render clock, life/teleport resets, snapshot row ingestion and batched engine body updates. The client crosses into native code once for a row batch and once for remote body application. Local bodies, headset/controller poses and local prediction remain outside this service. The script adapter retains diagnostic getters and a full reference path (`--gdscript-interpolation`); lifecycle callers use explicit `erase()`/`reset()` rather than modifying an exported history dictionary. Histories exported for diagnostics are copies.

Scene membership, authoritative player-state application, local reconciliation dispatch and cosmetic event execution in `arena.gd`/`cq_authority.gd` remain the next extraction. This does not complete P1 or remove the Godot runtime. [Projection/interpolation validation](validation/native-client-state-20261016/README.md).


## P1 continued — batched player fields and reconciliation

`FPSMovement.snapshot_apply_fields()` now applies validated player row batches, including timers, remote blast deltas and authoritative targets. Local ACK reconciliation orchestration, stamina, jetpack and posture decisions run through `FPSMovement.prediction_reconcile()`. Script adapters retain scene height/view and collision hooks; lifecycle and cosmetics still remain in the arena. Reference selectors remain for differential verification. This does not complete native entity ownership or remove compatibility dictionaries.

The 239-check differential fixture passes; field application is about 3× faster at 64/128 players on the development N95. Desktop and simulated tracked standalone-client smoke tests pass. One existing obstacle test fails identically on both reference and native paths. [Validation, measurements and bundle renders](validation/anime-native-state-20261016/README.md).


## P1 continued — native session and entity membership

`FPSClientSession` now owns validated admission/catalog, roster deltas and engine entity bindings, body membership updates, tick/epoch ordering, once-only presentation-event selection, life/death/staging/deployment/round transitions and action sequence generation. Script factories still provide initial resource/signal wiring, with camera/UI and cosmetic adapters retained. Unchanged roster refreshes no longer repeat nametag callbacks. Production standalone CQ requires the new native capability; `--gdscript-client-session` preserves the reference fixture.

1,207 session/entity checks, 239 state/reconciliation checks and desktop/tracked/reference integration tests pass. [Validation and exact remaining boundary](validation/native-session-20261016/README.md). Connection DNS/profile handling, asset transfers/cache, compatibility dictionaries and scene/UI/cosmetic execution remain the next P1/P3 services to extract.


## P1/P3 continued — native connection, transfers and bounded avatar input

`FPSClientServices` now owns DNS resolution/cancellation, resume-token I/O with atomic profile saves, transfer queues/protocol state, disk-streamed downloads, bounded background validation and generation-safe cache publication, persistent upload streams, busy retries and ENet enqueue backpressure. The bounded UTAV reader and metadata inspector are native by default, including all geometry/animation/IK checks, with a retained independent oracle. Production CQ requires the new native capability.

121 service/container checks, 1,207 session checks and 239 state/reconciliation checks pass. Real separate clients upload/download/select a new 6.3MB avatar via the standalone authority; desktop/tracked functional smoke tests and 13 real rendered avatars pass. [Validation and precise remaining boundaries](validation/native-services-20261016/README.md). Scene/UI/GPU construction, library lifecycle and cosmetic dispatch remain adapters. VR interactions, world/audio orchestration and launcher services remain separate phases.


## P2/P4 continued — interaction state and deterministic environment

`FPSVRInteraction` now owns two-hand aiming engagement/hysteresis, shoulder-stock alignment and smoothing, tracking-space swim-stroke accumulation/decay, bounded physical throw launch/guidance, and collision-swept grenade preview trajectories. The rig supplies controller poses and authored grip anchors; independent script state machines remain selectable with `--gdscript-vr-interactions`. Controller ownership, physical magazines/reloading, wheel interactions, scopes and haptic/device dispatch remain adapters or pending extraction.

`FPSWorld.weather_sample()` and `weather_lightning()` now own the deterministic day-cycle schedule, variable fog/rain targets, transitions and lightning timing. Native/reference parity covers transition boundaries, late-join times and seeds. GPU rain/audio/light scene creation and scheduling remain script orchestration. `--gdscript-weather` retains the reference fixture.

Exported standalone CQ connection now rejects script-reference CLI selectors and missing native class capabilities. Editor binaries keep differential fixtures available. This is a preflight check, not proof of a script-free client or completed cross-platform packaging.

[Validation and outstanding boundaries](validation/native-interactions-20261016/README.md). Remaining work includes physical reload/grab/vehicle/weapon interactions, avatar/presentation lifecycle, compatibility dictionaries and scene factories/cosmetic dispatch, environment/streaming/audio/voice orchestration, launcher update/storage/process services, legacy-host retirement and packaged Windows/Android/headset QA. These remain real implementation tasks; this batch does not finish the whole migration.
