# District workers in the dedicated server

The prototype is isolated on `experimental/cq-districts`. The original checkout remains on `main`, with its ordinary game changes retained. This branch includes those ordinary changes as a preservation baseline, followed by a separate prototype commit; do not merge the whole experimental branch into main to take a single backend fix.

**The existing console-only dedicated executable can run a district worker.** A two-process private coordinator test now exercises real movement input, a physical boundary crossing, state transfer and replay protection. This establishes server-runtime reuse, not a playable public district backend. Normal server startup remains monolithic. `set sv_simulation districts` is still rejected.

CQ clients still require the separate launcher and protocol. The ordinary client cannot join CQ, and the CQ client cannot join an ordinary server. No shared client profile, capacity increase for normal modes, or public worker ports were introduced.

## Implemented on the experimental branch

- `deathmatch/server/districts/state.gd` is the shared schema-2 actor transfer implementation. The original prototype imports it as well.
- Actor transfer rebases buffered-fire expiry, valid view timestamps, nested melee timestamps and the existing top-level deadlines between clocks. An absent view timestamp stays absent; expired actions stay expired. Weapon charge duration is preserved as a duration.
- Removal/restoration no longer uses ordinary player departure/admission. This avoids departure announcements, team reassignment and spawn side effects during migration. Positive human IDs do not acquire bot AI; source lag history is cleared.
- `deathmatch/server/districts/wire.gd` shares the private framed Variant transport. It bounds frames to 1 MiB, receive accumulation to one frame plus header, queued output to 2 MiB, and decoded messages to 256 per poll. Object decoding remains disabled. A failed transport stops processing.
- `--experimental-cq --cq-worker <0..15>` selects a private worker entry point before ordinary dedicated startup. It requires headless operation, a loopback coordinator port and a 256-bit token. The worker opens an outgoing loopback connection, never an ENet listener. Both sides verify the token in the probe; the coordinator also verifies PID, district, map hash and schema.
- Workers use production movement, combat, bots and input validation, with local pickups. Inputs require the current map epoch, actor ownership and district generation. The coordinator supplies global CQ ownership; workers do not advance capture rules independently.
- Transfers remove source authority into escrow before preparing the destination. Prepare is inactive; commit activates once. Replayed commits return the original receipt even after the actor subsequently departs. Destination lag-compensation history is invalidated. Source-owned and boundary-crossing projectiles are terminated. Transactions are bounded; generation metadata is released with escrow.
- Round reset requires a newer epoch and clears actors, projectiles and transactions. Coordinator disconnection or silence for 15 seconds stops the worker. This is fail-closed behavior, not durable crash recovery.
- Console packaging has an opt-in `--cq-assets` flag for the Vesper BSP, navigation mesh and CQ configuration. The dedicated runtime resolves external assets and does not require graphical scene caches. The source/client launcher still requires its prepared scenes.

The worker's snapshots are private state records. They are deliberately not passed directly to the public replication receiver. The raw schema is rejected by that receiver.

## Validation

The [local clock/codec probe](validation/district-integration.json) now passes the previously failing clock checks: transfer from clock 100 to 800 preserves 0.25 seconds of buffered-fire life and a view timestamp age of 0.08 seconds. It also checks sentinel/expired timestamps, health, armour, invulnerability, respawn, production input acknowledgement and codec round-trip.

The [console-worker probe](validation/district-server-probe.json) passes 45 checks using two actual packaged console server processes. It checks authenticated startup, shared map/schema, routed positive-ID human input, wrong-owner/stale-generation rejection, nested deadlines and charge, physical crossing, no active owner during escrow, prepare/commit replay, exactly one destination authority, late commit replay without resurrection, epoch reset and worker exit on coordinator loss. This uses a private test coordinator, not human ENet clients or VR prediction.

The existing two-district/eight-bot prototype also passes a deliberately rejected transfer with rollback followed by a successful crossing. All eight actors remain accounted for, state is preserved, and duplicate acknowledgements do not duplicate ownership. CQ's rule suite passes 215 assertions. The separate ENet admission suite checks the existing monolithic CQ session and both directions of client-profile isolation; it does not test a public district gateway.

Reproduce from this branch (Godot 4.7.2 and the existing audited console template required):

```sh
python3 tools/build_console_server.py --cq-assets \
  --template /path/to/console-only/FPSloppaServer.x86_64 \
  --output Builds/CQWorkerServer
python3 tools/build_console_server.py --verify-only --output Builds/CQWorkerServer
godot --headless --xr-mode off --path . --script tools/district_sim/server_probe.gd
godot --headless --xr-mode off --path . --script tools/district_sim/integration_probe.gd
godot --headless --xr-mode off --path . --script tools/district_sim/run.gd -- \
  '{"zones":2,"seconds":14,"name":"server-shared-state","reject_once":true,"port":29473}'
godot --headless --xr-mode off --path . --script deathmatch/tests/conquest.gd
python3 tools/test_conquest_network.py
```

The probe's loopback port is 29471. Its watchdog closes connections and stops its child processes. Worker tokens are ephemeral and excluded from validation receipts. The worker entry point is an internal development interface; run the probe rather than treating it as a public server command.

## Remaining public-backend work

An optional backend in the ordinary dedicated executable is feasible without merging the clients. The CQ profile should continue to select a separate admission protocol and its own capacity settings. A future `sv_cq_backend` option can select the implementation within that profile, with the current monolithic implementation as the default.

The public gateway must retain one stable ENet connection per player and own assets, identity, teams, capture state, round time, RCON, voice and the ownership directory. It must stop simulating actor proxies when workers own them. It also needs worker supervision, freshness checks and coordinated round resets.

Playable district clients require scoped replication caches/baselines, authority event forwarding, a generation-bound transition acknowledgement, clearing old prediction and interpolation, and rejecting delayed old-district state/events. The current observer is not a substitute. Disconnect/reconnect during transfer, destination failure during commit, loss of the coordinator, overloaded districts, crowded-district performance and a full CQ match need explicit tests before enabling the public option. Durable failover and cross-district ballistics remain undefined.

No 64-human performance, desktop/VR handoff quality or public gateway readiness is claimed by these worker tests. Main remains the working branch; cherry-pick only reviewed independent fixes if they later become useful to the ordinary server.
