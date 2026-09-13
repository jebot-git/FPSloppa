# Remote current-source server test — 12 September 2026

The current console-only server is available at **45.147.228.101:27777**, in a separate detached screen session. Production on port **7777** remained running under its original PID throughout testing. The test instance requires the matching current-source client protocol, `fpsloppa-31-team-radio`; its existing version label remains `0.10v`. This was a test deployment, not a published release.

Final test state: ASSAULT, `as_hislop`, capacity 16, no players or pending joins, and the 30-minute timer paused while empty. The test directory is `/home/blux/FPSloppa-tests/20260912T112318Z`; screen session `fpsloppa-test-20260912`. RCON binds only to remote loopback and was accessed through SSH. Credentials are excluded from this report.

## Results

- A cold client downloaded and verified 24,581,692 bytes of map and VRM data before admission, about 13.7 seconds after engine startup. Both SHA-256 hashes matched the served originals.
- All 16 active synthetic clients joined and completed a six-minute run involving movement, jumping, crouching, firing, pickups and respawning. A 17th client was rejected. Clients recovered across DM → ASSAULT → TF map transitions.
- A further eight-client, three-minute run covered Painful Memories, Frigate and Lasercade. All clients exited successfully.
- Remote RCON exposed a bug: permitted map IDs were compared against an array of dictionaries. The lookup now checks each dictionary's ID. Local authentication/replay/command validation tests passed, and the rebuilt remote server successfully changed to Painful Memories and Frigate.
- The console package passed the local 14-map audit. Remote dynamic dependencies contain no graphics, audio or XR libraries. Server health logs recorded zero orphan nodes and zero engine diagnostics.
- The empty-server timer remained paused, including after clients disconnected.

## Performance findings

Host: two vCPUs, 1,967 MiB RAM, no swap. The 60 Hz physics budget is **16.67 ms**. Values below are five-second health snapshots, not all-frame percentiles.

| Map / mode | Active clients | Samples | Median physics | P95 physics |
| --- | ---: | ---: | ---: | ---: |
| Lasercade / DM | 16 | 20 | 26.749 ms | 32.966 ms |
| HiSlop / ASSAULT | 16 | 27 | 17.889 ms | 20.634 ms |
| lqdm1 / TF | 16 | 20 | 19.093 ms | 23.501 ms |
| Painful Memories / DM | 8 | 17 | 16.499 ms | 19.572 ms |
| Frigate / ASSAULT | 8 | 6 | 13.033 ms | 13.999 ms |
| Lasercade / DM | 8 | 11 | 20.969 ms | 22.787 ms |

Admission capacity works, but these measurements do not establish acceptable 16-player performance on this host. Even eight clients exceeded budget on heavier geometry. The synthetic clients deliberately keep moving into geometry and jumping, making this a collision-heavy workload. Profile per-player movement, stair/capsule sweeps and map collision complexity first; these are investigation targets, not yet proven individual bottlenecks.

During the baseline process-monitor window, RSS changed from 131,528 to 131,656 KiB. In the patched run it ranged from 116,268 to 130,220 KiB as maps and clients changed, then settled. File descriptors ranged from seven to nine. No sustained unbounded growth was demonstrated; this short run cannot rule out long-term leaks. Initial probe teardown produced extra orphan warnings because the harness replaced an instantiated scene's script; fixing the harness removed those extra warnings. A pre-existing local test shutdown warning remains distinct from the server's zero runtime orphan count.

The baseline server socket drop counter increased from 207 to 401 during monitoring; the patched run increased from zero to six. The baseline monitor began after the join burst. These counters measure local socket drops, not end-to-end packet loss. They warrant investigation alongside physics scheduling, without attributing connection issues to the hosting provider.

## Voice finding

Three real clients sent and decoded synthetic Opus audio through the console relay in TDM. Each sender phase contained 100 proximity packets or 100 team packets.

- With one second of settling after admission, the teammate received 77 proximity and 76 team packets, failing the receive threshold. The enemy received all 100 proximity packets and zero team packets.
- With eight seconds of settling, the teammate received all 200 packets and the enemy received exactly the 100 proximity packets. Decoding and nonzero audio levels passed. Neither run echoed voice to the sender or leaked team voice to the enemy.

The initial failure remains unresolved. Startup transport behavior and unreliable packet throttling are possible investigation targets; the test does not establish the cause. This checks transport, routing and decoding with a generated tone, not live microphone capture or VR audibility.

## Reproduction and evidence

Machine-readable measurements and hashes: [remote-current.json](validation/remote-current.json). Raw local artifacts are under ignored `test-results/remote-current/`, including baseline and patched server logs, client logs, cold-download hashes and both voice outcomes. Do not publish the staged deployment archive/config: it contains the temporary test RCON secret.

Reusable tools added for this work:

- `tools/run_remote_probes.py --host HOST --port PORT --label LABEL --count 16 --hold 360` runs bounded active clients and reaps their processes. Use only against an authorized test instance.
- Add `--cold --spectator` for verified initial downloads or `--reject` for the over-capacity probe.
- `tools/run_remote_voice_test.py --host HOST --port PORT --label LABEL --settle 8` tests synthetic proximity/team Opus routing on a TDM server with three available slots.
- `tools/remote_server_monitor.py PID OUTPUT --seconds 600` samples only the selected process and its owned UDP sockets.

No identical active-player baseline of the old production build was run, so these results do not prove a regression relative to the released 0.10v server. They cover one public-network route, not multiple geographic regions. The temporary clients and monitor exited; the test server remains available independently of SSH.
