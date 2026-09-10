## 0.4v external storage and rotations

See [external assets](docs/EXTERNAL-ASSETS.md) for persistent map/VRM directories, client BSP uploads, storage limits and separate `<tag>_maplist` settings. `sv_map_uploads 0` disables client BSP uploads. Use only matching 0.4v clients.

# Dedicated server

The optional **Entryway-Dedicated-Server-Linux.zip** contains a Linux x86-64 executable and its PCK. Godot installation, a display, GPU and audio hardware are not required. Keep the executable and PCK together. Unzip, edit `server.cfg`, then run:

```sh
./start-server.sh
# Or directly, including from another working directory:
/path/to/FPSloppaServer.x86_64 -- +exec /path/to/server.cfg
```

The dedicated-server export automatically starts headless with OpenXR disabled. It reads `server.cfg` beside its executable by default. `--config /absolute/file.cfg` and Q3-style `+exec /absolute/file.cfg` select a different file. Arguments after `--` belong to the game. Source-project equivalent:

```sh
./run-desktop.sh --headless -- --server +exec /absolute/server.cfg
```

## Configuration

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
| fraglimit | 1–100 individual DM or team TDM frags |
| sv_gametype | Initial `dm`, `tdm`, `ctf` or `koth`; default `dm` |
| sv_gametypes | Optional space-separated allowlist for mode votes; includes initial mode |
| capturelimit | CTF captures to win, 1–100, default 5 |
| hilllimit | KOTH points to win, 1–3600, default 120 |
| sv_friendlyfire | Team damage, 0 or 1; default 0 |
| sv_votes | Enable majority map/team/mode votes, default 1 |
| timelimit | 1–60 minutes |
| sv_voice | 1 enables configured voice; 0 disables voice |
| sv_voice_backend | `builtin` (default) or external `mumble` handoff |
| sv_mumble_url | `mumble://host:port/channel` endpoint; required for Mumble, no credentials |
| map | Bundled or cached custom arena ID when no rotation is configured |
| sv_maplist | Optional quoted, space-separated rotation of up to 32 map IDs |

Set `sv_maxclients "32"` to allow up to 32 connections. **Player limits above 16 are unsupported: performance, gameplay and maps are not balanced for more than 16 players.** The server prints this warning at startup and shows it to joining players. In-game hosting remains capped at eight total players.

See [GAMEMODES.md](GAMEMODES.md) for team rules, objective scoring and player votes. In-game hosts remain DM-only. See [VOICE.md](VOICE.md) for the external Mumble option.

Restart the server to apply configuration changes. `--port`, `--map`, `--frags` and `--minutes` override file values. A nonempty `sv_maplist` starts with its first map and advances after each intermission, wrapping at the end. An empty list repeats `map`; `--map` selects a single arena and overrides the rotation. Every map must be bundled or already cached on the server; unknown IDs stop startup.

Clients stay connected during rotation and download a missing map automatically. Scores, inventory, projectiles and map entities reset. The new round waits for map transfers or their timeout. Packets from the previous map are rejected. This is a small Q3-style configuration subset, not a Quake console: no command chaining, nested exec, arbitrary script execution, RCON, passwords or master-server registration.

Clients need this protocol version (`entryway-13-team-modes`). PC desktop and PC VR share the same server; the experimental Android targets retain that protocol. The configured UDP port carries gameplay, voice, map downloads and avatar downloads. Allow it through the firewall; Internet hosts behind NAT need port forwarding or a reachable server. A full transport may refuse connection before the game can display a specific rejection reason.

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
