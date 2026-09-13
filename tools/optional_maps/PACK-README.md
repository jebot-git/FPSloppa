# FPSloppa Optional Community Map Pack

53 additional maps in seven game-mode categories: 35 non-TF maps from Arena Collection 1,
13 LibreQuake arenas and five reviewed community adaptations. Retired TF maps and
Tiny Assault layouts are excluded. See **CATALOG.md** for the sorted list.
Each BSP appears once, in its primary category. LibreQuake and community arenas
also support the additional modes listed in the catalog.

## Install all maps or selected categories

Extract this ZIP into a temporary folder. With Python 3.9 or newer:

```sh
python3 install.py --game-dir /path/to/FPSloppa --dry-run
python3 install.py --game-dir /path/to/FPSloppa
```

On Windows, use `py -3 install.py --game-dir "C:\Games\FPSloppa"`.
For selected categories, append e.g. `--category ctf --category koth`.
Available tags: `dm tdm ctf koth ig ft cc`.
The destination is the external asset root containing `maps/`, including when
using the game's `--asset-root` override. Close the game before installation.

Without Python, merge the **contents** of `categories/<tag>/maps/` into the
game's `maps/` directory for each desired category. Keep the included
`OptionalMapPack/` notices alongside the BSPs. Do not copy the category folders
themselves into `maps/`: the game scans BSPs directly inside `maps/`.

Quest/Pico: copy the same contents into the application's external `files/maps/`
directory (`/sdcard/Android/data/org.entryway.arena.quest/files/maps/` or the
corresponding `org.entryway.arena.pico` directory). No APK modification is needed.
Then restart the game, or use **ASSETS → Rescan** while disconnected. First load
builds a scene/navigation cache using the installed game version.

The installer checks every selected payload before copying, refuses conflicts,
and can be rerun safely. It leaves `server.cfg` and existing rotations intact.
If a file differs, resolve that specific file manually before retrying; the
installer never force-replaces it. Use the matching game source/build with this
pack for curated menu names and mode filtering. Older builds can discover the
BSPs as imports but may offer them under unrelated modes.

## Rotations and categories

Files in `rotations/` are examples for each supported mode, including compatible
multi-mode maps from the DM category. Copy only IDs whose maps you installed into
your existing `maps/<tag>_maplist.txt`; the game accepts at most 32 IDs per list.
An explicit `<tag>_maplist` in `server.cfg` takes precedence. Per-category examples
containing only that category's maps install under
`maps/OptionalMapPack/categories/<tag>/`.

## Credits and scope

Keep all supplied author readmes, licence texts, texture provenance and original
validation receipts with redistributed maps. They live inside each category's
`maps/OptionalMapPack/` directory. Licences remain per asset; this compilation
does not relicense community maps or Makkon artwork. Community maps retain their
authors' redistribution conditions, including free/noncommercial distribution
where specified. Original Makkon records and LibreQuake textures are preserved.

Arena Collection 1 is recovered byte-for-byte from the 0.5v release commit named
in PACK.json. Its geometry and documentation are CC0 and textures are LibreQuake
BSD-3-Clause.
Historical readmes describe their original packaging and test dates; installation
instructions in this file apply to the combined pack. Current base maps have
separate IDs and are not included.

AD, original TeamFortress, FortressOne and ThreeWave conversions were local-only
and are excluded, as are unreviewed community downloads. No original ThreeWave
assets are included. CTF here contains the five authored Arena Collection maps;
the six new ThreeWave-inspired authored studies are part of the base game.

Existing geometry, route and bot-test reports are historical evidence. Current
pack verification checks installation, catalog discovery and BSP imports; it is
not a new competitive balance, multiplayer or headset performance certification.
Full QuakeC map scripting
is not reproduced by FPSloppa.
