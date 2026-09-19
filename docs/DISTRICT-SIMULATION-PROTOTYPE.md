# Independent district simulation: prototype results

The kilometre map runs as sixteen independent Quake DM authorities, with four bots initially assigned to each. A separate observer renders only its current district. **This is a process-based prototype, not shared-scene multithreading or production multiplayer integration.**

Measured on 2026-09-19: Core i7-12700, Intel Arc A770, Godot 4.7.2 Fedora, Mobile Vulkan, 1280×720, 4× MSAA, observer capped at 120 FPS. Each full run lasts 32 wall-clock seconds after all workers are ready; the first five seconds are excluded from observer frame statistics.

| Requested speed | Achieved district speeds | Observer mean FPS | Frame p95 | Transfer latency | Worker memory |
|---|---:|---:|---:|---:|---:|
| 1× | 1.000–1.000× | 107.3 | 13.65 ms | 63–74 ms | 907 MiB |
| 4× | 3.938–3.997× | 93.3 | 15.42 ms | 30–47 ms | 911 MiB |

At the 4× request, workers completed 126.03–127.90 simulated seconds in approximately 32 wall seconds. Their clock spread was 1.87 simulated seconds: clocks are independent, not globally synchronized. Relative actor timers are rebased on transfer. The active observer's snapshot-age p95 was 46 ms; this is time since the last received snapshot, not measured end-to-end packet latency.

The final 4× run recorded 6,479 damage events, 342 match events and 337 spawns. All 64 actors moved, all districts advanced, and the observer held no more than 5 actors. Unvisited districts sent zero continuous scene snapshots. One statistics update per second from each district remains available to the broker.

The observer tracked approximately 271 MiB of static Godot allocations separately from the workers. The broker received 15.04 MiB across all connections during the run/setup/stop sequence. These counters are not total process RSS or GPU memory. Each process retains the static full-map physics/navigation caches; that memory duplication can be reduced in a later implementation.

## What was exercised

- Real production bot decisions, capsule movement, collision queries, Quake weapons, damage, pickups and respawns inside each authority. No background district was paused or approximated.
- Four scripted gate crossings: district 0 → 1 → 5 → 4 → 0. The harness stages bot -1 near each gate, then ordinary movement triggers export. This bot has controlled health/inventory and temporary invulnerability for the transfer assertions.
- Source escrow, staged destination admission, destination-state snapshot, commit acknowledgement, owner change and subscription switch. No two active authorities own the actor simultaneously.
- Health, armour, ammunition, owned/current weapon, scores/deaths, life serial, velocity, stance/body state, cooldowns and clock-relative deadlines preserved at commit.
- Every prepare and commit is deliberately sent twice. Replays produce acknowledgements without duplicate bodies. Final ownership is audited across all stopped workers: 64 active actors, zero escrow, matching the broker directory.
- A separate eight-actor test rejects the first destination admission, restores the source actor just inside the gate, then retries successfully. Duplicate, stale and wrong-district viewer snapshots are rejected.
- Render triangles are clipped to district rectangles, with lightmap/texture coordinates retained. Only the active district is visible. The observer uses normal avatar rigs and local projectile visuals, including the production two-effect surface illumination budget.

## Interpretation and limitations

The previous monolithic 64-bot run achieved about 0.55× headlessly. Its live 4× request achieved only 0.28× and about 2.1 FPS. This prototype demonstrates that local ownership and parallel authorities can remove that particular monolithic bottleneck. It is **not a controlled measurement of threading alone**: collision/AI target sets are local, only local avatars are animated, game interactions change, and the observer does not reproduce the full hitscan/audio/event stream or player prediction.

Each district still has the existing 256-projectile limit rather than sharing the old global 256 cap. Projectile counts and combat outcomes differ. Independent district DM timers/rounds are not a global match; team objectives, global scoring, late source-district hit credit, sound and remote-player admission are not integrated.

Boundaries are hard partitions. Actors across a gate cannot see or hit each other through the boundary, and outgoing projectiles terminate. An open gate can reveal empty space until the viewer switches districts. A production map needs transition rooms/opaque portals, or overlapping visibility and coordinated cross-border combat. A crowded district still costs one authority; this test does not solve 64 actors gathering in the same district.

The actor pauses briefly during handoff. The destination accepts its current local timeline; no global catch-up occurs. A failed prepare can roll back, but worker crashes or an ambiguous commit timeout stop the experiment. There is no persistent transaction journal, reconnect recovery, trust boundary for public clients, or dynamic load balancing.

Godot’s active scene tree is not safe to manipulate from arbitrary threads, which is why this experiment uses independent engine processes. A thread-based version would require worker-owned data/physics server state and message passing, without concurrent access to the existing arena nodes. [Godot thread-safe API documentation](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html).

The runs completed their functional checks without script errors. Godot reported ObjectDB/resource-in-use diagnostics at shutdown, as in the earlier graphical benchmark; those cleanup diagnostics remain unresolved. Performance figures describe a short local test, not release-build, VR or internet capacity guarantees.

See [implementation and launch commands](../tools/district_sim/README.md), [raw consolidated measurements](validation/district-simulation.json), [1× screenshot](../test-results/district-sim/districts1x.png), and [4× screenshot](../test-results/district-sim/districts4x.png). Production servers, player limits and maplists are unchanged.
