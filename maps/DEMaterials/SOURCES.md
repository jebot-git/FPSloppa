# DE surface artwork — 26 September 2026

The five BSP29 reconstructions share the material pass in
`tools/de_texturing/materials.py`. Brush planes, collision layout, entities,
starts, sites and navigation are retained. Material names, sampling scale,
panel alignment, embedded albedo and the resulting baked lightmaps change.

| Map | Main surfaces |
|---|---|
| Dust2 | Worn lime plaster, sandstone paving, rough tunnel masonry, timber gates and framed crates |
| Nuke | Pale corrugated steel, steel decking, separate ceiling panels, yellow reactor cladding, heavier lower-level panels |
| Inferno | Warm plaster, weathered white brick in the east/west buildings, cobbled lanes, timber ceilings and shutters |
| Aztec | Moss-jointed ruin stone, rough rock ceilings, worn bridge planks, existing carved bands and grass |
| Train | Weathered red/white brick, worn slab flooring, green/rust freight panels, steel underframes and separate indoor ceilings |

Makkon Industrial/Metal artwork is by **Ben “Makkon” Hale**, palette/LUT credit
**ptoing**. The original WAD2 names, dimensions, indexed pixels and all four mip
levels are retained byte for byte. These textures retain their separate license;
see `Makkon_License.txt` beside each map and the project's existing permission
record in `tools/makkon/README.md`. No Makkon artwork was supplied to a generative
image tool. LibreQuake textures retain their BSD-3-Clause notices and credits.
Each map's `texture-sources.json` records the exact archive, WAD and miptex hashes.

Three new original textures were made with the **built-in imagegen tool**, with
no reference images. Unaltered outputs are kept in `source/`; `sources.json`
pins them by SHA-256. Build conversion resamples them to 512×512, uses only
non-emissive Quake palette indices 0–223 and produces four box-filtered mipmaps.
These are albedo textures, not normal/roughness/PBR maps. The existing small
painted A/B signs, markings, water and carved trim remain original builder art.

## Exact generation prompts

### `source/plaster.png`

Create a production game texture: one square seamless tileable warm pale sandstone-colored weathered lime plaster wall albedo, viewed perfectly straight-on orthographic, no perspective. Fine sand grains, subtle trowel marks and small irregular worn patches revealing rough limestone mortar, understated age and stains, occasional tiny cracks. Restrained light cream ochre palette, moderate brightness, natural detailed surface suited to Mediterranean village and desert fortress walls in a classic multiplayer shooter. Completely flat diffuse illumination with no directional shadows, no ambient vignette, no bright center, no strong large feature, no bricks, no objects, no typography, no borders, no watermark. Opposite edges should tile seamlessly both horizontally and vertically. 1024x1024. This is a brand-new original texture, no reference images.

### `source/ruins.png`

Create one original seamless square game texture, tileable in both directions: ancient Mesoamerican ruin masonry, large irregular rectangular gray limestone blocks in staggered horizontal courses with worn chipped edges and thin recessed mortar, restrained patches of olive green moss in joints, subtle weathering and age. Orthographic front view, physically flat wall texture albedo under uniform diffuse light, no directional cast shadows or vignette. Light to medium neutral gray stone with muted green details, sufficiently bright to read in a shaded game level. Realistic material detail with clear block forms, about 5 blocks across and 6 courses high; no ornament, no glyphs, no vines, no text, no objects, no perspective, no border. 1024x1024. Opposite edges meet seamlessly. Brand-new original art, no reference images.

### `source/paving.png`

One square seamless tileable game texture albedo of worn pale sandstone paving. Top-down orthographic flat surface only, large rectangular slabs laid in a mixed running-bond pattern, about 4 slabs across and 5 courses high, shallow narrow sand-filled joints, softly worn chipped edges, faint scuffs, fine natural pores and restrained tonal variations. Warm light beige and muted gray cream, avoid orange. Uniform diffuse illumination, no cast shadows, no gradients or vignette, no objects, text, plants, symbols, perspective, border or watermark. Opposite edges must tile seamlessly horizontally and vertically. Classic desert fortress multiplayer shooter floor, clear materials, natural realistic detail. Original asset, no reference images. 1024x1024.

## Build and review

Run the existing Dust2 and ClassicDE builders sequentially (both update shared
map catalogs), then `tools/de_texturing/prepare.gd` through Godot. It writes raw,
BC7 and ASTC4 caches with complete mipmaps and matching source hashes, including
the dictionary-versioned aliases required by the four func_detail maps. For
geometry edits, run the respective map's navigation bake first. Texture-only
changes retain the verified navigation resource.

`tools/de_texturing/preview.gd` captures the real game renderer, each authored
viewpoint and both plant areas. `deathmatch/tests/defusal_maps.gd` checks all ten
sites and confirms no floating site text is created; the original map traversal
tests cover spawns, forward/return routes and navigation. Rebuild the internal
installer with `tools/build_base_assets.py` before packaging.
