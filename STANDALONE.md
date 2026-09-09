# Quest / Pico standalone builds

Separate ARM64 release-runtime APKs can be built with Godot 4.7.2 and official Godot OpenXR Vendors 5.1.0 (Meta for Quest, Pico for Pico). They use the Vulkan Mobile renderer, mobile textures, Internet and microphone permissions, and a persistent local development signing key. These are experimental sideload builds, not store releases.

Both share PC/server protocol `entryway-13-team-modes`, authoritative combat, pistol-only spawns, fixed hitboxes, host map downloads and 25 MB avatar transfers. Crossplay is preserved in the implementation; a completed cross-device match has not been verified. Native APK behavior has not been tested on a standalone headset; Quest Pro/WiVRn checks exercised the PC build.

## Install and play

Enable developer mode and USB debugging on the headset, authorize this computer, then install the appropriate package:

```sh
adb install -r Builds/Android/Entryway-Quest.apk
adb install -r Builds/Android/Entryway-Pico.apk
```

Use only the APK matching your headset. Launch Entryway Arena from the headset's unknown sources/developer applications. Join the PC or dedicated server's reachable IP and configured UDP port (see SERVER.md). Voice starts in push-to-talk mode and requests microphone access at startup. Hold the off-hand grip to speak. Quest tracking permissions (body, hands, eyes, face) and Pico eye permission are queued after microphone access. Denial leaves the game usable; retry from **VOICE… → RETRY ACCESS** or headset app settings. Tracking support still depends on the hardware/runtime, and first-time grants may require an app restart. Smooth turning is the default. Touch and Pico controller profiles are included; PC Index support remains.

## Rebuild

The installed toolchain uses Temurin JDK 17.0.20.1, Android command-line tools 23, SDK platform 36, build-tools 36.1.0, platform-tools 37.0.1, NDK 29.0.14206865, CMake 3.10.2 and Godot 4.7.2 Android export templates. The SDK/NDK versions match the downloaded template’s `config.gradle`; its wrapper uses Gradle 8.11.1. Downloads came from the official Godot, Eclipse Adoptium and Google repositories, with archive checksums verified. No system Java replacement is needed. `gradlew --no-daemon help` completed successfully after installation; setup logs are in `test-results/android-dependencies.log` and `test-results/android-gradle-setup.log`.

Set Godot Editor Settings → Export → Android Java SDK Path and Android SDK Path to your installed JDK/SDK. These are configured here as `/home/blux/.local/share/entryway-toolchains/jdk-17.0.20.1+1` and `/home/blux/Android/Sdk`.

```sh
python3 tools/install_android_dependencies.py
python3 tools/build_android.py
# Or select one vendor:
python3 tools/build_android.py --target Pico
```

The installer accepts `JAVA_HOME` and `ANDROID_SDK_ROOT` overrides. The builder also accepts `GODOT_BIN`, and otherwise finds `godot` on PATH. It restores the generated Gradle template from the matching installed export templates when absent. Source archives exclude android/build and its caches. The local signing key and password stay outside the project under `~/.local/share/entryway-toolchains/signing/`; back up that directory privately to preserve update compatibility. These credentials are never included in the source archive. A different key requires uninstalling the previous installation or choosing another package ID.

Run `python3 tools/verify_android.py` to check vendor manifests, ARM64 libraries, protocol and original map/avatar hashes. The verifier requires microphone/vendor tracking declarations and current voice/body scripts, so old APKs will fail. The Android SDK and matching Android export templates are installed, including the generated `android/build` Gradle project. Version 0.3v includes rebuilt Steam Audio extension libraries aligned for 16 KiB pages. Body and hand extensions are optional and require device/runtime support.

Exports and signature reports are under `test-results/`; APKs and SHA256 files are under `../Builds/Android/`. The builder verifies signatures and 16 KB ZIP alignment. Both exports retain plain GDScript and the VRM release-runtime compatibility patches. The Entryway exporter includes original VRM/BSP files for network transfers.

## Device validation still required

Test tracking, controller grips/buttons, MToon rendering, VR menus, microphone permission/capture, voice latency, reconnects, downloads and PC/Quest/Pico matches on physical devices. Profile eight-player matches at the headset target frame rate. Default avatars have about 27–34 thousand triangles and 16–17 materials each; the 25 MB custom-model cap does not bound GPU memory. Avatar LODs and material reduction may be needed.

Android scoped storage still needs a document-picker workflow for convenient local VRM/BSP imports. Host-downloaded assets use the game's writable data directory. Runtime VRM decoding and downloaded BSP compilation are synchronous and can stall rendering. A Compatibility fallback can still be selected in Godot for device-specific troubleshooting. APK packaging success does not establish mobile thermal performance, store compliance or headset support.

References: [Godot Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html), [Android XR deployment](https://docs.godotengine.org/en/4.7/tutorials/xr/deploying_to_android.html), [official OpenXR Vendors 5.1.0](https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.1.0-stable).

See TRACKING.md for Quest body permission, SlimeVR setup and native Pico tracker limitations. See AUDIO.md for positional voice and mouth animation.

This release requests the lowest advertised standalone refresh rate at or above 72 Hz, enables OpenXR VRS/foveation, uses 2× MSAA on Android, and reduces avatar/light costs. These are configuration and code optimizations, not a measured 72 FPS headset certification. See PERFORMANCE.md.

The 0.3v APKs use version code 7 and the same private development signing key used for 0.2v. Builds signed with a different key require uninstalling the older app before sideloading; preserve any wanted local settings first. The signing key stays outside this repository.
