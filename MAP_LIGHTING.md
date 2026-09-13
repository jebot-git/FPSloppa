# Generated arena lighting and architecture

September 12 static-rendering refinement: Contrast now uses a shared RGB shoulder
that lifts readable midtones without clipping individual colour channels; Classic
remains the default. Pressureworks and Vesper Abbey have modestly stronger bounced
fill and more sunlight samples with a six-degree penumbra, retaining the tested
low AO and original atlas sizes. All 25 base-map caches now contain colour mipmaps
averaged in floating-point linear light, with source-hash validation to reject
stale scene caches after a rebake. See [implementation and tests](docs/STATIC-RENDERING-IMPLEMENTATION.md).

An opt-in **Settings → Graphics → Baked lighting → Contrast (experimental)** response is now available. It improves dark/light separation using the existing atlas sample and draw pass. All 25 current base-distribution maps now include the tested low baked AO (32 Quake units, strength 0.5), merged into their existing RGB lightmaps. Geometry, gameplay entities, light styles, atlas sizes and navigation remain unchanged. Classic/Contrast changes the light response; it cannot remove baked AO. See [distribution AO validation](docs/validation/lighting-ao-distribution.json). See [the lighting experiment, measurements and comparison commands](tools/lighting_experiment/README.md). Large original TF maps use 4096×4096 atlases (48 MiB RGB pixel data), rather than the 1024×1024 atlases described below for the generated collection.

The 40-map collection now imports its compiled Quake lightmaps into Godot. Previously the BSP lighting lump was present but unused, so only the environment and nearest dynamic lights illuminated the geometry.

The compiler uses full VIS, supersampled lighting, ambient occlusion, one bounce, warmer sunlight and contrasting wall/corridor lamps. RGB light data is embedded in the BSP using ericw-tools `-bspxlit`; a host only needs to send the BSP to preserve coloured lighting. The `.lit` sidecar is retained for other engines. The importer opts in through the generated worldspawn `_fpsloppa_bake` key, leaving existing downloaded maps and their materials unchanged.

Opaque generated-map surfaces share one padded 1024×1024 RGB atlas (3 MiB uncompressed) per loaded map, with one additional texture sample and no extra geometry pass. UVs follow Quake's 16-unit luxel grid, including negative texture coordinates. Filtering uses replicated edge gutters. Invalid light offsets fall back to neutral shading. The renderer lifts dim baked values for VR readability while retaining baked occlusion and gradients. A small live lighting contribution preserves muzzle/projectile effects; existing dynamic map lights still illuminate players. This is static geometry lighting, not baked light probes for moving VRMs. Animated Quake light styles are not implemented by this opt-in path.

Rooms now vary their lower/upper wall materials, dado bands, cornices, overhead beams, stepped stone entrances and sky courts. Team bases use coloured trim instead of uniformly coloured walls. Visible lamps correspond to bake emitters, and connecting corridors have ceiling fixtures. The original route graphs and objectives remain, with added architecture kept above player clearance or against walls. Art remains the same licensed LibreQuake texture subset; original Doom/Quake textures or geometry are not copied.

Reference: [ericw-tools light documentation](https://ericwa.github.io/ericw-tools/doc/light.html). Quake-style contrast and warm masonry, plus Doom-style panel bands, tech lighting and contrasting room treatments, inform the original architecture.

Validation includes atlas sample/UV/gutter tests, coloured-bake import assertions, full map clearance/navigation checks and actual rendered screenshots. Headset performance and competitive playability still require device/play testing.

Map skyboxes, animated surfaces and stone weathering are default behaviour. Fog rendering and the sky/fog graphics control have been removed. See [recommendations 4–6 and validation](docs/MAP-PRESENTATION.md). All 25 bundled maps now use compact lightmaps and full-resolution selective BC7/ASTC 4×4 caches; lightmaps, glow and cutouts remain uncompressed. See [static assets and Contrast tests](docs/STATIC-ASSETS.md). Quest validation is deferred.

## BSP import audit

Fresh BSP import does not run a lighting or AO bake. The baked-light reader requires worldspawn `_fpsloppa_bake` set to `1` and an existing lighting lump; it consumes embedded BSPX RGBLIGHTING when present, otherwise native grayscale samples. External `.lit` sidecars are not read by this path. Unmarked third-party BSPs retain legacy materials, so their stored lightmap is not applied. `generate_occlusion_culling` builds visibility occluders, not ambient occlusion.

AO already baked into an opted-in map’s light samples is preserved by the importer, shader and scene cache. The September 13 audit verified Ashfall (33,505 lit faces), the external Softbox BSP without/with opt-in (0/2,699 lit faces), and the controlled Pressureworks AO-off/AO-low pair (6,350 lit faces each, distinct preserved atlas pixels). All five fresh/cache cases passed with zero invalid or overflowing faces. [Audit details](docs/AUDIO-IMPORT-AUDIT.md) · [Raw receipt](test-results/bsp-import-audit/results.json).
