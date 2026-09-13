# Optional LibreQuake deathmatch maps

Extract this release pack beside the game so the BSPs land in `maps/`. In the ASSETS menu, rescan folders while disconnected. Add `lqdm9 lqdm10 lqdm11 lqdm12 lqdm13` to the desired `maps/<tag>_maplist.txt` files. Keep the enclosed readmes, contributor credits and license notices.

Source: LibreQuake v0.09-beta full and developer releases, https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta . These five arenas are by ZungryWare. All embedded texture mip levels were replaced with matching LibreQuake developer WAD textures; `manifest.json` records provenance and hashes. `validation.json` records actual Godot render-triangle, collision, spawn and teleport checks. Several upstream development-grid textures are replaced by readable industrial flooring/panels in the current Makkon theme. QuakeC scripts and custom mod logic are not reproduced.

September 2026 theme: selected original Makkon textures now supplement LibreQuake. The separate Makkon_License.txt applies to those textures; texture-theme.json verifies current BSP hashes and unchanged geometry. Earlier texture-validation.json and source WAD references document the original LibreQuake build, before this texture-only pass. Reproduce the theme with tools/makkon/maintained.py after rebuilding the original source.
