# Remote VR hotfix session — 14 September 2026

The current working-tree fixes were deployed to the previously used remote machine, **45.147.228.101:27777**, in `/home/blux/FPSloppa-tests/20260914-hotfix`. The existing production server on port 7777 was left running and unchanged. The dedicated server uses the audited console-only 4.7.2 runtime, a fresh code pack, verbose gameplay/network logs and a per-process CPU/memory/socket monitor. The client was Linux Godot 4.7.2, Vulkan Mobile, Intel Arc A770 and Meta Quest Pro through WiVRn v26.9.

## DM7 pipe diagnosis and fix

The wearer became stuck at approximately `(20.24, -3.75, -45.70)` in the short pipe's lower end. NetBot 10 also became stuck. All six authored `trigger_push` brushes existed. A local collision simulation reproduced the jam at the same wall.

Two defects combined:

1. The default Quake conveyor produced 312.5 m/s. A player could pass its approximately two-metre-wide downstream lift trigger in one physics step. Quake's original server bounds each velocity component at 2,000 Quake units/s, equivalent to 62.5 m/s at the game's map scale. [Original engine source](https://github.com/id-Software/Quake/blob/master/WinQuake/sv_phys.c).
2. The runtime's reverse scene traversal applied overlapping push brushes in reverse BSP order. At the bend, the lower conveyor could overwrite the upward lift force.

`deathmatch/maps/runtime.gd` now restores BSP model order among push regions and applies the original component-wise limit to unannotated Quake push forces. Explicitly calibrated FPSloppa pads and legacy HiSlop forces retain their previous convention. This adds setup-time sorting, not new per-frame collision queries. Geometry, textures and BSP hashes are unchanged.

The exact map collision now passes twelve traversals: both pipes, three lateral approach offsets and two starting phases. The short pipe reaches its upper exit above Y=5.5 m; the tall pipe reaches its exit above Y=22 m. No widening, invisible-blocker removal or new launch pad was needed for those routes. Existing Hyperborea launch ramps and telefrag behavior also pass. Relevant fixtures are `deathmatch/tests/dm7_pipes.gd` and `deathmatch/tests/pad_telefrag.gd`; the latter was updated to use the bundled Hyperborea map and explicitly create its target after rotation.

The server and headset client were restarted with the correction. Live telemetry captured the short-pipe ascent at approximately 62.17 m/s. The wearer confirmed **both pipes, movement, jumps and rocket firing were correct**. The wearer also confirmed grenade jumping works mechanically; no implementation changes were requested or made for it.

## Network and movement observations

The first capture lasted 493 seconds and the corrected capture 222 seconds. Each included periods with the wearer and three automated remote clients. The initial clients included synthetic body-tracking payloads intended to exercise bandwidth; these caused the visibly unnatural NetBot 10 pose. They were replaced with ordinary desktop-controlled clients for visual checks and the entire corrected capture. That pose is not evidence of a defect in an actual second headset's tracking.

The corrected four-player capture contained 1,619 focused active samples:

| Measurement | Median | 95th percentile |
| --- | ---: | ---: |
| Round-trip ping | 28 ms | 39 ms |
| Received update jitter estimate | 4.15 ms | 10.26 ms |
| Remote interpolation delay | 83.29 ms | 95.52 ms |
| Server input age | 17 ms | 33 ms |
| Server physics tick | 7.18 ms | 11.41 ms |
| Client frame interval | 14.01 ms | 20.94 ms |

The server recorded zero socket drops, zero orphan nodes and no engine/script errors. Snapshot payloads stayed within 1,100 bytes. Median snapshot traffic was about 6.1 kB/s per peer; this excludes other packet types and transport overhead. Replicated player-version gaps were 0.264% of observed plus skipped versions. These are sequence gaps, not a direct measurement of UDP packet loss. Server memory peaked near 124 MiB.

Grounded moving samples had a median standing speed of 9.4 m/s. No sustained moving crouch/prone samples were captured, so this session does not add a remote stance-speed measurement.

The wearer reported no rubber-banding, delayed jumps or missed rockets after the correction. The client nevertheless recorded **one prediction reset**, with a 4.40 m historical position error near the short-pipe exit; retain this as a follow-up case for fast forced movement. It is not evidence that the wearer perceived a four-metre visible jump. Ordinary soft corrections also occurred. This session does not establish that every reconciliation path is flawless.

Frame timings are observational: three automated clients, collision tests and a later package export also ran on the same development PC. They are not an isolated VR GPU benchmark, a constant 72 Hz guarantee, or standalone Quest/Pico performance. Before/after traffic figures are not directly comparable because the synthetic tracking load was removed. The first capture's update-age counter contains a reset artifact during map transition; it must not be read as a 186-second network stall.

Both headset processes and all nine automated client instances exited with code 0. The Godot/OpenXR teardown logged `XR_ERROR_SESSION_NOT_STOPPING`, a spatial-marker signal-disconnect error and four interaction-profile RID leaks; MultiMesh interpolation warnings also occurred during gameplay. There were no GDScript runtime errors in the final VR capture. These shutdown diagnostics are retained, so this is not a claim that the client logs are error-free. The worn-device feedback was successful.

## Artifacts and remaining test server

Full local logs, telemetry, before/after server captures, reproduction traces, deployment receipt, candidate hashes and the derived `summary.json` are retained in `test-results/remote-vr-20260914/`. Raw local telemetry and credentials are not distribution files. The source inspection script `summarize.py` reproduces the measurements there.

Linux and Windows hotfix candidates were rebuilt with the pipe correction, and `Builds/Hotfix-0.11v/SHA256SUMS` was refreshed. They remain unpublished. Windows/VirtualDesktop was not exercised in this session.

The test clients are closed. Port 27777 remains available on DM7 with a one-hour process timeout measured from the corrected server's restart; it will stop automatically. The unchanged production process continues on port 7777. No grenade-jump implementation work is pending.
