# Independent district simulation prototype

This opt-in experiment runs the existing Quake DM simulation in **sixteen separate headless Godot processes**, initially four bots each. A seventeenth process acts as the local broker and a snapshot-driven observer. The observer renders and animates only its current district. This is not a change to production servers or ordinary clients.

The existing scene-tree movement, physics queries, combat and bot AI cannot simply be called concurrently on the same Godot scene tree. Process isolation gives each district its own scene tree, physics world, navigation state, and main thread without rewriting those systems into a data-only threaded simulator. A future thread implementation would need that separation at the engine-server/data level; this prototype does not claim to implement it.

## Run

Run from the repository root with the base game assets and the kilometre map caches installed. To regenerate those, first follow `maps/Benchmark1km/README.md`.

```sh
godot --headless --xr-mode off --path . --log-file /tmp/district-prepare.log --script res://tools/district_sim/prepare.gd

godot --xr-mode off --audio-driver Dummy --path . --resolution 1280x720 --log-file /tmp/district-view.log --script res://tools/district_sim/run.gd -- '{"zones":16,"seconds":32,"speed":1,"name":"districts1x","port":29344}'

godot --xr-mode off --audio-driver Dummy --path . --resolution 1280x720 --log-file /tmp/district-view4x.log --script res://tools/district_sim/run.gd -- '{"zones":16,"seconds":32,"speed":4,"name":"districts4x","port":29345}'

# Fault injection: reject the first admission, roll back, and retry.
godot --xr-mode off --audio-driver Dummy --path . --resolution 1280x720 --log-file /tmp/district-rollback.log --script res://tools/district_sim/run.gd -- '{"zones":2,"seconds":12,"speed":1,"name":"rollback2","port":29346,"reject_once":true}'

python3 tools/district_sim/report.py
```

`seconds` is **wall time** here, unlike `tools/km_benchmark/simulate.gd`, where it means simulated time. The 4× setting uses 240 physics ticks/second with a 1/60 s simulated step. Workers start behind a readiness barrier. Every district continues simulating at the requested rate regardless of which district is viewed. The observer remains at normal wall-clock time, with a 120 FPS cap.

The broker launches and stops its worker processes. Ports bind only to `127.0.0.1`; this is a trusted local test protocol, not a public network service. Output, per-worker logs and screenshots go to `test-results/district-sim/`.

## Ownership and synchronization

Each worker owns only its local actors, eight pickups and local projectiles. It retains the static full-map collision and navigation caches for convenience; distant actors do not exist in that worker. Actor IDs are globally unique and the broker maintains the ownership directory. There is no shared mutable scene-tree state between processes.

Only the subscribed district emits continuous scene snapshots, at up to 20 Hz wall time. Other districts emit one small statistics message per second. A destination also supplies a complete snapshot when preparing/committing an arrival. Scene packets include local actors, positions/velocity, inventory, health, armour, deaths/scores, timers, avatar references, pickup availability/respawn timers, projectiles and the local round clock. Sequence numbers reject duplicate/stale/wrong-district viewer updates. Socket queues and framed packet sizes are bounded; deserialization does not enable Objects.

An actor crosses a district boundary through ordinary movement before transfer begins:

1. The source exports the actor, removes it from active simulation, and holds its state in escrow.
2. The destination validates admission and stages the actor, without creating a second active body. It acknowledges a complete destination snapshot.
3. The broker orders commit. The destination restores the actor and returns the committed snapshot.
4. The broker changes the owner, releases source escrow, and switches the tracked actor's observer subscription. Replayed prepare/commit messages are idempotent.

The actor is paused during this local handoff. Absolute deadlines are encoded relative to the source clock and rebased to the destination clock, retaining their remaining simulated duration. Health, inventory, scores, serial, velocity, stance and relevant movement state are retained. Local AI planning is regenerated in the destination; stale enemy references/path plans are not carried over. Independent district clocks are not globally lock-stepped.

A refused prepare cancels the destination and restores the source actor just inside the gate, with zero velocity to avoid immediately crossing again. The test then retries. A connection failure or ambiguous commit timeout stops the experiment; there is no durable crash recovery or leader election.

For reproducible transfers, the harness stages bot -1 beside four gates at fixed wall-time intervals and commands it to walk across. This bot temporarily gets protected health/inventory test values. The other 63 bots use normal AI; the transfer test is not player-input prediction testing. The visible client is an observer, not a playable network client.

## Rendering and gameplay limits

`prepare.gd` clips the baked BSP render triangles to all sixteen district rectangles, interpolating UVs, normals, colour and lightmap coordinates. The viewer displays one such district and at most its local actors/pickups/projectiles. Production avatar rigs, projectile visuals and the two-effect surface illumination budget are used locally. The observer does not replicate the full hitscan/audio/event stream or run player prediction.

District boundaries are hard simulation/visibility boundaries in this prototype. Cross-district hitscan cannot acquire targets, and projectiles are terminated when they leave their owning district. Existing source-district projectiles are not carried with a departing actor. Maps with open gates can expose empty space beyond the rendered district until the view switches. The decorated kilometre city now has opaque holographic gates. They hide ordinary direct views across the boundary; a production design still needs acknowledged transitions and tests for camera/head motion, plus a defined cross-border combat policy.

Only independent DM is exercised. There is no global team objective, shared match-end authority, cross-district sound, network reconnect/admission protocol, adaptive load balancing or migration of a crowded district. Sixty-four actors gathering in one district would again burden one authority. Each process retains the existing 256-projectile limit, so the aggregate projectile budget differs from the monolithic benchmark. Results therefore demonstrate this architecture's feasibility, not an identical-gameplay threading speedup.

The main tradeoff is increased memory and process count. Consult [the measured report](../../docs/DISTRICT-SIMULATION-PROTOTYPE.md) before using this as a basis for integration.

Server/client integration readiness, local API probes and the recommended optional-backend design are documented in [DISTRICT-SERVER-INTEGRATION.md](../../docs/DISTRICT-SERVER-INTEGRATION.md). No production launch flag is added by that assessment.
