# CQ resident-core migration work in progress

User authorised proceeding with the entire remainder of the implementation on 2026-10-14. Architecture is a host-independent C++ resident authority with Godot transport and scene/Jolt integration. Do not stop at another partial scalar-helper implementation or treat this checklist as completion. Production/live service is still the old path; do not enable the new core as production until feature, protocol and real-map tests pass.

Previous prototype: docs/validation/voxel-battle/resident-authority-core-20261014/REPORT.md (local 32/64 120-second small-fixture tests). Those metrics predate the current migration. Preserve prior uncommitted changes; no commits/push requested in the current task.

## Current implementation

- `authority_math.h`, `authority_vr.{h,cpp}`: typed validated poses, true inverse basis math, CQ reload geometries 2/7/12, fresh/duplicate tracking history, eject/pull/reseat/pouch/rack/flick and pack arming delay; native jetpack; port of UT99 constrained weapon reach/head handling.
- `authority_core` now consumes CQI1 and CQI2 tracked commands, keeps physical states per weapon, uses tracked muzzles and physical reloads, room-scale movement/rebasing and VR posture. Jetpack is cold-enabled per player or by CQ shocktroop class.
- `authority_cq`, `authority_gameplay`, `authority_utilities`: native class XP/selection/loadout, 500 XP levels, T2 unlocks 5/10/15; boxes/limits/cooldowns/weighted supply, injury/revival/bleedout; spotting/NVG/laser validation; CQ capture/income/kills; reliable bounded action queue; grenade throws/bounce/fuse; healing pools and energy-only spherical shields. Several APIs remain to be wired through the Godot adapter and production scene.
- `authority_snapshot`, `authority_cq_snapshot`, `authority_wire.h`: CQA2 TLV extensions for poses, physical reloads, projectiles, jetpack, class/mode/boxes/fields; old CQA1 small fixture remains available.
- `deathmatch/native/authority_protocol.gd`: new input encoder and frame decoder. Decoder currently understands types 1–4 and skips 5+; finish all CQ/entity sections and hook to real clients.
- `authority_collision`, `authority_queries`: native canonical anatomy, rounded OBB sweeps, bounded history and body/head traces, relative-motion queries. Native Godot adapter has sphere world sweeps and muzzle backoff. Need finish robust sweep collider attribution, entity exclusion and projectile freshness, damage-type/random/spread/knockback parity.
- `authority_terrain`: cold imports of exact road bins, pads/rivers/port from authored landscape; native road/water classification. `FPSAuthority.configure_terrain` exists, but export/import bridge and differential tests not yet added.
- Native Godot registration/profiles/SCons/CMake updated; KinematicCollision3D required for room movement. No script per-player gameplay loop is used in the new fixture.

## Latest tests/evidence

- `/tmp/cq-native-vr-differential.log`: 15,007 checks pass, comparing typed pose validation and both-handed physical reload trajectories against actual GDScript CQ sources.
- `/tmp/cq-native-reference-tests.log`: 831,752 checks pass (12,000 scoring and 16,000 jetpack reference records, CQ gameplay unit cases, 64-player 3,600-tick deterministic replay and prior core tests).
- `/tmp/cq-native-body-oracle.log`: 874,092 checks pass, including 18,000 body sweeps, all 101 anatomy height definitions vs GDScript and an independent convex-distance oracle.
- Golden generator: `tools/authority_core/reference_export.gd`; files `/tmp/cq-native-golden3/{points,jetpack,bodies,anatomy}.bin`. C++ runner `/tmp/cq-native-vr-core/authority-tests /tmp/cq-native-golden3`.
- Rounded GDScript broadphase has real false negatives: e.g. body record 86 at height .89/radius .015 misses despite head part intersecting. Do not force the new correct geometry to reproduce these misses. Oracle tests verify all queries, exact dimensional parity separately. Counters `collision_legacy_misses`/`collision_legacy_late` exist in reference_tests.cpp but still need inclusion in main JSON to record the differences.
- Latest successful portable extension build log `/tmp/cq-native-terrain-build.log`; rebuild after further C++ edits. Earlier host-system ASan runtime missing; use existing Jammy Podman toolchain for ASan/UBSan.
- Current `tools/authority_core/run_suite.py` still runs the previous small non-XR fixture only. Integrate reference exports, VR/UT99 reach/codec tests, new gameplay suites and tracked load, then full CQ/map/VPS tests.

## Build caveats

Use ONE native build at a time. `python3 tools/build_gameplay_native.py --target linux --server --container -j 8`.

Tracked command queues made aggregate initialisation blow up GCC optimisation. `authority_state.cpp` deliberately defines Command/Player constructors out of line, preventing expansion of 128 × 32 pose initialisers. Keep this separation.

Do not glob `authority*.*` into clang-format: ignored SCons `.os` objects are beside source. Restrict to `.cpp`/`.h`. Source receipts already hash flat .cpp/.h files.

## Remaining work (continue autonomously)

1. Finish validation of new code: native protocol decode, live Jolt sweeps, typed UT99 reach vs all five model profiles and more jetpack/VR/core interruption tests; integrate golden suites and sanitizers.
2. Finish combat parity: first-step projectile freshness; 200 ms rewind wire field; exact spherical/world collision attribution; headshot damage, spread/direct random, rocket falloff/self damage/impulse; guidance; melee and events/effects.
3. Implement native vehicles/turrets/recon/airstrike and remaining class interactions. Reuse existing assets/client models/cameras. World/movement callbacks stay Godot/Jolt; state and scheduling must remain native. Existing source definitions are in deathmatch/conquest/classes/*.gd.
4. Implement native bounded event replication, all entity/class frame sections and client bridge. Existing player/skin admission/synchronisation should be retained; no VRM/fullbody/face/finger support should return.
5. Wire opt-in whole CQ authority into the real class arena without running the legacy per-player/class/vehicle/mode loops. Avoid a per-tick import/export mirror of old gameplay Dictionaries. Cold metadata and client presentation Dictionaries are fine.
6. Round completion/intermission/restart, respawn host/life collider synchronisation, UI actions, map water/roads/light metadata and native day/night/NVG logic; server-specific non-CQ legacy modes need not be ported.
7. Real-map full matched 32/64 suites, then isolated live-VPS testing. User already permits suspending live service for tests. Existing tools/player_simulation/run_vps_comparison.py has guarded same-UID SIGSTOP/SIGCONT supervisor. Do not deploy the old prepared PCK as if it contains current code. Live server 87.106.27.237 as blux, service fpsloppa-cq, current release 20261014-jolt-6abfbf5. Do not put credentials in files/chat.

## Known details to check

- Default non-CQ fixture uses teams 1/2 and 0 means FFA. CQ uses teams 0/1; `same_team`/impact guards switch with cq.enabled. Do not accidentally make red team immune logic use truthiness.
- `spawn_class` now preserves technician slot 6 for T2 turret but removes medic slot 6 for T2 healing grenade. Respawn must only restore the old weapon in non-CQ mode; new class gets its primary.
- Session owner tokens persist across respawn for boxes; life handles remain distinct for damage and stale events. Disconnect removes owned dispensers.
- Core input CQI2 currently accepts only 48/240/288-byte packets with flags <=255. `Command.view_time` added but not yet encoded/decoded. Add bounded extension and keep old fixture compatibility.
- `Weapon.radius` in prototype doubles as blast radius for launchers (5). New `Projectile.sweep_radius` fixes this to .025 for launchers. Do not use blast radius for a collision sphere.
- CQA2 prototype only has player rows + TLV; legacy clients cannot use it until the production client bridge is finished.
- Current README's "not implemented" list is from the initial prototype and needs updating after the migration, while retaining honest remaining-gate status.


## Continuation update (later in the same user turn)

The implementation continued substantially beyond the checklist above. Do not redo earlier work; inspect current files.

### New native modules

- `authority_ballistics.cpp`, `authority_vehicles.cpp`: cold rocket/light/heavy placements; life-bound boarding/dismount with exit collision queries; tank drive/road bonus, water destruction/pilot gib, crush damage, 8-shot dispersed ballistic rocket barrages, light single/heavy paired volleys, reloads, ordnance/grenade-only damage.
- `authority_abilities.cpp`: turret flat-ground footprint, cooldown/replacement, vehicle-priority nonhoming shots; recon edge-to-edge swept scans/once-per-life alerts; continuous stationary 5s airstrike lock, original bearing, 12 scheduled impacts/300s cooldown; technician repair; vehicle launcher dwell and 120deg/sec homing; native event ring.
- `authority_round.cpp`: round XP awards/intermission/freeze/reset, persistent class XP/selected next loadout, respawn life invalidation; exact day/dusk/night/dawn weights, indexed lamp glare and sun glare; medic dragging and native melee dispatch.
- `authority_melee.{h,cpp}`: headset-relative tracked swing state, rotation-interpolated 16-segment sweep; real GDScript reference parity over 6,000 samples.
- `authority_entities.cpp`: CQA2 sections9–14 for vehicles/turrets/flights/grenades/events/remaining player state. Header6 currently29 bytes after count (winner/scores/time/light/round_epoch/intermission/lighting_time/remaining), then30 bytes/zone. Section14 now83 bytes/player including jump/jetpack/fire acknowledgements.
- `authority_protocol.{h,cpp}`: bounded native frame validator exposed as `FPSCodec.validate_authority_frame(bytes,expected_players,tick)`. Used by load clients instead of an expensive full GDScript projection for every synthetic peer. Full decoder/presentation is tested separately.
- `authority_world.cpp`: native Godot world and entity callbacks, cold vehicle body attachment, dynamic turret colliders, grounded Jolt vehicle movement, entity ray exclusions, near-contact `get_rest_info` sphere attribution, clear exits, seating and collider lifecycle. World node is cold configured, fallback parent for old fixture. Tank mask1 permits running over infantry; players mask3.

### Updated core/protocol

- Cold `configure_player` imports trusted class XP/choices once before inputs; cannot be reused to refill. CQ accepts negative bot IDs (non-CQ fixture still positive only).
- CQI2 lengths now48..310, flags up to8191. Optional flag256 appends view_time4; flag4096 appends jump_event4,jump_seq4,jetpack_event4,fire_event4,fire_weapon1,fire_mask1 after any view_time. Event counters bounded32 forward and acknowledged. Native burst now completes on release and latches while held, matching actual CQ; non-CQ fixture behavior retained.
- Projectile first-step freshness, mortar bounce/arming/stuck/fuse, vehicle and turret damage, random Massacre direct damage, CQ falloff/self half damage/blast impulse, stance spread, designator guidance and launcher vehicle homing added.
- Core main thread checks now use Godot OS main-thread identity as well as owner identity.
- Need independently inspect combat parity/edge cases; do not assume new tests cover every path.

### Godot integration (WIP; not yet exercised as a complete production arena)

- `deathmatch/native/cq_metadata.gd`: cold exact authored map road/water export.
- `authority_protocol.gd` decoder supports all14 sections, finite checks, reliable action and rewind input extensions.
- `cq_presentation.gd`: client-only projection to existing `_snapshot` presentation/prediction API, preserving class UI, tank cameras, skins, NVG and models. Parser passes; projection tested on a one-player Jolt tank fixture. Needs full actual arena integration checks, especially grenades, vehicles, cooldown timestamps, projectile FX and reload visuals.
- `cq_authority.gd`: opt-in `--cq-native-authority`, dedicated server only for now. Core owns gameplay. Godot owns asset/admission/transport. Arena `_physics_process` native branch bypasses old entire gameplay/snapshot/history loops. Native direct `_packet` RPC goes to `core.submit_packet`; old Dictionary ingress is a fallback with validation. Native `_part` snapshots are bounded/MTU-sized and client switches after receiving them.
- `tools/voxel_battle/class_arena.gd` routes spawn/admission/use/class/gear/utility/NVG/throws into bridge. `deathmatch/arena.gd` has virtual `_send_input` hook so client prediction stays existing but packed native ingress is used after negotiation. Full inheritance chain parser passes.
- **Important remaining gaps:** actual arena launch/admission/render/client test not run; bot planner integration currently absent (old bots mutate intent Dictionaries and aren't ticked by bypassed loop); map/vote/re-host resets need handling rather than current explicit map-epoch failure; native `lives` caches are admission presence only and queries use current `core.inspect` life; round native respawns do not update server presentation/player metadata except actual collider, intentional avoidance of per-tick mirrors but check admission/lifecycle dependent services. UTX avatar-change hook not yet wired (default reach cached; `configure_resident_avatar` exists in class arena but `avatars/network.gd.queue_avatar` hook still needed). No deployment yet.
- `deathmatch/conquest/classes/grenades.gd` snapshot bounds raised to128 inventories/384 shots for native player storage; verify prior tests.

### Latest verification

- `/tmp/cq-protocol-coverage.log`: **909,409 checks pass** including all prior golden data + 6,000 melee samples + entity gameplay + mutation corpus + trigger/jump retransmission, burst behavior and cold profile no-refill.
- Golden folder `/tmp/cq-native-golden4` adds `melee.bin`; generator and C++ reader updated.
- `/tmp/cq-native-sanitizers.log`: ASan+UBSan **902,607 checks pass**, predates latest protocol/redundancy/frame validator; rerun sanitizer after remaining edits. Image has no CMake and ENTRYPOINT is SCons: use `podman run --entrypoint python3` and compile standalone source list directly with g++ flags, or install own build tool in ephemeral container.
- `/tmp/cq-presentation-functional.log`: **591 checks pass**, real Jolt tank + all-section decode + client presentation projection.
- VR functional remains16,817 and terrain15,506 pass (rerun with final build).
- Full class-arena parser `/tmp/cq-resident-arena-parse3.log` passes.
- Latest successful portable extension build `/tmp/cq-native-wire-build.log`. Native source unchanged since build except no? Check receipt `require_build` before suites.

### Load harness changes and discoveries

- `host.gd`, `driver.gd`, `run_suite.py` now support `--cq-core --tracked --jungle-map`, full real collision map, 11capture areas/8vehicles, all4classes/T2utility selection, tracked arms/poses/reloads, class grenades/recon, CQA2 compressed bounded frame pieces. Production_cq remainsfalse because it's a separate fixture.
- Split client drivers into4 peers/process default (`--clients-per-process`). Native wire validator avoids quadratic GDScript frame parsing across synthetic peers. `_done` now waits for per-peer reliable acknowledgements (15s timeout). Transport-close guard prevents post-disconnect RPC spam. Source manifest includes native protocol GDS files now.
- `/tmp/cq-resident-full-smoke2-20261014/summary.json`: small fixture32/64 tracked CQ5s passed ~30Hz/no disconnect/bad frames/overflow, pre-native-validator. Medians1.553ms and4.319ms (not VPS/not full map).
- `/tmp/cq-resident-jungle-smoke-20261014` **failed frame-delivery gate** using old expensive GDS decoder. Do not claim timing success. 32server stayed30Hz but synthetic clients dropped assemblies. New native validator fixes load decoder overhead; need rerun.
- `/tmp/cq-driver-smoke.json` and server/client logs are a4-client real-map smoke, overwritten by `/tmp/cq-driver-smoke.py` manual runner. They verify native validator and32/64 full TLVs before scaling.
- Telemetry isolated startup input loss: ENet `PEER_PACKET_THROTTLE` starts0..~5/32 and recovers32/32 around6s (even localhost). RPC inbound count equals native accepted, rejected0/overflow0: losses happen before native ingress. Old 5s ~30% acceptance was mostly startup throttling. Full120s initial prototype97% fits startup transient, but avoid claiming exact root cause beyond observed throttle.
- Host now caches UT99 reach profile once before ENet opens instead of rereading model for every join; bridge caches default reach as well.
- **Most recent edit:** warm-up is now8 seconds, input/frames still flow during warm-up, animation/fire cycle begins at measured phase. Server reports warmup_native counters separately, native measured counters subtract baseline; client min/total_inputs_sent and received frames subtract measurement baselines. Driver logs per-client transport stats (rtt/loss/throttle at1Hz), and `_command` RPC count is reported to distinguish transport loss from rejection. Need rerun after these latest harness edits.
- Last manual cached4-client smoke used5s warm-up, accepted535 measured out of604sent because throttle still5/32 at5s then32at6s. This motivated8s warm-up. Native image source receipt unaffected by GDS-only edits.

### Next actions

1. Finish/verify actual CQ arena bridge (including avatar hook, bot intent integration or genuine native bot planner, lifecycle/map resets, player metadata/services without per-tick authoritative mirrors). Run actual arena with new wire clients, not only separate fixture.
2. Run full harness after8s warm-up/native validator. Start5s32/64 jungle smoke then120s matched suites. Keep source/library unchanged while a suite runs; runner rejects changed hashes. Add adequate process cleanup and report real per-client offered counts/throttle; don't hide startup results.
3. Complete frame fuzz/codec/presentation tests and sanitizer rerun. Native validator just added; reference semantic decoder remains independent. Main golden suite currently909,409.
4. Update README/docs with honest feature coverage and gates; old README says infantry-only.
5. Isolated VPS tests after local real arena passes. Service still unchanged; user permits suspension. Existing guarded same-UID SIGSTOP/SIGCONT pattern in tools/player_simulation/run_vps_comparison.py. Prepared old deployment bundle is stale. No commit/push requested current task.


## Latest continuation update — read before resuming

The preceding update is older than the following. Current implementation is still uncommitted, live VPS unchanged, task remains active and must be finished.

### Current implementation additions

- Actual arena integration was exercised successfully: `/tmp/cq-actual-server2.log` had **no errors**, `/tmp/cq-actual-client2.log` had no script errors, received native frames (tick~500) through real asset admission and `_snapshot` presentation. Client shutdown reports9resources still in use; compare baseline/clean teardown before treating this as new. Initial actual test exposed missing `mode.kind`; fixed with full base mode fields in `cq_presentation.gd`.
- `authority_ai.cpp` now provides a native prototype bot decision loop for negative IDs: perception5Hz (4 nearest LOS candidates), goal/capture selection, steering, firing/lead, reload, NVG, recon/airstrike/tool decisions. It feeds typed commands to the same core. Navigation is a Host scene query to `game.resident_navigation` -> existing bounded jungle road/navmesh service. Bot population remains Godot admission/scene lifecycle. Native AI has unit coverage but real bot-map navigation/match still needs testing; fidelity is a new prototype, not a line-for-line port of old planners.
- Core timings separate `ai_us`, `mode_us`, movement, combat, snapshot. `FPSAuthority.metrics` now exposes scores/winner/remaining/intermission/round epoch; bridge keeps only these global control-plane values in Godot, without player gameplay mirror.
- Native `configure_spawn(team,point)` imports real spawn candidates; respawn chooses clear/far sites. Respawn/teleport restores collider height/layer/mask, including after a prone death or vehicle seat. Need a real Jolt crouch/respawn regression test still.
- Native `request_restart` handles administrative reset without awarding round XP. TEAM action8 changes team/new life, clears owned combat entities, keeps class progression. Native GRENADE_EQUIP action9, selected/offhand/primed flags and desktop press/pin/release were added. Client G/physical shoulder requests now use native actions. Grenade inventory presentation defaults selected=-1 (was incorrectly always selected; fixed). Action enum upper bound9. Native reliable requests carry life/map epoch/sequence for use/grenades; TEAM is server-control-only. `spawn_request` handles team changes/spectator detach. Verify real team/suicide/respawn flows.
- Bridge reset/rejoin/map-instance rebuilding added, with cold exact profile XP/choices preservation. Default reach profile cached; `avatars/network.gd.queue_avatar` now calls the native avatar-change hook. Dynamic native turret bodies are cleaned in `FPSAuthority` destructor; borrowed tank bodies are not freed by it. OS owner checks guard main thread and OS existence.
- Protocol bumped `CLASS_PROTOCOL` to `fpsloppa-cq-frontier-18-resident1`. Old live release remains17; do not send old clients as if compatible.
- **IMPORTANT fixed assembly bug:** `_part` now sets `epoch=map_epoch` immediately after reset on the first chunk, so later chunks do not repeatedly clear the assembly. This fix has not yet been retested in a real arena.
- Stable session damage credit added: `Projectile.credit` at END of aggregate, not between owner/team (preserves prototype aggregate layout). `Core.damage(..., bool headshot=false,Session={})` resolves session token only when old life no longer resolves, preserving kill XP through respawn while preventing reconnect/reused-ID credit. Vehicles/grenades/turrets/airstrikes propagate credit; new tests prove respawn credit/reconnect isolation. Keep life guards for victims/physical identities.
- Headshot flag now propagates on direct projectile damage. RAY event7 added for hitscan/beam FX, GRENADE event8 separate from projectile explosions. Airstrike stack blast has effect=1 to suppress duplicate generic explosion; flight event4 renders its FX, duplicate glare removed. Existing client visual helpers are reused. Native frame validator allows event kinds0..8.
- **Wire changes since prior update:** projectile section3 rows are now67 bytes, not50: original50 + flagsu8@50(stuck1,quake2), gravityf32@51,arm@55,sweep_radius@59,age@63. GDS decoder and native validator updated. Section14 remains83bytes; flagsbyte@46 now primed1/selected2/offhand4. Global section6 remains29bytes after count. The current library must match these changes; check receipt before testing.
- Native CQ desktop standing collider now targets1.70m, matching the actual voxel arena client; VR remains1.65 clamp as original. Non-CQ fixture remains1.65. Spread crouch threshold corrected1.6. Anatomy still matches existing clamped1.65 hit-body definitions.
- Cooldown preservation through rounds retained as original; cold map reload imports remaining cooldowns via configure_player `cooldowns` array. Need verify cold save/reload in actual arena.
- `--stress-test` added to separate fixture and arena bridge: cold `configure_stress` only before inputs, restores reserve ammo/grenades and rejects combat damage, retains physical magazines/reload/cooldown and water/fall deaths. Flag persists across respawn. This is for matching old stress workload; label it in reports. Normal finite-ammo case should also be tested. Latest host pack firing window changed to animation260..299/300, because firing60..150 occurred before the 6.6s VR pack arming delay and never exercised technician salvos. Others retain60..150. Verify sustained counts in long runs.

### Verification and current processes

- Latest standalone suite before the most recent desktop1.70/spread edits: **909,452 checks pass** (`/tmp/cq-stress-tests2.log`, `/tmp/cq-fx-credit-tests.log`). Includes native AI basic behavior, reliable fire/jump, bursts, desktop grenade selection/release, team/restart, session credit.
- **Current tool exec session27387** launched cmake build + tests + portable build after desktop height/spread and host pack firing-window fixes. Logs `/tmp/cq-parity-build.log`, `/tmp/cq-parity-tests.log`, `/tmp/cq-native-parity-build.log`. Check all exit/results. Latest prior confirmed portable build `/tmp/cq-native-final-wire-build.log`; this included current67-byte projectile wire and83-byte player extra? Check source receipt; last known build was after FX/session changes, yes. Never trust a stale executable test log when compilation failed (some shell calls did not use set-e; inspect build log too).
- `/tmp/cq-resident-jungle-smoke2-20261014/summary.json` **passed** 5-second32/64 tracked actual-map separate fixture, native validator and8s warm-up. 32 median1.734ms,p953.559ms;64 median4.072ms,p959.841ms,30Hz, no disconnects/badframes/overflow, measured accepted fraction~1. These precede later AI/lifecycle/wire additions. Not production arena or VPS; no capacity conclusion yet.
- Earlier failed jungle suite was synthetic GDS decoder bottleneck; keep failure documented, don't reuse its timing as pass.
- Caching profile improved admission but startup ENet throttling still measured. Warm-up8s, all startup counters/transport telemetry retained, measurement counters subtract baseline. Last passing32/64 showed full throttle32/32 by measurement. Native RPC count matched accepted, demonstrating ingress losses were before native validation.
- Final sanitizer rerun still needed (prior ASan/UBSan902,607 predates current features). Existing container has no CMake and SCons entrypoint; direct compile via `podman --entrypoint python3` g++ source list (all authority_*.cpp EXCEPT world.cpp + tests files), include src, -O1 -g1 -fsanitize=address,undefined. Golden `/tmp/cq-native-golden4`.

### Remaining priorities

1. Finish tests for real arena after latest assembly/FX/lifecycle updates: actual real clients, tracked poses, grenade selection, death/respawn collider, team changes, rejoin, actual bot navigation. `/tmp/cq-actual-run.py` orchestrates actual dedicated scene+custom full arena client in `/tmp/cq_actual*.gd`, port27949 and config `/tmp/cq-native-arena.cfg` (not credentials). Make this a reusable repo test rather than only temporary scripts.
2. Finish vote/control-plane view if enabled: bridge calls votes.tick and handles team/restart, but client vote_state projection currently preserves `game.votes.view`; separate native control replication not yet added. Default CQ config votes0. Lobby native host not integrated; default config lobby0. Do not quietly leave requested feature paths broken.
3. Check incoming legacy fallback validation and optional fields; native clients use packed `_packet` after first native frame; late physical grenade/use requests carry life/epoch via new reliable `_request`. Native peer fallback class throws are rejected. Class/gear choices apply next spawn and intentionally use existing UI RPCs with native XP validation.
4. Add reusable full client/sanitizer tests; run final full suite/ASan. Then120s32/64 tracked jungle normal and stress with source/library frozen for run. Need updated categories (AI/mode, transport/engine outside native) and meaningful sustained shot counts. Current README is stale infantry-only.
5. Package current library/scripts/assets into a NEW bundle (old20261014 prepared PCK is stale), run isolated VPS tests with guarded service suspension and always resume. User authorises suspension; no new permission needed. Live service still unchanged. Use existing same-UID PID identity/independent SIGCONT guardian pattern. Report scope honestly (VPS loopback load clients also consume CPU).
6. Document reuse in main branch, current protocol/lifecycle/host contract, omitted non-CQ legacy modes, prototype AI differences and outstanding blockers found by tests. Do not commit/push unless newly requested; preserve all earlier uncommitted work.

## Completed continuation — 2026-10-14

The resident CQ prototype implementation and this continuation's validation are complete. Read `docs/validation/voxel-battle/resident-cq-complete-20261014/REPORT.md` and the rewritten README before using the older outstanding-work lists above.

- Final native/ASan/UBSan: 909,456 checks. Godot/Jolt suites:592 /16,817 /15,506 /603, all pass.
- Actual arena desktop/tracked admission, shooting, grenades/NVG, prone death/gib/respawn, team changes and jetpack pass. Collider restart regression passes. Bot ground-navigation smoke passes; authored edge-merge warnings are explicitly counted, not suppressed.
- Four local120s32/64 finite-ammo/stress cases pass with frozen source/library hashes, ~30Hz and no malformed frames/disconnects/saturation. NativeAI and CQ mode timing categories are now included; current-life class shot counters confirm technician salvos are exercised and increased under stress.
- Portable release launcher uses `--resident-suite` through frontier entry (release templates cannot use editor `--script`). The Node wrapper uses the same Host fixture and detaches RPC roots synchronously during disconnect to work around the Godot4.7.2 bound/unbound cache-clear callback mismatch. No engine diagnostic is filtered.
- Four VPS120s32/64 finite-ammo/stress cases pass.64-normal p50/p95=6.719/14.793ms;64-stress=7.220/16.375ms, ~30Hz. Server meanCPU~31–33% of one core, maxRSS~438MiB. Measured-window server-socket drops do not increase; startup64 sockets had9/12 drops. Loopback fleets share VPS CPU, no rendering/AI in fixture.
- Service was guarded-SIGSTOP during full VPS suite and resumed successfully: samePID1600382/start59460619, active/running, NRestarts0, unchanged release20261014-jolt-6abfbf5. PublicUDP7777 compatible client health passed10s/229snapshots/no rejection. The default live release is not changed.
- Local final outputs: `/tmp/cq-resident-final-normal5-20261014`, `/tmp/cq-resident-final-stress4-20261014`; actual `/tmp/cq-real-arena-final2-20261014`. Native and bridge files unchanged during final load suites; source manifest verifies afterward.
- Final portable bundle: `/home/blux/Documents/cq-resident-authority-20261014-portable6`; remote `~/fpsloppa-cq/tests/resident-authority-20261014-final`; VPS results `~/fpsloppa-cq/tests/resident-full-20261014`. All collected evidence is in the report directory.
- Native authority remains opt-in,64 remains unsupported. Main-branch reuse boundaries and untested WAN/lethal-match/interactive-device scenarios are documented. No commit/push requested or performed; earlier uncommitted work preserved.
