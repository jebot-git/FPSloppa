# Remote eight-client all-mode test — 12 September 2026

The current console-only build was deployed to `45.147.228.101:7777`. The previous release process (PID 76043) was terminated. Eight independent local Godot clients sent normal ENet player commands to the remote host; a ninth graphical client spectated and recorded the session. No lobby transition occurred.

## Completed rounds

Map selection and applicable weapon rules were drawn once from a recorded random seed (`1001658562`). TF was fixed to Quake and Assault to UT99. IG, IF and CC retained their mandatory weapons. Other modes used their selected ruleset’s normal spawn/pickup inventories. Each mode had a one-minute round limit; Assault completed two one-minute attack/defend legs with its normal side-switch intermission.

| Mode | Map | Weapon rules | Result |
|---|---|---|---|
| DM | qsrc_dm3 | quake | NetBot 03 wins · 1 frags |
| TDM | qsrc_dm6 | doom | RED WINS · 6 : 4 |
| CTF | ctf_crownreach | ut99 | DRAW · 0 : 0 |
| KOTH | koth_alichar | doom | BLUE WINS · 1 : 6 |
| IG | qsrc_dm6 | doom | NetBot 04 wins · 7 frags |
| IF | qsrc_dm6 | doom | DRAW · 0 : 0 |
| FT | qsrc_dm3 | doom | RED WINS · 1 : 0 |
| CC | cc_basement | doom | NetBot 06 wins · 1 frags |
| TF | tf_vesper | quake | BLUE WINS · 0 : 1 |
| AS | as_frigate | ut99 | DRAW · neither team completed the assault |

All rounds retained eight players and one spectator. There were nine transport connections and nine departures during the full run; map-readiness handshakes reused these connections. All nine client processes exited with code 0. Server health snapshots reported zero orphan nodes, and the server engine log contained no errors. Client shutdown retained the known one-/two-instance ObjectDB warnings.

## Recording and export

Final [MP4](../video-output/remote-all-modes-2026-09-12.mp4): **11:56.82, 1440×900 at 30 FPS, H.264/AAC, ten chapters, 851,150,274 bytes**. The complete MP4 decoded successfully with no errors. [Raw demo](../test-results/remote-all-modes/all-modes.fpsdemo).

The spectator changed camera angle every 12 seconds and followed another bot every 24 seconds. The complete demo validates: **13,835 frames, 715.999999999677 seconds, ten modes, peak nine peers**. It contains 70 snapshot intervals longer than 100 ms, including map-loading transitions; this count alone is not packet-loss evidence.

Source demo: `test-results/remote-all-modes/all-modes.fpsdemo`. The MP4 is a Godot replay render using the same camera pacing, rather than a capture of the desktop. Segment screenshots and renderer logs are retained with the video. Replay workers report pre-existing resource-in-use shutdown warnings and some physics-interpolation warnings; those are separate from the clean remote server engine log.

## Findings and limits

- TF performed real flag take/drop/capture actions and ended BLUE 1–0. Freeze Tag completed a freeze round. KOTH accumulated hill points.
- One DM bot stayed stationary for the sampled round at `(-24, 5.995, -16)`, while the median bot travelled about 391 m. Another fell out of the arena. Reproduce the spawn/navigation situation before changing player collision.
- Instafreeze recorded only two shot-effect events, one freeze and no team point. Most bots kept moving. This needs a longer targeted encounter/thaw test; it does not demonstrate good combat coverage.
- CTF Crownreach had no flag take or capture in this short round. Neither team reached an Assault objective in the one-minute Frigate legs. These limits are too short to establish balance on the larger objective maps.
- The network bot adapter reuses navigation, perception and combat planning, but routes abilities through client RPCs and does not share the practice bots’ internal team-information bus. These results should not be treated as a complete test of server-side practice AI or every TF class/weapon.

## Process sampling and cleanup

An external `/proc` monitor sampled the last 265 seconds (late CC, TF and Assault), not the entire run. Resident memory ranged from **125.78 to 125.91 MiB**; median CPU use was **29.9%** of one core, with p95 **39.9%**. The process held five threads and seven file descriptors, and its UDP sockets recorded **zero drops**. This is a bounded stability observation, not proof that all leaks are absent.

After the match, the test server (PID 90076) and its monitor exited. A remote process and socket check found no running FPSloppa/Godot servers and no UDP listener on port 7777. The previous release remains stopped. Its empty detached shell session was left intact. The test package and logs remain on disk under `/home/blux/FPSloppa-AllModes-Test/`.

The authenticated RCON `match <mode> <map> <rules>` command was added so a mode/map/rules change happens in one transition. A local test against the actual console build verified invalid input rejection, same-map weapon remapping and fixed-loadout preservation. Deployment hashes matched the local executable and PCK.

Evidence: [structured results](validation/remote-all-modes.json), `test-results/remote-all-modes/`, and [test tools](../tools/remote_match/README.md).

## Replay fix found during export

The CTF replay exposed a reset-time assumption that catalog objective metadata always contains `red`, `blue` and `hill`. CTF metadata may legitimately omit a hill. The reset now applies bases and hill independently, preserving map/spawn fallbacks. A focused test passed both flags-without-hill and hill-without-flags cases, and the affected video portion is rerendered with the fix. This local correction was made after the remote run; the remote build hashes above identify the exact version that was tested.

Replay camera QA also found that inherited physics interpolation could override camera rotations applied between physics ticks. The render-frame director now disables camera interpolation, and the video is regenerated using the verified centered chase/side/elevated views. This affects the observation/export harness, not player movement. The task-created SSH control connection and RCON tunnel were closed after log collection.
