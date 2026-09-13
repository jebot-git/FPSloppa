# BA-2 source acquisition

Downloaded 13 September 2026 for an isolated model feasibility assessment.

- Asset: **BA-2 (Blast All Bot Mark 2), version 1.1**, by **Quandtum**.
- [Original listing and provenance discussion](https://opengameart.org/content/ba-2-blast-all-bot-mark-2).
- [Original ZIP](https://opengameart.org/sites/default/files/Quandtum_BA-2_v1_1.zip).
- Local original: `source/Quandtum_BA-2_v1_1.zip`.
- SHA-256: `e73d1d6e52697315405c75dea4d530a6ffa1910288b40e150cda25adb031c893`.
- Extracted unmodified `.blend`, `Preview.jpg` and `readme.txt`: `source/extracted/`.

The author labels the model CC0 in both the listing and packaged readme. The readme identifies plaintextures.com and goodtextures.com as texture sample sources. The listing contains a historical discussion about those samples and CC0; a 2021 comment attributed to GoodTextures permits use within models/games but distinguishes redistribution of standalone source textures. Preserve this distinction rather than treating the texture provenance as independently verified CC0. The acquisition assessment added no distribution assets. The later TB prototype adds an opt-in runtime model; see [runtime credits](../../deathmatch/vehicles/ba2/SOURCES.md). No release package has been generated for it.

All five texture maps are actually packed into the `.blend`, including the specular image whose internal name differs from its file path. The original material references the unavailable `OCT_RENDER` renderer. Inspection disables embedded script execution; preview renders reconstruct only diffuse and emission with a new material. Original source bytes are preserved.

Inspection scripts: `inspect_blender.py` and `pose_probe.py`. Results: [assessment](../../docs/BA2-FEASIBILITY.md), [rig inventory](../../test-results/ba2/inspection.json), [pose checks](../../test-results/ba2/pose-checks.json). These directories are excluded by current client export filters.

Authored derivative: [10 m walk animation](animated/README.md), created with `author_walk.py`. The derivative retains Quandtum's geometry, UVs, weights and painted maps, replaces the animation controls with baked actions and reconstructs the legacy material. The original ZIP and extracted source remain unchanged.
