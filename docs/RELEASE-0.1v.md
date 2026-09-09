# FPSloppa 0.1v

Initial packaged release of the VR/desktop arena shooter. The in-game title and executable names remain Entryway Deathmatch / Entryway.

- Five bundled LibreQuake BSP deathmatch arenas; the original Entryway map has been removed.
- Offline practice against three simple navigating, shooting and respawning bots. Pistol-only spawns and shared arena rules.
- PC OpenXR VR and desktop controls, full weapon movement, smooth turning by default, Touch and Index bindings.
- Online authoritative deathmatch, host map downloads, optional dedicated server with Q3A-style configuration, and positional voice chat.
- VRM avatars with a 25 MB import limit, shared hitboxes, automatic asset transfer, body-tracking inputs, IK, speech-driven mouth shapes, and bounded eye/blink synchronization when the headset/runtime/model supports it.
- Recorded spatial sound effects, blood/gibs and shot reactions; original generated launcher icon.
- Vulkan Mobile rendering, reduced lighting and avatar costs, VRS/foveation where supported, and frame telemetry.

## Downloads

- Linux and Windows ZIPs: extract the entire archive and use the included desktop or VR launcher.
- Linux dedicated server ZIP: edit `server.cfg`, open the configured UDP port, and run `start-server.sh`.
- Quest and Pico APKs: experimental ARM64 sideload builds, signed with the project's persistent development key. Version name `0.1v`, Android version code 4.
- Source ZIP: Godot 4.7.2 project, vendored plugins, source assets and build instructions. Godot also generates source archives from this tag.
- `SHA256SUMS`: checksums for the attached files.

All clients and servers must use protocol `entryway-dm-7-eyes`; older builds cannot join. The private signing key is not included in the repository or release.

## Validation and limits

Automated checks passed for bounded eye data, all three VRM eye/blink/mouth bindings, body tracking and spatial audio, bots on all five BSP maps, combat, ENet eye replication, host map downloads, voice transport, exported Linux client/server startup, and exported avatar loading. APK checks cover signatures, alignment, ARM64 libraries, tracking permissions and original transferable asset hashes.

A controlled single-viewport desktop benchmark on Intel ADL-N improved from 49.3 ms to 16.4 ms median frame time (about 61 FPS). **72 FPS on VR headsets is not verified.** No Quest/Pico headset was connected; native eye/body tracking, standalone installation, cross-device matches, and sustained thermal performance still require device testing. Windows was exported but not executed on Windows. See `PERFORMANCE.md`, `EYES.md` and `STANDALONE.md` for details.

Custom VRM decoding and downloaded BSP compilation can cause stalls. Bots do not plan sophisticated teleporter/platform routes. Native Pico full-body tracking remains subject to the vendor-plugin limitations described in `TRACKING.md`.

Bundled assets retain their original licenses; see `ASSET_CREDITS.md` and included license notices.
