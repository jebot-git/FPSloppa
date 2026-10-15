# Authority player-state experiments

These experiments extend the Jolt/snapshot regression deployment. They do not
change the live service or enable the new authority paths by default. The current
native snapshot preparation remains the reference for this suite.

## Ordered stages

| Stage | Added switch | What changes |
| --- | --- | --- |
| reference | none | GDScript player/input bookkeeping, native snapshot preparation/encoder |
| player-state | `--native-player-state` | Persistent per-arena native roster; input timeout and jump/jetpack consumption, typed timer advancement, trigger buffering/restoration and reload-motion math |
| input-state | `--native-input-state` | Required-field/type/finite validation, sequence/time projection, jump/jetpack acknowledgement, movement/button projection and fire-event acceptance |
| fanout | `--native-snapshot-fanout` | Native packet/recipient loop using the same Godot RPC methods/channels and per-packet bandwidth reservation |
| buffers | `--native-snapshot-buffers` | Immutable native value-tree handoff; encoder reconstructs its own Godot containers before existing record expansion/encoding |

The runner accumulates the switches in this order. Each switch can also be tested
individually. All variants use the same Jolt world, gameplay order, snapshots,
wire protocol, packet sizes and send cadence. No Quake movement path is added.

Player timers are imported at their original per-player commit point, because
combat, respawn and equipment still write gameplay dictionaries. This is a
migration boundary, not a replacement for the complete player controller. The
native roster retains typed timer storage, reconciles membership/life each tick
and releases departed peers. Physics, pose validation, weapon impacts, inventory,
reload gesture decisions, damage and scene mutation stay on the authority thread.

The immutable queue retains the two-job bound, tokens/epochs and cache semantics.
It carries no live Array/Dictionary containers between producer and encoder;
value leaves use Godot copy-on-write semantics. Typed containers or unsupported
values use the existing deep-copy path to preserve their metadata. Profiles report
`submitted` and `fallback` counts. This is an allocation/copy experiment, not an
assumed improvement or a buffer pool.

## Correctness gates

`deathmatch/tests/player_simulation.gd` checks full arena input state against the
reference adapter, malformed fields, lost/repeated jump and jetpack events,
trigger expiry/buffering, cooldown/charge completion, peer reuse and owner-thread
guards. Another 1,600 motion sequences compare reload tracking transforms, freshness, body-motion rejection and gesture invalidation against GDScript. It also measures bookkeeping separately at 32 and 64 players.

`snapshot_preparation.gd` checks exact packet bytes after nested producer mutation,
including the immutable path, typed-container fallback, owner-thread guards and
the two-job bound. `snapshot_network.gd` checks real ENet admission, class/clip
replication and recording; the prepared deployment runs it with all new switches.

For the complete offline regression bundle:

```sh
python3 tools/collision_service/prepare_deployment.py \
  --template /path/to/linux_release.x86_64 \
  --jolt-source /path/to/pinned/jolt --output /tmp/cq-authority-suite
python3 /tmp/cq-authority-suite/run_suite.py \
  --output /tmp/cq-authority-regressions --authority-experiments
```

Build the portable native server library first with
`python3 tools/build_gameplay_native.py --target linux --server --container`.
The packaging step rejects stale source/binary receipts.

## Capacity comparison

In a checkout:

```sh
python3 tools/player_simulation/run_suite.py \
  --binary /tmp/cq-authority-suite/release/cq-server \
  --output /tmp/cq-authority-capacity --seconds 120 --players 32 64
```

The prepared bundle also contains `tools/player_simulation/run_suite.py` and its
capacity dependencies, so the same command works without the checkout. It uses
an isolated loopback port (27879 by default) and separate user-data directories.
It never starts/stops production services. Do not use the live service's port.
Run on an otherwise stable host with enough resources for the client fleet, or
place the load generators elsewhere for deployment-level conclusions.

Every stage runs 32 and 64 separate animated-input ENet client processes. Reports
include achieved Hz, callback/preparation percentiles, category self-time per
simulation tick, replication queue counters and immutable buffer counts. The
runner rejects missing reports, failed/rejected/disconnected clients, missing
snapshots, script errors and attribution nesting errors. Timing regressions are
reported rather than hidden behind a performance threshold. All variants have
the same fine instrumentation; do not directly compare their absolute scope
self-times with older, more coarsely instrumented runs.

The default is two minutes after admission per case. Shorter runs are smoke tests.
Use `--stages reference input-state` or other stage subsets for controlled repeats.
Use `--skip-regressions` only after validating the exact prepared package.

## Fine attribution

New `player.*` scopes separate delivery/timeout, stance/equipment, movement,
room-scale correction, timers, melee, trigger/combat handling, grenade input,
magazine/reload updates and pickup checks. New `input.*` scopes separate basic
validation, time/event updates, scalar/button fields, pose/room validation,
fire events and equipment/physical interactions. Native roster reconciliation
has a separate `simulation.player_bind` scope; include it when judging savings.
Inclusive scopes contain children. Only disjoint self-time means can be added;
percentiles cannot be added/subtracted to derive an engine-only budget.

## Suspending the live service for a VPS comparison

When maintenance is authorized, `run_vps_comparison.py` can suspend a CQ service
owned by the current SSH user while running the full two-minute matrix. It
verifies the prepared bundle first and refuses to suspend a watchdog-managed
service or another user's process. It preserves the installed release/config,
collects per-thread CPU/RSS/UDP-drop samples, and resumes the original process in
cleanup. A detached guardian also resumes it if the supervisor exits unexpectedly
or exceeds its timeout; PID start-time checks prevent signaling a reused PID.

Run `test_supervisor.py` locally to check resume identity guards and candidate
process-group cleanup without touching a service. On the VPS, use `--verify-only`
first; run under `nohup` so an SSH disconnect does not interrupt the comparison:

```sh
python3 run_vps_comparison.py --bundle /path/to/prepared-suite \
  --output /path/to/new-results --suspend-service fpsloppa-cq.service --verify-only
nohup python3 run_vps_comparison.py --bundle /path/to/prepared-suite \
  --output /path/to/new-results --suspend-service fpsloppa-cq.service \
  > /path/to/supervisor.log 2>&1 < /dev/null &
```

The explicit `--suspend-service` switch is required to suspend anything. Existing
same-package regression results are reused; the remote capacity runner does not
require a full Godot editor installation. Check `status.json` and perform a public
client admission/snapshot probe after restoration. A suspended systemd service can
still report `active`; the process state and restoration probe are the checks that
matter.
