# Shared BSP texture replacements

`rules.json` is the curated name-to-art table. The generated runtime dictionary is
`deathmatch/maps/texture_replacements/manifest.json` and `replacement-miptex.lmp`.
It combines LibreQuake v0.09-beta BSD-3-Clause artwork with four original generated
gothic reliefs. Source dimensions and animation names are retained. Material-family
matches are approximations, not an official or pixel-identical id/LibreQuake crosswalk.

The runtime loader applies this dictionary to **missing named textures** in every
supported BSP29/BSP2 import, including client downloads. It preserves embedded pixels.
Unknown names and unnamed `-1` texture slots use neutral stone with a diagnostic;
their intended appearance cannot be recovered from the BSP. Missing-texture scene
caches include the dictionary content version. The approximately 4.2 MB dictionary is exported
inside the game, independently of external map folders. Original id/QRP pixels and
QuadCompati placeholder images are not shipped.

Rebuild with Python 3 and Pillow:

```sh
python3 tools/texture_replacements/build.py --librequake /path/to/dev/texture-wads
```

For external-header BSPs, embed exactly the same replacements before distributing:

```sh
python3 tools/texture_replacements/convert.py input.bsp output.bsp
```

For explicitly authorized conversions of maps that still contain old textures,
`--replace-known` replaces only names in the dictionary. Unknown embedded assets
remain intact and are reported: inspect `output.textures.json` and check their
licenses before sharing. `--use-lightmaps` enables FPSloppa's renderer for the map's
existing lightmap lump; it does not perform a new bake. Geometry, collision, UV
dimensions and lightmap bytes remain unchanged. Always write to a separate output.

ThreeWave and original TF test conversions remain **local only**. This tool grants
no rights to redistribute a map. Supply tools/instructions, not restricted BSPs.
The FortressOne converter prioritizes the same named dictionary when run in this
repository; its legacy fallback remains for unreviewed custom texture names.

To capture four real game views per map:

```sh
python3 tools/quake_source/preview.py /path/to/maps --match qsrc_dm
python3 tools/quake_source/preview.py /path/to/local/threewave/maps --match threewave
python3 tools/quake_source/preview.py /path/to/local/tf/maps --match tf_original
```

TF/CTF views use both teams' spawn and flag positions; Quake views use spread DM
spawns. These are visual checks, not proof of multiplayer balance or headset FPS.
See `SOURCES.md` in the runtime dictionary and `PROMPT.md` here for art provenance.

Run the import/conversion regression test with `python3 tools/texture_replacements/test.py /path/to/qsrc_dm1.bsp`. Assemble the gallery after rendering with `python3 tools/texture_replacements/gallery.py`.
