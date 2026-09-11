# BSP texture and multiplayer preview review — 2026-09-11

The shared dictionary contains 427 named entries, using LibreQuake v0.09-beta art and four newly generated gothic motifs. Curated material-family matches are approximate. There is no hash-selected fallback in the Quake source build or shared runtime dictionary. Unknown external names use neutral stone with a diagnostic; a BSP slot without a name cannot recover its intended texture.

All 15 maps rendered successfully in the current game with four views each. The local interactive gallery and three contact sheets are in `test-results/quake-source-previews/`. Quake DM1–DM7 use fresh full-VIS/RGB light bakes. ThreeWave and original TF comparison copies now opt into rendering their existing embedded lightmap data, fixing dark interiors in the initial comparison. No postprocessing brightness adjustment was applied to screenshots. TF/CTF views cover both teams' spawn/flag areas; DM views cover four spread spawn locations.

## Validation

- Shared importer test: missing named headers, unnamed slots, case matching, liquid names, original UV dimensions, embedded-texture precedence and malformed-offset rejection passed. Default conversion preserves embedded assets and all nontexture lumps.
- Seven Quake source maps: all mip levels match the provenance dictionary; full visibility and embedded RGB bakes verified. All seven runtime traversal tests passed.
- Isolated host and two clients: fresh map download, hash verification, joining, reliable announcements and pistol-only start passed on rebuilt DM1.
- Original TF 2fort5 and well6 local copies: both traversal audits passed.
- ThreeWave local copies: five passed traversal. CTF2M4 still fails two lift-passenger checks against overhead geometry. Swimming and teleport checks pass; do not treat the map as fully accepted.
- Independent byte comparison confirms the eight TF/ThreeWave local copies retain identical geometry, collision and lighting lumps. Only texture data and the world lightmap opt-in changed.
- Preview runs completed without engine errors. Godot reports small ObjectDB shutdown warnings in these standalone harnesses. No VR headset performance or human match-balance test was performed.

## Art and distribution

The OpenGameArt CC0 gothic set reviewed was too cartoon-like, so no OGA artwork was added. See `deathmatch/maps/texture_replacements/SOURCES.md` and the retained generated atlas/prompt in `tools/texture_replacements/`. No original id/QRP texture pixels are included in shipped art.

The optional seven-map GPL Quake source addon is `../Builds/FPSloppa-Quake-Multiplayer-Addon.zip`, with source, license notices, texture provenance and optional gametype maplists. It excludes singleplayer maps and DM8. ThreeWave/TF comparison BSPs stay under `../Builds/Texture-Consistency-Local/`; do not publish those BSPs. Repository changes provide conversion tools and instructions only.
