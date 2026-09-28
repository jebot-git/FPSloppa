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

`dust2_rebuild/` builds an editable CS 1.6 Dust2 layout study as BSP29, with
procedural desert textures, embedded RGB lighting and full VIS. It also bakes
Godot collision/navigation and tests primary routes in both directions. See
[`maps/Dust2Rebuilt/README.md`](../maps/Dust2Rebuilt/README.md) for commands and
fidelity limits. The installed map is opt-in and does not change rotations.

DE objective art lives in [the Blender workshop](defusal/README.md). `run_defusal_network.py` runs a four-process local ENet test; `deathmatch/tests/defusal_demo.gd` checks its recording. `defusal_preview.gd` renders the purchase wheel, surface-mounted bomb, cutters and chest carrier. See [DE validation](../docs/BOMB-DEFUSAL.md).

`classic_de/` builds and validates the four additional classic DE BSP29 studies;
see [map build instructions](../maps/ClassicDE/README.md).
`classic_de/audit.py --references /path/to/cs16/maps` produces a read-only
BSP29/BSP30 geometry and entity comparison. It needs NumPy and Matplotlib;
reference maps are not installed. See [the fidelity assessment](../docs/DE-MAP-FIDELITY.md).
`classic_de/tactics.py` emits hash-bound DE bot lanes/holds after map rebuilds.
`classic_de/study_views.gd -- <map-id> --views` captures the changed tactical
features; `classic_de/study_report.py` summarizes retained before/after soak and
regression receipts. See the [CS 1.6 tactics study](../docs/CS16-MAP-TACTICS-STUDY.md).
`compose_de_orchestral.py` writes an editable MilkyTracker XM;
`generate_de_music.py --install` renders the current DE orchestral cue.
`run_defusal_grenades.py` validates utility over real local ENet.

`titanball/cindercoil/` generates the circular, ascending TB map, prepares its
desktop/mobile caches, bakes navigation and tests Titan/fighter traversal.
See [Cindercoil source and rebuild instructions](../maps/Cindercoil/README.md).

`mipmap_imports.py` audits persisted texture import settings; use `--fix` before
a Godot editor reimport to migrate older local imports. `audit_mipmaps.gd`
inspects actual loaded mip chains across runtime images, models, installed maps
and avatars. See [texture mipmap policy and validation](../docs/TEXTURE-MIPMAPS.md).

`stonehenge/` rebuilds an optional BSP29 Stonehenge terrain/layout study for the
proposed Tribes loadout, prepares desktop/mobile caches, and verifies collision
and CTF objectives. See [Stonehenge references and fidelity limits](../maps/Stonehenge/README.md).

`de_announcer/generate.py` bakes the five DE team, round-result and planted-bomb
calls with an offline Piper voice, including the plant confirmation chirp.
See [audio provenance and rebuild parameters](../deathmatch/audio/announcer/DE-SOURCES.md).

### Tribes movement test

`python3 tools/run_tribes_network.py` checks a real local ENet server, predicted
pilot and late spectator with delayed/lost inputs.
`python3 tools/stonehenge/package_test.py` exports the separate Linux Stonehenge
test bundle with desktop and VR launchers, map caches and notices.
See [controls and validation](../docs/TRIBES-MOVEMENT.md).
