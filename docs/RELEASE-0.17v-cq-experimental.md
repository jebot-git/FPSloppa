# FPSloppa CQ 0.17 — corrected VR client builds

Fixes rendered client startup in the 0.17 game-only release. Both Linux and Windows packages are corrected. Extract the full archive and run `Play-VR` or `Play-Desktop`; clients connect automatically to **87.106.27.237:7777**. No launcher/updater is included.

- Preserve Godot's complete script-class metadata when packaging, including implicit `RefCounted` classes used by XR hands and VR menus. The old packager silently omitted these classes, causing VR script compilation failures.
- Initialize terrain texture arrays outside assertions. Release templates omit assertion expressions, leaving the arrays uninitialized and producing repeated texture-format errors. Voxel header reads now also execute normally in release builds.
- Add a shipped resource check that compiles the VR-only dependency graph and verifies terrain texture array allocation/uploads, even in headless checks.

Linux and Windows-under-Wine resource and multiplayer checks are included with the validation evidence. Linux startup is additionally exercised with the real Forward+ Vulkan renderer and WiVRn-Pro OpenXR runtime. Native Windows GPU/OpenXR hardware remains untested.

Compatible with the deployed CQ server at **87.106.27.237:7777**, with destruction, 64 slots and adaptive 60/30 Hz simulation. Sustained 64-player load remains experimental. This hotfix does not change gameplay protocol or native binaries.

Artifacts include per-file hashes and licenses; verify downloads with `SHA256SUMS` and `BUILD-MANIFEST.json`.
