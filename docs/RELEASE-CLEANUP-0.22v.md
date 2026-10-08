# Release cleanup and validation - 0.22v

Previous generated client/server exports were moved outside release staging before
building. Runtime templates, player assets, historical releases and test evidence
were retained. Generated manual delivery copies are ignored; canonical HTML/PDF
and reproducible manual tools are versioned. Client packages contain the portable
manual, with source-tree-only links removed.

Fresh packaging exposed two server dependencies introduced by coloured names.
The server now includes the pure name parser and loads visual nametags only on
clients. Bundled maplists are filtered to the 68 shipped maps; installing the
78-map expansion replaces them with combined rotations. User-configured maplists
continue to override defaults. Only active raw/BC7/ASTC caches are included, removing
about 720 MB of redundant scene aliases before compression.

The prepared archive referenced by the prior expansion receipt was unavailable
locally. The three original ST maps were rebuilt from the repository's generators
with ericw-tools 0.18.1, preserving flag objectives. A lower Stonehenge spawn moved
0.5 m off a collision seam. All three maps passed acceptance checks; navigation and
render caches were rebuilt and verified. Aztec/Train caches were refreshed with
the current preparation pipeline. All 204 active base-map cache variants pass.
The 78 expansion BSPs and prepared caches are byte-identical to the existing draft;
only its vehicle guide and base-asset validation receipts changed.

The release regression run passed 36 suites and 803,249 checks. The actual console
runtime passed all 68 bundled maps, collision, movers, stripped presentation and
lobby checks. Packaged Linux launcher/DM/ST/DE smoke tests, launcher transfers and
identity, transactional updater checks and 19 directory-service tests passed.
Quest APK checks cover manifest/version, signature, current code/assets, Vulkan-only
runtime, ARM64 libraries and 16 KiB alignment. Windows is cross-built and audited.
No new native Windows, physical-headset or haptic-vest playtest is claimed.

Deployment caught a host-built gameplay library requiring glibc 2.43. Both Linux
gameplay libraries were rebuilt with the Ubuntu 22.04 container, and release
packaging now rejects libraries requiring glibc newer than 2.35. The rebuilt
server loads its extension successfully on the Ubuntu 24.04 deployment host.

The deployment configuration has 16 human seats, all modes enabled, a lobby, no
local/worker bots and UDP 7779 queries. TB/TF/CC are excluded only from the ballot.
DE uses a 20-second purchase phase and `sv_de_winlimit 4`: first to four wins,
halftime after three, at most six rounds. An authoritative six-round 3:3 draw and
the ballot policy pass the dedicated configuration check.

See [validation receipt](validation/release-0.22v.json). Final distribution bytes
and the release commit are identified by the published BUILD-MANIFEST.json and
SHA256SUMS; final archive verification runs before publication.
