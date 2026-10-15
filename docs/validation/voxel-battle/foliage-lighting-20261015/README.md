# Foliage billboard illumination — 2026-10-15

The baked material converter returned early for every transparent material. Tree, bush and undergrowth cards use alpha-scissor transparency, so their original unshaded materials bypassed world illumination. Fixed-Y alpha-scissor cards now reach the existing baked billboard shader. Conversion preserves tint, alpha and cutout threshold; blended effects retain their own materials.

## Validation

Godot 4.7.2, Forward+, Intel ADL-N desktop Vulkan GPU: **34 checks passed**. The regression test covers all nine tree/bush billboard variants and all four undergrowth species, material property preservation, blended-material exclusion, and rendered real foliage assets in transformed MultiMesh instances.

The controlled captures place tree mesh, tree card, bush mesh and bush card from left to right. The old materials remain visible in `before-night.png`; converted cards follow world darkness in `night.png`. Day, storm, lightning and atlas-shadow captures verify the shared lighting response. Storm/day luminance ratios are approximately 0.53/0.56 for tree mesh/card and 0.54/0.54 for bush mesh/card. The spatial atlas test verifies each instance samples its own position rather than inheriting another instance’s shadow. Raw measurements are in `results.json`.

The actual jungle preview also loaded, streamed terrain and asserted all nine billboard variants were automatically converted through the map setup path (`world-smoke.log`). This is a scene smoke check; the isolated fixture supplies the measured visual comparison. The smoke script temporarily restores original card materials in memory for its initial capture.

Run from the project directory with a graphical display:

```sh
Godot_v4.7.2-stable_linux.x86_64 --xr-mode off --path . --script deathmatch/tests/cq_foliage_lighting.gd
Godot_v4.7.2-stable_linux.x86_64 --xr-mode off --path . --script docs/validation/voxel-battle/foliage-lighting-20261015/world_smoke.gd
```

Outputs go to `test-results/foliage-lighting/`. Headless execution runs material checks only. Script parse checking and `git diff --check` also passed. Foliage geometry, artwork and LOD distances are unchanged. No frame-time benchmark or headset test was performed; no live service deployment was made.
