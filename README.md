# FPSloppa · TF development build

[0.5v build notes](docs/RELEASE-0.5v.md) · [Published releases](https://github.com/jebot-git/FPSloppa/releases)

**Arena Collection 1:** forty additional original BSPs, five per game mode, with an optional installer and visual atlas. See [the map-pack readme](optional-arena-pack/README.md). VRMs now use restrained arena lighting; see [AVATAR_LIGHTING.md](AVATAR_LIGHTING.md).

**New in 0.5v:** optional TF classes, class badges, VRM spy disguises and two original TF arenas. See [TF.md](TF.md). This uses a newer protocol than the published 0.4v release.

FPSloppa is a PC OpenXR and desktop online arena shooter with eight external LibreQuake arenas, Quake I BSP imports, textured 3D weapons and VRM avatars. Practice starts an offline match against three bots on the selected BSP map. The original Entryway map has been removed. See [MAPS.md](MAPS.md) for arenas, custom imports and supported entities. Open `project.godot` in **Godot 4.7.2** and press **F5**, or run `./run-vr.sh` on Linux with an active OpenXR runtime. Use `./run-desktop.sh` for mouse and keyboard. On another system, set `GODOT_BIN` or open the project in Godot.

See [VR.md](VR.md) for Touch / Index controls, tracked weapons, VR menus, IK and validation limits. Custom VRM avatars have a **25 MB** limit; missing BSP maps download automatically from the host. Normal multiplayer modes spawn with **only dual pistols and 50 shared bullets**; IG and CC use their mode-specific weapons, and TF uses class loadouts. Blood, gibs, pain reactions and spatial sound effects are included.

PC binaries: use Play-VR or Play-Desktop in the Linux/Windows ZIP. The optional Linux server ZIP runs without installing Godot. See [SERVER.md](SERVER.md) for `server.cfg`, [VOICE.md](VOICE.md) for voice chat, and [STANDALONE.md](STANDALONE.md) for Quest/Pico APK installation and device-testing limitations. Smooth turning now defaults on.

For VR callsign editing, saved-name configuration and the system-username fallback, see [VR callsign setup](VR.md#callsign). Use matching 0.5v clients and servers; the protocol changed from earlier releases.

Maps and avatars now live beside the executable in `maps/` and `vrm/`, outside the Godot package. Standalone users should open **ASSETS…** and download the base assets, or extract the Base-Assets ZIP into the app’s external files directory. See [external asset setup](docs/EXTERNAL-ASSETS.md). Left-handed controls, seated mode, Instagib, Freeze Tag and Chainsaw Circus are available.

## Play online

1. One player chooses an arena, callsign, UDP port (default **7777**), frag limit and time limit, then selects **Host Match**.
2. Other players enter that host's IP address or hostname and the same port, then select **Join Match**. Use `127.0.0.1` only for clients on the host's own computer; use the host's LAN address for other computers on the same network.
3. For Internet play, allow the selected UDP port through the host firewall and forward it on the router to the hosting computer, or use a publicly reachable dedicated server. Join using the host's public address.

All participants need the same project version. In-game hosting supports **eight players total**, including the playing host. Dedicated servers default to eight and allow **up to 32 players (above 16 is unsupported; performance, gameplay and maps are not balanced for these counts)** through `sv_maxclients` in `server.cfg`. Joining an ongoing match is supported. There is no account service, automatic matchmaking, NAT relay, public server browser, or host migration. Dedicated servers support configured map rotation. WAN latency and router traversal have not been tested from this workspace; real ENet loopback sessions with independent processes have been tested.

**PRACTICE VS BOTS** starts an offline match on the selected BSP map with three simple AI opponents. The selected gamemode determines weapons and pickups.

## Desktop controls

| Control | Action |
|---|---|
| WASD / mouse | Move / aim |
| Left mouse | Fire primary weapon; hold for repeated fire |
| Right mouse | Fire the second pistol while dual pistols are selected |
| Shift | Walk instead of running |
| 1 | Fist / chainsaw |
| 2 | Dual pistols |
| 3 | Shotgun / super shotgun |
| 4, 5, 6, 7 | Chaingun, rocket launcher, plasma rifle, BFG |
| Mouse wheel | Cycle owned weapons |
| E | Use a nearby door |
| Space | Jump / swim on Quake maps |
| F | Weapon whip (no ammo required) |
| Tab | Scoreboard |
| Enter | Chat; Enter again sends, Esc cancels |
| Esc | Match menu / resume |
| Fire or Space while dead | Respawn after the two-second delay |

Movement is fast. All maps allow jumping and swimming. Stair stepping is automatic. Platforms cycle automatically.

## Weapon behavior

There are no magazines or manual reloads. Shotguns have an automatic firing/reload cycle. First pistol/chaingun shots are accurate; sustained fire spreads. Pistols use 4.2° horizontal spread (down from 5.6°). Selecting slot 2 equips a pair, with independent firing cycles and one shared bullet pool. Pellet damage is randomized. Free vertical mouse aim replaces the original game's vertical auto-aim.

| Weapon | Behavior | Approximate firing interval / ammo |
|---|---|---|
| Fist | 2–20 melee damage | 0.57 s, no ammo |
| Chainsaw | Rapid 2–20 melee damage | 0.114 s, no ammo |
| Dual pistols | 6/12/18 hitscan damage per shot | 0.40 s per pistol, 1 shared bullet per shot |
| Shotgun | 7 pellets, mostly horizontal spread | 1.00 s, 1 shell |
| Super shotgun | 20 pellets, wider horizontal/vertical spread | 1.63 s, 2 shells |
| Chaingun | Rapid 5/10/15 hitscan damage | 0.114 s, 1 bullet |
| Rocket launcher | Traveling rocket, 20–160 direct damage plus up to 128 splash; self-damage; walls block splash | 0.57 s, 1 rocket |
| Plasma rifle | Rapid traveling bolts, 5–40 damage | 0.086 s, 1 cell |
| BFG 9000 | 0.86 s charge, large projectile, then 40 forward tracer rays from the shooter's location on impact | 1.72 s, 40 cells |

These are approximations, not an emulation of Doom's 35 Hz state machine or random table. Weapon models use the CC0 Oldschool AFPS Weapons pack by Drummyfish, converted in Blender, with a BFG adaptation and the original textured shotgun-based super-shotgun variant. The fist derives from the bundled CC0 VRoid model. Muzzle flashes, shot tracers, recoil, hit feedback and synthesized sounds are authored for this project. Green armor absorbs one third of incoming damage; blue armor absorbs one half, limited by remaining armor.

## Match rules

- Default: **20 frags / 10 minutes**, followed by a ten-second intermission and automatic restart.
- Players spawn with 100 health, only dual pistols and 50 shared bullets. Inventory resets on death. Spawn points favor distance from living opponents.
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

Core files: `arena.gd` (networking/combat/match), `fighter.gd` (movement and marine), `weapons.gd` (tuning), `art.gd` (weapon asset assembly and sound), `interface.gd` (menus/HUD) and `bots.gd` (offline navigation and combat input). The eight bundled BSP arenas and user-imported BSPs are playable.

Behavior references: [id Software's original weapon routines](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_pspr.c). Networking references: [Godot high-level multiplayer](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html) and [ENet peer statistics](https://docs.godotengine.org/en/stable/classes/class_enetpacketpeer.html). This implementation is independently written. Original Doom music, sound samples, sprites and source code are not bundled. See [asset credits](ASSET_CREDITS.md).

Optional [body tracking](TRACKING.md), [recorded spatial audio and speech-driven VRM mouths](AUDIO.md) are included in protocol `entryway-13-team-modes`. Update the server and every client together.

Eye-tracked VRM gaze and measured blinking are automatic on supported OpenXR runtimes/models; see [EYES.md](EYES.md). See [PERFORMANCE.md](PERFORMANCE.md) for rendering changes, profiling commands and hardware-validation limits. The generated launcher artwork is documented in [ICON.md](ICON.md).

Voice starts in push-to-talk mode (**V** / VR off-hand grip). The voice controls are selectable inside the VR menu; Android requests microphone and vendor tracking access with a retry option. Tracked VR players can look down at their own head-hidden avatar body for an IK reference. See [VOICE.md](VOICE.md) and [TRACKING.md](TRACKING.md).

Every held weapon can perform a short-range weapon whip: press **F** on desktop or swing the weapon in VR. It deals **10 damage** before armor, with **0.8 seconds** between attacks and at most one victim per swing. A deliberate VR swing is required; resting the weapon against a player does no damage. The server checks range, walls, cooldown and normal spawn protection. VR swings require slowing the weapon before swinging again.

### Spectators, presentation and soundtrack

Select **Join as spectator** before **JOIN MATCH** to watch with a free-flying camera. Desktop uses WASD and Space/Ctrl for up/down; VR uses the left stick to move, right stick left/right to turn and right stick up/down to fly. Spectators have no visible avatar, collision, pickups, weapons or damage, appear separately on the scoreboard, and keep their role through map downloads and rotation. They occupy a connection slot (8 on menu-hosted servers, up to 32 in dedicated server configuration; above 16 is unsupported). CLI joining also accepts `--spectate` alongside `--connect`.

The final scoreboard opens automatically when a match ends, including its VR surface, and closes for the next round. **SETTINGS…** is available before joining and during matches. Audio controls include master, effects, music, voice playback, output device and access to microphone/voice controls. Graphics controls include render resolution (50–125%), MSAA and shadows; desktop also offers fullscreen/windowed mode and FOV. Changes apply immediately and persist alongside your other client preferences. VR FOV and refresh timing remain headset/runtime controlled.

Four original tracker compositions provide a looping industrial action score with recorded guitar, bass and acoustic drums. Their editable ProTracker modules are about 52 KiB each; portable Ogg playback totals 2.67 MiB. Music defaults to 30% and has its own saved volume control. See [music sources](deathmatch/audio/music/SOURCES.md). New supply models distinguish bullets, shells, rockets, cells, medkits and armour with cached single-surface meshes.


## 0.4v arena update

Dedicated servers support DM, TDM, CTF and KOTH, with configurable limits, team switching and majority votes for balance, available maps and allowed game types. In-game hosting remains DM-only with eight slots. See [GAMEMODES.md](GAMEMODES.md) and [server.cfg](server.cfg).

Eight freely licensed LibreQuake arenas are bundled. Menus use an original iron/brass theme with large VR controls; CTF flags use cloth banners with distinct team emblems. Steam Audio provides headphone HRTF spatialisation for effects and built-in positional voice on Linux, Windows and Android. Sound settings include a standard spatial-audio fallback. Dedicated servers may advertise an external Mumble client handoff; built-in voice remains the default.

This build also includes the previously developed dual pistols, controller finger gestures/tracker fixes, spectator mode, end-of-match scoreboard, audio/graphics settings, new pickup models, restored CC0 super shotgun and four original tracker soundtracks.

Rocket splash now supports rocket jumping with reduced self damage and bounded, replicated knockback. Megahealth and mega armour have distinct colours, labels and moving halos; pain, respawn, powerful-item spawn and pickup cues are improved. Settings → Graphics adjusts VR HUD size and vertical position within saved limits.

Controls, two-handed aiming, physical jumps, demo/video tools and the optional voting lobby: [session features](SESSION_FEATURES.md).

Hit registration, latency simulation and test limitations: [network testing](NETWORK_TESTING.md).
