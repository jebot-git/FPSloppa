# Dedicated server

The optional **Entryway-Dedicated-Server-Linux.zip** contains a Linux x86-64 executable and its PCK. Godot installation, a display, GPU and audio hardware are not required. Keep the executable and PCK together. Unzip, edit `server.cfg`, then run:

```sh
./start-server.sh
# Or directly, including from another working directory:
/path/to/EntrywayServer.x86_64 -- +exec /path/to/server.cfg
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
| sv_maxclients | 1–16 players (default 8); dedicated host consumes no player slot |
| fraglimit | 1–100 frags |
| timelimit | 1–60 minutes |
| sv_voice | 1 permits voice relay; 0 rejects voice packets |
| map | Bundled or cached custom arena ID when no rotation is configured |
| sv_maplist | Optional quoted, space-separated rotation of up to 32 map IDs |

Set `sv_maxclients "16"` to opt into a 16-player dedicated server. In-game hosting always remains capped at eight total players.

Restart the server to apply configuration changes. `--port`, `--map`, `--frags` and `--minutes` override file values. A nonempty `sv_maplist` starts with its first map and advances after each intermission, wrapping at the end. An empty list repeats `map`; `--map` selects a single arena and overrides the rotation. Every map must be bundled or already cached on the server; unknown IDs stop startup.

Clients stay connected during rotation and download a missing map automatically. Scores, inventory, projectiles and map entities reset. The new round waits for map transfers or their timeout. Packets from the previous map are rejected. This is a small Q3-style configuration subset, not a Quake console: no command chaining, nested exec, arbitrary script execution, RCON, passwords or master-server registration.

Clients need this protocol version (`entryway-dm-10-melee`). PC desktop and PC VR share the same server; the experimental Android targets retain that protocol. The configured UDP port carries gameplay, voice, map downloads and avatar downloads. Allow it through the firewall; Internet hosts behind NAT need port forwarding or a reachable server. A full transport may refuse connection before the game can display a specific rejection reason.

## Running as a service

Example systemd unit; adjust the user and installation path:

```ini
[Unit]
Description=Entryway arena server
After=network-online.target

[Service]
User=entryway
WorkingDirectory=/opt/entryway
ExecStart=/opt/entryway/EntrywayServer.x86_64 -- +exec /opt/entryway/server.cfg
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

The service user needs a writable user-data directory for avatar/map caches. Logs flush immediately and are available through journald. No service is installed automatically. Custom-map source/cache/manifest files belong in the service user’s Godot `Entryway Deathmatch/maps` user-data directory; bundled maps need no setup. See [MAPS.md](MAPS.md) for import and transfer limits.

Independent clients tested the exported binary: joining, voice relay, custom config name/map/limits, disabled voice, connection cap and invalid-config exit. WAN and production load testing remain separate. See `test-results/server_config_summary.json` and `voice_binary_summary.json` in the source project.

Build again with official Godot 4.7.2 export templates and `python3 tools/build_release.py` (or set `GODOT_BIN`). Export approach follows [Godot’s dedicated-server documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).

For an offline packaged-asset diagnostic, run `./EntrywayServer.x86_64 -- --check-assets`. It checks bundled source hashes, decodes all three default VRMs and verifies spring-bone initialization, then exits with a result code. It does not start a listening server.

Source rotation checks: `python3 deathmatch/tests/run_rotation_tests.py`. Independent clients cover wraparound, missing-map download, preserved peer identities, round resets and rejection of old-map snapshots. Use matching 0.2v clients and server packages for this protocol.
