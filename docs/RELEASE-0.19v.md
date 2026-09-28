# FPSloppa 0.19v

This release focuses on the arena and CS/DE experience. ST, Stonehenge and the Tribes loadout are deferred: they are unavailable in hosting, votes, server configuration and map selection, and their artwork, music and map payloads are excluded. Experimental source work is retained for later development.

- Improved CS weapon handling, including dominant-hand VR menus, corrected triggers, virtual stock refinements and the AWP scope mount. CS weapons now use their aligned sights without the guiding laser.
- DE team assignments, round victories and bomb planting have audible announcements. Updated map cover, doors and decorations include Dust2's double doors and fixes for floating Aztec/Inferno props. CS bullets can penetrate eligible cover through the existing collision system; actual collision validates each exit and inconsistent brush metadata blocks the shot.
- Server operators can exclude selected modes from the post-game/lobby ballot using `sv_ballot_exclude_modes`, while keeping those enabled modes available to ordinary votes.
- Eleven CC0 avatars are included. Texture mipmaps and compressed map caches remain part of the bundled assets.
- Linux, Windows and Quest clients use Vulkan-only Godot runtimes with the OpenGL backend removed. The Linux dedicated server remains graphics-free.

All packages include the required base assets; no separate base-asset download is needed. Quest remains experimental. Install matching 0.19v clients and server: the network protocol is `fpsloppa-63-arena-release` and is incompatible with older builds. Windows and Quest packages are cross-built; device validation is separate from the automated release checks.

ST configurations are not accepted by this release. Keep an experimental checkout if you need the current ST development build.
