# FPSloppa · 0.1v

[Download release 0.1v](https://github.com/jebot-git/FPSloppa/releases/tag/0.1v) · [Release notes](docs/RELEASE-0.1v.md)

FPSloppa (in-game title: Entryway Deathmatch) is a PC OpenXR and desktop online arena shooter with five bundled LibreQuake deathmatch arenas, Quake I BSP imports, textured 3D weapons and VRM avatars. Practice starts an offline match against three bots on the selected BSP map. The original Entryway map has been removed. See [MAPS.md](MAPS.md) for arenas, custom imports and supported entities. Open `project.godot` in **Godot 4.7.2** and press **F5**, or run `./run-vr.sh` on Linux with an active OpenXR runtime. Use `./run-desktop.sh` for mouse and keyboard. On another system, set `GODOT_BIN` or open the project in Godot.

See [VR.md](VR.md) for Touch / Index controls, tracked weapons, VR menus, IK and validation limits. Custom VRM avatars have a **25 MB** limit; missing BSP maps download automatically from the host. Multiplayer spawns grant **only the pistol and 50 bullets**. Blood, gibs, pain reactions and spatial sound effects are included.

PC binaries: use Play-VR or Play-Desktop in the Linux/Windows ZIP. The optional Linux server ZIP runs without installing Godot. See [SERVER.md](SERVER.md) for `server.cfg`, [VOICE.md](VOICE.md) for voice chat, and [STANDALONE.md](STANDALONE.md) for Quest/Pico APK installation and device-testing limitations. Smooth turning now defaults on.

## Play online

1. One player chooses an arena, callsign, UDP port (default **7777**), frag limit and time limit, then selects **Host Match**.
2. Other players enter that host's IP address or hostname and the same port, then select **Join Match**. Use `127.0.0.1` only for clients on the host's own computer; use the host's LAN address for other computers on the same network.
3. For Internet play, allow the selected UDP port through the host firewall and forward it on the router to the hosting computer, or use a publicly reachable dedicated server. Join using the host's public address.

All participants need the same project version. Sessions support **eight players total**, including a playing host. Joining an ongoing match is supported. There is no account service, automatic matchmaking, NAT relay, public server browser, host migration, or cross-map rotation. WAN latency and router traversal have not been tested from this workspace; real ENet loopback sessions with independent processes have been tested.

**PRACTICE VS BOTS** starts an offline match on the selected BSP map with three simple AI opponents. Everyone spawns with a pistol and collects other weapons from the arena.

## Desktop controls

| Control | Action |
|---|---|
| WASD / mouse | Move / aim |
| Left mouse | Fire; hold for repeated fire |
| Shift | Walk instead of running |
| 1 | Fist / chainsaw |
| 2 | Pistol |
| 3 | Shotgun / super shotgun |
| 4, 5, 6, 7 | Chaingun, rocket launcher, plasma rifle, BFG |
| Mouse wheel | Cycle owned weapons |
| E | Use a nearby door |
| Space | Jump / swim on Quake maps |
| Tab | Scoreboard |
| Enter | Chat; Enter again sends, Esc cancels |
| Esc | Match menu / resume |
| Fire or Space while dead | Respawn after the two-second delay |

Movement is fast. All maps allow jumping and swimming. Stair stepping is automatic. Platforms cycle automatically.

## Weapon behavior

There are no magazines or manual reloads. Shotguns have an automatic firing/reload cycle. First pistol/chaingun shots are accurate; sustained fire spreads. Pellet damage is randomized. Free vertical mouse aim replaces the original game's vertical auto-aim.

| Weapon | Behavior | Approximate firing interval / ammo |
|---|---|---|
| Fist | 2–20 melee damage | 0.57 s, no ammo |
| Chainsaw | Rapid 2–20 melee damage | 0.114 s, no ammo |
| Pistol | 5/10/15 hitscan damage | 0.40 s, 1 bullet |
| Shotgun | 7 pellets, mostly horizontal spread | 1.00 s, 1 shell |
| Super shotgun | 20 pellets, wider horizontal/vertical spread | 1.63 s, 2 shells |
| Chaingun | Rapid 5/10/15 hitscan damage | 0.114 s, 1 bullet |
| Rocket launcher | Traveling rocket, 20–160 direct damage plus up to 128 splash; self-damage; walls block splash | 0.57 s, 1 rocket |
| Plasma rifle | Rapid traveling bolts, 5–40 damage | 0.086 s, 1 cell |
| BFG 9000 | 0.86 s charge, large projectile, then 40 forward tracer rays from the shooter's location on impact | 1.72 s, 40 cells |

These are approximations, not an emulation of Doom's 35 Hz state machine or random table. Weapon models use the CC0 Oldschool AFPS Weapons pack by Drummyfish, converted in Blender, with super-shotgun and BFG adaptations. The fist derives from the bundled CC0 VRoid model. Muzzle flashes, shot tracers, recoil, hit feedback and synthesized sounds are authored for this project. Green armor absorbs one third of incoming damage; blue armor absorbs one half, limited by remaining armor.

## Match rules

- Default: **20 frags / 10 minutes**, followed by a ten-second intermission and automatic restart.
- Players spawn with 100 health, only a pistol and 50 bullets. Inventory resets on death. Spawn points favor distance from living opponents.
- Spawn protection lasts 1.5 seconds and is cancelled by firing.
- Suicides subtract one frag. A death adds to the victim's death count. Fire/Space respawns after two seconds; automatic respawn follows three seconds later.
- Weapons, ammunition, health and armor respawn after 30 seconds; the BFG pickup takes 60 seconds. Pickup claims are resolved by the server once.
- Tab shows names, frags, deaths and ping. The feed shows kills, chat, joins and departures.

## Dedicated server

A separate Linux executable is available with Q3-style configuration. See [SERVER.md](SERVER.md).

```bash
./run-desktop.sh --headless -- --server --map lqdm1 --port 7777 --frags 20 --minutes 10
```

Or use Godot directly:

```bash
godot --headless --xr-mode off --path /path/to/Godot -- --server --port 7777
godot --path /path/to/Godot -- --connect 127.0.0.1 --port 7777
```

The server simulates movement and combat. Clients send movement/aim/fire intent at 30 Hz and receive state at 20 Hz. Clients predict their own movement and weapon feedback, then correct to server positions; other marines interpolate. Hitscan rewinding is capped at 200 ms using transport-measured ping. Health, ammo, inventory, damage, pickups, frags and round state stay server-owned. This is a small playable prototype, not a hardened competitive anti-cheat system; prediction is deliberately simple.

## Validation and source

`deathmatch/tests/rules.gd`: 13 checks for weapon rules, armor, weapon cycling and invalid input rejection.

`deathmatch/tests/combat.gd`: 13 checks for spawn protection, hitscan, melee, chaingun cadence, plasma, projectile removal, rocket damage/self-damage, wall occlusion, BFG charge/impact and contested pickups.

`deathmatch/tests/run_network_tests.py`: launches one dedicated server and two independent ENet clients, checks replicated combat/inventory, scoring, respawns, pickup respawn, chat, round restart, disconnect/rejoin, and late-join projectile/door state. Logs are written to `test-results/`.

```bash
godot --headless --xr-mode off --path . --script res://deathmatch/tests/rules.gd
godot --headless --xr-mode off --path . --script res://deathmatch/tests/combat.gd
python3 deathmatch/tests/run_network_tests.py /path/to/godot
```

Core files: `arena.gd` (networking/combat/match), `fighter.gd` (movement and marine), `weapons.gd` (tuning), `art.gd` (weapon asset assembly and sound), `interface.gd` (menus/HUD) and `bots.gd` (offline navigation and combat input). Only the five BSP arenas and user-imported BSPs are playable.

Behavior references: [id Software's original weapon routines](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_pspr.c). Networking references: [Godot high-level multiplayer](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html) and [ENet peer statistics](https://docs.godotengine.org/en/stable/classes/class_enetpacketpeer.html). This implementation is independently written. Original Doom music, sound samples, sprites and source code are not bundled. See [asset credits](ASSET_CREDITS.md).

Optional [body tracking](TRACKING.md), [recorded spatial audio and speech-driven VRM mouths](AUDIO.md) are included in protocol `entryway-dm-7-eyes`. Update the server and every client together.

Eye-tracked VRM gaze and measured blinking are automatic on supported OpenXR runtimes/models; see [EYES.md](EYES.md). See [PERFORMANCE.md](PERFORMANCE.md) for rendering changes, profiling commands and hardware-validation limits. The generated launcher artwork is documented in [ICON.md](ICON.md).
