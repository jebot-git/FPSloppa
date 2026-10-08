# Converted DE penetration

`build.py` emits hash-bound BSP solid trees and face polygons for all 14 retained
converted maps. Texture-name rules and overrides assign wood, glass, vent,
metal, concrete or blocking surfaces; ambiguous opaque textures use concrete.
These are adaptation rules, not exact GoldSrc material equivalence.

Runtime queries merge adjacent solid leaves, preserve air gaps, account for
angle and material, follow active translated models, and check real physics
exits. Invalid data or exceeded budgets block penetration. Weapon power,
ammunition, player hitboxes and damage replication reuse existing CS combat.
Bots acquire targets through ordinary visibility; this does not grant wall vision.

Validation receipts: `validation.json` (14 real maps, 33,159 probes),
`edge_cases.json` (18 checks), `network-server.json` and `network-client.json`
(real ENet damage through converted Inferno cover). Combat fixtures exercise
both backends, headshots, power limits and ammunition conservation.

Rebuild with `python3 tools/de_penetration/build.py`. Run `validate.gd` and
`edge_cases.gd` through headless Godot, then `python3 tools/de_penetration/network.py`.
The base-bundle preflight rejects missing or stale penetration profiles.

## Santorini bot recording

`python3 tools/de_penetration/record_santorini.py` starts a loopback server on
28981, ten bots split 5v5, and a spectator client. `santorini.cfg` sets a
six-round maximum (first to four wins, sides change after round three). The
server waits for the spectator and FFmpeg before starting the buy phase.
The late-process camera follows live bots without changing their inputs.
FFmpeg records only the game window at 720p/30 FPS and its isolated PulseAudio
sink; desktop audio and microphones are not captured. This Linux workflow
requires X11, PulseAudio/PipeWire, xwininfo, xprop and FFmpeg.

Output: `test-results/de-santorini-recording/santorini-5v5.mp4`, with server,
client, final-score and recording receipts alongside it. The client closes
after the final scoreboard. The local server holds the completed match.
Wallbang policy tests: `./run.sh --headless --xr-mode off --script
 tools/de_penetration/bot_wallbang.gd` (put the command on one line).

Use `python3 tools/de_penetration/record_santorini.py --smooth-camera` for a
separate recording in `test-results/de-santorini-smooth-recording/`. This uses a
damped third-person chase camera with obstruction checks and a close-space
first-person fallback. It preserves the original recording. Server receipts
include raw versus filtered travel-input direction variation.
