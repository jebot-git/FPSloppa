# Converted-map render gallery

Render all 22 newly adapted Classic ST maps and 14 retained converted
Varq DE maps with the actual game renderer:

```sh
python3 tools/map_gallery/render.py
python3 tools/map_gallery/render.py --resume
python3 tools/map_gallery/render.py --map de_varq_mirage
python3 tools/map_gallery/package.py  # requires Pillow
```

The renderer requires a working Vulkan display and the generated map files,
Classic probes and DE conversion reports. It uses an offscreen 1920×1080 viewport
so desktop window limits do not reduce capture resolution. Each map has three
whole-map overviews, both teams' starts, and four directions at each objective.
ST maps also include two closer base overviews: 15 images per ST map and 13 per DE
map, 512 images total. Overviews disable fog to reveal the full footprint; ground
views retain the game's weather, textures and lighting. No map geometry is
changed for the screenshots.

Outputs live in `test-results/map-gallery`: offline `index.html`, ST/DE contact
sheets, original PNGs, small browsing thumbnails, and separate portable ZIPs.
The package step validates every PNG's dimensions and nonconstant pixels, checks
render logs and capture counts, and records BSP/image hashes in `validation.json`.
The renders document the current adaptations, including their existing visual
and routing limitations; they are not evidence of full retail asset fidelity.
