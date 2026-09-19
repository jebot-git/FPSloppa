# TF development addition

Optional TF now adds nine classes, distinct badges, VRM disguises, engineering and flag objectives. See [TF.md](TF.md) for rules and setup.

## 0.4v modes

IG, FT and CC rules are documented in [0.4v release notes](docs/RELEASE-0.4v.md). CC disables every pickup through the gamemode, without editing map files. Each mode uses its own `<tag>_maplist`, with INSTAFREEZE falling back to the Instagib list unless its own list is supplied.

# Arena modes and player votes

In-game hosting and offline practice offer all supported modes and allow at most eight players. Dedicated servers select their initial mode and allowed mode votes through configuration.

| Mode | Rules | Score limit |
|---|---|---|
| `dm` | Individual deathmatch | `fraglimit`, default 20 |
| `tdm` | Red vs blue team frags; suicides and teamkills subtract a team frag | `fraglimit` |
| `ctf` | Steal the enemy flag and bring it to your base while your flag is home | `capturelimit`, default 5 |
| `if` | INSTAFREEZE: Instagib railgun combat with Freeze Tag freezing, teammate thawing and team elimination rounds | `fraglimit` (team rounds won) |
| `koth` | Hold the active hill for one point per second; it moves every 30 seconds through at least three sites; both teams present pauses scoring | `hilllimit`, default 120 |

KOTH rotation runs independently of scoring: empty and contested hills still move. A countdown above the active ring shows time until relocation. Each of the four bundled maps has three authored sites; the round starts at site 1 and repeats 1 → 2 → 3. Moving clears ownership and fractional capture credit. Older custom maps fall back to distinct playable spawn locations. See [rotating KOTH](docs/KOTH-ROTATION.md).

All modes also obey `timelimit` in minutes. Team modes end with the team result on the scoreboard; tied team scores at timeout are a draw. Flag carriers drop their flag on death, disconnect or team change. Touch your dropped flag to return it; unattended flags return after 30 seconds. Flag interaction and hill occupancy check distance, height and walls. Spectators cannot participate in objectives or combat.

Teams are assigned automatically to keep numbers balanced. Name labels include a small red diamond or blue circle beside the callsign, alongside the HUD team indicators; CTF banners have different emblems as well as colours. Nametag icons respect walls, death, cloak and Spy disguise, and are omitted in free-for-all modes. CTF respawns use the home side of the arena. Friendly fire defaults to off; `sv_friendlyfire "1"` enables it. Team assignment survives ordinary map rotation.

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

During a match, proposals last 25 seconds and require a strict majority of the active human players present when called. The proposer votes yes automatically. Spectators and late arrivals cannot vote, each player has one ballot, and proposals have a server-wide 60-second cooldown. Votes end when the round ends or a map transition begins. Set `sv_votes "0"` to disable voting. Offline practice does not use votes.

## Maps

Base DM/IG/FT/TDM offer the seven Quake source ports; IF defaults to IG. CC offers four [dedicated remodels](maps/CC/README.md), KOTH four rotating-hill remodels and CTF six CTF Studies maps. Original LibreQuake maps have moved to an optional expansion tested with the standard arena modes. These defaults do not restrict user imports or explicit server maplists.

Custom BSP maps use separated deathmatch spawn locations as fallback flag bases and a central spawn as the hill. Server operators should test custom objective layouts before putting them in a team rotation. Objective coordinates are supplied by the server, so downloaded BSPs retain the host's placements even if cached under a different ID. `tools/place_objectives.gd` regenerates bundled coordinates from baked navigation and world collision; `deathmatch/tests/team_objectives.gd` verifies them.

Assault (AS) is available with the bundled **HiSlop** train map. Enable it through
`sv_gametype` / `sv_gametypes` and `as_maplist`, just like TF. See [AS.md](AS.md).

## IF — INSTAFREEZE

Instafreeze combines standard Instagib combat with Freeze Tag's red/blue teams. Everyone starts with the penetrating one-hit railgun, unlimited ammunition and its normal 1.5-second firing interval. Pickups and physical melee are disabled. Selecting Quake or UT99 weapon variants does not change these rules.

A lethal rail hit freezes the opponent instead of killing and respawning them. In both Freeze Tag and Instafreeze, airborne frozen players fall to the ground while movement and attacks remain locked. A frozen player falling out of the arena returns to a spawn point still frozen, without another death or frag. Frozen players use the existing frozen-avatar effect and HUD thaw indicator. An unfrozen teammate must stay within 1.5 metres for three uninterrupted seconds, with no wall between them. Moving away resets thaw progress. Thawing restores health and the railgun in place, with normal spawn protection. Friendly fire follows `sv_friendlyfire`.

Freezing the entire opposing team awards one team point, followed by the existing three-second Freeze Tag round reset. `fraglimit` counts team rounds won; `timelimit` remains the overall match time limit. Environment deaths and telefrags retain Freeze Tag's existing behaviour.

```cfg
set sv_gametype "if"
set sv_gametypes "ig if ft"
set ig_maplist "qsrc_dm1 qsrc_dm2"
set fraglimit "10"
set timelimit "15"
```

IF defaults to the Instagib maplist, with the usual server rotation fallback. Set `if_maplist` or supply `maps/if_maplist.txt` for a separate rotation. Imported `if_` maps enter only IF; untagged imports enter DM, TDM, IG, FT and IF. Existing curated Instagib arenas remain compatible. Both lobby and in-game votes use this same list. In-game hosts can select **INSTAFREEZE** in Host Match. The mode currently reuses Freeze Tag's Cryostasis music.

Validation: `python3 deathmatch/tests/run_instafreeze_tests.py` covers rules, hosting, maplist selection and three-process ENet replication.

**TB — TITANBALL:** TF classes and Quake loadouts. Red pilots the BA-2 to Blue’s base; Blue stops it. Ashfall Boulevard is the native BSP playtest map, with a 350 m route and checkpoints at 80/230 m. Preparation lasts 60 seconds, then a fixed 10:00 clock with two +3:00 checkpoint extensions. Pilots board with 200 HP, fixed heavy-ordnance hull protection and no cockpit regeneration. Voluntary exit locks for 10 seconds; acceleration/braking take 5 seconds, followed by a 3-second stationary wait before replacement boarding. See [rules and validation](docs/TITANBALL.md).

Round-end and lobby voting instead use a shared 3×3 grid of complete map/mode/loadout choices. One click casts a changeable vote; the highest count wins at the deadline, with grid order breaking ties. See [session features](SESSION_FEATURES.md) for the full ballot rules.
