# Online hit registration and latency tests

FPSloppa uses server-authoritative weapon cooldowns, ammunition, collision and damage. Hitscan shots now carry the server timeline corresponding to the shooter's smoothed remote-player view. The server interpolates its per-physics-tick position history, instead of selecting a coarse 50 ms sample using half the ping. Rewind is bounded by server-measured RTT plus 120 ms for snapshot/render delay, with a hard 300 ms ceiling. Nonfinite, future or excessively old requests cannot extend that window. Local hosts and bots use current authoritative positions.

History records player life/teleport serials. Shots cannot interpolate through respawns or long teleports, and spectators do not absorb shots. Map collision and doors use their current server state: compensation does not rewind the whole environment. Matching the rendered view, accounting for interpolation and bounding history follow the principles described in [Valve's networking documentation](https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking) and [lag-compensation implementation](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/player_lagcompensation.cpp).

Projectiles retain real travel time and server collision. Sweeps account for projectile radius and target motion within each physics tick, with thin-wall, initial-overlap and side-cover checks. Client visuals extrapolate for at most 100 ms between updates, stop at walls and smooth small corrections. Projectile end markers and snapshot sequence watermarks prevent delayed/duplicate messages from restarting a projectile or removing a newer spawn. Only the server applies damage; client visual extrapolation cannot create hits. Projectiles are not retroactively fast-forwarded through players to compensate for uplink delay, so normal leading still matters.

Snapshots use bounded FastLZ compression over their existing unreliable ordered channel. This eliminated the oversized-packet warning in the two-player test scenario. It is not a guarantee that larger matches never require fragmented packets. The protocol changed to `fpsloppa-17-lag-compensation`; clients and servers must use the same build.

## Reproduce

Run from the source checkout with Godot 4.7.2 available; set `GODOT_BIN` if necessary:

```sh
python3 tools/validate_lag_network.py
python3 tools/validate_lag_network.py --rtt 100 --jitter 15 --loss 0.02
```

The runner starts a dedicated ENet host and two independent clients behind a seeded, bidirectional UDP proxy. It needs localhost UDP ports 27787–27789. The default matrix uses 20, 40, 60, 80 and 100 ms **round-trip latency** (half each way), then jitter/loss/duplication and an asymmetric 20 ms uplink / 80 ms downlink. OS scheduling and ENet polling add a few milliseconds to measured ping. `--rtt 200` tests 100 ms each way. `--resume` explicitly continues the completed profiles in the existing summary; omit it for a fresh full run.

The shooter aims at the actual smoothed remote model. Pistol and railgun targets strafe sinusoidally up to 9 m/s; plasma and rocket targets are stationary to test projectile transport independently of aim-leading skill. Each phase compares authoritative shots with damage registrations and both clients must observe damage and projectiles. Railgun shots into a wall must do no damage. Loss may discard a short fire input before the server accepts it; the hit count denominator is accepted server shots, not trigger attempts.

Additional Godot scripts under `deathmatch/tests/`:

- `lag_reliability.gd`: 200 moving-target cases, historical interpolation, spawn boundaries, bounded timestamps, spectators and cover; reproduces the old algorithm's misses.
- `hit_detection.gd`: grazing capsules, radius sweeps, crossing targets, different-time path crossings, thin walls, initial overlap and no repeat damage for rockets, plasma and BFG.
- `projectile_ordering.gd`: duplicate/reordered spawn, snapshot and end messages, plus bounded visual extrapolation.
- `map_transfer_guards.gd`: the shared 25 MB cap and malformed/out-of-order transfers.

Detailed logs and machine-readable results go into `test-results/lag/`. These automated tests establish behavior for the scenarios above. They do not replace WAN/headset playtesting, test 32-player load, measure end-to-end controller-to-photon latency or cover every combination of movement, maps and simultaneous explosions. The headless fixtures retain Godot ObjectDB shutdown warnings; test failures and script errors are checked separately.

## Naming and asset limits

The project name, main menu, scoreboard, model window, default server name, Android display labels and new export filenames use **FPSloppa**. Android application IDs and signing identities stay unchanged so existing installs and external asset folders remain usable. Desktop startup copies existing callsign/control, tracking and avatar-selection configuration from the legacy user-data folder when the corresponding new file does not exist.

BSP imports, player uploads and host downloads accept at most **25,000,000 bytes**, matching the VRM cap. Oversized files/offers are rejected before map parsing or receiving their content. Existing generated and base maps fit within this limit.

## Recorded results (2026-09-10)

| Configured RTT | Link conditions | Measured RTT | Registered / accepted shots |
|---|---|---|---|
| 20 ms | steady | 27–27 ms | 30/30 |
| 40 ms | steady | 48–49 ms | 30/30 |
| 60 ms | steady | 68–69 ms | 30/30 |
| 80 ms | steady | 89–90 ms | 30/30 |
| 100 ms | steady | 110–110 ms | 30/30 |
| 50 ms | ±10 ms jitter, 1% loss, packet duplication | 56–61 ms | 30/30 |
| 100 ms | ±15 ms jitter, 2% loss, packet duplication | 104–110 ms | 30/30 |
| 100 ms | ±5 ms jitter, 1% loss, packet duplication; 20/80 ms asymmetric | 110–111 ms | 30/30 |
| 200 ms | ±10 ms jitter, 1% loss, packet duplication | 203–212 ms | 30/30 |

All nine cover checks and both clients in each profile passed. The core 20–100 ms matrix registered 240/240 accepted shots; the extra 100 ms-per-direction stress case registered 30/30. Deterministic moving-target tests registered 200/200; the old rewind formula missed 188/200 in that demanding fixture. These are controlled test counts, not a predicted human accuracy rate.

The exported-client smoke test runs for ten seconds with `-- --quit-after-seconds 10`. This uses the same graceful music/microphone shutdown as the Quit button and window close; Godot’s immediate `--quit-after` flag bypasses that cleanup interval.
