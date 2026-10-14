# 64-connection drop investigation — 2026-10-14

The old failures were transport timeouts under load, not a 64-peer admission ceiling. All 64 transport peers could connect; no capacity rejection or application join timeout explained the departures. Connection-only admission with tracked inputs also succeeded for every client.

## Controlled VPS tests

12 vCPU / 24 GB VPS, isolated candidate bound to loopback UDP 7779. The production 32-slot UDP 7777 service remained active. Each fleet uses 64 separate ENet processes, cached-asset admission and 30 Hz synthetic tracked head/hand input. Full runs move and initially fire; controllers do not reload, so these are not continuous weapon-saturation tests. No AI or rendering. Clients stay 155 seconds; profiler runs 120 wall seconds after 64 players are present.

| Candidate | Clients completing | Median RTT* | Achieved simulation Hz |
|---|---:|---:|---:|
| Connection-only, no simulation/snapshots | 64/64 | 13 ms | Not a simulation measurement |
| Full simulation/snapshots, no firing, old polling/buffer | 23/64 | 283 ms | 26.43, population drops |
| Physics-step polling, stock receive buffer | 58/64 | 34 ms | 24.11, population drops |
| Physics-step polling + requested larger buffer | 64/64 | 37 ms | 21.80, all 64 retained |

*Median sampled admitted-peer RTT while population is at least 58; not an end-to-end input latency measure. Raw logs and fleets are in `raw/`. Different surviving populations make simulation Hz across these rows unsuitable as an optimization speedup comparison.

## Default-behavior confirmation

The final packaged candidate uses ordinary automatic idle polling plus the base physics-step poll; no manual trace-poll switches were supplied. All 64 clients completed 155 seconds, and every sample in the 120-second profile had 64 players. Achieved simulation rate was 21.07 Hz. The effective receive buffer was 425,984 bytes. The socket still counted 26,951 dropped UDP datagrams (including the initial simultaneous connection burst), so the fix establishes connection stability rather than zero packet loss. This reproduces the successful diagnostic result with production-default code. See `raw/default-fixed/64/{report.json,server.log,fleet/fleet.json}` and `summary.json`.

## Cause and correction

The overloaded engine ran as many as eight physics steps between idle-frame multiplayer polls. This starved reliable traffic/ACK service and inflated loopback RTT. Polling multiplayer on the main thread before each active dedicated physics step removed most of that delay, but the socket's 212,992-byte receive buffer still overflowed under bursts and clients continued to time out.

The native helper requests SO_RCVBUF = 4 MiB for the authority's own bound UDP socket. This VPS clamps the request; its effective reported buffer rises from 212,992 to 425,984 bytes. The combined change kept 64 peers alive for the complete diagnostic run. No kernel sysctl, timeout policy, physics backend or system service was changed. Kernel packet drops can still occur; successful transport does not imply zero packet loss.

The fix retains automatic idle polling and adds a main-thread poll between physics steps. Socket tuning logs requested and actual sizes at startup and fails gracefully on unsupported platforms. Both features have separate regression switches. The native helper's real-socket test verifies selection by port, isolation between sockets and harmless absence; frontier integration also passes (existing fixture cleanup warnings remain).

## Limits

Stable connections do not establish a sustainable 30 Hz simulation at 64 players. The 64-slot setting remains an unsupported performance option. These loopback fleets share CPU with the authority, bypass downloads and do not test WAN conditions. The live production service has not been replaced by this candidate.

Further assessment: [remaining blockers, ranked performance opportunities and complete server rewrite](CAPACITY-EVALUATION.md).

Subsequent [movement-attribution tests](../movement-attribution-20261014/REPORT.md) retained 64 with staggered admissions but lost peers in new simultaneous bursts, with recording enabled and disabled. The successful runs above remain valid; robust repeated burst admission is still an open release gate.
