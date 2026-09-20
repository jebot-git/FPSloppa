# CQ district capacity and master scalability

Measured 2026-09-20 on the experimental branch. The implemented limits are **16 districts, 64 connected players globally, and 16 reserved player slots per district**. Distribution does not automatically raise the global limit. Waiting players still count toward the server's 64-player maximum.

## Capacity, gates and reinforcement waiting rooms

The master reserves destination capacity before transferring an actor. An unfinished transfer also retains its source slot so a rejected arrival can safely roll back. Prepared admissions and respawn reservations count toward the limit; duplicate reservations for the same actor in one district count once. Workers independently enforce the same cap.

Incoming gates close at 16 reservations and reopen below 16. A red gate and “TRANSIT DISABLED” label accompany matching client-prediction and authoritative collision barriers. Players can leave a full district when the destination has room. If simultaneous arrivals race for the last slot, the master admits only one and rolls the other back without ending the match.

Death initially retains the resident's slot. A player may respawn in that same friendly district at 16/16, reusing their own reservation. Otherwise, the master selects and reserves the nearest controlled district with room. Respawning across districts follows the normal ownership handoff.

If no friendly deployment slot is available, including when the team has no controlled district, the player enters a **private reinforcement waiting room**. The master retains their identity, team and match statistics, while retiring their district actor and releasing its slot. The room is instantiated locally for that client, with enclosing collision, normal looking and local movement, and no battle input, weapons, pickups, capture influence or district radio. It consumes no district worker slot. Initial joins with no deployment slot use the same path.

The master keeps checking eligibility. A departure, disconnect or newly captured district can free a slot; the master reserves it and automatically deploys a waiting player there with a fresh actor generation and normal respawn state. The room remains visible until the new baseline arrives. Original four-person deployment groups survive this temporary placement for the next round. Match victory and timeout rules are unchanged: denying deployment can deplete reinforcements without inventing a separate elimination victory rule.

This is implemented for `sv_cq_backend districts`, with either local workers or external workers. Ordinary main-branch servers are unaffected. Matching rebuilt CQ clients, master and workers are required: public CQ protocol `fpsloppa-cq-experimental-3`, private worker protocol `cq-external-worker-2`, actor schema 3.

## Reference machine and measurement scope

Intel Core i7-12700, 12 physical cores / 20 logical CPUs, 62 GiB RAM. Each measured process was pinned to CPUs 8 and 9, one performance core and its SMT sibling. Other host applications remained running. Runtime: console-only Godot 4.7.2, optimized release build.

The measured production code is **commit `69d225d`, before the capacity/waiting-room changes**. The [receipt](validation/cq-scalability.json) records exact binary, pack and harness hashes and individual results. These are bounded CPU/serialization experiments, not a connected-player, physical multi-host, GPU or headset performance certification.

The master benchmark uses real snapshot scoping/encoding, actor deserialization/application, input decoding/forward serialization, and capture rules. It excludes actual TCP/ENet transmission, SSH encryption, voice, event fanout, ownership validation, migrations, joins and the new capacity bookkeeping. It runs 40 changing snapshot batches after five warmups. “Component core usage” models those measured costs at 20 snapshots/s, 30 input batches/s and 60 capture ticks/s; it is a lower-bound CPU estimate, not observed whole-process utilization:

```
core percent = [20 × (replication_ms + worker_ingress_ms)
                + 30 × input_batch_ms + 60 × capture_tick_ms] / 10
```

The worker benchmark runs actual physics/combat at 60 Hz, with 12 measured seconds after three warmup seconds, repeated twice. Synthetic human actors submit movement and sustained mixed UT99 weapon fire; their selected weapons/ammo are restored after local test respawns. It includes projectile collision, damage and pickup simulation, but no bot pathfinding or client rendering. It measures outgoing private-message serialization into a counting sink, without sending network traffic.

Godot's normal 60 Hz physics rate gives a 16.67 ms tick budget ([Engine documentation](https://docs.godotengine.org/en/stable/classes/class_engine.html)). The 20 Hz snapshot model gives a 50 ms batch budget, but a main-thread burst above 16.67 ms can still delay physics or input processing. Passing the average bandwidth/CPU budget alone does not establish smooth play.

## How many districts can one master handle?

For the current encoder on this reference core, **8–12 lightly populated districts are a reasonable CPU planning range**, with four players per district and no ordnance. Sixteen such districts leave limited headroom and produce long main-thread bursts. At 24 districts, replication alone exceeds a 50 ms snapshot interval. These are workload-dependent estimates; the application still only implements the 16-district topology.

| Districts × players | Total players | Replication mean | Replication p95 | Modeled component core usage |
|---|---:|---:|---:|---:|
| 4 × 4 | 16 | 5.94–5.98 ms | 8.29–8.30 ms | 15.7–15.9% |
| 8 × 4 | 32 | 12.55–12.62 ms | 17.23–17.33 ms | 31.9% |
| 12 × 4 | 48 | 20.52 ms | 27.58–27.66 ms | 50.8% |
| 16 × 4 | 64 | 29.53–29.56 ms | 38.96–39.12 ms | 71.9% |
| 24 × 4 | 96 | 50.66–50.69 ms | 65.00 ms | 120.0–120.1% |
| 32 × 4 | 128 | 76.12–76.15 ms | 95.17–95.39 ms | 177.1% |

District population matters more than worker count. With **16 players and 32 synthetic rocket records per district**, one district costs 18.51 ms mean / 21.13 ms p95 for replication. **Four full districts, 64 total players, cost 81.53 / 91.38 ms**, with modeled component usage of 178.9%. This cannot sustain the intended master update rate on the measured core. The new 16-player cap protects district simulation; it does not resolve this master bottleneck.

Basic XR head/hand/weapon poses also add work: one quiet district with 16 players took 17.20 ms mean / 19.70 ms p95 replication. This payload omitted full-body and face tracking.

The current master deep-copies/scans global state per recipient, then repeatedly encodes nearly identical district snapshots. Work grows roughly with total population squared for global scoping and with the sum of squared district populations for encoding. More idle workers are much cheaper than more populated districts; there is no useful universal “maximum districts per master” independent of workload and hardware.

## How many players can one district simulate?

Sustained mixed-weapon combat produced these timings across two runs:

| Players in one district | Worker tick p95 | Worst observed tick | Assessment against 16.67 ms |
|---:|---:|---:|---|
| 8 | 3.41–3.60 ms | 5.08 ms | Substantial headroom |
| **16** | **6.14–6.32 ms** | **9.18 ms** | Conservative target for this worker workload |
| 24 | 7.96–8.29 ms | 13.13 ms | More demanding; exceeds implemented cap |
| 32 | 10.72–10.87 ms | 23.61 ms | Occasional missed tick budget |
| 48 | 16.64–16.70 ms | 33.09 ms | At the sustained budget boundary |
| 64 | 21.32–24.34 ms | 36.83 ms | Sustained degradation |

Thus, around **32 players starts showing occasional worker deadline misses, 48 reaches the sustained boundary, and 64 exceeds it** in this scene. This is not a promise that players would perceive no degradation below 32: master serialization, packet loss/latency, richer tracking, map complexity, AI and client rendering can become limiting earlier. The implemented cap is 16.

At 16 combatants, the private full-state stream serialized approximately **13.5–13.7 Mbit/s per worker**; at 64 it reached 36.7–37.5 Mbit/s. Sixteen workers each producing the 16-player workload would therefore generate roughly 216–220 Mbit/s inbound to the master, before transport/encryption overhead—an extrapolation, not a tested or permitted 256-player session. Process RSS was roughly 160–185 MiB without active bot navigation; each worker still loads the city's static collision.

ENet's documented 4095-peer API ceiling is unrelated to practical FPSloppa capacity ([ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)). The CQ admission limit remains 64.

## Measured optimization candidate

A **benchmark-only** variant scopes and encodes once per district, then accounts for delivery to each recipient. It is not enabled in the game. Representative results:

| Workload | Shared-encoding mean / p95 | Modeled component core usage |
|---|---:|---:|
| 16 districts × 4 players, quiet | 7.87 / 10.24 ms | 28.3% |
| 24 districts × 4 players, quiet | 13.45 / 17.06 ms | 45.6% |
| 32 districts × 4 players, quiet | 20.45 / 25.13 ms | 66.0% |
| 48 districts × 4 players, quiet | 37.78 / 45.13 ms | 113.4% |
| 4 districts × 16 players, 32 rockets each | 5.99 / 6.88 ms | 27.8% |
| 8 districts × 16 players, 32 rockets each | 13.24 / 14.16 ms | 58.4% |
| 16 districts × 16 players, 32 rockets each | 31.69 / 34.42 ms | 127.7% |

This suggests **24–32 lightly populated districts might be a useful next design target after shared encoding**, with 24 offering more headroom. It does not demonstrate that larger game sessions work. Logical districts above 16 in this benchmark reuse the existing physical district coordinates/rules; no larger topology, real connections or capture game was built for those measurements.

Production shared encoding needs a district stream plus per-client baseline/generation handling, tested for joins, packet loss and migration. Further gains should come from district-indexed state instead of global deep copies, lean routine worker snapshots distinct from migration payloads, and bounded queue age. Only then should the global client/topology limits be reconsidered and tested on separate machines.

## Reproduction and validation

Keep the measured `69d225d` console package separate from newly built capacity packages. Build a baseline from that checkout, then run this checkout's harness against its binary. The harness repacks the supplied baseline PCK and adds only the benchmark entry point; it does not silently substitute current game scripts.

```sh
python3 tools/cq_gateway/scalability.py --binary Builds/CQExternal/FPSloppaServer.x86_64 \
  --name master-confirm --suite master --districts 4 8 12 16 24 32 --players 4 --repeat 2
python3 tools/cq_gateway/scalability.py --binary Builds/CQExternal/FPSloppaServer.x86_64 \
  --name worker-confirm --suite worker --players 8 16 24 32 48 64 --repeat 2
python3 tools/cq_gateway/scalability.py --suite master --districts 1 4 --players 16 \
  --ordnance 32 --name master-projectiles
python3 tools/cq_gateway/scalability.py --suite master --districts 1 4 8 16 --players 16 \
  --ordnance 32 --shared --name master-shared-projectiles
```

Choose CPU affinity appropriate for the host with `--cpus`. Raw runs remain under ignored `test-results/cq-scale/`; the committed receipt retains the confirmed suites. An early combat pilot was excluded because respawns did not retain the selected stress-test weapon; the corrected worker suite above does.

Capacity and waiting-room checks:

```sh
python3 tools/build_console_server.py --cq-assets --template /path/to/console-template \
  --output Builds/CQCapacity
godot --headless --xr-mode off --path . --script tools/cq_gateway/capacity_rules.gd
godot --headless --xr-mode off --path . --script tools/cq_gateway/capacity_admission.gd
godot --headless --xr-mode off --path . --script tools/cq_gateway/capacity_worker_probe.gd
python3 tools/cq_gateway/waiting_test.py
python3 tools/cq_gateway/external_test.py --binary Builds/CQCapacity/FPSloppaServer.x86_64 \
  --respawn --latency-ms 30 --failure --name capacity-final
```

The private-worker fixture fills a real worker to 16; the waiting-room network fixture uses logical capacity reservations and a real ENet client/master plus three independent console workers. It verifies retirement, input isolation, local room movement/walls, slot reopening and deployment baseline cleanup. These tests do not constitute a full 64-player live match or a headset comfort test.

Validation completed: 24 capacity/race/collision checks, 14 admission/waiting checks, 47 checks against two real console workers, 23 external-worker identity checks and 221 CQ rule/deployment assertions passed. The real waiting-room client completed retirement, local movement and automatic return; two prediction clients also passed the external-worker test with 30 ms added worker RTT, respawns, transfers, reset and expected worker-loss shutdown. The room and disabled gate were rendered and inspected on desktop. The [capacity validation receipt](validation/cq-capacity.json) records outcomes and final console-package hashes. Existing Godot ObjectDB/resource shutdown warnings remain in some fixtures.
