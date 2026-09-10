# External maps and avatars

PC and dedicated-server ZIPs include `maps/` and `vrm/` beside the executable. They are excluded from PCK and APK exports. Source checkouts use these same folders at the project root. Override both with `-- --asset-root /absolute/path` (append `--asset-root` to existing game arguments).

Quest and Pico APKs start without map/model payloads. Open **ASSETS… → Download base assets**, then rescan. Alternatively extract `FPSloppa-0.4v-Base-Assets.zip` into `/sdcard/Android/data/org.entryway.arena.quest/files/` or `/sdcard/Android/data/org.entryway.arena.pico/files/`. The resulting directories must be `files/maps` and `files/vrm`. The installer checks the archive and individual file SHA-256 hashes and preserves existing files. Joining a host downloads its missing BSP; offline practice requires a map installed first.

Copy Quake I BSP files into `maps/`, VRM files into `vrm/`, then rescan while disconnected. VRMs remain limited to 25 MiB. Legacy `user://maps` and `user://avatars` assets are copied on discovery; originals are preserved. Generated scenes go in `maps/cache/`. Changing BSP content changes its cache key. Do not copy cached scenes between unrelated importer versions.

Connected clients may import a BSP through **Import BSP**. A dedicated server accepts authenticated player uploads when `sv_map_uploads` is 1, verifies size, hash and BSP structure, and retains them in its own `maps/` folder. Missing VRMs are also retained in its `vrm/` folder and rediscovered after restart. Uploads have transfer limits and hashed filenames; the VRM store stops accepting new data at 1 GiB rather than evicting reusable models. BSP uploads are limited to 128 MiB each and a 2 GiB raw-map store. Administrators can remove unused files manually while the server is stopped.

Each gamemode has its own `maps/<tag>_maplist.txt`: `dm`, `tdm`, `ctf`, `koth`, `ig`, `ft`, `cc`. Put whitespace-separated map IDs there, up to 32. A nonempty `<tag>_maplist` in `server.cfg` overrides that file; the old `sv_maplist` is the fallback. Uploaded BSPs are added only to the current mode’s list. Mode changes select from the destination mode’s rotation.

The optional LibreQuake pack adds `lqdm9`–`lqdm13`. Extract its `maps/` directory alongside the existing one and add IDs to the desired mode lists. It includes upstream notices, author readmes and texture provenance. All embedded texture mip levels use LibreQuake WAD assets.

ThreeWave BSPs are deliberately absent from GitHub and release assets. Download the separate conversion-tools package and follow its `RIGHTS.md`. Converted community maps are for local testing and non-commercial server use, retain their original notices, and are not relicensed. Native CTF flags/team spawns are recognized; QuakeC scripting, runes and grapples are not reproduced.
