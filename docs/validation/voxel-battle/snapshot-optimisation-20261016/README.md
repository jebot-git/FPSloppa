# Snapshot compression and detail relevance — 16 October 2026

Implemented native lossless record deltas and distance-based avatar/reload detail for the **64-player production target**. All four final 120-second fixed-rate VPS cases passed. The live service was not redeployed or restarted.

The same deployment VPS and tracked-hand/reload workload were used as the preceding standalone matrix, after eight seconds of warm-up. Input frequency matches the configured tick. Normal ammo/damage and all four current T1 classes are used. These are loopback synthetic measurements, not WAN or continuously moving human VR pose recordings.

| Players / Hz | Before payload Mbit/s | After Mbit/s | Reduction | Before / after p95 tick ms | Before / after CPU (% of one core) |
| --- | ---: | ---: | ---: | ---: | ---: |
| 64 / 30 | 129.1 | 46.3 | 64.2% | 2.49 / 11.02 | 13.7 / 21.3 |
| 64 / 60 | 131.7 | 52.4 | 60.2% | 2.22 / 8.39 | 18.8 / 25.4 |
| 128 / 30 | 464.4 | 466.4 | -0.4% | 5.30 / 5.14 | 32.9 / 33.3 |
| 128 / 60 | 470.5 | 464.8 | 1.2% | 4.37 / 4.43 | 40.8 / 41.2 |

The 64/60 result is a **60% outbound application-payload reduction**, at the cost of additional codec CPU and baseline memory. Peak server RSS rose from 324.4 to 373.3 MiB. Its p95 callback was 8.39 ms and maximum 12.72 ms against a 16.67 ms tick budget. At 64/30 the p95 was 11.02 ms and maximum 19.12 ms against 33.33 ms. CPU includes the whole server process; callback timing does not include every ENet receive/flush operation. Payload figures exclude ENet/UDP/IP overhead.

Above 64 ready connections, the server deliberately uses the previous **shared full-snapshot path**. Thus the 128-player rows demonstrate preserved capacity, not personalised compression gains; their small traffic differences reflect different join order/combat outcomes. The 128/60 run held 60.000 Hz, with p95 4.43 ms and maximum 8.49 ms.

The implementation parses/indexes each authority snapshot once. Coarse player and tactical state remain complete for long-range combat, team markers, spotting and menus. Tracked avatar/controller detail enters at 128 m and exits beyond 160 m. Nearby remote players retain equipped-weapon physical reload detail; the owner retains complete physical reload state. This is detail relevance rather than complete spatial interest management or enemy-position secrecy.

The `row-xor-fastlz-v3` capability is negotiated in HELLO/WELCOME. Records match by section, entity identity and weapon slot, preventing insertions/despawns/LOD changes from shifting every later delta. Unchanged records reference the acknowledged baseline; changed records use lossless XOR data followed by FastLZ. Clients acknowledge only complete, validated reconstruction. Eight-frame caches, explicit missing-baseline requests and periodic independent frames provide recovery. Older native client libraries advertise no new capability and continue receiving full FastLZ frames.

Per-peer preparation uses a soft budget of half a simulation tick. Remaining recipients receive one shared independently compressed full snapshot once that budget is reached. Priority rotates between publications. This preserves state delivery while exchanging bandwidth for CPU headroom. In the final 64/60 run, 2,625 recipient deliveries (about 1.7%) used this budget fallback. Both `sv_cq_snapshot_delta` and `sv_cq_snapshot_relevance` default to 1 and can be disabled independently.

The unbounded prototype reduced traffic but regressed the experimental 128-player runs to 29.42/57.04 Hz at configured 30/60 Hz; `prototype-unbounded.json` retains those results. It is not the final default. Personalised processing above 64 requires further scaling work; the final shared-path fallback avoids shipping that regression.

The additional 60-second, 64-player test with **adaptive tick and destruction enabled** passed at 59.999 Hz, with 0 tick fallbacks and 0 recoveries. p95 callback was 10.44 ms. This exercises the enabled configuration, not a worst-case collapse stress test.

Validation passed 336 native checks covering record insertion/respawn, byte-exact reconstruction, size changes, malformed/bounded decoding, stale/forged ACKs, cache expiry, ownership filtering and relevance hysteresis. The real Godot client passed new-codec negotiation, full-frame fallback and a deterministic 10% packet-loss proxy with a one-second ACK blackout; it recovered automatically and completed 60 valid frames (worst observed gap 551 ms in the final fault test). The tracked-hand arena fixture passed shooting, grenades, NVG, death/gibbing, respawn, squads, team changes/presentation and jetpack. Its settled walking window had maximum prediction error 0.148 m and no corrections or hard resets. Linux client and server were built; other platform binaries need their normal native rebuild or use the negotiated full-frame fallback.

All final capacity cases admitted the requested population, fired every class and completed without disconnects, input rejection, input queue overflow or projectile pool overflow, with approximately 20 complete snapshots/s per peer. The 128/60 run recorded 83 additional server UDP receive drops during socket-monitor sampling; the other measured windows recorded zero. Delivery gates still passed. Exact snapshot gaps, process resource samples, configuration, source/binary receipts and socket-monitor coverage are included alongside the reports. Fixed-rate comparisons disable adaptive tick and destruction to match the preceding matrix. Test profiles are ephemeral and persistence is disabled; real voice/avatar transfers, high-entropy human VR movement, bot navigation and collapse bursts are outside this workload. Single passes and changed peer trajectories mean these are not bit-identical replays.

`results/comparison.csv` and `results/comparison.json` contain the before/after data. The baseline is `../standalone-capacity-20261016/`. Reproduce with `tools/standalone_server/run_matrix.py --snapshot-mode both` and `tools/standalone_server/compare_snapshots.py`; add `--adaptive --destruction` for the default-configuration case. `source.json`, `server-build.json`, `benchmark-sha256.json` and `live-before.txt`/`live-after.txt` record provenance and live-service invariance.
