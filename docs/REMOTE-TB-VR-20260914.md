# Titanball remote VR test — 14 September 2026

The existing remote test instance at **45.147.228.101:27777** ran `tb_ashfall`, Quake/TF rules, capacity ten: the headset wearer and four red attacking bots versus five blue defending bots. A test-only main-scene harness created server-authoritative bots while keeping normal network joining available. All nine bots were soldiers; this is not a mixed-class balance study. The production instance on port 7777 was not changed.

The first external-script launch did not load the harness in the release runtime. A packaged test scene corrected that, followed by a brief server/client restart. The complete capture after correction lasted **1,213.9 seconds**, on Linux Vulkan Mobile through WiVRn. The client exited with code 0. Both checkpoints were cleared in the completed round, but defenders won when the extended timer expired. A second round began before the wearer left.

| Measurement | Median | 95th percentile |
| --- | ---: | ---: |
| Client round-trip latency | 32 ms | 46 ms |
| Client frame interval | 14.96 ms | 19.05 ms |
| Server physics time | 20.87 ms | 28.61 ms |
| Human input age on server | 17 ms | 33 ms |

The server recorded no engine errors and no socket drops; peak RSS was about 205 MiB. The server physics time exceeds the 16.67 ms budget for 60 Hz, making nine-bot TB CPU cost a follow-up concern. This capture does not isolate navigation, cannon traces, collision, AI or ordinary network work sufficiently to identify the dominant cause. Local tests ran during part of the session, so client frame times are observational.

No client GDScript errors were recorded. Existing MultiMesh interpolation warnings appeared during gameplay. Captured process output also retained OpenXR shutdown diagnostics: session-not-stopping, a nonexistent spatial-marker signal disconnect and four InteractionProfile RID leaks. Exit code zero is not a claim of warning-free shutdown.

The wearer reported unclear vertical cockpit aiming, a sniper helper beam visible in the scope, a small scope picture and incorrect flamethrower effects/sound. Follow-up changes and offline validation are documented in `TB-CONTROLS-OPTICS-FEEDBACK.md`. This remote pack preceded those fixes and the new bot advanced-movement work.

Raw gameplay/performance logs, full client telemetry, the test harness, packaged test PCK and a reproducible `summarize.py`/`summary.json` are in `test-results/remote-tb-vr-20260914/`. The test server uses a one-hour automatic process timeout from its restart. Credentials and raw player telemetry are not distribution artifacts.
