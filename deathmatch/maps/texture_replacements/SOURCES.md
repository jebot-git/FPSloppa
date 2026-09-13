# Texture replacement art

Most tiles derive from LibreQuake v0.09-beta development WADs, released under the
BSD 3-Clause license. See the adjacent LibreQuake COPYING, CREDITS and licensing
notes. Upstream: https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta
The manifest records the exact source WAD, source tile and converted tile SHA-256.
Tiles are renamed, resized with indexed nearest-neighbour sampling and, where
specified, rotated to match the source brush texture orientation.

Four original motifs (ossuary, bronze guardian, sentinel mural, gargoyle) were
generated with the built-in image_gen tool on 2026-09-11 without reference images.
The source atlas and prompt are in `tools/texture_replacements/`. Crops are resized
and quantized to the game's palette, excluding emissive colours. No original id
texture pixels were used to produce these tiles. These generated additions are
provided with the project for use, modification and redistribution; to the extent
copyright rights attach to these additions, they are dedicated under CC0-1.0.
https://creativecommons.org/publicdomain/zero/1.0/

OpenGameArt was reviewed, including Puffolotti's CC0 gothic wall collection
(https://opengameart.org/content/walls-textures-for-multiple-purposes-mostly-gothic).
Its cartoon style did not fit the intended materials; no OGA files are included.
The source-name correspondence is a project-maintained approximation, not an
endorsement by id Software or LibreQuake.

September 2026 texture update: the shared replacement dictionary now includes a used-only Makkon WAD. Makkon records are copied without resizing, renaming or changing mip levels; their separate licence accompanies the maps. Current provenance is recorded in tools/makkon/selection.json, docs/validation/makkon-shared.json and texture-theme.json where present. Older LibreQuake-only receipts describe the pre-theme geometry/source build. See docs/MAKKON_MAP_REVIEW.md for scope and validation limits.
