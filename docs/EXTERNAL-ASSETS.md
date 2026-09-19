# External maps and avatars

PC and dedicated-server ZIPs include `maps/` and `vrm/` beside the executable. They are excluded from desktop PCKs; unified Android APKs carry a compressed installer archive. Source checkouts use these same folders at the project root. Override both with `-- --asset-root /absolute/path` (append `--asset-root` to existing game arguments).

Quest and Pico unified APKs include the base maps/models. First launch verifies and extracts them into `/sdcard/Android/data/org.entryway.arena.quest/files/` or `/sdcard/Android/data/org.entryway.arena.pico/files/` before loading the catalog. Bundled assets are repaired or updated by checksum; custom files and edited maplists/configs are preserved. No separate download is needed for offline practice. From 0.12v there is no separate Base Assets download or thin APK. ASSETS can repair the included APK assets offline; PC users can restore maps/ and vrm/ from their release ZIP. Optional maps and custom avatars remain external and download through the normal join barrier.

Copy Quake I BSP files into `maps/`, VRM files into `vrm/`, then rescan while disconnected. VRMs remain limited to 25 MiB. Legacy `user://maps` and `user://avatars` assets are copied on discovery; originals are preserved. Generated scenes go in `maps/cache/`. Changing BSP content changes its cache key. Do not copy cached scenes between unrelated importer versions.

Connected players and spectators may import a BSP through **IMPORT BSP…** in the pause menu without disconnecting. A dedicated server accepts authenticated client uploads when `sv_map_uploads` is 1, verifies size, hash and BSP structure, and retains them in its own `maps/` folder. Missing VRMs are also retained in its `vrm/` folder and rediscovered after restart. Uploads have transfer limits and hashed filenames; the VRM store stops accepting new data at 1 GiB rather than evicting reusable models. BSP uploads are limited to 25,000,000 bytes each and a 2 GiB raw-map store. Administrators can remove unused files manually while the server is stopped.

Each gamemode has its own `maps/<tag>_maplist.txt`: `dm`, `tdm`, `ctf`, `koth`, `ig`, `if`, `ft`, `cc`, `tf`, `tb`, `as`. Put whitespace-separated map IDs there, up to 32. Rotation precedence is a nonempty `<tag>_maplist` in `server.cfg`, then `sv_maplist`, then the mode’s file, then the configured map. IF falls back to IG when it has no separate list. Mode changes select from the destination mode’s rotation.

Imports use a case-insensitive leading filename tag followed by `_`: `tf_factory.bsp` enters only TF, `koth_tower.bsp` only KOTH, and `dm_arena.bsp` only DM. An untagged name or an unknown prefix enters **only DM, TDM, IG, FT and IF**. Classification uses the original filename, survives hash-based storage in `maps/cache/<sha256>-import.json`, and is preserved during downloads. Accepted imports are appended to the appropriate server lists and written to disk; startup restores their membership. Reimporting identical content keeps the existing entry and classification. Full lists retain the 32-map limit.

The importer renders a 320×180 PNG preview for each new map. Both the lobby wall and intermission ballot display these behind the map, mode and loadout text. Previews are cached by BSP checksum in `maps/previews/`, uploaded with client imports, and sent separately so voters can see maps they have not downloaded. PNG dimensions and size are validated, and server thumbnail transfers share the existing asset bandwidth budget.

A headless server stores and serves previews supplied by graphical clients. For maps copied directly into a server asset folder, generate previews on a graphical machine before copying the folder to the server:

```sh
godot --path . --script res://tools/generate_map_previews.gd -- --asset-root /absolute/path/to/assets
```

Add `--map <map-id>` to generate one map. The utility needs a graphical renderer. A card remains votable while its preview is unavailable or still being generated. Clients and server need matching `fpsloppa-39-rotating-koth` builds.

The separate Community Maps and Original TF Arenas downloads are retired from 0.12v onward. Pressureworks and Vesper Abbey remain bundled for TF, and Assault retains its full-sized variants. User imports remain supported. See [archive policy](ARCHIVED-EXTRAS.md).

ThreeWave BSPs are deliberately absent from GitHub and release assets. Download the archived conversion-tools package from the [0.5v release](https://github.com/jebot-git/FPSloppa/releases/tag/0.5v) and follow its `RIGHTS.md`. Converted community maps are for local testing and non-commercial server use, retain their original notices, and are not relicensed. Native CTF flags/team spawns are recognized; QuakeC scripting, runes and grapples are not reproduced.

Initial server connections and map changes now wait for map and required model verification before spawning. The loading screen shows byte progress and an estimated remaining time. Later model downloads appear in a small corner indicator; latency is shown in the opposite corner (on the floating status HUD in VR).

## Reviewed Makkon/community additions (12 September 2026)

See [Makkon provenance and permission](../tools/makkon/README.md) and [community map review](../tools/community_maps/README.md). Slipseer maps require at least 3/5 stars and a usable licence grant. Only approved adaptations enter the base asset catalog; unreviewed download archives are ignored and never packaged. All selected Makkon miptextures remain original WAD2 records.
