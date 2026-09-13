# Makkon textures for FPSloppa

Original WAD2 archives from [Makkon Textures on Slipseer](https://www.slipseer.com/resources/makkon-textures.28/), version 990, retrieved 12 September 2026. Textures by **Ben “Makkon” Hale**; palette/LUT credit to **ptoing**. The Industrial, Metal and CTF sets contain 1,632, 463 and 32 textures respectively.

The original [licence](Makkon_License.txt) is retained verbatim. These are not CC0 or BSD assets. Non-commercial use requires credit; commercial use requires express permission. The licence also restricts association with AI art and related uses. On 12 September 2026 the project owner explicitly confirmed permission covering FPSloppa alongside its generated title/promotional artwork. That project-specific confirmation does not grant permissions to other projects.

No textures are used for model training, generative-image input or generative art. Selected textures retain their original WAD2 format, indexed pixels, palette interpretation, dimensions, names and all four mip levels. Ordinary game rendering and material sampling do not modify the source texture records. Licence and per-texture provenance accompany installed maps.

Industrial panels and steel flooring suit HiSlop's train and Frigate's hull/interior. The Metal pack has more gothic masonry/ornamental patterns, used for Painful Memories. Lasercade retains coloured zoning with industrial colour variants and LibreQuake lights. The shared crosswalk also supplies industrial/metal families and red/blue team panels for LibreQuake, Quake-source and locally retained TF/ThreeWave conversions. Unused CTF banners remain in the source archives. The maker recommends nearest filtering; the game retains the player's filtering preference.

```sh
python3 tools/makkon/fetch.py --editor-wad
```

This verifies the original archives and produces `tools/makkon/local/FPSloppa-Makkon.wad`, containing exactly the 46 used original records (15,344,124 bytes), identical to the shipped `deathmatch/maps/texture_replacements/makkon-used.wad`. Add that WAD in TrenchBroom's Quake map texture collections when creating maps. Archives and the editor WAD stay outside source/release globs. `inventory.json` pins whole archives; `selection.json` pins the curated WAD and each record.

`theme.py` replaces BSP texture records while keeping texture indices and world-unit texture coordinates intact. It verifies that every geometry, collision, visibility, lightmap and entity lump, plus every BSPX payload, is unchanged. It never rescales or regenerates texture artwork. The Assault installer applies this theme to expanded maps; Tiny remains the LibreQuake-only donor for reproducible future builds.

`shared.json` defines explicit family substitutions; `build_shared.py` combines them with textures actually embedded in maintained maps. `maintained.py --install` applies texture-only changes to 13 LibreQuake maps and two authored TF maps, preserving original BSPs locally and checking all non-texture lumps. `test.py` verifies the minimal used set, original miptex bytes, alias provenance and conversion idempotence. See [the map review](../../docs/MAKKON_MAP_REVIEW.md).
