# Release cleanup and validation — 0.14v

Bakes, requested DM6/Titanball matches and focused regression tests completed before release cleanup began. Generated Linux, Windows, Android, console-server, Godot export and Gradle output directories were cleared. The existing audited console engine template and previous server configuration were preserved separately. Player content, source assets and historical releases were retained.

The release includes Linux, Windows, Linux dedicated server, Quest, Pico and self-contained source downloads. All 26 maps remain bundled. The internal base archive was refreshed with the fifteen authored-light rebakes and three native-map cache corrections. Raw, BC7 and ASTC caches match their BSP source hashes. See [lighting audit](BASE-LIGHTING-AUDIT.md).

## Validation

- 238 focused assertions passed: live bot counts/Titan eligibility/avatar orientation, real bot map controls, seven Q1 maps' trigger chains, VR physical controls/radio and tracking orientation. Authenticated RCON and one-server/two-client mover suites passed.
- DM6: eight bots, 300 simulated seconds, 2,023 shots, 2,589 damage events and 22 map-control plans. Every bot moved over 1.6 km. One bot had a temporary 13.22-second movement stall; this is retained as a limitation.
- Titanball: twelve bots, all six TF class pairs, team 0 victory at 683.68 simulated seconds, 30 boardings, 218 deaths and 349 cannon volleys. Current fixed-200-HP/heavy-ordnance/no-regeneration rules were used.
- Rendered Quake light values matched the reference response despite strong ambient/directional fill. All fifteen relit maps and the three cache-corrected maps were rendered; representative views were inspected.
- Clean exports exposed two bundled XR Tools resource errors. The teleport revert handler now returns null for unknown properties, and the fall-damage example root matches its Node3D script. An isolated load/instantiate check passed. The fallback avatar's visual helper loads lazily so the console pack does not import client-only XR resources.
- Linux and Windows exports and PCK audits passed. Quest/Pico APK manifests, version code 19, signatures, ARM64 native libraries, 16 KiB alignment, Vulkan settings and embedded asset hashes passed.
- The rebuilt console-only server passed all 26 base-map startup/collision/door/train checks. Fourteen real ENet admission/population/rotation checks passed, including human priority and TF-class Titanball bots.
- A fresh Linux ZIP extraction ran graphical DM6/Quake, Titanball/Quake and rebaked Solstice KOTH practice checks. All reached host-ready and exited without engine/script errors using their bundled assets.
- Linux, Windows, dedicated-server and source ZIP integrity, asset hashes and payload exclusions passed. Final packaging repeats the archive checks after the release commit so the source archive includes this report.

[Machine-readable receipt](validation/release-0.14v.json). Published SHA256SUMS and BUILD-MANIFEST.json identify the final download bytes and commit. The preliminary source-archive byte count in the receipt precedes this report's final inclusion.

No fresh human headset, native Windows or Pico hardware test is claimed. These automated matches do not certify human-team balance or full-capacity server performance. Existing shutdown-only resource warnings remain.
