# CQ live-test follow-up — 15 October 2026

Worktree: `experimental/cq-voxelspace`, upstream base `1a6f952cc4433d24df407550766e99dc2c09db30`. Changes are local and uncommitted. The deployed server has not been changed in this batch. New client/server builds must match protocol `fpsloppa-cq-frontier-29-vr-mechanics` (CQI3 carries validated swim input).

## Implemented

[fixes.json](fixes.json) maps all 16 reported issues plus cloak orientation to the corresponding changes. Medic injector and technician repair tool use the back of the hip; deployable boxes remain on the shoulder. Dot rise was reduced from the initial excessive adjustment to 4.2 mm in asset space, or 15% of the 28 mm reticle window. The supplied sight drawing's front-view horizontal datum informs the optical-axis reference; the rendered dot remains inside the opening, clear of barrel and housing. No optic housing enlargement is included.

Additional repairs remove the missing `wheel_open()` call from vehicle input, disable inappropriate interpolation of render-updated instance meshes, and add an explicit eye-gaze action for the runtime. Frame reports now use actual OpenXR refresh rate, wall-clock percentiles, measured render costs and spike context (class, weapon, vehicle, NVG, scope, menu and loading).

## Frame pacing

[pacing.png](pacing.png) and [pacing.json](pacing.json) summarize the recorded session, not a benchmark of these changes. Low FPS during shocktroop testing clustered at approximately **16:23–16:25 and 16:27–16:30 Europe/Prague**, around **0:30–2:00 and 4:30–7:00 after the 16:22:45 launch**. The plot and JSON retain the individual sampled intervals rather than implying continuously low FPS throughout those ranges.

632 live gameplay samples: mean 83.29 FPS, median 89, minimum 64. Shocktroop median 76 FPS, with 159 sampled seconds below 75; other classes had zero or one. Across 71 ten-second windows, median window p95 was 15.403 ms and worst 31.752 ms. All 71 window p95 values exceeded the 90 Hz budget (11.11 ms); 22 exceeded two budgets. The old logger incorrectly labeled the target as 72 Hz.

WiVRn application's CPU p95 was about 11.26 ms, GPU p95 5.81 ms. Lower GPU engine utilization during slow intervals supports a CPU/scheduling hypothesis, but class and runtime correlations do not establish cause. Old telemetry lacks vehicle/NVG/scope context. Server native physics p95 was approximately 2.21 ms with no UDP buffer drops or service restarts. This was a single-player session and does not validate 64-player capacity. Native legacy server-log HP/input fields were stale and must not be interpreted as lost input. Encode-to-predicted-display latency is not full motion-to-photon latency.

## Validation

- Native authority with recorded reference workloads: **917,417 checks passed**.
- Same authority under AddressSanitizer and UndefinedBehaviorSanitizer: **917,417 checks passed**.
- Godot/native Jolt integration: **593 checks passed**.
- Simulated CQ VR mechanics: **31 checks passed**, including grip, back-hip mounts, pistol support, menu following, CQI3 and scope exclusion.
- Rendered optics, seating and prior rendering regressions: **56 checks passed**. Dot screenshots are included.
- Production loopback arena: desktop and tracked clients passed; four-bot navigation case passed (19 existing authored-navmesh edge warnings).
- Suicide/killfeed: **13 checks passed**.
- Audio quality: **51 checks passed**.
- Rendered pacing logger smoke check emitted measured CPU/GPU costs and real monitor refresh rate; an empty scene capped at 90 FPS is not a game-performance comparison.
- Isolated medic fixture client/server check: player medic 35 HP, armour 0; allied incapacitated bot 1 HP approximately 1.2 m away.

Evidence is under [checks](checks). Simulated glove imports produce existing invalid-UID warnings and resolve through their valid text paths. Medic headless client exit still reports 29 ObjectDB instances / 13 resources; the fixture state and ordinary gameplay checks pass, but this cleanup issue remains. Real headset ergonomics, audio balance, dynamic foveation and frame-pacing improvement require a further headset test.

## Prepared medic scene

`res://tools/voxel_battle/medic_test.tscn` uses the native authority on a separate loopback server, without restarting the deployed service. Player starts as medic at 35 HP / 0 armour; a nearby allied incapacitated bot has 1 HP and a five-minute training bleedout window. Normal-match bleedout is unchanged. Reset with **F8** or **RESET MEDIC TEST** in the menu. Fixture API requires both the explicit command-line flag and test-world metadata; it is not a production RPC.

Prepare with `python3 tools/voxel_battle/prepare_medic_test.py --output NEW_DIRECTORY`. Default starts only the local server and writes `run-client.sh` for the WiVRn-Pro client. `--check` validates headlessly and stops its server; `--xr` explicitly launches VR. The ready instance is recorded in `/home/blux/.cache/cq-medic-test-20261015-ready/prepared.json`.
