# Steam Audio

Godot extension 0.3.1: https://github.com/stechyo/godot-steam-audio/releases/tag/0.3.1 (MIT).
Upstream archive SHA-256: bac5b378e3a950859552305f59cca98c2b0a7788e5100ec179947b62df5d44ce

Includes Valve Steam Audio 4.8.0 runtime libraries distributed with that release (Apache-2.0; bundled dependency notices in THIRDPARTY.md). CPU HRTF processing is used; optional AMD GPU libraries are omitted. The extension manifest omits unsupported macOS targets.

The extension binaries were rebuilt locally as **0.3.1 + Entryway fixes**. Valve's runtime binaries remain unchanged. Apply the patches in this order to the upstream 0.3.1 source:

1. `patches/entryway-lifetime.patch`: serialize source lifetime/mixing/simulation, detach all playback parents before destruction, release per-source DSP effects, skip unused reflection work, bound mixer writes, and align Android libraries for 16 KiB pages.
2. `patches/entryway-point-source.patch`: direct binaural HRTF for point-source effects and voice.
3. `patches/entryway-reference-distance.patch`: normalize reference-distance gain and handle a coincident listener/source direction.
4. `patches/entryway-shutdown.patch`: destroy the server singleton, wake/join the reflection worker before releasing SDK state, and remove an extra scene retain. Rebuilt for Linux x86-64, Windows x86-64 and Android ARM64/x86-64 on 2026-10-01.

Pinned godot-cpp: `714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa`. Steam Audio source/header revision: `9920bda53ec0ffc2e37fc12c9e9f52af792ed924` (SDK 4.8.0). Source patches retain the upstream MIT license. Build tools: SCons 4.11.1, Ubuntu 22.04 GCC for portable Linux, LLVM-MinGW 20260908 for Windows, Android NDK 29.0.14206865 for Android. Release libraries also serve debug game launches on all platforms.

To reproduce: unpack upstream source with the pinned godot-cpp submodule, put SDK headers in `src/lib/steamaudio/unity/include/phonon/` and SDK libraries in `src/lib/steamaudio/lib/`. Apply each patch with `patch -p1`, and copy `patches/entryway-build-profile.json` to the source root. Run SCons with `build_profile=entryway-build-profile.json target=template_release platform=linux arch=x86_64`. Windows adds `platform=windows use_llvm=yes mingw_prefix=/path/to/llvm-mingw`; Android uses `platform=android arch=arm64 ANDROID_HOME=` with `ANDROID_NDK_ROOT` pointing to the NDK (repeat for `arch=x86_64`). Copy the resulting extension libraries from `project/addons/godot-steam-audio/bin/` alongside the unchanged SDK runtime libraries.

For Linux debug, repeat with `target=template_debug`. Source inputs for the September 30 rebuild (SHA-256):

- GitHub codeload `stechyo/godot-steam-audio` tag `0.3.1`: `d6e2932ac5f5ce5c63e8c50ee877127b07ca7d3a070fed98a31cf5d8b42a7710`.
- GitHub codeload `godotengine/godot-cpp` at the pinned revision: `607aa1a8e332a6b3251f5d5b4caf0e20590673a8c8529003c980421e8f8a072f`.
- Valve headers at the pinned SDK revision: `phonon.h` = `c648233150ee13d67a8af15a2d1bcd6d1a0780f7d494d1f3fd54812fb29d56cc`; `phonon_version.h` = `0da5c0113004bf91fbe80df2acc0ed24032ba93dd0d599c057737627c605100a`.

Build each platform sequentially: upstream shares object paths. For current Android NDKs, pass `ANDROID_HOME=` and set `ANDROID_NDK_ROOT` to the selected NDK. For LLVM-MinGW, generate a phonon import archive from the bundled SDK DLL exports with `llvm-dlltool -m i386:x86-64 -d phonon.def -l libphonon.a`; the static linker search expects that archive name. Valve SDK runtime bytes remain unchanged.
