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
