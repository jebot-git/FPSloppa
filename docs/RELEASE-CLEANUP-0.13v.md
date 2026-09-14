# Release cleanup and validation — 0.13v

Linux and Windows export staging directories were cleared and rebuilt. Obsolete Entryway Android exports and checksum files were removed. Publication uses the same six explicit downloads as 0.12v: Linux, Windows, Linux dedicated server, Quest, Pico and self-contained source. Retired Community Maps, Original TF Arenas and Base Assets downloads remain excluded. Historical releases, research logs and user-installed content are not part of the cleanup.

All 234 runtime/notice assets and 26 bundled BSP maps are retained, with identical payload hashes to 0.12v. The internal offline Base Assets archive and manifest were refreshed for 0.13v. Desktop packages are assembled from explicit required file lists; logs, captures, stale exports and retired map-pack directories cannot enter the downloads from reused folders. The source archive retains authored code, mapping sources, tests and research reports.

## Validation

- Fixed TB configuration/gameplay: **196 checks passed** (47 heavy-weapon routing, 40 pilot lifecycle, 56 health/healing regression, 25 server configuration/population lifecycle, 28 ladder).
- Linux and Windows PCK audits passed, including actual packaged 200 HP, heavy-ordnance enabled, regeneration disabled, removal of the configurable server key, and required dedicated bot population code.
- Quest/Pico APK checks passed: vendor manifests, Vulkan policy, Android version code 18, signatures, 16 KiB native alignment, current gameplay/server/bot scripts, raw texture dictionary, and all 234 embedded asset hashes.
- The rebuilt console-only server passed the runtime/package audit and all 34 map startup/gameplay cases.
- All 14 real ENet loopback checks passed against the rebuilt server: bot fill, human priority at capacity, concurrent joins, full-human rejection, refill, rotation and TB teams/classes. The config contains no ordnance option.
- A fresh Linux ZIP extraction passed bounded graphical DM7/Quake, Assault/UT and TITANBALL/Quake practice tests, using only its packaged assets. All reached host-ready and exited normally without engine/script errors.
- Linux, Windows, dedicated-server and source ZIP audits passed archive integrity, exact runtime asset hashes and payload exclusions. New source files and the server config were checked directly in their archives. Final source packaging and publication repeat these checks after the release commit.

[Machine-readable validation receipt](validation/release-0.13v.json). Exact final download sizes and SHA-256 hashes are in the published build manifest and checksum file.

No fresh headset or native Windows/Pico hardware test is claimed. Existing engine exit-time resource warnings remain. Human team balance and full-capacity network performance are not certified by these checks.
