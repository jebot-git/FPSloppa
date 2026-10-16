# CQ standalone server

The dedicated CQ host is a C++17 executable. It uses Jolt 5.5.0, ENet 1.3.18 and the existing host-independent CQ authority core. It has no Godot engine, scene tree, GDExtension, GDScript, PCK, renderer or audio backend at runtime.

The native application owns admission, input/action validation, simulation scheduling, 60/30 Hz adaptation, bot population and navigation, collision queries and character/vehicle movement, destruction, snapshot compression/fanout, avatar validation and transfer, player profiles, voice routing, weather seed distribution, chat, restart votes, logging and authenticated RCON. Combat, classes, progression, physical reloads, VR melee, vehicle weapons, spotting, squads and deployment use the shared authority core.

The current frontend still uses Godot for rendering and UI. `FPSNativeClient` is its native ENet transport and frame assembler; `deathmatch/native/standalone_client.gd` adapts received events to the existing presentation. Its `FPSClientPeer` exposes local identity to presentation code and does not carry SceneMultiplayer RPCs.

## Build

On Linux, install CMake, Ninja, a C/C++17 compiler and Python 3.12 or newer. The dependency fetcher verifies pinned archive hashes from `dependencies.json`. No system Godot SDK is needed to compile the server.

```sh
python3 tools/build_standalone_server.py -j3
```

Use `--cc /path/to/cc --cxx /path/to/c++` to select compilers. Jolt is built for baseline SSE2 with cross-platform deterministic floating-point settings; AVX/AVX2 are disabled. The build is a Linux server target. A matching frontend must be built with `tools/build_gameplay_native.py` for each client platform.

Cook the authoritative map **offline** on the development machine with the project's matching Godot version and current native client extension:

```sh
GODOT_BIN=/path/to/godot python3 tools/build_standalone_server.py --cook
```

The cooker exports enabled static collision shapes, navigation polygons and links, authored roads, terrain/river data, objectives/spawns, lamps, vehicle spawns, destruction support/collision/rubble data and validated bundled UT99 avatars. It writes checksummed JSON and binary data to `native_server/cooked`. The generated data and downloaded dependency sources are ignored by Git.

```sh
./launch-frontier-server.sh
# Or run the binary directly:
native_server/build/cq-server --world native_server/cooked \
  --config native_server/server.cfg --state /path/to/persistent-state
```

The defaults are 64 clients, adaptive 60 Hz with 30 Hz fallback, destruction enabled and no bots. Set `sv_cq_bot_fill` to fill seats with native bots. Set `sv_cq_adaptive_tick 0` with `sv_cq_tick_rate 30` or `60` for a fixed rate. The standalone host supports the unified `voxel_jungle` CQ map; mode/map changes, district workers, arbitrary map uploads and the obsolete lobby are outside this host's configuration.

## Packaging and migration

```sh
python3 tools/build_standalone_server.py --skip-build --output /tmp/CQ-Server
python3 tools/build_standalone_server.py --verify-only --output /tmp/CQ-Server
/tmp/CQ-Server/start-server.sh
```

The packaging check verifies source/build receipts, every package checksum and the absence of Godot runtime resources. The VPS package/export scripts use this target. `tools/frontier_vps/fpsloppa-cq.service` uses the new CLI. Keep `state` outside the release directory when upgrading. No live service is changed by building or packaging.

This changes the wire protocol to `fpsloppa-cq-native-1`: deploy matching clients and server together. Existing Godot-RPC clients cannot connect. For historical Godot-host regression fixtures, clients can opt into `--cq-legacy-transport`. Those fixtures do not exercise the standalone executable.

Existing Godot-host session state is not automatically imported. Native profiles are server-owned, selected using an opaque random resume token stored per endpoint by the client. Back up the server state and client token file; losing a token creates a new profile. Existing production progression needs an explicit, trusted migration before rollout.

RCON preserves `fpsloppa-rcon-1` challenge/HMAC-SHA256 framing over TCP. It is disabled until a password is configured. Supported commands: `status`, `bots N`, `kick ID`, `say TEXT`, `restart`, `loglevel off|normal|verbose`. The package binds RCON to loopback. Secrets and resume tokens are excluded from logs. Voice packets are validated and relayed; the server does not decode Opus or load an audio runtime.

Avatar upload validation runs in at most two background jobs. Profile writes run in one bounded worker queue. Downloads use bounded chunks, disk streaming and ENet reliable-window backpressure. Destruction cells/rubble collision shapes are prebuilt; impacts change collision membership and native structural state.

## Verification

```sh
native_server/build/cq-server-tests
# Generate independent reference queries, then exercise the real world:
godot --headless --xr-mode off --path . --script tools/standalone_server/reference_samples.gd
native_server/build/cq-server-tests native_server/cooked
# Against an isolated server on UDP 17777:
native_server/build/cq-load-client native_server/cooked/world.json 17777 64 30 report.json
```

The load tool sends ordinary player input and validates received CQA3 snapshots. It reports admission, disconnects, movement, snapshot cadence and gaps, including a separate steady-state window after five seconds. It does not render avatars or claim to emulate client GPU load. Native bot tests additionally exercise server-side planning/combat. Use the actual arena desktop/tracked fixtures for end-to-end frontend verification.

The Jolt host is independently implemented; shared gameplay does not imply bit-identical Godot CharacterBody movement. Compare client prediction corrections on the target device, especially stairs, crowded doorways, room-scale movement and vehicles. Heightfield/grass parity, real admission and movement, destruction invariants and gameplay fixtures are checked separately.
