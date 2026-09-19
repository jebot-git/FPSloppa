## 0.4v external storage and rotations

See [external assets](docs/EXTERNAL-ASSETS.md) for persistent map/VRM directories, client BSP uploads, storage limits and separate `<tag>_maplist` settings. `sv_map_uploads 0` disables client BSP uploads. Use only matching 0.4v clients.

# Dedicated server

The optional **FPSloppa-Dedicated-Server-Linux.zip** contains a Linux x86-64 executable and its PCK. Godot installation, a display, GPU and audio hardware are not required. Keep the executable and PCK together. Unzip, edit `server.cfg`, then run:

```sh
./start-server.sh
# Or directly, including from another working directory:
/path/to/FPSloppaServer.x86_64 -- +exec /path/to/server.cfg
```

The dedicated binary is compiled as a console-only application. X11, Wayland, Vulkan, OpenGL, OpenXR, ALSA and PulseAudio drivers are absent; command-line options cannot enable a graphical session. It has no Steam Audio, TwoVoIP, VRM rendering or tracking plugins. Fatal errors print to the console instead of launching dialog programs; desktop URL/file launching is disabled in the runtime. It reads `server.cfg` beside its executable by default. `--config /absolute/file.cfg` and Q3-style `+exec /absolute/file.cfg` select a different file. Arguments after `--` belong to the game. Source-project equivalent:

```sh
./run-desktop.sh --headless -- --server +exec /absolute/server.cfg
```

## Configuration

### Building the console binary

Build with `python3 tools/build_console_server.py`. The builder downloads and verifies the pinned Godot 4.7.2 source archive and compiles a Linux x86-64 release runtime. Build dependencies are Podman, Python 3.12+, and a normal Godot executable for generating the PCK. The pinned Ubuntu 22.04 container installs its own C/C++ compiler and SCons 4.9.1. Engine compilation runs with container networking disabled. To use the host compiler instead, pass `--native-toolchain`; install SCons in a build virtual environment if necessary (`python3 -m venv Builds/server-tools`, then `Builds/server-tools/bin/pip install scons==4.9.1`), and pass `--scons Builds/server-tools/bin/scons`.

Output is `Builds/ConsoleServer/` inside the project. This replaces the legacy generic export in `../Builds/Server/`; release packaging uses the new directory exclusively. The generic dedicated export preset has been removed to prevent accidental builds with client drivers. PC and Android client exports are unchanged.

The shipped process needs only the platform C/C++ runtime libraries (`libc`, `libm`, `libstdc++`, `libgcc_s` and the ELF loader). It does not require Godot, graphics libraries, an audio daemon, a desktop session or audio hardware. The default Ubuntu 22.04 build keeps the library baseline compatible with that distribution and newer compatible Linux systems. For `--native-toolchain` builds, compile on the oldest distribution you intend to support: the host compiler determines the glibc/libstdc++ requirements.

The minimal PCK contains server gameplay, physics/navigation, networking, packet relay and metadata validation. Original BSP and VRM files remain outside the PCK for client downloads. The server constructs collision and liquid volumes from BSP data without reading texture pixels or graphical scene caches. It does not decode voice or instantiate avatar models; clients still perform spatial playback and rendering. Dummy Godot resource/display/audio APIs remain for shared engine types, with no hardware drivers.

`server-build.json` records compiler options, runtime dependencies, resource inventory and executable/PCK digests. `python3 tools/build_console_server.py --verify-only` checks the existing artifact; `python3 deathmatch/tests/run_console_server_tests.py` exercises the server resource graph and map/lobby physics in the same console runtime. The full release builder always uses this server builder, and `--package-only` audits the artifact before archiving it. To reuse an already compiled runtime, pass `--template /absolute/console-template` or set `FPSLOPPA_SERVER_TEMPLATE` for `tools/build_release.py`. A generic Godot template fails the driver audit.

### Server settings

Use one command per line. `set`, `seta` and `sets` are equivalent; double quotes preserve spaces. `//` and `#` start comments outside quotes. `map <id>` selects an arena. Unknown commands, malformed quotes, oversized files and out-of-range values stop startup with exit code 2.

```cfg
sets sv_hostname "My Arena"
set net_ip "*"
set net_port "7777"
set sv_maxclients "8"
set fraglimit "20"
set timelimit "10"
set sv_voice "1"
map "lqdm1"
set sv_maplist "lqdm1 lqdm2 lqdm4 lqdm7 lqdm8"
```

| Setting | Meaning |
|---|---|
| sv_hostname | Server name sent to joined clients |
| net_ip | Local bind address, or `*` for all interfaces |
| net_port | UDP port, 1024–65535 |
| sv_maxclients | 1–32 players (default 8); counts above 16 are unsupported; dedicated host consumes no player slot |
| sv_bot_fill | Target total occupancy (humans + bots), 0 disables; must not exceed sv_maxclients |
| fraglimit | 1–100 individual frags, team TDM frags, or FT/IF team rounds |
| sv_gametype | Initial `dm`, `tdm`, `ctf`, `koth`, `ig`, `if`, `ft`, `cc`, `tf`, `tb` or `as`; default `dm` |
| sv_gametypes | Optional space-separated allowlist for mode votes; includes initial mode |
| capturelimit | CTF captures to win, 1–100, default 5 |
| hilllimit | KOTH points to win, 1–3600, default 120 |
| sv_friendlyfire | Team damage, 0 or 1; default 0 |
| sv_votes | Enable in-match majority votes and between-match grid ballots, default 1 |
| timelimit | 1–60 minutes |
| sv_voice | 1 enables configured voice; 0 disables voice |
| sv_voice_backend | `builtin` (default) or external `mumble` handoff |
| sv_mumble_url | `mumble://host:port/channel` endpoint; required for Mumble, no credentials |
| map | Bundled or cached custom arena ID when no rotation is configured |
| sv_maplist | Optional quoted, space-separated rotation of up to 32 map IDs |

Set `sv_maxclients "32"` to allow up to 32 connections. **Player limits above 16 are unsupported: performance, gameplay and maps are not balanced for more than 16 players.** The server prints this warning at startup and shows it to joining players. In-game hosting remains capped at eight total players.

For a ten-player match populated automatically, use `set sv_maxclients "10"` and `set sv_bot_fill "10"`. The target includes spectators because they consume server slots. Human players take priority: an accepted join reserves a human seat, and a bot yields its place once the incoming player's assets are ready. Multiple simultaneous downloads cannot overbook human seats. Bots refill vacant slots after disconnects and rebuild their navigation on map rotation. They use normal server physics, objectives and TF classes, and cannot vote. A full server containing only humans still rejects extra joins. Bot AI adds server CPU work; choose the population for your hardware. RCON `status` identifies bots and reports both settings. Kicking a bot removes it through the usual departure cleanup; automatic fill will create a replacement.

TITANBALL uses fixed cockpit rules: boarding grants 200 HP with a 200 HP maximum, and cockpit regeneration is disabled. A living exit restores the normal class maximum and full class health; death ejection does not revive the pilot. Rockets, grenades, pipebombs, detpacks, the Heavy's assault cannon, engineer sentries and Titan cannons can damage an occupied hull. Only direct impacts and explosions on the hull qualify; nearby splash remains blocked. Heavy primary projectiles retain their firing-time classification. Other classes' small arms, on-foot players and other modes follow the established rules. The retired `sv_tb_heavy_ordnance` line is ignored when loading older configs and cannot disable protection. RCON status reports the fixed rule read-only.

See [GAMEMODES.md](GAMEMODES.md) for team rules, objective scoring and player votes. In-game hosts can select all supported modes, with an eight-player limit. See [VOICE.md](VOICE.md) for the external Mumble option.

Restart the server to apply configuration changes. `--port`, `--map`, `--frags` and `--minutes` override file values. A nonempty `sv_maplist` starts with its first map and advances after each intermission, wrapping at the end. An empty list repeats `map`; `--map` selects a single arena and overrides the rotation. Every map must be bundled or already cached on the server; unknown IDs stop startup.

Clients stay connected during rotation and download a missing map automatically. Scores, inventory, projectiles and map entities reset. The new round starts when the first player is admitted; other players enter after their own map and model checks finish. Slow or stalled downloads do not freeze ready players or block lobby voting and countdowns. Packets from the previous map are rejected. This is a small Q3-style configuration subset, not a Quake console: no command chaining, nested exec, arbitrary script execution or master-server registration. Password-protected RCON is documented below.

Clients need this protocol version (`fpsloppa-39-rotating-koth`). PC desktop and PC VR share the same server; the experimental Android targets retain that protocol. The configured UDP port carries gameplay, voice, map downloads and avatar downloads. Allow it through the firewall; Internet hosts behind NAT need port forwarding or a reachable server. A full transport may refuse connection before the game can display a specific rejection reason.

## Running as a service

Example systemd unit; adjust the user and installation path:

```ini
[Unit]
Description=Entryway arena server
After=network-online.target

[Service]
User=entryway
WorkingDirectory=/opt/entryway
ExecStart=/opt/entryway/FPSloppaServer.x86_64 -- +exec /opt/entryway/server.cfg
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

The service user needs a writable user-data directory for avatar/map caches. Logs flush immediately and are available through journald. No service is installed automatically. Custom-map source/cache/manifest files belong in the service user’s Godot `FPSloppa/maps` user-data directory; bundled maps need no setup. See [MAPS.md](MAPS.md) for import and transfer limits.

Independent clients tested the exported binary: joining, voice relay, custom config name/map/limits, disabled voice, connection cap and invalid-config exit. WAN and production load testing remain separate. See `test-results/server_config_summary.json` and `voice_binary_summary.json` in the source project.

Build again with official Godot 4.7.2 export templates and `python3 tools/build_release.py` (or set `GODOT_BIN`). Export approach follows [Godot’s dedicated-server documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).

For an offline packaged-asset diagnostic, run `./FPSloppaServer.x86_64 -- --check-assets`. It checks bundled source hashes, decodes all three default VRMs and verifies spring-bone initialization, then exits with a result code. It does not start a listening server.

Source rotation checks: `python3 deathmatch/tests/run_rotation_tests.py`. Independent clients cover wraparound, missing-map download, preserved peer identities, round resets and rejection of old-map snapshots. Use matching 0.3v clients and server packages for this protocol.

Spectators join through the normal map handshake and occupy a configured connection slot. Their role is server-owned, survives map changes, and is excluded from combat and winner selection. The client checkbox **Join as spectator** or `--connect ADDRESS --spectate` requests that role.

## Extensive diagnostics

```cfg
set sv_log_level "verbose"
set sv_log_file "user://logs/server.jsonl"
set sv_log_max_mb "8"
set sv_log_backups "3"
```

`sv_log_level` accepts `off`, `normal` (default) and `verbose`. Structured records appear on stdout with a `SERVER_LOG` prefix. A nonempty `sv_log_file` also writes plain JSONL to that file; parent directories are created. `user://` uses the server's Godot user-data directory, or use an absolute path writable by its service account. Startup fails clearly if the requested log file cannot be opened.

Normal logs include startup/version/protocol/configuration summaries, joins/rejections/timeouts, disconnections, match announcements, round results and map transitions. Verbose adds damage/kill details, spawns, pickups, ballots, and a five-second health record with peer teams, ping, input age/sequence, health, scores, pending joins, projectile count, accepted/received input counts, voice relay/rejection counts and process/physics timings. Chat message contents, voice samples, credentials, and raw XR/body poses are not logged.

Files rotate at `sv_log_max_mb` (1–512 MiB, default 8), retaining `sv_log_backups` older files (1–9, default 3). Normal events flush immediately; verbose batches flush each second. Individual records are bounded to 16 KiB. Keep verbose enabled while diagnosing a problem, then return to normal to reduce disk and console traffic. `off` disables these additional structured records; Godot errors and existing startup/game messages still reach stdout/stderr.

## Between-match waiting lobby

Set `sv_lobby "1"` to enable the unarmed voting room and `sv_lobby_seconds "45"` to choose its duration (15–180 seconds). The default is disabled. See [controls, demos and lobby documentation](SESSION_FEATURES.md) for voting and rotation behavior.

### Announcer policy

`set sv_announcer "1"` enables WARLORD announcer calls (default). Set it to `"0"` to disable all announcer calls for every player; restart the dedicated server after editing the config. This leaves combat sounds and capture fanfares enabled. Players may lower or mute their own announcer volume in Settings → Audio. The server policy is authoritative and persists across map rotation; client volume cannot override a disabled server policy.

## Empty-server timing

A dedicated server keeps the full match duration until its first client has
finished downloading required assets and joined. A ready spectator also counts
as a connected client. Pending connections/downloads alone do not start the
clock. When the last ready client disconnects, the remaining match time pauses;
lobby and intermission countdowns pause as well. Connection timeouts and asset
transfer work continue. A new client resumes the existing countdown; normal
client-hosted and practice-game timing is unchanged.

Assault (AS) is available with the bundled **HiSlop** train map. Enable it through
`sv_gametype` / `sv_gametypes` and `as_maplist`, just like TF. See [AS.md](AS.md).


## Remote console and connection diagnostics

RCON is disabled until a password is configured. It uses a separate TCP listener, loopback-only by default:

```cfg
set rcon_password "choose-a-long-unique-password"
set rcon_bind "127.0.0.1"
set rcon_port "7778"
```

Use an SSH tunnel (`ssh -L 7778:127.0.0.1:7778 USER@SERVER`) and run `python3 tools/rcon.py 127.0.0.1 status`. The client prompts for the password; automated tools may supply `FPSLOPPA_RCON_PASSWORD` in their environment. Do not put passwords in command-line arguments. Requests and responses use nonce-based HMAC-SHA256 authentication; commands themselves are not encrypted, so keep the loopback binding and use SSH for remote access. Each nonce permits one command. Authentication attempts, connections, input sizes and command names are bounded.

Commands: `status`, `map <current-mode-maplist-entry>`, `mode <enabled-mode>`, `match <enabled-mode> <configured-map> <doom|quake|ut99>`, `kick <peer-id>`, `say <message>`, `restart`, `loglevel <off|normal|verbose>`, `help`. There is no shell execution, arbitrary script evaluation or unrestricted config setter. Passwords and command arguments are omitted from the RCON audit log.

Join logs now include transport address/RTT/loss, handshake stages and timeout stage. Protocol mismatch, private practice and full-server rejection have separate explanations. Initial transport/hello deadlines are 30 seconds; asset preparation retains its separate extended deadline. A bounded reserve of ENet handshakes permits explicit rejection when the admitted-player limit is reached; it does not enlarge the gameplay capacity or the eight-player host limit.

Engine error callbacks are deduplicated and drained once a second into `engine_diagnostic` records. Verbose health also includes static memory, node/orphan counts and transport-peer counts. The generated dedicated launcher explicitly selects headless mode, XR off and Dummy audio, and writes early engine output to `server-engine.log`. Client connection stages are kept in a bounded `user://client-network.jsonl` with one rotated backup. Send both engine and structured logs when reporting a failure.

KOTH uses one fixed, map-authored hill throughout the round. Contested time does not score. The retired `koth_move_points` setting is accepted and ignored so older configurations still load. The bundled KOTH rotation contains four dedicated LibreQuake remodels; see `maps/KOTH/README.md`. With `sv_lobby 1`, a separate wall displays the completed round's saved scoreboard alongside the existing voting room.

Experimental Doom / Quake I / UT99 weapon selection and controls: [Weapon variants](docs/WEAPON_VARIANTS.md). Doom remains the default.

INSTAFREEZE (`if`) uses Instagib combat with Freeze Tag thawing and team scoring. It falls back to `ig_maplist` / `maps/ig_maplist.txt` unless a separate `if_maplist` or `maps/if_maplist.txt` is supplied. Imports populate the separate IF list when eligible. Include `if` in `sv_gametypes` to offer it in votes. See [GAMEMODES.md](GAMEMODES.md#if--instafreeze).

Base rotations now use Quake DM1–DM7 for DM/IG/FT/TDM, four rebuilt CC arenas, six CTF Studies and four rotating KOTH arenas. Original LibreQuake arenas are optional. Explicit `*_maplist` entries keep their order and may select imported, optional or cross-mode maps; the base selection is not an operator allowlist. Installing base assets preserves existing personalised maplist files.

Rotation precedence is an explicit mode-specific config list, then a nonempty `sv_maplist`, then the mode's maplist file, then the configured `map`. A global personal rotation therefore overrides bundled files; a mode-specific config list can override that global rotation.

TF always uses Quake weapons; Assault always uses UT99. Host settings, `sv_weapon_rules`, CLI overrides and mode votes cannot override these requirements. The configured preference resumes in unrestricted modes.

RCON `match` selects the mode, map and weapon rules in one transition. It rejects a contradictory TF/AS rules argument. It accepts only enabled mode/map pairs, rebuilds pickup mappings when rules change, and preserves fixed loadouts in IG, IF and CC. `status` also reports effective weapon rules, lobby state, intermission and round result.

Experimental **CQ — CONQUEST** has a separate source-tree launcher and protocol, and its own `sv_cq_maxclients` (up to 64) and `sv_cq_bot_fill` settings. These do not raise `sv_maxclients` or the ordinary host limit. CQ cannot rotate into other modes or the lobby. See [CQ setup, rules and current backend limits](docs/CONQUEST.md) before launching `./launch-conquest.sh --server`.
