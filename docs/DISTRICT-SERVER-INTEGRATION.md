# CQ gateway and district workers

The experimental branch now has an optional playable ENet gateway in the existing dedicated executable. `main` remains the ordinary working branch. CQ still requires its separate launcher and protocol (`fpsloppa-cq-experimental-2`); normal clients and normal game capacity settings remain separate.

## Configuration and launch

Add these to a CQ-only server configuration:

```cfg
set sv_cq_backend districts
set sv_cq_worker_limit 16
```

`sv_cq_backend` defaults to `monolithic`; `districts` is rejected outside CQ. Worker limits range from 2 to 16 and are independent of `sv_cq_maxclients`. Workers start on demand. Empty workers can be replaced while retaining pickup cooldowns. An actor in transit reserves both its source and destination; a limit must leave room for that overlap. Exceeding the limit when no worker can be evicted stops the experimental session rather than allowing two authorities or unowned actors. The limit is a resource guard, not a guarantee that any population fits that many workers.

Package the server with the pinned map, navigation and trusted collision cache:

```sh
python3 tools/build_console_server.py --cq-assets \
  --template /path/to/console-only/FPSloppaServer.x86_64 \
  --output Builds/CQGatewayFinal
python3 tools/build_console_server.py --verify-only --output Builds/CQGatewayFinal
Builds/CQGatewayFinal/FPSloppaServer.x86_64 -- \
  --experimental-cq --config /path/to/cq-server.cfg
```

The packager generates a server-only collision scene from the verified BSP and embeds it in the PCK. Clients cannot upload or replace that resource. Public BSP/model admission still uses the existing asset protocol. Full-city static collision remains available in every worker for spawning and traces; dynamic actors, pickups and projectiles belong to one district. Bot navigation is created only for districts containing bots, and empty districts skip actor/AI simulation while their clocks continue.

Clients launch from this branch:

```sh
./launch-conquest.sh 45.147.228.101
```

The live test used UDP **45.147.228.101:7787**. The CQ test service was shut down at the owner’s request after validation; it is no longer a public test endpoint. The ordinary server continues on 7777. The temporary test deployment was removed from `~/FPSloppa-CQ-Experimental/20260920-gateway`, after stopping its user service `fpsloppa-cq-experimental.service`. It is capped at four workers, 1 GiB and one CPU core's worth of time on a two-core/2-GB host. User lingering keeps it alive after SSH disconnect. It is a transient testing service, not a boot-enabled production installation. Stop it with `systemctl --user stop fpsloppa-cq-experimental`. RCON listens only on loopback and was accessed through SSH; credentials are absent from the repository and validation receipts.

The configured CQ admission ceiling is 64, but this small test host and its four-worker cap are **not** a 64-player deployment. The ordinary server and its configuration were not replaced.

## Authority and replication

The gateway owns the public ENet connection, admission, model choices, transport RTT, team directory, capture rules, match clock, radio and RCON. Its fighters are proxies populated by worker snapshots; it never runs their movement/combat or bot AI. Pending actors cannot capture circles. Global capture/time can continue while another actor transfers.

Private loopback workers authenticate with an ephemeral per-process token, expected PID, district, map hash and transfer schema. Input goes through the public size/rate/sender/map checks, then the gateway's ownership, sequence and district-generation checks, then production validation in the owning worker. Friendly-fire policy comes from the gateway. Workers cannot advance CQ capture independently.

Each client has its own replication cache and receives current-district actors, pickups and projectiles, plus global CQ objectives and roster identity. Actors outside its interest set are hidden and excluded from local actor collision. The graphical map remains the existing full-city map with its existing occlusion; this change does not introduce streaming of static district geometry.

Whitelisted worker audiovisual events—including shots, impacts, pickups, damage, hit confirmation, projectiles and kill announcements—cross an authority-only RPC wrapper carrying the recipient's generation. Global gateway announcements remain global. RCON status reports worker counts, ownership phases, generations and input/transfer statistics.

## Handoff and prediction

1. The source removes the actor into escrow before offering it. Owned projectiles are ended; cross-boundary projectiles are also terminated. Cross-district ballistics are not supported.
2. The gateway advances the actor's generation and sends a reliable transition. The client freezes movement prediction, clears its prediction/interpolation/projectile history and pending input edges, and acknowledges the new generation.
3. The destination stages the complete actor state. It activates only after prepare and client readiness. Duplicate commits return the original receipt, including after a later departure.
4. A committed human waits for fresh generation input before movement/combat resumes, preventing held actions during baseline application. On commit, the gateway releases source escrow and sends a reliable, district-scoped baseline. The client applies position/velocity, seeds the replication receiver and resumes prediction. A same-life transfer preserves the player's view orientation; a real respawn still follows normal spawn handling.
5. Delayed old-generation snapshots, effects and inputs are rejected. Fire/jump event counters remain monotonic, while old pending local edges are cleared. Valid view timestamps and buffered/nested action deadlines are rebased between worker clocks; destination lag history is invalidated at commit.

Round reset pauses workers, advances their private epoch, clears actors/projectiles/transactions/pickup state and waits for reset acknowledgements before redeploying actors through new client baselines. Public map identity does not need to change. Disconnected actors are retired from every possible owner and staged transaction.

Workers exit on coordinator loss. Worker loss, stale authority, transport overflow, ambiguous transfer failure or exhausted active-worker capacity closes the gateway. This is deliberately fail-closed; there is no durable failover or automatic recovery of a match.

## Validation and limits

[Consolidated receipt](validation/cq-gateway.json) contains the final local and internet results and the deployed package hash. The final code was tested with:

- Two real ENet clients crossing out and back through separate districts, firing, rejecting delayed generations, and receiving fresh baselines after RCON round restart. Each retained the global two-player roster while seeing only its local actor.
- A single predicted client visiting three districts with a two-worker pool, exercising eviction and re-entry, four physical crossings and a round reset; no hard prediction resets.
- Eight bots for 35 seconds: all eight moved, 11 transfers completed, and forcibly terminating a worker caused gateway exit code 3 instead of continuing with uncertain authority.
- 47 private-worker assertions covering transfer/clock/replay/epoch behavior, friendly-fire policy and coordinator loss; 221 CQ rule/configuration assertions; both directions of client-profile rejection, unchanged ordinary capacity and monolithic 64-entry CQ admission.
- An audited console package with no client native plugins, using the same dedicated executable for gateway and workers.

On the remote host, final loaded-worker handoffs measured **133–134 ms**. Both final internet clients reported zero hard prediction resets. Maximum recorded prediction error before correction was approximately 0.65 m in that run; this does not mean visually perfect movement. Final cold starts still required **5.7–9.3 seconds** of deliberate handoff freeze. Peak service memory was approximately **543 MiB** under the 1-GiB cap. An earlier build hit that cap while repeatedly importing the BSP; the embedded collision cache and lazy AI initialization resolved the observed test failure.

These are headless clients executing real input, physics prediction and internet ENet transport. They do not certify rendered desktop/VR comfort, voice quality, a complete balanced CQ match, 64-human performance, every possible failure interleaving, or pickup persistence under arbitrary long-running overload. Known Godot/GDExtension shutdown resource diagnostics remain in the test-driver logs; runtime script/physics errors and gameplay assertions fail the harness.

Reproduce local tests:

```sh
python3 tools/cq_gateway/run.py --server-binary Builds/CQGatewayFinal/FPSloppaServer.x86_64
python3 tools/cq_gateway/run.py --server-binary Builds/CQGatewayFinal/FPSloppaServer.x86_64 \
  --name local-pool --clients 1 --worker-limit 2 --pool-route
python3 tools/cq_gateway/bots_and_failure.py
godot --headless --xr-mode off --path . --script tools/district_sim/server_probe.gd -- \
  "$PWD/Builds/CQGatewayFinal/FPSloppaServer.x86_64"
godot --headless --xr-mode off --path . --script deathmatch/tests/conquest.gd
python3 tools/test_conquest_network.py
```

The live harness uses `--remote --host <host> --port <CQ-port> --rcon-port <local-SSH-forward> --config <private-config>`. Test outputs/configuration are ignored under `test-results/cq-gateway`; RCON secrets are generated separately from SSH authentication. All implementation and deployment work belongs to `experimental/cq-districts`; no main-branch merge was performed.
