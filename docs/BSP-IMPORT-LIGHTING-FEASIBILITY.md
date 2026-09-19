# BSP lighting during import

Investigated 19 September 2026. **Feasible using the existing BSP lightmap renderer and a background CPU compiler.** This investigation adds isolated diagnostic tools, not a production import feature. Original maps and importer behavior were preserved.

## Existing support

`deathmatch/maps/baked_light.gd` reads native Quake grayscale samples and embedded BSPX `RGBLIGHTING`. It currently requires worldspawn `_fpsloppa_bake "1"`; ordinary external maps without that marker ignore their authored lightmaps. The importer already constructs the necessary face UVs and atlas. Automatically consuming valid existing lightmaps is the smallest useful change, with no lighting calculation needed.

For a new bake, ericw `light` operates directly on a compiled BSP using its lighting entities. No original MAP, QBSP rebuild or new VIS pass is needed. Its `-bspxlit` option embeds color samples in the transferred file. See the [compiler documentation](https://ericw-tools.readthedocs.io/en/latest/light.html). The experiment used the locally installed **v0.18.1**; newer versions have different options, so production must pin and test its tool version.

Godot's stock LightmapGI baker is [editor-only](https://docs.godotengine.org/en/stable/classes/class_lightmapgi.html). The current loader also disables light entity import and UV2 generation. Using the established BSP pipeline avoids introducing an editor dependency and a separate lighting asset format into runtime imports.

## Measured proof of concept

Four CPU threads, 4×4 supersampling, one bounce, ambient occlusion, approximate visibility disabled. Sequential runs on this workstation; these are sample timings, not worst-case guarantees. Output stayed below the current 25 MB import limit.

| Map | Input / output bytes | Bake | Headless scene import after bake | Baked faces |
| --- | ---: | ---: | ---: | ---: |
| External `forrest_ctf_maps/softbox.bsp` | 981,808 / 1,363,416 | 3.92 s | 0.26 s | 2,926 |
| Current TF Pressureworks | 10,691,346 / 10,892,148 | 17.55 s | 1.51 s | 6,350 |

All six imports (original, existing-light opt-in, fresh bake for each map) completed. The four opt-in/rebaked cases had zero invalid or overflowing lightmap faces. Softbox's untouched import had zero baked faces because of the opt-in gate; enabling its original samples lit 2,699 faces without a bake. Native-light opt-in took 0.26 s to import versus 0.18 s for the original. Pressureworks already uses baked lighting.

Byte comparisons confirmed unchanged geometry, collision, textures, VIS and face topology for both rebakes; parsed gameplay entities also matched. Native-light opt-in changed only entity metadata. The external rebake changed 227 face lightstyle records, expanding coverage into previously unlit faces. This is a reason to preserve authored lighting by default, not a claim of visually equivalent output. Static first-style rendering remains the engine's existing limitation.

This proves data compatibility, timing and atlas construction, not artistic quality or performance on every supported device. BSP2, very large maps, malformed inputs, exported Windows/Android builds and visual readability of the new bakes were not exercised. Godot emitted one ObjectDB instance cleanup warning at exit; no import assertions failed.

## Proposed production flow

1. Validate and stage the source. Preserve its original filename for the mode-prefix classifier and keep the original bytes. Inspect lighting availability before choosing a path.
2. Default to **use existing lighting** when valid samples are present. Enable the reader through a consistent import policy rather than requiring authors to add FPSloppa keys. Version scene caches so old unlit caches do not mask the change. Support `.lit` sidecars separately if desired; currently only grayscale and embedded RGB are read.
3. Offer **bake lighting** as an asynchronous step, automatic for suitable unlit maps or explicitly requested for a rebake. A missing lighting lump does not imply sufficient light sources exist: check light entities and worldspawn sun/minlight settings, retain a fallback, and report an unusable result rather than publishing a black map.
4. Run a pinned native compiler in an isolated temporary directory with bounded threads, memory, output size and elapsed time. Queue jobs and allow cancellation. Spawn by argument vector, not shell interpolation. Preserve any successful original import if the bake fails. The existing synchronous `Maps.import_custom()` call must not run a blocking compiler on the main thread, especially while connected to a live match.
5. Validate the compiled BSP again, check immutable geometry/gameplay data, rebuild its scene/atlas, then generate its preview. Select atlas size from measured required space; the diagnostic's fixed 4096 atlas is not an appropriate universal default. Reject overflow or use a defined fallback.
6. Publish only after success. Cache work by source hash + compiler version + settings. The published BSP gets its own SHA256, which drives the existing map identity and transfer checks. Preserve original source-name metadata across staging so `tf_`, `koth_`, etc. classification survives.
7. Bake once before catalog publication/upload and distribute the exact resulting BSP to all peers. Do not rebake downloaded copies independently. Desktop importers can bake locally; an optional dedicated-server job can process uploads from devices without a compiler, but must return the final canonical hash/row to the uploader before registration. Server-side automatic baking requires queue/resource limits in addition to the existing upload limits. Native RGB samples travel inside the current BSP transfer; no separate lighting transfer protocol is needed.

Start with desktop baking and consumption of its results on all clients. A server can run the CPU compiler without rendering a scene, while a graphical client supplies the preview through the existing mechanism. Shipping native executables and their libraries/notices is additional platform packaging work. On-device Android baking has not been demonstrated and should not be a first-version dependency.

## Reproduce

From the repository root, with the existing external diagnostic fixture:

```sh
python3 tools/lighting_experiment/import_bake_probe.py \
  --light /tmp/fpsloppa-ericw/ericw-tools-v0.18.1-Linux/bin/light \
  test-results/lighting-coverage/external-original.bsp maps/tf_pressureworks.bsp
godot --headless --xr-mode off --path . \
  --script res://tools/lighting_experiment/import_bake_probe.gd
```

The Python probe intentionally supports BSP29 only. It writes isolated copies and bake receipts under `test-results/import-light-bake/`; the Godot probe writes `import.json` there. Durable results from this run are in `docs/validation/import-light-bake.json`.
