# Release cleanup and validation — 0.12v

The supported downloads are Linux client, Windows client, Linux dedicated server, Quest APK, Pico APK and source ZIP. Community Maps and Original TF Arenas are retired from this and later releases. Their former release entrypoints now stop with a retirement message; staging and publication reject the retired downloads. Historical releases remain unchanged. Pressureworks and Vesper Abbey remain the two bundled TF arenas, with 26 base maps in total.

Base Assets remains an internal build product, embedded in both unified APKs. PC archives contain its runtime files directly. The source ZIP now includes all runtime files as well as editable map/WAD sources, eliminating the separate asset-only download. Thin APK builds are retired, and the asset panel repairs Android assets from the included archive without HTTP. Fresh installation, damaged-map repair, and preservation of custom files and edited maplists passed using the actual Godot installer.

The old asset manifest contained 373 files, including twelve CTF build logs, a lift demonstration video, authoring images/WADs/maps, research material, and three development validation reports under docs/. Those docs/ paths are invalid for the standalone installer, which only accepts maps/ and vrm/. The new manifest contains 234 runtime/notice files, with the same maps, avatars, lightbakes, navigation and detail-preserving BC7/ASTC4 caches. Licences and provenance remain included; editable source lives in the source ZIP. No user-installed maps or files are deleted by this change.

Desktop packaging now enumerates required binaries, native dependencies, assets, user documentation, launchers and notices. It no longer archives arbitrary files from reused output folders. Old Entryway exports, logs, captures, development reports and source-map payload cannot enter the client ZIP through stale staging contents. The server already uses an explicit package list. Source packaging additionally excludes the retired map-pack directory, demonstration videos and temporary/backup files. All final archives are checked independently for unwanted entries, exact base asset membership and hashes.

The packaged texture dictionary also needed correction: 0.11v exported makkon-used.wad as a PackedScene, while the runtime reads its original bytes with FileAccess. An authored Keep import policy now exports the raw WAD, without the unusable generated scene. Both desktop PCK audits decode a Makkon replacement texture and check the dictionary checksum; Android verification compares the complete original WAD bytes.

## Results

- Linux and Windows PCK audits passed, including current fire delivery, cockpit controls, flamethrower resource and raw dictionary decoding.
- Quest and Pico vendor manifests, Vulkan settings, signatures, 16 KiB alignment/native libraries and all 234 embedded asset hashes passed.
- Fresh Linux ZIP extraction ran DM7/Quake, Assault/UT and TITANBALL/Quake practice, each reaching host-ready and exiting normally without engine/script errors. These were bounded desktop smoke tests, using only assets from the archive.
- Console runtime/package audit and instrumented gameplay suite passed.
- Rocket input/physics/landing and real ENet Quake/Doom regressions passed (nine processes).
- Cockpit controls: 29 checks passed. Preparation countdown and eligible-mode loadout voting passed. Rendered flamethrower feedback: ten checks passed, with the existing shutdown-only resource warning.
- Binary/source archive integrity and exact asset selection passed. Final source packaging and publication repeat archive checks and SHA-256 verification after the release commit.

Before final source/report regeneration, Linux was 560.5 MB, Windows 572.2 MB and server 99.3 MB, each about 38 MB smaller than 0.11v. Quest/Pico are about 609.5 MB each, down from 647.3 MB. The self-contained source ZIP is about 949 MB; it replaces the former source-plus-Base-Assets pair. Exact final sizes and hashes are in BUILD-MANIFEST.json and SHA256SUMS.

A headless invocation of the rendered flame fixture was invalid because it requires a HUD/camera; its rendered rerun passed. The initial package audit also encountered an unwritable default user log directory; the audit now logs explicitly under test-results. Neither harness problem is treated as a successful test. Native Windows/Quest/Pico hardware tests were not repeated for these final packages. Earlier human VR results and known performance/teardown limits are described in the release notes.
