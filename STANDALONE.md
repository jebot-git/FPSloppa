# Unified standalone installation

Starting with 0.15v, releases target Windows, Linux and Quest. Pico builds are discontinued; previous releases and existing controller compatibility code are retained.

Current Quest builds include the game plus all base runtime assets in one APK. All 26 base maps include low baked ambient occlusion. Install the matching APK and launch it. On first launch, a disk worker verifies and extracts the included maps, scene/navigation caches, models and notices before the game catalog loads. A temporary XR camera presents loading status before the full game rig starts. No separate asset APK, download or folder copy is needed. Later launches verify the assets and repair damaged bundled files. Custom imports and edited maplists/configs are preserved.

Files inside the embedded ZIP are compressed, but the APK stores that ZIP without another compression layer so Android can seek through it efficiently. Double compression caused minutes of asset-verification delay on Quest 3. Allow additional storage for extracted assets. Optional maps and other players' custom models still download from the server when needed. The ASSETS menu remains available for rescanning and manual recovery.

# Quest standalone builds

An ARM64 release-runtime APK can be built with Godot 4.7.2 and official Godot OpenXR Vendors 5.1.0 (Meta for Quest). It uses the Vulkan Mobile renderer, mobile textures, Internet and microphone permissions, and a persistent local development signing key. This is an experimental sideload build, not a store release.

Quest shares PC/server protocol `fpsloppa-39-rotating-koth`, authoritative combat, mode-appropriate loadouts, fixed hitboxes, host map downloads and 25 MB avatar transfers. Crossplay is preserved in the implementation; a completed cross-device match has not been verified. On 12 September 2026, the native Quest APK installed its assets, loaded `qsrc_dm1` and initialized the full OpenXR rig on a physical Quest 3 using Vulkan 1.3.295 / Adreno 740. The wearer confirmed correct scene rendering and tracking, with no avatar shimmer observed; Practice mode and bot combat were confirmed in the live log. A subsequent check exposed intermittent OS-level controller disconnects in both the game and Quest Home. A headset restart resolved them, and the same APK passed the ADB/manual retest ([diagnostics](docs/validation/quest-controllers.json)). Sustained match performance remains unverified. Native Pico hardware has not been tested.

## Install and play

Enable developer mode and USB debugging on the headset, authorize this computer, then install the appropriate package:

```sh
adb install -r Builds/Android/FPSloppa-Quest.apk
```

Use only the APK matching your headset. Launch FPSloppa from the headset's unknown sources/developer applications. Join the PC or dedicated server's reachable IP and configured UDP port (see SERVER.md). Voice starts in push-to-talk mode and requests microphone access at startup. Hold the off-hand grip to speak. Quest tracking permissions (body, hands, eyes, face) are queued after microphone access. Denial leaves the game usable; retry from **VOICE… → RETRY ACCESS** or headset app settings. Tracking support still depends on the hardware/runtime, and first-time grants may require an app restart. Smooth turning is the default. Touch and Pico controller profiles are included; PC Index support remains.

## Rebuild

The installed toolchain uses Temurin JDK 17.0.20.1, Android command-line tools 23, SDK platform 36, build-tools 36.1.0, platform-tools 37.0.1, NDK 29.0.14206865, CMake 3.10.2 and Godot 4.7.2 Android export templates. The SDK/NDK versions match the downloaded template’s `config.gradle`; its wrapper uses Gradle 8.11.1. Downloads came from the official Godot, Eclipse Adoptium and Google repositories, with archive checksums verified. No system Java replacement is needed. `gradlew --no-daemon help` completed successfully after installation; setup logs are in `test-results/android-dependencies.log` and `test-results/android-gradle-setup.log`.

Set Godot Editor Settings → Export → Android Java SDK Path and Android SDK Path to your installed JDK/SDK. These are configured here as `/home/blux/.local/share/entryway-toolchains/jdk-17.0.20.1+1` and `/home/blux/Android/Sdk`.

```sh
python3 tools/install_android_dependencies.py
python3 tools/build_base_assets.py  # when base files change
python3 tools/build_android.py      # unified is the default
# Quest is the only standalone release target.
```

The installer accepts `JAVA_HOME` and `ANDROID_SDK_ROOT` overrides. The builder also accepts `GODOT_BIN`, and otherwise finds `godot` on PATH. It restores the generated Gradle template from the matching installed export templates when absent. Source archives exclude android/build and its caches. The local signing key and password stay outside the project under `~/.local/share/entryway-toolchains/signing/`; back up that directory privately to preserve update compatibility. These credentials are never included in the source archive. A different key requires uninstalling the previous installation or choosing another package ID.

Run `python3 tools/verify_android.py` to check vendor manifests, ARM64 libraries, protocol, current scripts, embedded archive and all map/avatar hashes. The verifier requires microphone/vendor tracking declarations and current voice/body scripts, so old APKs will fail. The Android SDK and matching Android export templates are installed, including the generated `android/build` Gradle project. Version 0.3v includes rebuilt Steam Audio extension libraries aligned for 16 KiB pages. Body and hand extensions are optional and require device/runtime support.

Exports and signature reports are under `test-results/`; APKs and SHA256 files are under `../Builds/Android/`. The builder verifies signatures and 16 KB ZIP alignment. The Quest export retains plain GDScript and the VRM release-runtime compatibility patches. The Android builder embeds the verified base ZIP temporarily, removes its build input afterward, and keeps optional packs out of the APK. Thin builds are retired. Base Assets remains an internal build input and is not published separately. The normal verifier requires unified APKs.

## Device validation still required

Test tracking, controller grips/buttons, MToon rendering, VR menus, microphone permission/capture, voice latency, reconnects, downloads and PC/Quest matches on physical devices. Profile eight-player matches at the headset target frame rate. Default avatars have about 27–34 thousand triangles and 16–17 materials each; the 25 MB custom-model cap does not bound GPU memory. Avatar LODs and material reduction may be needed.

Android scoped storage still needs a document-picker workflow for convenient local VRM/BSP imports. Host-downloaded assets use the game's writable data directory. Runtime VRM decoding and downloaded BSP compilation are synchronous and can stall rendering. Mobile/Vulkan is the maintained renderer; automatic OpenGL/GLES fallback is disabled. APK packaging success does not establish mobile thermal performance, store compliance or headset support.

The September renderer change removes OpenGL-specific avatar/decal workarounds and targets Vulkan on Quest. Export verification checks the actual packaged renderer settings. See the [renderer support assessment and Quest test status](docs/RENDERER-SUPPORT.md).

References: [Godot Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html), [Android XR deployment](https://docs.godotengine.org/en/4.7/tutorials/xr/deploying_to_android.html), [official OpenXR Vendors 5.1.0](https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.1.0-stable).

See TRACKING.md for Quest body permission, SlimeVR setup and native Pico tracker limitations. See AUDIO.md for positional voice and mouth animation.

This release requests the lowest advertised standalone refresh rate at or above 72 Hz, enables OpenXR VRS/foveation, uses 2× MSAA on Android, and reduces avatar/light costs. These are configuration and code optimizations, not a measured 72 FPS headset certification. See PERFORMANCE.md.
