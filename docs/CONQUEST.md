# CQ — CONQUEST experimental base

**Current default:** [81-district campaign](CAMPAIGN-81.md), 128 players globally and 16 per district. The remaining document describes the explicit legacy 16-district prototype and its historical tests.

CQ is a playable, isolated experimental mode on the baked nighttime Vesper city. It uses the existing authoritative server and normal ENet input/prediction, with a separate launch profile and protocol. **The independent district-worker prototype is not the backend of this implementation.** Whole-map simulation and replication still run in one authority; the worker handoff, interest management and recovery work described in [the integration assessment](DISTRICT-SERVER-INTEGRATION.md) remains outstanding. The 64-player setting is an experimental admission ceiling, not a tested claim of 64-human or VR performance.

## Launch and isolation

From this source checkout with Godot 4.7.2, the base assets and prepared Vesper map installed:

```sh
./launch-conquest.sh --legacy --server
./launch-conquest.sh --legacy 127.0.0.1
# Remote player: replace 127.0.0.1 with the CQ server's address.
```

The default UDP port is 7787. Set `GODOT_BIN` to select the engine. Edit [conquest.cfg](../conquest.cfg) for server settings. Additional client arguments, such as `--spectate`, cannot bypass server policy; CQ spectators are disabled. This is a source-tree experimental launcher, not a newly exported client/server distribution. The prepared city caches reference source-tree presentation assets, so ordinary release packages do not include this experiment yet.

`sv_cq_maxclients` is independent of `sv_maxclients`, ranges from 2 to 64 and defaults to 64. `sv_cq_bot_fill` ranges from 0 to that CQ limit and defaults to 0. Ordinary hosting retains its eight-player maximum and ordinary dedicated configuration retains its existing 32-player ceiling. Setting a CQ limit on an ordinary server has no effect. Set `sv_cq_bot_fill 64` for a full local bot population; joining humans replace bots and retain team balance.

CQ server startup requires both the launch profile and a CQ-only configuration. It rejects mixed mode lists and lobby configurations. The launcher supplies `--experimental-cq`, selecting a distinct protocol; ordinary clients cannot join CQ and CQ clients cannot join ordinary servers. The profile remains fixed until process exit. This is an explicit compatibility/opt-in boundary, not proof that an unmodified shell script was executed: a deliberately modified client can reproduce the protocol, like any other client protocol.

CQ uses only the pinned Vesper map. Server votes, lobby entry, mode/map/loadout changes through RCON, team switching and map uploads are disabled. Round end shows results and restarts CQ on the same map. RCON status, bot count, kick, say and restart remain available. The CQ client hides ordinary hosting, spectator and team/vote controls. It can disconnect and reconnect to another CQ server, but must be relaunched normally to play other modes.

## Territories and deployment

District numbering runs left to right, then top to bottom. `H` denotes a homebase:

| | West | | | East |
|---|---|---|---|---|
| North | **01 Red H** | 02 Red | 03 Blue | **04 Blue H** |
| | 05 Red | 06 Red | 07 Blue | 08 Blue |
| | 09 Blue | 10 Blue | 11 Red | 12 Red |
| South | **13 Blue H** | 14 Blue | 15 Red | **16 Red H** |

Each corner homebase's other three districts in its 2×2 block form its fixed perimeter. Initial deployment assigns two balanced teams, up to 32 players each, in eight groups of four per team. At full capacity there are exactly four players in every district. Groups determine initial deployment; subsequent respawns use current ownership. A late arrival cannot deploy in a group district that has become hostile.

## Capture, respawn and victory

- Each district has a stationary 3 m capture circle and a static red or blue flag for its current owner. The flag cannot be picked up. Labels show control, progress, contested state and homebase locks.
- A living, non-spectating attacker in the circle scores one point per second, independent of player count. Perimeters require 10 points; homebases require 30.
- A homebase can accumulate capture progress only while the attacker owns all three of its perimeter districts. Losing a prerequisite clears homebase progress. A perimeter lost on the same update prevents a homebase capture from completing.
- Both teams in the circle pause capture. When the last member of a team leaves or dies, that team's progress resets to zero. Successful capture clears both teams' progress, including the opposing team's accumulated points.
- Circle presence uses the existing KOTH height and world-line-of-sight checks. Dead players and spectators cannot contest.
- Death respawns the player in the nearest currently friendly district, measured by horizontal distance to its center. The existing spawn-clearance and opponent-spacing logic chooses among that district's four spawns. There is no hostile-district fallback if the team has no territory.
- Controlling all four homebases wins immediately. At timeout, the team with more homebases wins; 2–2 is a draw. The supplied configuration uses a 30-minute round. Perimeter count and kills do not break a tie.

## Equipment and radio

UT99 is the fixed default arsenal for this first CQ implementation. Spawn equipment is the normal UT99 impact hammer, enforcer and translocator. A deterministic CQ pickup layout replaces the benchmark's uniformly powerful equipment without altering its baked geometry.

Corner homebases contain rocket launchers, Redeemers, sniper rifles, flak cannons, Kegs of Health and shield belts. The twelve perimeter districts use shock rifles, miniguns, pulse guns, rippers, ordinary health and thighpads. Ordinary pickup/respawn behavior applies. CQ disables the generic paired weapon caches so a perimeter shock-rifle pickup cannot silently grant a sniper rifle. Placement is tied to corner geometry, not the current owning team.

Team radio and team text are routed authoritatively to teammates in the sender's current district and directly gate-connected districts. Connectivity means orthogonal neighbors, not diagonals or a transitive path through the entire city, and does not require friendly ownership of those districts. Enemy players and spectators do not receive the team channel. Spatial voice is also limited to these neighboring districts. General text chat remains global.

## Validation and limits

[Validation receipt](validation/conquest.json) records deterministic rule/geometry tests, real ENet admission, bot replacement and a 64-actor live smoke test. The admission suite verifies both directions of profile rejection, the CQ seat limit, unchanged ordinary-server capacity, server startup without the profile being rejected, and a real CQ client receiving the full 64-actor roster/model catalog.

The final rule suite passed 215 assertions. The final 20.1-wall-second bot smoke test retained all 64 actors; all moved and fired 321 shots in total. It advanced 11.6 simulated seconds (about 0.58× real time), with mean bot processing about 21.5 ms per physics tick. CQ now limits bot equipment/roaming searches to the current district while retaining cross-city objective routes. This remains too slow to certify 64-player performance. The short bot smoke test is not a complete balanced CQ match. This legacy CQ backend uses one authority. The experimental `sv_cq_backend districts` option now provides a public ENet gateway, district-scoped dynamic replication and generation-bound prediction handoffs; see [implementation, live tests and limits](DISTRICT-SERVER-INTEGRATION.md). Static-map rendering remains unchanged. The two-client gateway tests and isolated 64-entry model support do not certify 64-player performance or VR comfort. Shutdown retains the existing Godot/GDExtension ObjectDB/resource diagnostics; validation treats script errors and gameplay assertions as failures.

Reproduce:

```sh
godot --headless --xr-mode off --path . --script deathmatch/tests/conquest.gd
python3 tools/test_conquest_network.py
godot --headless --xr-mode off --path . --script deathmatch/tests/conquest_soak.gd -- --experimental-cq
godot --xr-mode off --audio-driver Dummy --path . --resolution 1280x720 --script deathmatch/tests/conquest_views.gd -- --experimental-cq
```

[Red homebase preview](../test-results/conquest/district-00.png) · [Blue homebase preview](../test-results/conquest/district-03.png) · [Perimeter preview](../test-results/conquest/district-01.png)
