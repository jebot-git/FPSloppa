# Asset conversion

Run Blender in background mode with `--python tools/export_weapons.py` or `--python tools/export_fist.py` using an absolute script path. The fist script uses the bundled CC0 VRoid D file. For weapons, extract https://opengameart.org/sites/default/files/afps_weapons.zip into `WeaponSource/` beside the Godot project directory first. That source pack is CC0 by Drummyfish. The game itself uses the already converted files in `deathmatch/weapons/` and does not require Blender.

Run `python3 tools/generate_sounds.py` from any directory to regenerate the twenty original CC0 mono WAV effects with Python’s standard library. The generator uses a fixed random seed; no external samples are required. After regenerating or replacing weapon clips, run `python3 tools/balance_weapon_audio.py` to refresh the cadence-aware runtime gain table (requires ffmpeg).

`python3 tools/build_release.py` exports Linux/Windows PC clients and a Linux dedicated server, then packages them and the source ZIP. Install matching Godot 4.7.2 export templates first; set GODOT_BIN to choose the executable. `--package-only` refreshes archives from existing binaries. Android presets are experimental and excluded from this release script.

`python3 tools/build_android.py` builds the Quest release APK and validates signing and alignment. See STANDALONE.md for toolchain setup and local signing details. Generated Android templates and caches are excluded from source archives.

Use the official matching Godot executable via `GODOT_BIN` for release exports. The source ZIP honors Git exclusions, omitting private live-device captures, build caches, signing files and generated release archives.

`python3 tools/prepare_release.py` stages a fixed artifact allowlist and checksums after exports and packaging. Run `python3 tools/package_optional_release.py` to build the combined 62-map optional/community pack in `dist/`; [its builder and checks](optional_maps/README.md) retain mode categories and original notices. ThreeWave/TF/AD conversion tools remain archived with 0.5v. See [the archive policy](../docs/ARCHIVED-EXTRAS.md).

The [UT Avatar Converter](ut_avatar_converter/README.md) is a separate portable Linux/Windows utility for original UT99 `.u` models and `.utx` skins (including ZIP/UMOD archives). It generates an editable experimental humanoid rig and VRM output. Its source and [Linux/Windows releases](https://github.com/jebot-git/UTAvatarConverter/releases/tag/v0.1.0) now live in the independent [UTAvatarConverter repository](https://github.com/jebot-git/UTAvatarConverter). The general [AvatarConverter](https://github.com/jebot-git/AvatarConverter) is independent too. Local build/test wrappers accept `--checkout`; see each tool README.

The [MDL Avatar Converter](mdl_avatar_converter/README.md) provides a separate experimental Quake MDL/PAK to VRM workflow. Its [Linux/Windows release](https://github.com/jebot-git/MDLAvatarConverter/releases/tag/v0.1.0) requires no external editor or extraction helper. Local build/test wrappers accept `--checkout`. GoldSrc MDL is unsupported.

## Optional bHaptics native prototype

`python3 tools/build_bhaptics_native.py` builds the Linux/Windows x86_64 Godot GDExtension for direct Bluetooth vest feedback. Linux requires Rust/Cargo, pkg-config and libdbus development headers; Windows requires the Rust MSVC toolchain and C++ build tools (Windows build unvalidated here); `--offline` uses cached dependencies and `--release` builds an optimized library. See [BHAPTICS.md](../BHAPTICS.md) for setup and opt-in hardware tests.

The [master directory](master_server/README.md) is a standalone Python service for public server discovery. Release packaging includes its own small ZIP and the [browser setup guide](../docs/SERVER-BROWSER.md) in all desktop/server downloads.
