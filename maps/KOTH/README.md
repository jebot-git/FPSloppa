# FPSloppa rotating-hill arenas

The default bundled KOTH rotation contains:

- `koth_solstice` — **Solstice Crown**, from LibreQuake Solstice (`lqdm1`).
- `koth_torture` — **Torture Crucible**, from Torture Pit (`lqdm2`).
- `koth_hyperborea` — **Hyperborea Tribunal**, from Hyperborea (`lqdm3`).
- `koth_alichar` — **Alichar Overload**, from Alichar Sector (`lqdm8`).

Each has three authored hill sites, with one active site moving every 30 seconds. New level scoring decks have four approach ramps and supplies outside the scoring circles. The original widened layout and team starts are retained where clear of the new hills. Original maps remain available to their other modes. The four derivatives are offered by the KOTH host menu, lobby votes and default server rotation. `set koth_maplist "koth_solstice koth_torture koth_hyperborea koth_alichar"` explicitly selects the full rotation; a subset is also supported. `koth_move_points` remains ignored; relocation follows elapsed time. A visible countdown floats above the active hill.

Original maps by **ZungryWare and LibreQuake contributors**, from [LibreQuake v0.09-beta](https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta). Map and LibreQuake asset redistribution is under BSD-3-Clause; retain the accompanying COPYING, CREDITS and licence-information files. `original/` preserves the unmodified source maps. `source/` contains the FPSloppa derivatives and their shared used-texture WAD. `BUILD.json` records source hashes, compiled hashes and texture correspondence.

**Makkon textures:** credit Makkon, see the included `Makkon_License.txt`. Textures remain original miptex records; they are not generated, resampled, trained on, or used as generative-art inputs. The project owner's separately confirmed permission covers association with FPSloppa promotional artwork. This does not grant downstream users broader rights than the supplied licence; obtain any necessary permission for their own use.

Rebuild from repository root with `python3 tools/koth/rotation_build.py --compiler /path/to/ericw-tools/bin`, then `godot --headless --xr-mode off --path . --script res://tools/koth/bake.gd`. The current builder uses the checked-in derivative MAP sources and shared WAD, preserves existing geometry, and performs visibility plus four-sample-axis lighting with bounce and ambient occlusion. `ROTATION.json` records hill positions, source/BSP hashes and compiler commands. The bake step refreshes scene caches, BC7/ASTC texture variants and navigation. `tools/koth/build.py` is the earlier fixed-hill derivation tool; it is not the current rebuild entry point. Design and validation: [rotating KOTH](../../docs/KOTH-ROTATION.md).

Base-distribution update: imported maps and explicit personalised server maplists remain available; the four-map selection is the bundled default, not a runtime prohibition on other arenas.
