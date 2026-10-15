# Unified jungle CQ VPS deployment

The live target is `blux@87.106.27.237` (Ubuntu 24.04, AMD EPYC-Milan, 12 vCPU,
24 GB RAM). This package runs the frontier class arena directly, with Godot
4.7.2, CS movement, resident native authority, adaptive 60/30 Hz physics, 200-point CQ and a
32-player default. It does not deploy the legacy district worker stack.

Ordinary `--server --config server.cfg` startup selects native authority and starts
at 60 Hz, falling back to 30 Hz under pressure and recovering after sustained
headroom. No extra flags are needed. Set `sv_cq_adaptive_tick "0"` and
`sv_cq_tick_rate "30"` or `"60"` for a fixed rate; `--cq-fixed-tick` also disables
adaptation. Older configs that omit the adaptive setting inherit the new default.
This takes effect when a rebuilt package is launched; it does not update an
already running deployment. See [the governor policy](../authority_core/README.md).

Runtime layout:

- `~/fpsloppa-cq/releases/20261013-frontier/cq-server{,.pck}`: versioned runtime and resource pack.
- `~/fpsloppa-cq/current`: active release symlink.
- `~/fpsloppa-cq/server.cfg`: production settings, `set sv_cq_maxclients "32"`.
- `fpsloppa-cq.service`: system service running as `blux`; logs in journald.
- `~/.local/share/godot/app_userdata/FPSloppa/`: persistent CQ profiles, imported skins, collision cache and validation output.

The template disallows scene/path overrides, so `entry.tscn` is the pack's main
scene. `entry.gd` chooses normal authority, `--capacity` or `--clients`.
Native TwoVoIP's Linux release library must also be copied as a loose file at
`addons/twovoip/libs/libtwovoip.linux.template_release.x86_64.so` beside the
executable. The headless release's extension list loads TwoVoIP and the server-native FPS extension; Steam
Audio and XR vendor extensions are excluded. XR stays disabled.

The package must contain the current working tree, including uncommitted map,
UT99, class and vehicle files; exporting Git HEAD would omit the prototype.
Copy imported resource remaps and their `.godot/imported` targets, global script
class and UID caches. Use `deathmatch/server/package.gd` with a JSON manifest
of `{output, files:[{path:"res://...", source:"/absolute/path"}]}` to create
`cq-server.pck`. The reusable `package.py --template /path/to/linux_release.x86_64 --output
/path/to/release` performs this staging and packing without changing the
working project. Set `run/main_scene="res://tools/frontier_vps/entry.tscn"`
in the packaged project configuration. Keep ordinary project settings intact.

Run `tools/voxel_battle/bake_jungle_collision.gd` locally and stage only the
reported fingerprinted heightmap cache in the remote Godot user directory.
A fresh server otherwise generates 2,030,625 terrain samples before accepting
clients. This cache is derived from the same terrain, not simplified collision.
Keep the baked lighting assets and raw inputs used by `map_identity()`.
Verify runtime and pack SHA-256 after transfer and perform a bounded startup
on test UDP 28817 before taking down another game service.

## CoreCU transition and recovery

Original SWGXR data, binaries and configuration remain under `~/swgxr`; no
accounts, characters, databases or container volumes are removed.
CoreCU's `ExecStop` sends `exit` over its private FIFO and waits for saves.
Stop frontends, then CoreCU, verify success and absence of `corecu`, then stop
database/container. Stopping an already inactive `swgxr.target` alone does not
reliably stop independently running leaf services. Disable the target's boot
entry and the 05:00 UTC restart timer while CQ occupies this VPS.

Restore SWGXR if requested:

```sh
sudo systemctl stop fpsloppa-cq.service
sudo systemctl disable fpsloppa-cq.service
sudo systemctl enable --now swgxr.target
sudo systemctl enable --now swgxr-daily-restart.timer
```

Check each service and authenticated gateway readiness after recovery.
Do not force-kill CoreCU if its save-and-exit fails.

## Capacity tests

For the Jolt migration's deployable regression suite, see
[the isolated test bundle](../collision_service/DEPLOYMENT.md). Its runtime tests
use packaged resources and private user data; its optional capacity tools use a
separate candidate port. Preparing or staging this bundle does not activate it
as the production release.

For real ENet tests, temporarily append `--profile-players 32` (or 64),
`--profile-seconds 120 --stress-test` to the service command. Select a test
config with matching `sv_cq_maxclients`. `metered_arena.gd` records the actual
server callbacks, projectile work, history, snapshot packing/RPC fanout,
engine physics, wall tick intervals and achieved simulation Hz. Stress mode
refills reserve ammo and reapplies spawn protection; it must be removed afterwards.
Normal firing can clear spawn protection. Synthetic neutral controllers do not
perform a physical magazine reload, so these runs include initial firing followed
by movement/pose traffic rather than continuous weapon saturation.
Timings overlap: engine physics includes callbacks, and server tick includes
projectiles. Percentiles of overlapping categories must not be added.

Run `client_fleet.py --binary ./cq-server --players 32 --seconds 155 --output
/path/to/validation/fleet-32`, then the 64-player variant. Each simulated
player has its own process, input stream and ENet connection. Clients move,
shoot, send synthetic XR head/hand poses, receive every snapshot packet and
sample-decode packets. Cached map/model readiness is acknowledged without
asset downloads; these clients do not construct the map or render avatars.
They are not bots and do not validate live headset/GPU rendering.
The fleet should finish with every client successful; check the server's
player-count distribution for the entire measured interval.

`capacity.gd` is a separate full-map, scripted-human probe with 120 simulated
seconds per population at 30 Hz. Its snapshot fanout is an estimate, not
actual transport. It reports achieved Hz and wall duration when the machine
cannot sustain real time. Do not conflate this with the live fleet results.

Sample the authority PID with `tools/remote_server_monitor.py`; client fleet
CPU is excluded from that PID's CPU/RSS counters. Running clients on the same
VPS still consumes host resources. Provider inbound UDP 7777 must be allowed
for external players; a permissive host firewall alone is insufficient.

## Unsupported 64-slot configuration

Keep production at 32 slots. Explicitly setting `sv_cq_maxclients "64"` enables the unsupported option; the updated package reports the capacity policy at startup, through RCON status and to joining players. See [capacity assessment](../../docs/validation/voxel-battle/vps-20261013/CAPACITY-64.md) for the sample configuration, measured limits and validation gate.

## Native backend candidate

The package now requires the portable server-native build. Build with `python3 tools/build_gameplay_native.py --server --container` before packaging. See [native backend guide](../../docs/NATIVE-CQ-BACKEND.md) for build, fallbacks, worker/queue ownership and main-branch reuse. `native_compare.py` can launch an isolated candidate on loopback UDP 7779 and run fleets without changing the production service; `process_sampler.py` records its per-thread CPU and owned socket drops.

## Connection-drop diagnostics

Dedicated servers service ENet before every active physics step as well as on ordinary idle frames. The Linux native helper requests a 4 MiB receive buffer and logs the actual kernel-clamped size in `network_receive_buffer`; this does not change host sysctls. Keep normal polling and tuning enabled. `--network-poll-idle-only` and `--network-default-buffer` are regression switches.

The metered candidate accepts `--trace-network` (manual idle polling and one-second transport/physics-batch telemetry), `--trace-poll-physics` (additional diagnostic physics polling), `--trace-tune-buffer`, `--network-no-simulation` and `--network-no-snapshots`. On the fixed code, base physics polling is already enabled; do not add `--trace-poll-physics` unless deliberately measuring duplicate polling. Disable the base fixes with the regression switches to recreate the old behavior. `native_compare.py` forwards repeated `--server-arg=...` and `--client-arg=...`; clients accept `--no-fire` and `--connection-only`. A connection-only run must not be reported as simulation capacity.

See [drop investigation](../../docs/validation/voxel-battle/network-drops-20261014/REPORT.md). Test default behavior without manual trace polling before promoting a release. All recorded fleets here use cached assets and loopback networking; they do not establish WAN latency or asset-download performance.

## Movement and query attribution

Add `--server-arg=--attribute-movement` to `native_compare.py` to enable main-thread scoped timings after the target population is reached. Add `--server-arg=--attribution-output --server-arg=/absolute/path/ticks.jsonl` to retain per-tick samples in a chosen location (its parent must exist). Without an output argument, raw data goes to `user://vps-validation/attribution-ticks.jsonl`. The report includes calls, total time, mean/max call time, per-tick call counts and inclusive/self percentiles. Query counts describe engine API calls; one slide or sweep can perform several internal physics operations.

`deathmatch/server/attribution.gd` is disabled outside this opt-in metered run. It uses main-thread wall-clock scopes, including time spent in engine calls and any scheduling pauses. Inclusive scopes overlap; self time subtracts instrumented descendants and still includes uninstrumented work and recorder overhead. Input accepted during idle polling is carried into the next tick's sample, so summing all scope totals is not a physics-callback-only CPU measure. No worker thread may use this shared recorder. Samples are held in memory for the bounded profile and written after the measurement ends.

Coverage includes player simulation/CS/stairs/posture, edge rays, slide/floor snap, room-scale movement (zero requests counted separately), vehicle slide/terrain/water/clearance work, class services, spotting, hit/cover and class ray/shape/cast queries, input acceptance, physics-step ENet polling and snapshot preparation/fanout. Query parameter construction is charged to the enclosing scope rather than the engine query. The broadphase's internal engine operations and other uninstrumented modes are outside this attribution.

Run `summarize_attribution.py --report report.json --ticks ticks.jsonl --baseline recording-disabled-report.json --output summary.json` to rank exclusive mean costs and correlate queries with the slowest 5% of callback samples. The control difference is not a calibrated overhead measurement: consecutive shared-VPS runs can have different gameplay and scheduling. A failed fleet must not be treated as a full-population test; inspect raw minimum player count and fleet exits. Use `--stagger-ms 125` for a separate staggered-admission experiment and record that workload difference.
