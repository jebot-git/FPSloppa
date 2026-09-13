# Renderer support — 12 September 2026

FPSloppa maintains **Mobile/Vulkan** for Linux, Windows and standalone Quest/Pico. OpenGL/GLES Compatibility is unsupported and automatic OpenGL fallback is disabled in `project.godot`. Windows retains Godot's native D3D12 fallback capability; it has not been validated here. The dedicated server requires no graphics API.

The project now uses one MToon fill policy and the Mobile decal path. The Compatibility-specific avatar fill, mesh-decal workaround and global depth-prepass workaround were removed. Map/demo preview helpers and default rendering tests use Mobile. Older OpenGL comparison tools and receipts remain as historical diagnostics, not supported game configurations.

## Platform basis

[Meta's Vulkan mobile-VR article](https://developers.meta.com/horizon/blog/vulkan-for-mobile-vr-rendering/) describes Vulkan support for MSAA, multiview and foveation and its lower-overhead design. It dates from 2019; it supports the API's suitability, not a claim that this particular Godot build is certified on every headset.

[Pico's hardware/software matrix](https://developer.picoxr.com/document/unreal/hardware-and-software-specifications/) lists Vulkan rendering for its supported Neo3/4 devices. The supplied [Pico Vulkan page](https://developer.picoxr.com/document/unreal/vulkan-rendering/) returned only navigation content to the research tool, so its exact warning about simultaneously enabling GLES/Vulkan was not independently verified. Those engine-specific export settings must not be confused with Godot retaining unused backend code inside a stock export template.

Godot's [fallback setting](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-rendering-device-fallback-to-opengl3) controls automatic selection of Compatibility. Exported Android `project.binary` is checked for Mobile and disabled OpenGL fallback. The APK manifest requires Vulkan 1.1. The stock template still contains OpenGL implementation code and a GLES hardware-capability declaration; that does not enable a second active game renderer. No claim is made that custom engine binaries were compiled with OpenGL physically removed.

## Physical validation

A physical Quest 3 successfully installed the bundled assets, loaded **qsrc_dm1** and reported **XR_READY OpenXR** on **Vulkan 1.3.295 / Mobile / Adreno 740**, using Oculus runtime 207.218.0. The final 30-second startup capture contains no missing-viewport warnings or engine errors. VrApi reports roughly 72 FPS after startup at a 72 Hz target; this short startup sample is not sustained match or thermal validation. A later read-only log confirms Practice mode and bot combat in the same process. The wearer confirmed that the scene and tracking look correct and no avatar shimmer was seen. This is a manual Quest 3 check, not exhaustive coverage of all avatars/maps.

Two first-launch problems were fixed: the asset ZIP must be stored without a second compression layer in the APK for efficient Android random access, and a temporary XR camera must submit loading frames before the full game rig exists. The APK verifier now enforces seekable ZIP storage as well as packaged Mobile/Vulkan settings and the required Vulkan manifest feature. Both Quest and Pico APKs pass verification. The desktop Mobile MToon emission regression also passes.

The [validation receipt](validation/quest-vulkan.json) records APK/source hashes and the bounded device capture. Raw captures remain under `test-results/quest-vulkan/`. To repeat the test, run `python3 tools/test_quest_vulkan.py --serial DEVICE_SERIAL --seconds 30 --label startup`. This command **stops and relaunches FPSloppa**, then retains only that app's process log. Do not run it during an ongoing manual headset check.

Quest and Pico APKs are locally signed experimental sideload builds. Native Pico and Windows hardware testing remain separate from Quest validation. The older [lighting assessment](../tools/lighting_experiment/README.md) and OpenGL receipts record the former support policy and its measurements.

A subsequent session exposed intermittent controller tracking loss and OS-level disconnects. Quest SyncBossHAL logs contain repeated `IMU corrupt` messages, while both controllers report 60% battery on reconnect. FPSloppa remains running. The wearer subsequently reproduced the failure in Quest Home both with USB connected and unplugged. This makes an FPSloppa-only or active USB/ADB cause much less likely; the underlying controller/runtime cause remains unresolved. A clean restart and Home-only test with fresh batteries is the next isolation step. This qualifies the earlier short tracking check without changing its rendering/no-shimmer observation. See the [controller diagnostic receipt](validation/quest-controllers.json).

After restarting the headset, the same installed APK passed a repeat 45-second ADB startup capture: Vulkan/OpenXR ready, `qsrc_dm1` loaded, no engine errors or missing-viewport warnings. The companion controller log contains zero `IMU corrupt` messages and reports both controllers connected. The wearer reported no issue during this retest. Restart resolved the observed fault; a transient headset OS/runtime problem is plausible, but its exact cause is unproven. No game code or APK changes were made between these runs.
