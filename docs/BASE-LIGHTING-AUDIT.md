# Base-map lighting audit and corrections

All 26 base maps contain grayscale light data and correctly sized embedded RGB lightmaps. The bright Q1 previews came from conversion-added fill, a shared brightness lift, and a full-bright fallback for ordinary surfaces without light samples.

## Fifteen completed authored-light rebakes

| Maps | Correction |
| --- | --- |
| Q1 DM1–DM7 | Full VIS and 4×4-sample RGB lighting; removed added minimum light, sun and bounce; rebuilt navigation. |
| KOTH Solstice, Torture, Hyperborea, Alichar | Removed the conversion-added minimum light of 48 and rebaked 4×4-sample RGB lighting. |
| CC Hyperborea, Psychofuge, Ghostquarter, Basement | Removed the conversion-added minimum light of 52 and rebaked 4×4-sample RGB lighting. |

All fifteen use the verified Quake-style display-space response, without the shared square-root brightness lift. Ordinary sample-less surfaces use a black atlas entry. Raw, BC7 and ASTC scene caches were rebuilt.

The eight LibreQuake derivatives retain their original sunlight, including Hyperborea's authored `_sunlight2 666`. Their geometry, collision, VIS, textures and gameplay entities were verified unchanged by relighting. Their existing navigation meshes were preserved. Four previews per map were rendered and representative views inspected.

## Three cache corrections without relighting

HiSlop has 850 ordinary sample-less faces; Confluence and Skyfracture have 12 each. Their importer policy and raw/BC7/ASTC caches now use the black entry. Their existing light samples, geometry and navigation remain intact. Their native brightness response and live lighting remain in use; the reserved black entry contributes no baked emission.

## Eight maps with no matching defect

Frigate, Pressureworks, Vesper, Tideworks, Crucible, Deepvault, Crownreach and Ashfall have no ordinary faces without samples. Their minimum light, sunlight and bounce settings belong to their FPSloppa source generators. The audit found no reason to apply the same source-restoration rebake to them.

Eleven native maps retain the shared Classic/Contrast response around which they were authored. A future global appearance change would require separate visual review.

## Evidence

- [Final per-map audit](validation/base-lighting-audit.json): sample counts, source comparisons and hashes; no remaining identified rebake or missing-face candidates.
- [Active cache audit](validation/base-lighting-caches.json): all 26 caches match their BSP source hashes.
- [Additional bake receipt](validation/base-authored-rebake.json): preserved geometry and compiler flags.
- [Q1 validation](validation/quake-restored.json): compiler, cache, traversal, networking and rendered-response checks.

Reproduce the data audit with `python3 tools/lighting_experiment/audit_base_authored.py`; stage the eight derivative light bakes with `python3 tools/lighting_experiment/restore_authored.py`.
