# CQ deployment and VPS tests — 2026-10-13

CQ is live at **87.106.27.237:7777 UDP**, limited to **32 players / 30 Hz**.
CoreCU completed native save-and-exit with successful systemd status and no remaining
native process. Its database/container are stopped and persistent data is retained.
The SWGXR boot target and 05:00 UTC restart timer are disabled. CQ is enabled at boot.
The user opened the provider firewall; a full local client subsequently joined over WAN
and validated the normal map/model readiness barrier.

## Live 32-player test

All 32 independent ENet clients completed. The measured window lasted 120.06 seconds and maintained all 32 players.
Achieved simulation: **29.94 Hz**, against a 30 Hz target.

| Authority category | Median ms | p95 ms | p99 ms |
|---|---:|---:|---:|
| Simulation tick | 16.840 | 21.118 | 22.942 |
| Projectile work (inside simulation) | 0.004 | 1.192 | 1.812 |
| Snapshot build/encode/RPC fanout | 6.497 | 9.149 | 9.962 |
| History | 0.178 | 0.234 | 0.257 |
| Whole authority physics callback | 21.967 | 29.727 | 32.130 |
| Godot engine physics frame monitor | 32.003 | 36.383 | 176.588 |
| Wall tick interval | 33.537 | 38.523 | 39.936 |

Authority CPU averaged 85.8% of one logical CPU; p95 95.9%. Peak RSS was 486.3 MiB. Reserved snapshot fanout averaged 31.5 Mbps (includes the protocol budget allowance, not a wire capture).
The process recorded 1293 additional kernel receive drops in the measured window. Connections remained stable, but p95 engine time exceeded the 33.33 ms budget; capacity has little headroom.

## 64-player attempt and isolated probe

The live fleet failed: 51 distinct players joined and only 16/64 clients completed. Admissions stalled and connections timed out. There was no sustained full-population live profile; this must not be described as a successful 64-player match.

The separate full-map probe held 64 scripted players for 120 simulated seconds at 30 Hz. Including its 3-second warmup, it took 151.24 wall seconds and achieved **24.40 Hz**. Peak RSS: 609.5 MiB.

| Isolated category | Median ms | p95 ms | p99 ms |
|---|---:|---:|---:|
| Simulation tick | 29.130 | 39.588 | 45.199 |
| Simulation excluding projectiles | 29.068 | 39.445 | 45.034 |
| Projectiles | 0.002 | 0.004 | 1.698 |
| Snapshot build | 3.210 | 4.604 | 4.798 |
| Snapshot encode | 6.144 | 9.573 | 9.988 |
| Godot engine physics frame monitor | 55.645 | 64.081 | 69.217 |

The baseline is CPU limited well before exhausting RAM or the 1 Gbps bandwidth allowance.
The authority simulation and engine physics dominate the measured work; snapshot processing adds meaningful cost. These categories do not establish a narrower movement-versus-collision sub-breakdown.

## Test scope and release

- Synthetic clients ran on VPS loopback; only final full-client join validated WAN.
- AI, live XR and rendering were disabled; synthetic tracked head/hand transforms were sent.
- Reserve refill does not simulate physical magazine reload; initial firing is followed by movement/pose workload.
- Engine physics monitor includes callbacks and catch-up batches; overlapping percentile categories must not be added.
- 64-player live test never held all 64 seats; isolated probe bypasses transport admission.

Synthetic clients receive all packets and sample-decode snapshots. The one-process-per-client rerun avoids the receive starvation of the initial multiplexed harness. The 32/64 probes distribute players differently, so their category numbers are not an exact controlled A/B comparison.

Test-only CLI options were removed. Production uses `server.cfg`, CS movement, no bot fill, monolithic frontier CQ and the fixed 200-point rules. Native XR remains disabled for all headless processes.

Deployment and recovery instructions: [tools/frontier_vps/README.md](../../../../tools/frontier_vps/README.md).
Raw reports, per-client exit statuses, authority process sampling and CoreCU shutdown evidence are in this directory.
