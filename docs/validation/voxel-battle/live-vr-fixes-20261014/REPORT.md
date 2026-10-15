# CQ live VR fixes — 14 October 2026

Worktree: `.worktrees/cq-voxelspace`, branch `experimental/cq-voxelspace`. Reviewed the supplied Downloads/rec.mp4 through timestamped frames. These changes target the resident native CQ authority and its paired client. Protocol is now `fpsloppa-cq-frontier-22-live-fixes`; client and server must update together.

## Changes

- Transport has eight seats: dedicated driver, front passenger and six side pods. Entry markers match native boarding anchors. Jump dismounts; a passenger can use the vacant driver seat without being ejected. Squad spawning uses free passenger seats and never a driver's seat. Cockpit glass now provides an outside view, and all seats have visible furnishings. Transport retains existing 100 HP and battery-tank damage rules.
- Native reload logic separates trigger-operated magazines/pouch from grip-operated charging handles. Carried magazine rounds and reload events replicate explicitly. Hand attachment uses tracked aim axes, magazines show remaining rounds, charging handles protrude and play nearby sounds, pistol slides and bolts move and lock visibly when empty. CQ weapon-hand B/Y ejects; support-hand B/Y opens the tactical map; hardware menu alone opens the menu.
- Shared muzzle metadata now aligns effects to weapon geometry. Three optics render actual red dots. Pistols have a small front-blade alignment correction. Holstered main weapons use a diagonal chest mount. Existing articulated hands now receive live controller curls.
- Either hand can grip the shoulder utility/radio. Utility use and grenade throw origins follow the selected tracked hand, while authority validation remains native. World-anchored deployment/menu panels and removal of duplicated movement smoothing address deployment and uphill jitter.
- The combat tactical map shows the local player's heading, controlled POIs and squad positions. Virtual stock has a pressed highlight and explicit on/off state. Dynamic foveation is selectable separately from static foveation; eye gaze interaction is enabled for runtimes that expose it.
- NVG runs before transparent UI and optical overlays. Daytime occupies 55% of the lighting cycle. Uncontested POI capture takes 10/N seconds for N allied players in the circle; opposing presence stops capture.
- Rocket tank trajectories use a 5 km horizontal limit, sufficient flight lifetime and maximum-range ballistic solutions in the native authority. This does not enlarge the existing map or let shots pass through terrain.
- Door openings are 2.3 m, storeys 3.6 m, and stairs are wider and moved away from adjacent walls. Rebuilt baked lighting covers 154,360 vertices and 384 fixtures.
- Jetpack ignition and sustained thrust have positional audio. Walking grass rustle is silent; running rustle is reduced to -26 dB. Ambience has its own persisted volume slider and audio bus. New reload and jetpack sounds are original procedural assets with source generators under tools/cq_audio.

## Validation

- Native golden and ASan/UBSan runs: 910,228 checks each. [Core](core-tests.json), [sanitizers](sanitizers.log).
- Jolt functional suites: 33,993 checks, including actual eight-seat boarding. [Suite evidence](suite.json).
- 32/64 tracked synthetic clients: 301 measured ticks at approximately 30 Hz, zero malformed frames and disconnects. Server callback p95: 2.8/6.5 ms. At 64 players 99.96% of minimum offered inputs were accepted during the measurement. This short test does not certify sustained 64-player capacity.
- Rendered live-fix checks: 53; controller/hand/menu interactions: 17; audio: 16; menu: 62; NVG GPU: 12; NVG rules: 25; squad/map: 38; rendered transport: 55. Logs and rendered screenshots are retained alongside this report.
- Production CQ desktop and tracked clients passed admission, squad/class changes, firing, reload-related input, jetpack, grenade, NVG, death and respawn checks. Four real-map bots moved and fired for 600 ticks; 19 existing authored-navmesh edge warnings remain. [Arena evidence](arena.json).
- Portable native package passed build-receipt validation. [Release hashes](release-sha256.json).

## Limits of automated confirmation

Physical magazine reinsertion, shoulder reach, sight comfort and perceived uphill/deployment stability still require the player's headset confirmation. Tests cover state transitions, real controller inputs, native geometry queries and rendered views. Gaze-directed foveation depends on what the connected OpenXR runtime exposes; selecting dynamic mode alone does not establish that eye tracking is active. The old broad cq_vr_port fixture remains incompatible with earlier CQ UI removals; current focused fixtures passed instead. Audio fixture shutdown reported eight leaked test objects; no runtime script errors occurred there. Blender MCP was unavailable during this pass, so mesh adjustments are runtime geometry/shader changes, not a newly authored Blender file.

## Live deployment

Remote release `20261014-cq-live-fixes` passed uploaded-file SHA-256 verification and isolated native startup on UDP 28817. Activated through the visible sudo terminal. The previous service was stopped and its release/config retained for rollback. New service PID 1635945, server collector PID 1636304. Server diagnostics: `/home/blux/fpsloppa-cq/analytics/20261014-cq-live-fixes` on the remote host. The matching VR client PID 234257 and client/WiVRn collector PID 234258 were launched with local diagnostics under `/home/blux/.cache/cq-live-fixes/analytics-20261014`. Collectors run for up to two hours, pinned to these process identities. Raw controller poses and microphone audio are not captured by these collectors.

The live client connected successfully with a focused XR session, map loaded, 100 initial shocktroop armour and the player-controlled class/calibration/deployment menu open. WiVRn 26.9.3-pyrowave.1 identifies Meta Quest Pro and registers the WiVRn Eye Tracker. Initial menu telemetry reports 90 FPS; this is not an in-match performance measurement. No script or engine errors appeared in the initial client log. Existing glove UID fallbacks and Jolt solver-bias warnings remain. [Launch check](live-client-check.json).
