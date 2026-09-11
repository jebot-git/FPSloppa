# FPSloppa 0.8v

This release adds distinct metal music for every gameplay mode, body-tracking gestures, clearer combat feedback and more reliable VR movement, water and asset loading.

## Audio and combat

- Eight original metal scores use recorded electric guitars, bass and acoustic drums, with different riffs and rhythms for each mode. The title remains dark and ambient; the lobby uses light elevator music with corrected harmony. Tracks load asynchronously, crossfade and retain a separate music volume.
- WARLORD announcer calls cover match events, first blood, kill combinations, streaks and objective captures. Dedicated servers control them with `sv_announcer` (enabled by default); clients have an independent volume. VoiceBosch's CC BY-SA 4.0 license and attribution are included.
- BFG explosions add a 9 m radial blast with distance falloff and cover checks alongside the existing forward spray. Rocket jumping remains intact.
- CC chainsaw reach is shorter. Blades stop at world geometry with sparks and grinding sound; opposing blades can parry, imposing a 300 ms recovery on both players.
- Frozen players become cyan ice statues with a ground marker and frozen/thaw-progress label. Their original model materials return when thawed.

## VR and movement

- BSP water detection supports swimming, underwater feedback, breath depletion and drowning, including compatible TF maps. Short backward arm pulls propel VR swimming; downward strokes lift the player. Held jump remains available for swimming upward.
- With hip and both feet/lower legs tracked, hold a standing T-pose for about 1.4 seconds to calibrate automatically. A short jingle and haptic pulse confirm completion. Lower the arms before repeating; pose stability and cooldown checks prevent repeated calibration.
- Full-body knee bending, fast physical-jump detection, stair movement and view smoothing are improved. Controller-tracked arms remain visible without full-body tracking; the redundant fist mesh is hidden.
- Movement uses physics delta time and visual interpolation. VR guns have a short direction guide, and bindings dropdowns support trigger dragging.
- VR text chat appears in the notification area.

## Rendering, networking and servers

- Texture mipmaps and filtering work across imported map surfaces. Preparing mip variants and warming shaders reduces pauses when changing filtering settings.
- Map/model validation, hashing and disk transfers run through a bounded worker queue. Join/download completion guards prevent entering before required assets are ready. Voice preferences persist across reconnects.
- Dedicated-server match, lobby and intermission timers pause while no clients have finished joining. Ready spectators also start the clock; connections still downloading do not.

## Downloads and compatibility

Use matching **0.8v clients and servers**, protocol `fpsloppa-22-saw-contacts`. Android version code is **13**; package IDs and the existing signing identity are retained.

Downloads include Linux/Windows clients, a Linux dedicated server, experimental Quest/Pico sideload APKs, source, base assets, optional LibreQuake extra maps and the two original TF arenas. Desktop/server archives include base assets; standalone headsets download the matching base-asset package on first setup.

The soundtrack uses compact Ogg playback (about 14.34 MiB for all ten tracks), with editable source arrangements and A/B recordings in the source project. Comparison audio and source sample banks are excluded from game binaries.

Validation covers source regressions, exported Linux client/server joining, package contents, Android permissions, current native libraries and signing/alignment. Windows and standalone Android builds are inspected but are not physically tested here. The latest swimming-stroke and automatic-calibration comfort thresholds still need wearer verification. Existing isolated shutdown warnings are documented in the validation report; short server-load checks are not a long-duration leak certification.

See `docs/validation/release-0.8v.json` for the release checks. Private microphone recordings, raw tracking captures, local imported avatars and local converted commercial maps are excluded from release archives.

## Archived extras

The original forty-map Arena Collection 1 and the ThreeWave, TeamFortress and Arcane Dimensions conversion tools remain available **only from the [0.5v release](https://github.com/jebot-git/FPSloppa/releases/tag/0.5v)**. They will not be revised, developed further or included in later releases unless a map-loader or format change requires revisiting compatibility. The 0.5v downloads remain unchanged.
