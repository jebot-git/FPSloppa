## 0.4v modes

IG, FT and CC rules are documented in [0.4v release notes](docs/RELEASE-0.4v.md). CC disables every pickup through the gamemode, without editing map files. Each mode uses its own `<tag>_maplist`.

# Arena modes and player votes

In-game hosting and offline practice always use **DM** and allow at most eight players. Dedicated servers can use DM, TDM, CTF or KOTH and opt into up to 16 connections (including spectators).

| Mode | Rules | Score limit |
|---|---|---|
| `dm` | Individual deathmatch | `fraglimit`, default 20 |
| `tdm` | Red vs blue team frags; suicides and teamkills subtract a team frag | `fraglimit` |
| `ctf` | Steal the enemy flag and bring it to your base while your flag is home | `capturelimit`, default 5 |
| `koth` | Hold the marked hill for one point per second; both teams present pauses scoring | `hilllimit`, default 120 |

All modes also obey `timelimit` in minutes. Team modes end with the team result on the scoreboard; tied team scores at timeout are a draw. Flag carriers drop their flag on death, disconnect or team change. Touch your dropped flag to return it; unattended flags return after 30 seconds. Flag interaction and hill occupancy check distance, height and walls. Spectators cannot participate in objectives or combat.

Teams are assigned automatically to keep numbers balanced. Red/blue name labels and HUD team indicators identify players; CTF banners have different emblems as well as colours. CTF respawns use the home side of the arena. Friendly fire defaults to off; `sv_friendlyfire "1"` enables it. Team assignment survives ordinary map rotation.

## Dedicated configuration

```cfg
set sv_gametype "ctf"              // Initial mode.
set sv_gametypes "dm tdm ctf koth" // Optional modes available for player votes.
set sv_maxclients "16"
set fraglimit "30"
set capturelimit "5"
set hilllimit "120"
set timelimit "10"
set sv_friendlyfire "0"
set sv_votes "1"
set sv_maplist "lqdm3 lqdm6 lqdm5"
```

Omit or leave `sv_gametypes` empty to lock the server to `sv_gametype`. A nonempty list must include the initial mode and contain only valid mode names. The game-mode vote control appears only when more than one mode is allowed. Map rotation retains the current game type.

## Teams and voting

Open **Menu → Teams & Votes** on desktop or VR. Players can switch to the smaller team; switches reset their inventory and position, drop carried flags, and have a 30-second cooldown. They do not grant new spawn protection. A successful **balance teams** vote reshuffles active players using their current frag ranking in alternating pairs, keeping team sizes within one. Scores already earned by each team stay with that team.

**Vote: Map** offers the server's available bundled and imported arenas. **Vote: Mode** offers only its configured mode list. A passed map vote changes immediately and uses the existing verified BSP download flow. A passed mode vote starts a fresh round on the current map and assigns teams for the new rules. Spectators stay spectators. If a voted map is in the rotation, rotation continues from that entry; otherwise it continues from the previously selected rotation position.

Proposals last 25 seconds and require a strict majority of the active human players present when called. The proposer votes yes automatically. Spectators and late arrivals cannot vote, each player has one ballot, and proposals have a server-wide 60-second cooldown. Votes end when the round ends or a map transition begins. Set `sv_votes "0"` to disable voting. Offline practice does not use votes.

## Maps

The eight bundled [LibreQuake arenas](MAPS.md) have authored red-base, blue-base and hill coordinates in `deathmatch/maps/manifest.json`. These are adaptations of freely licensed deathmatch layouts, not original symmetrical CTF maps. Connected walkable routes, objective floors and multiple home-side spawns are checked automatically; competitive balance still benefits from playtesting. Hyperborea, Transport Tubes and Ghost Quarter were added for this update.

Custom BSP maps use separated deathmatch spawn locations as fallback flag bases and a central spawn as the hill. Server operators should test custom objective layouts before putting them in a team rotation. Objective coordinates are supplied by the server, so downloaded BSPs retain the host's placements even if cached under a different ID. `tools/place_objectives.gd` regenerates bundled coordinates from baked navigation and world collision; `deathmatch/tests/team_objectives.gd` verifies them.
