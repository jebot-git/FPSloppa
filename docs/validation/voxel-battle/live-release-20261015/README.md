# CQ live release review — 15 October 2026

Source branch: `experimental/cq-voxelspace`, based on `2ab5a07f`. The changes described below are in the working tree. The published 0.17 archives and live server have not been replaced by this pass, and no new headset session was launched.

## Evidence and timing

Server journal/events and local client, engine, network, WiVRn and GPU-kernel logs were collected for approximately **20:14:30–21:03 Prague (18:14:30–19:03 UTC)**. [Raw log hashes](evidence.json), [analytics](analytics.json), [frame windows](frame-windows.json), and [frame-pacing chart](frame-pacing.png) preserve the analysis. The private raw bundle is [live-logs.tar.gz](/home/blux/.cache/cq-live-20261015-final/live-logs.tar.gz); peer addresses remain in that local archive.

The two Downloads recordings, `2026-10-15 19-41-02.mkv` and `2026-10-15 19-58-34.mkv`, were inspected through their duration. [Video hashes](videos.json) and contact sheets in `checks/` retain the evidence. Both demonstrate vegetation selection changes during head movement. Their filenames are not treated as synchronized test timestamps.

| Measurement | Result |
| --- | --- |
| Local frame reports | 280 ten-second windows, 217,495 frames |
| Active gameplay | 247 windows, weighted **77.72 FPS** |
| Median of active-window wall-time p95 values | **24.72 ms** |
| Median of active-window GPU-render p95 values | **4.45 ms** |
| Median of active-window renderer-CPU p95 values | **0.43 ms**, not total client CPU |
| Server health samples / peak connected players | 581 / **3** |
| Sampled server physics median / p95 / maximum | **1.61 / 2.13 / 7.65 ms** |
| In-window server engine diagnostics | None recorded |

The slowest active window began at **20:26:24 Prague**, shocktroop in vehicle 1, averaging **65.37 FPS**. Class averages were medic 73.73, scout 78.68, shocktroop 77.34 and technician 79.64 FPS; these different activities do not establish a class-specific cause. Only one window was tagged scoped, insufficient to qualify scope performance.

WiVRn logged recenter failures around **20:16:11–20:16:44 Prague**, followed by a stream-socket network exception and paused session at 20:16:44. The filtered kernel log contains no matching GPU reset/hang/OOM/segfault report. This is a local headset-stream interruption, not evidence explaining the Windows player's separate connection report.

**Vive Pro 2 was running at 90 Hz**, correcting the earlier 120 Hz report. Saved frame statistics belong to the local Quest Pro/WiVRn client, also at 90 Hz. They cannot identify the Vive user's alternating CPU-spike cause. There was no per-frame physics/grass/audio attribution in that capture; subsequent opt-in telemetry groups those workloads and labels whether refresh rate is runtime-reported or assumed. Window percentiles cannot be combined into a global frame percentile. Three connected clients do not qualify 64-player capacity, and unchanged legacy server combat counters do not describe all native CQ combat.

## Implemented changes

- Scope magnification uses the physical aperture and eye distance for the selected zoom. Its camera has its own compositor so shared NVG processing cannot overwrite the scope texture before the main-view pass.
- Red dots use a collimated eye ray clipped to the physical lens, with a restrained emissive 4-MOA dot. Vulkan renders verify lateral eye movement holds the screen aim direction and leaving the aperture hides the dot.
- Confirmed local shot tracers attach to the current rendered muzzle when the confirmation belongs to the current life/weapon and the short correction is unobstructed. Authoritative hit positions are retained. This corrects delayed tracer presentation; it does not by itself prove every ballistic case.
- Grass selection is stable around the player rather than rebuilt from a mono camera frustum on head turns. Far cards receive stable spatial priorities across the range; the existing 2,048-instance and 12-group limits remain. Updates require movement or dirty tiles. Sound behavior was not assumed to be the spike cause.
- VR tanks retain their real hull as a heading reference. Transport driver and front passenger avatars render; enclosed pod occupants remain hidden.
- Transport steering requires throttle/reverse input and movement. **Main-hand trigger accelerates; offhand trigger brakes/reverses; main joystick click toggles headlights.** The physical wheel still requires a grip. Menus follow the final cabin transform in the same frame.
- UT avatar torsos now include physical headset yaw in addition to locomotion yaw. Head/hand/weapon poses are rebased into that facing so IK and attachments do not rotate twice. Desktop actors retain locomotion yaw, and dead actors retain their final facing.
- Controller-inferred OpenXR hand tracking is requested at startup. Local gloves now consume those joint curls, with per-finger controller fallback, independently of body calibration. Automated checks exercise joint routing and automatic skeleton updates; real Index confirmation remains outstanding.
- The Costa Rican ambience layer was excluded after the rooster report. Both 120-second day/night loops were regenerated at their existing levels. The original WAVs are untouched. [Audio quality and source scans](audio/) document the change; [audition](../../../audio/cq-jungle-20261015/audition.ogg) is day then night with +8 dB review gain. Automated classification supports source selection and is not a listening guarantee.

## Validation

[Validation receipt](validation.json) and logs in `checks/` record:

- Native core: **266,458 checks**, including a 64-player deterministic replay over 3,600 ticks and idle/coasting transport steering at 30/60 Hz.
- Grass: **4,281 checks**, including rotation stability and far-range coverage.
- Optics/tracer/tank view: **30 checks** with real Vulkan scope and dot captures.
- Transport: **72 checks**, including cabin avatars and same-frame moving-menu placement.
- Wheel input: **25 checks** covering trigger pedals, handedness and headlights.
- Avatar attachments/facing: **1,094 checks** across all five base models, quarter/half-turns, death facing and tracked transform preservation.
- Avatar LOD: **107 checks** pass with the facing correction.
- Local hand tracking: passing controller fallback, independent inferred joints and automatic glove modifier checks.
- Field audio: **51 assets** pass finite-sample, clipping, DC and loop-seam checks.
- Native Linux server, Linux client and Windows client libraries rebuilt successfully; relevant GDScript checks and `git diff --check` pass.

Hardware verification of the fixes, especially Index fingers, moving-vehicle comfort and Vive pacing, remains for a subsequent test.
