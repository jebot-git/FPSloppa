FPSloppa external map library

Place BSP29/BSP2 files directly in this folder, then choose ASSETS -> RESCAN.
Leave the .bsp extension on the file; maplists refer to the filename without it.
Each mode has its own <tag>_maplist.txt (dm, tdm, ctf, koth, ig, ft, cc).
Server config <tag>_maplist settings override the corresponding file.

Downloaded and uploaded BSP files persist as custom_<SHA256>.bsp. Validated
Godot scenes are cached under cache/; no executable scene is sent over the
network. Base cache/ and navigation/ files are provided for faster loading.
Only known default assets are included in release archives; personal imports
are never repackaged by the release builder.

Optional packs: copy their BSPs here, preserve their readmes/licenses, and add
the map IDs to the modes in which you want to play them. Default game maps and
textures are LibreQuake BSD-3-Clause; see LibreQuake-COPYING.txt and credits.
