# Dedicated bots and TITANBALL hull policy — 2026-09-14

Bot fill is opt-in. TITANBALL hull protection is now fixed rather than configurable. Restart after changing `server.cfg`:

```text
set sv_maxclients "10"
set sv_bot_fill "10"
```

`sv_bot_fill` targets total occupancy, including humans and spectators. Bots yield a slot when an accepted human finishes loading, refill vacancies after departures, and retain normal game objectives and team/class behavior. Concurrent accepted downloads reserve human seats; a human-only full server rejects further joins. Bot departures use ordinary player cleanup, including pilot ejection and owned deployables. A nonpilot bot is preferred when choosing whom to replace. Bots do not vote. RCON status reports bot identities, fill target, explicit bot-count override and the hull policy.

Use `bots 6` over authenticated RCON to request six bots alongside the humans, capped by `sv_maxclients`. `bots 0` removes all bots. Changes apply immediately, survive map/mode changes, and preserve human players. The override lasts until the server restarts; `sv_bot_fill` remains the startup setting for total-population filling. Status `bot_count: -1` means the startup fill policy is active.

Titan targeting uses the same weapon eligibility as actual hull damage, including the Heavy super-nailgun exception. Bots with no usable damaging weapon ignore the mounted pilot, and armed bots select an eligible weapon.

TITANBALL always uses 200 HP, no cockpit regeneration, and the approved heavy-weapon filter for occupied TB hulls: rockets, grenades, pipebombs, detpacks, Heavy assault cannon, engineer sentries and Titan cannons. Impacts must contact the hull; nearby splash remains excluded. Heavy primary projectiles retain their firing-time class classification. No new weapon implementations are introduced. Other modes and on-foot damage retain their usual rules. See [the preceding balance experiment](TB-HEAVY-ORDNANCE-TEST.md) for the gameplay effect.

Navigation fixes wait for usable map geometry before installing links, include trigger-operated Vesper elevators, recognize lift approaches before obstruction recovery, hold position while waiting/riding, and steer onto fixed upper landings. Connected push volumes are traced together so a Quake pipe route leads through its redirects to the actual landing. The planner checks capsule clearance there. Lift links cover ascent; descent continues to use available walking/drop routes.

Validation recorded before the fixed TB defaults were adopted (see the current release notes for subsequent checks):

- 21 configuration/lifecycle checks: defaults, invalid settings, total population, human reservations, replacement, disabling fill, bot pilot cleanup and rotation.
- 14 real ENet/console-server checks: startup fill, human replacement at capacity, moving bots observed by a remote client, simultaneous joins, explicit full rejection, refill, rotation, TF team/class assignment and error-free operation. This is a local loopback test.
- 32 map checks covering 14 physical traversals: all four Vesper elevators, an additional wait/board/exit case with the elevator initially upstairs, five routes through DM7's two connected pipe systems, DM7's ordinary lift, and all three Hyperborea angled jump pads. Destination tolerance is 0.45 m, allowing the navmesh's vertical offset; elevator completion additionally requires solid ground outside the moving platform.
- 34 movement regressions, including real rocket and piston takeoff/self-damage/air-control behavior, plus four route-query checks.
- 46 heavy-ordnance damage checks.
- Rebuilt console artifact passed the existing 34-map audit without client rendering/audio dependencies.

Mechanic tests supply fixed navigation goals and use the existing bot steering, BSP triggers and player physics. They do not establish full-match balance, Internet performance, or headset behavior. Existing Vesper navmesh edge-merge warnings and the engine's exit-time ObjectDB warning remain; final suites reported no script/engine errors.

[Machine-readable results and source hashes](validation/server-bots-navigation.json). The console server is rebuilt locally under `Builds/ConsoleServer`; these changes have not been published or deployed remotely.

To reproduce, run `deathmatch/tests/run_server_bots_tests.py`, `deathmatch/tests/server_bots.gd`, `deathmatch/tests/bot_map_transport.gd`, `deathmatch/tests/bot_movement.gd`, `deathmatch/tests/bot_navigation.gd`, `tools/ba2/gameplay/heavy_ordnance_tests.gd`, and `deathmatch/tests/run_console_server_tests.py`. GDScript tests run through Godot headless with XR disabled and a writable absolute log path. The network tests bind loopback UDP/TCP ports 28942/28943 and respect RCON's existing rate limit.

## BSP controls

Bots inspect route-blocking BSP doors and resolve their upstream touch/shootable controls through target chains. They press buttons through player movement and shoot switches or nearby secrets through ordinary weapon input. Open/disabled controls are skipped, close combat interrupts a detour, and timeouts bound failed attempts. Crusher controls are avoided when the bot or a teammate is inside the swept area. Custom QuakeC scripts remain unsupported.
