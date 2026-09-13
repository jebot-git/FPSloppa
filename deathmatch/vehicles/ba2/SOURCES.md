# BA-2 runtime model

**BA-2 (Blast All Bot Mark 2), v1.1, by Quandtum**. Source: https://opengameart.org/content/ba-2-blast-all-bot-mark-2

The author labels the model CC0. The original readme names PlainTextures and GoodTextures as texture sample sources; the listing discusses those samples and permits their use within models/games without treating standalone texture redistribution as independently verified CC0. See the full [acquisition and provenance notes](../../../tools/ba2/SOURCES.md).

`model.scn` is FPSloppa's derivative: baked 18-bone slow walk, approximately 10 m height, reconstructed diffuse/emission material and rigid X-axis cannon hinges. It retains all 6,696 original triangles. The shell and eye (816 triangles) form a separate skinned mesh so they can be hidden only from a seated pilot's interior camera. The remaining 5,880 triangles include all four cannons and legs. External views retain the complete robot. No external cabin or platform was added.

Rebuild with `tools/ba2/gameplay/prepare_asset.gd` from `tools/ba2/animated/BA2-10m-walk.glb`; the original ZIP remains unchanged. The belly ladder is procedural FPSloppa geometry. This asset supports the experimental TB — TITANBALL test fixture; no release package was produced in this task.
