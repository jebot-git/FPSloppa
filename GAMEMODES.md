# TF development addition

Optional TF now adds nine classes, distinct badges, VRM disguises, engineering and flag objectives. See [TF.md](TF.md) for rules and setup.

## 0.4v modes

IG, FT and CC rules are documented in [0.4v release notes](docs/RELEASE-0.4v.md). CC disables every pickup through the gamemode, without editing map files. Each mode uses its own `<tag>_maplist`, except INSTAFREEZE, which shares the Instagib list.

# Arena modes and player votes

In-game hosting and offline practice offer all supported modes and allow at most eight players. Dedicated servers select their initial mode and allowed mode votes through configuration.

| Mode | Rules | Score limit |
|---|---|---|
| `dm` | Individual deathmatch | `fraglimit`, default 20 |
| `tdm` | Red vs blue team frags; suicides and teamkills subtract a team frag | `fraglimit` |
| `ctf` | Steal the enemy flag and bring it to your base while your flag is home | `capturelimit`, default 5 |
| `if` | INSTAFREEZE: Instagib railgun combat with Freeze Tag freezing, teammate thawing and team elimination rounds | `fraglimit` (team rounds won) |
| `koth` | Hold the fixed marked hill for one point per second; both teams present pauses scoring | `hilllimit`, default 120 |

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

Base DM/IG/FT/TDM offer the seven Quake source ports; IF shares IG. CC offers four [dedicated remodels](maps/CC/README.md), KOTH four fixed-hill remodels and CTF six CTF Studies maps. Original LibreQuake maps have moved to an optional expansion tested with the standard arena modes. These defaults do not restrict user imports or explicit server maplists.

Custom BSP maps use separated deathmatch spawn locations as fallback flag bases and a central spawn as the hill. Server operators should test custom objective layouts before putting them in a team rotation. Objective coordinates are supplied by the server, so downloaded BSPs retain the host's placements even if cached under a different ID. `tools/place_objectives.gd` regenerates bundled coordinates from baked navigation and world collision; `deathmatch/tests/team_objectives.gd` verifies them.

Assault (AS) is available with the bundled **HiSlop** train map. Enable it through
`sv_gametype` / `sv_gametypes` and `as_maplist`, just like TF. See [AS.md](AS.md).

## IF — INSTAFREEZE

Instafreeze combines standard Instagib combat with Freeze Tag's red/blue teams. Everyone starts with the penetrating one-hit railgun, unlimited ammunition and its normal 1.5-second firing interval. Pickups and physical melee are disabled. Selecting Quake or UT99 weapon variants does not change these rules.

A lethal rail hit freezes the opponent in place instead of killing and respawning them. Frozen players cannot move or attack, and use the existing frozen-avatar effect and HUD thaw indicator. An unfrozen teammate must stay within 1.5 metres for three uninterrupted seconds, with no wall between them. Moving away resets thaw progress. Thawing restores health and the railgun in place, with normal spawn protection. Friendly fire follows `sv_friendlyfire`.

Freezing the entire opposing team awards one team point, followed by the existing three-second Freeze Tag round reset. `fraglimit` counts team rounds won; `timelimit` remains the overall match time limit. Environment deaths and telefrags retain Freeze Tag's existing behaviour.

```cfg
set sv_gametype "if"
set sv_gametypes "ig if ft"
set ig_maplist "qsrc_dm1 qsrc_dm2"
set fraglimit "10"
set timelimit "15"
```

IF uses **exactly the Instagib maplist**: `ig_maplist`, or `maps/ig_maplist.txt` when the setting is empty, with the usual server rotation fallback. There is no separate `if_maplist` or map conversion. Every Instagib arena can be used. Both lobby and in-game votes use this same list. In-game hosts can select **INSTAFREEZE** in Host Match. The mode currently reuses Freeze Tag's Cryostasis music.

Validation: `python3 deathmatch/tests/run_instafreeze_tests.py` covers rules, hosting, maplist selection and three-process ENet replication.

**TB — TITANBALL:** TF classes and Quake loadouts. Red pilots the BA-2 to Blue’s base; Blue stops it. Ashfall Boulevard is the native BSP playtest map. Preparation lasts 60 seconds, then a fixed 10:00 clock with two +3:00 checkpoint extensions. Pilots board with 200 HP, fixed heavy-ordnance hull protection and no cockpit regeneration. See [rules and validation](docs/TITANBALL.md).
