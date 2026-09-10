# Generated arena lighting and architecture

The 40-map collection now imports its compiled Quake lightmaps into Godot. Previously the BSP lighting lump was present but unused, so only the environment and nearest dynamic lights illuminated the geometry.

The compiler uses full VIS, supersampled lighting, ambient occlusion, one bounce, warmer sunlight and contrasting wall/corridor lamps. RGB light data is embedded in the BSP using ericw-tools `-bspxlit`; a host only needs to send the BSP to preserve coloured lighting. The `.lit` sidecar is retained for other engines. The importer opts in through the generated worldspawn `_fpsloppa_bake` key, leaving existing downloaded maps and their materials unchanged.

Opaque generated-map surfaces share one padded 1024×1024 RGB atlas (3 MiB uncompressed) per loaded map, with one additional texture sample and no extra geometry pass. UVs follow Quake's 16-unit luxel grid, including negative texture coordinates. Filtering uses replicated edge gutters. Invalid light offsets fall back to neutral shading. The renderer lifts dim baked values for VR readability while retaining baked occlusion and gradients. A small live lighting contribution preserves muzzle/projectile effects; existing dynamic map lights still illuminate players. This is static geometry lighting, not baked light probes for moving VRMs. Animated Quake light styles are not implemented by this opt-in path.

Rooms now vary their lower/upper wall materials, dado bands, cornices, overhead beams, stepped stone entrances and sky courts. Team bases use coloured trim instead of uniformly coloured walls. Visible lamps correspond to bake emitters, and connecting corridors have ceiling fixtures. The original route graphs and objectives remain, with added architecture kept above player clearance or against walls. Art remains the same licensed LibreQuake texture subset; original Doom/Quake textures or geometry are not copied.

Reference: [ericw-tools light documentation](https://ericwa.github.io/ericw-tools/doc/light.html). Quake-style contrast and warm masonry, plus Doom-style panel bands, tech lighting and contrasting room treatments, inform the original architecture.

Validation includes atlas sample/UV/gutter tests, coloured-bake import assertions, full map clearance/navigation checks and actual rendered screenshots. Headset performance and competitive playability still require device/play testing.
