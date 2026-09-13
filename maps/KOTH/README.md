# FPSloppa fixed-hill arenas

The default bundled KOTH rotation contains:

- `koth_solstice` — **Solstice Crown**, from LibreQuake Solstice (`lqdm1`).
- `koth_torture` — **Torture Crucible**, from Torture Pit (`lqdm2`).
- `koth_hyperborea` — **Hyperborea Tribunal**, from Hyperborea (`lqdm3`).
- `koth_alichar` — **Alichar Overload**, from Alichar Sector (`lqdm8`).

Each has a fixed hill, remodeled scoring geometry and approaches, widened horizontal layout, relocated team starts and supplies outside the scoring circle. Original maps remain available to their other modes. The four derivatives are offered by the KOTH host menu, lobby votes and default server rotation. `set koth_maplist "koth_solstice koth_torture koth_hyperborea koth_alichar"` explicitly selects the full rotation; a subset is also supported. `koth_move_points` no longer moves the hill.

Original maps by **ZungryWare and LibreQuake contributors**, from [LibreQuake v0.09-beta](https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta). Map and LibreQuake asset redistribution is under BSD-3-Clause; retain the accompanying COPYING, CREDITS and licence-information files. `original/` preserves the unmodified source maps. `source/` contains the FPSloppa derivatives and their shared used-texture WAD. `BUILD.json` records source hashes, compiled hashes and texture correspondence.

**Makkon textures:** credit Makkon, see the included `Makkon_License.txt`. Textures remain original miptex records; they are not generated, resampled, trained on, or used as generative-art inputs. The project owner's separately confirmed permission covers association with FPSloppa promotional artwork. This does not grant downstream users broader rights than the supplied licence; obtain any necessary permission for their own use.

Rebuild from repository root with `python3 tools/koth/build.py`, then `godot --headless --xr-mode off --path . --script res://tools/koth/bake.gd`. The builder expects LibreQuake development sources/WADs under `tools/koth/local/dev`, locally procured Makkon archives used by `tools/makkon/theme.py`, and ericw-tools under `/tmp/hislop-ericw/ericw-tools-v0.18-Linux/bin`. `spawns.json` contains the reviewed spawn placements; do not regenerate it casually, as it is part of the map design. Research and rationale: `docs/KOTH-REMODEL-STUDY.md` in the repository.

Base-distribution update: imported maps and explicit personalised server maplists remain available; the four-map selection is the bundled default, not a runtime prohibition on other arenas.
