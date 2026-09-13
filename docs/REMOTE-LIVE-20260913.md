# Remote live network validation — 2026-09-13

The current console server, including the Impact Hammer jump fix, was deployed and tested at **45.147.228.101:27777**, then stopped at the user’s request. It was left in TITANBALL on Ashfall with Quake loadout and zero clients/pending joins. Functional checks passed; latency outliers and eight UDP drops remain performance findings.

## Deployment

- Remote directory: `/home/blux/FPSloppa-tests/20260913T180803Z`; process 109676; screen `fpsloppa-test-20260913t180803z`.
- Protocol `fpsloppa-35-mode-loadouts`; Godot 4.7.2 console-only runtime.
- RCON listens only on remote loopback 27778, reached through an SSH forward on local 27878.
- Archive verified before extraction; deployed binary/PCK/Ashfall hashes also verified. Resource pack SHA256: `d43e188e7e86a5114e29a9e0a4aff94f87ad67884dcbcbdd64412cb84d00e8ac`.
- Production UDP 7777 had no listening game server before deployment. Existing unrelated remote sessions were preserved.
- The test package adds current Ashfall BSP/navigation to the base-manifest assets and explicitly enables its TB maplist. The final mode is runtime state; the staged startup config initially uses DM for testing.

## Live clients

Twelve independent ENet players plus one visible Vulkan Mobile spectator rotated through all eleven modes. Four players additionally supplied validated synthetic body/face poses. Each client's active state, roster, map, mode and log freshness were checked throughout each hold. All thirteen clients exited successfully, with no script or engine errors. A demo and a verified screenshot were saved.

| Mode | Map | Loadout | Continuous hold | Median / maximum client ping |
|---|---|---|---:|---:|
| DM | qsrc_dm3 | doom | 20 s | 37 / 400 ms |
| TDM | qsrc_dm6 | quake | 20 s | 37 / 419 ms |
| CTF | ctf_crownreach | ut99 | 20 s | 38 / 400 ms |
| KOTH | koth_alichar | doom | 20 s | 37 / 382 ms |
| IG | qsrc_dm6 | doom | 20 s | 38 / 418 ms |
| IF | qsrc_dm6 | doom | 20 s | 49 / 400 ms |
| FT | qsrc_dm3 | doom | 20 s | 51 / 383 ms |
| CC | cc_basement | doom | 20 s | 50 / 416 ms |
| TF | tf_vesper | quake | 20 s | 50 / 418 ms |
| AS | as_frigate | ut99 | 20 s | 49 / 402 ms |
| TB | tb_ashfall | quake | 100 s | 50 / 403 ms |

These short holds validate networking and mode changes, not completed matches or competitive balance. TITANBALL's hold extends beyond its 60-second preparation interval. Tracked poses were synthetic; no physical headset was tested.

## Other checks

- Empty-cache client: downloaded 17,431,609 bytes, admitted in about 19.6 seconds, then moved for a verified 15-second hold. The downloaded BSP used a content-addressed custom map ID.
- Capacity: all 16 moving/firing clients retained for 60.43 seconds; all exited zero.
- A 17th connection was explicitly rejected with `Server full (16/16 players)`.
- Two clients rejoined successfully after capacity clients disconnected, holding for 15 seconds. This checks released capacity/re-admission, not reconnection of the same live process.
- Synthetic Opus: teammate received 95 public and 97 team packets; opponent received 100 public and zero team packets; sender received no echo. Both recipients decoded audio successfully.

## Performance findings

Server CPU: median 51.3%, p95 78.7%, peak 96.8% of one CPU core. Peak sampled RSS: 210.2 MiB; process high-water mark: 223.3 MiB. Measurements include joins and mode transitions over 825 one-second samples.

Most gameplay clients were around 30–70 ms, but client 11 repeatedly showed approximately 300–400 ms. High-latency peers also appeared in simpler capacity and two-client rejoin tests, so the symptom is not exclusive to full-body traffic or maximum load. The cause remains unresolved; a functional pass is not a clean latency assessment.

Eight UDP receive drops first appeared at **18:41:56 UTC during the 13-client TITANBALL segment**. They were noticed when checking capacity metrics, but timestamp analysis places them earlier. The capacity/rejoin/voice phases added no more drops. No client disconnected and the server logged no runtime diagnostics.

## Artifacts and cleanup

- [Machine-readable receipt](validation/remote-live-20260913.json).
- Full receipts/logs: `test-results/remote-live/20260913T180803Z/`.
- Demo: `test-results/remote-live/20260913T180803Z/remote-clients/live.fpsdemo` (about 148 MiB).
- Live screenshot: `test-results/remote-live/20260913T180803Z/remote-clients/live-dm.png`.
- Auxiliary client receipts: `test-results/remote-current/live-20260913-*`.

All test client processes and the temporary resource monitor were stopped/reaped. The isolated server has been terminated at the user’s request; its game/RCON ports and local RCON forward are closed. SSH credentials were supplied through the terminal password prompt and were not written to deployment files.
