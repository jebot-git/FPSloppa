# Resident authority core — 2026-10-14

Implemented the selected architecture as a separate host: host-independent resident C++ authority, Godot ENet transport and Godot/Jolt scene integration. The existing script authority loop is not called by this host. **This is an infantry prototype, not a feature-complete CQ rewrite or a production deployment.**

## Two-minute local transport/physics runs

Godot 4.7.2, Jolt, portable Jammy-built dedicated extension. Each run used a separate headless server and real ENet client APIs, a small collision fixture and synthetic desktop commands. Clients moved, jumped, changed stance, fired carbine projectiles upward and reloaded. There was no rendering, XR, AI, vehicles or full-map/CQ simulation. The roster stayed alive and active throughout.

| Clients | Seconds | Tick Hz | Callback p50 ms | p95 ms | Max ms | Accepted inputs | Accepted / minimum offered | Shots |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 32 | 120.004 | 29.999 | 1.038 | 1.324 | 2.605 | 111,612 | 96.89% | 12,352 |
| 64 | 120.006 | 29.999 | 2.083 | 2.532 | 4.975 | 223,487 | 97.00% | 24,704 |

Both cases: 3,600 measured ticks; no rejected inputs, queue overflow, projectile saturation, deaths, unexpected disconnects or malformed assembled frames. Every client sent at least 3,600 input commands. Minimum complete frames per client: 2,391 / 2,393, against 2,400 nominal publications. The input-delivery gap is real: short startup smokes accepted only about 30% of inputs, while the two-minute runs accepted about 97%. Its exact transport cause has not been isolated. These results do not establish lossless input delivery or acceptable join latency.

## Mean callback breakdown

These means are per measured tick. The residual is a subtraction, not a separately instrumented transport category.

| Category | 32 clients ms | 64 clients ms |
|---|---:|---:|
| Input consumption, movement, posture/edge queries and Jolt character collision | 0.705 | 1.319 |
| Weapon scheduling, projectile queries and impacts | 0.115 | 0.227 |
| Native player-frame serialization | 0.002 | 0.004 |
| Remaining adapter, sampling, compression and RPC enqueue work | 0.184 | 0.439 |
| Total callback mean | 1.006 | 1.989 |

Movement/collision accounts for about 66% of the 64-client callback in this fixture. Physics work and ENet polling performed outside the callback are excluded. Child percentiles must not be added together. No full-CQ speedup is claimed: previous VPS tests include the jungle map, tracked VR input, class/mode/vehicle state, production snapshot format and fine attribution. This local host has a much smaller feature/workload surface and has not been run on the VPS.

## Correctness and integration checks

- Standalone C++ suite: 249,035 checks, including a seeded 64-player / 3,600-tick deterministic replay, malformed/truncated binary packets, bounded queues, short input edges, lifecycle guards, reload/salvo accounting, friendly-fire isolation, kill attribution and detached frames.
- The same standalone suite passed AddressSanitizer and UndefinedBehaviorSanitizer in the Jammy toolchain container with no sanitizer findings. The host system lacks its GCC ASan runtime, so the container was used. The compiler's debug variable-tracking note in the log is not a sanitizer finding.
- Original Godot/Jolt functional suite: 49 checks. Extended afterward to 592 passing checks, including 180 movement frames compared with the actual shared `cs16.gd` reference, posture/ceiling clearance, hitscan collider identity, copy isolation, reconnection and removal of scene bodies.
- Six existing regressions passed with the expanded extension: player simulation, snapshot preparation, immutable snapshot buffers, native backend, network delivery and fire delivery. The player fixture retains its previously documented cleanup diagnostic (21 ObjectDB instances / 8 resources), accepted by the existing regression policy; no new errors were accepted.
- The final hardened runner was checked with both 32/64 five-second smokes. It additionally checks steady population and offered input rate, requires at least 90% input acceptance for runs of 30 seconds or longer, verifies source/library stability during a run and cleans child process groups on termination. The two-minute reports also meet these added numerical gates. Smoke timings are not used in the table above.

## Migration boundary and remaining work

Persistent typed state replaces the Dictionary-backed authority pattern for the tested infantry pipeline. The native class is registered in both build profiles and built by both SCons/CMake. Scene/physics work remains on the owner engine thread; this is not a 12-vCPU parallelisation result.

Production migration still requires VR poses and physical reloads, jetpack, complete collision/weapon and injury parity, CQ classes/abilities/vehicles/objectives, production admission/skin synchronisation and full entity replication. The prototype uses a new player-only wire; it cannot serve current game clients. Utility inventory and XR payloads are explicitly rejected. See [architecture, constraints and reproduction](../../../../tools/authority_core/README.md).

The live VPS service was not changed or suspended during this work. Existing uncommitted experiments were preserved. No commit or push was performed for this new prototype.

## Evidence

[Full summary](summary.json), [32-client report](32-server.json), [64-client report](64-server.json), [extended functional checks](functional-extended.log), [sanitizers](sanitizers.log), [existing regression results](regressions/summary.json), [hardened runner smoke](harness-smoke-summary.json), [native build receipt](native-build-receipt.json).

The full-run summary also contains hashes of ignored SCons `.os` objects because its initial collector used a broad glob. Those are provenance records, not required source artifacts. The final runner limits source hashing to source files and includes its own harness plus the library hash.
