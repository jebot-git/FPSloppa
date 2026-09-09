# Quest / Pico standalone builds

Separate ARM64 release-runtime APKs are built with Godot 4.7.2 and official Godot OpenXR Vendors 5.1.0 (Meta for Quest, Pico for Pico). They use the Vulkan Mobile renderer, mobile textures, Internet and microphone permissions, and a persistent local development signing key. These are experimental sideload builds, not store releases.

Both share PC/server protocol `entryway-dm-7-eyes`, authoritative combat, pistol-only spawns, fixed hitboxes, host map downloads and 25 MB avatar transfers. Crossplay is preserved in the implementation; a completed cross-device match has not been verified. No Quest or Pico was connected during building.

## Install and play

Enable developer mode and USB debugging on the headset, authorize this computer, then install the appropriate package:

```sh
adb install -r Builds/Android/Entryway-Quest.apk
adb install -r Builds/Android/Entryway-Pico.apk
```

Use only the APK matching your headset. Launch Entryway Arena from the headset's unknown sources/developer applications. Join the PC or dedicated server's reachable IP and configured UDP port (see SERVER.md). Grant microphone permission to use voice chat; voice is off by default. Smooth turning is the default. Touch and Pico controller profiles are included; PC Index support remains.

## Rebuild

The local toolchain uses Temurin JDK 17.0.20.1, SDK platform 36, build-tools 36.1.0, platform-tools 37.0.1, NDK 29.0.14206865, CMake 3.10.2 and matching Godot 4.7.2 export templates. Versions come from the installed Godot Android template's config.gradle. Gradle 8.11.1 downloads its dependencies on first build. Existing Ubuntu runtime libraries satisfy the tools' native dependencies; root package installation was unavailable because sudo required interactive authentication.

Set Godot Editor Settings → Export → Android Java SDK Path and Android SDK Path to your installed JDK/SDK. On this machine they are `/home/blux/.local/share/entryway-toolchains/jdk-17.0.20.1+1` and `/home/blux/Android/Sdk`.

```sh
python3 tools/install_android_dependencies.py
python3 tools/build_android.py
# Or select one vendor:
python3 tools/build_android.py --target Pico
```

The builder accepts JAVA_HOME, ANDROID_SDK_ROOT and GODOT_BIN overrides. It restores the generated Gradle template from the matching installed export templates when absent. Source archives exclude android/build and its caches. The local signing key and password stay outside the project under `~/.local/share/entryway-toolchains/signing/`; back up that directory privately to preserve update compatibility. These credentials are never included in the source archive. A different key requires uninstalling the previous installation or choosing another package ID.

Run `python3 tools/verify_android.py` to check vendor manifests, ARM64 libraries, protocol and original map/avatar hashes. All these checks passed for both APKs. No export script errors occurred; body and hand extensions are optional and require device/runtime support.

Exports and signature reports are under `test-results/`; APKs and SHA256 files are under `../Builds/Android/`. The builder verifies signatures and 16 KB ZIP alignment. Both exports retain plain GDScript and the VRM release-runtime compatibility patches. The Entryway exporter includes original VRM/BSP files for network transfers.

## Device validation still required

Test tracking, controller grips/buttons, MToon rendering, VR menus, microphone permission/capture, voice latency, reconnects, downloads and PC/Quest/Pico matches on physical devices. Profile eight-player matches at the headset target frame rate. Default avatars have about 27–34 thousand triangles and 16–17 materials each; the 25 MB custom-model cap does not bound GPU memory. Avatar LODs and material reduction may be needed.

Android scoped storage still needs a document-picker workflow for convenient local VRM/BSP imports. Host-downloaded assets use the game's writable data directory. Runtime VRM decoding and downloaded BSP compilation are synchronous and can stall rendering. A Compatibility fallback can still be selected in Godot for device-specific troubleshooting. APK packaging success does not establish mobile thermal performance, store compliance or headset support.

References: [Godot Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html), [Android XR deployment](https://docs.godotengine.org/en/4.7/tutorials/xr/deploying_to_android.html), [official OpenXR Vendors 5.1.0](https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.1.0-stable).

See TRACKING.md for Quest body permission, SlimeVR setup and native Pico tracker limitations. See AUDIO.md for positional voice and mouth animation.

This release requests the lowest advertised standalone refresh rate at or above 72 Hz, enables OpenXR VRS/foveation, uses 2× MSAA on Android, and reduces avatar/light costs. These are configuration and code optimizations, not a measured 72 FPS headset certification. See PERFORMANCE.md.
