# Vesper Megalopolis — nighttime lighting bake

The city has been rebuilt and fully relit for night. The moon and sky now provide a subdued blue fill, while windows, streetlamps, braziers and holographic architecture provide the local illumination. This changes the baked lighting and the opt-in material response, rather than only darkening the skybox.

![Before and after nighttime bake](../test-results/city/night-comparison.png)

[All districts](../test-results/city/districts.png) · [Night skyline](../test-results/city/city_skyline.png) · [Gate illumination](../test-results/city/gate.png)

## Lighting changes

- Compiler moon/sky/minimum settings changed from **90/35/10 to 9/4/1**. These are artistic compiler settings, not physical lux measurements. The night panorama, fog contribution, ambient fill and remaining live directional fill were also reduced.
- **1,424 baked point emitters** now correspond to visible light sources: 512 window samples, 192 gate samples, 184 ring samples, 160 roof-band samples, 128 streetlamp samples, 64 canopy samples, 64 plaza-ring samples, 64 braziers, 36 orbital samples, 16 beacons and four data-pylon samples.
- Tall windows illuminate both their lower and upper façade. Gates illuminate their approaches on both sides. Braziers cast warm light, with their geometry and emitters moved clear of the gallery. Small shrine rings were enlarged enough to sit outside their opaque stone spires.
- The night material response removes the previous automatic shadow lift. Compiler faces with no light samples are explicitly dark for this opted-in profile; they no longer receive a neutral grey fallback. Existing map profiles retain their existing response.
- All fixture illumination is baked. No new real-time lights, particle simulation or per-frame illumination scripts were introduced; the existing two-effect weapon-light budget remains unchanged.

## Bake and verification

Full VIS, 2×2 supersampling, embedded RGB lighting, one diffuse bounce and ambient dirt completed: **qbsp 1.9 s, vis 26.3 s, light 61.3 s**. The final light compiler log has zero misplaced-emitter warnings. The BSP is **24.20 MB**, below the unchanged 25 MB importer cap.

All **44,543 rendered BSP faces** are accounted for: 43,738 sampled RGB faces and 805 fully shadowed faces using explicit black. There are zero invalid samples or atlas overflows. All 330 prepared surface batches have the night response enabled. Existing 16-texel and city 32-texel sample tests, opt-in material checks and dark-face fallback tests pass.

BSP vertices, collision geometry, face topology, textures and structural leaf data match the previous city. Full VIS can produce different compressed offsets, so comparisons exclude those offsets and lighting records. All 64 spawns remain connected; 64 floor probes, 144 gate-clearance probes and 16 perimeter collision probes pass. Normal map loading resolves the decorated cache, and the separately clipped district cache has been regenerated.

Fixed foreground crops of the cathedral, foundry and data district renders have 43–52% of their previous mean sRGB luma. The bright gate remains at about 89%, preserving the intended contrast between emissive sources and their surroundings. These are image-comparison measurements, not photometric energy measurements. Twenty final engine views cover all districts and representative details.

Current bot-run results are maintained in [CITY-DECORATION.md](CITY-DECORATION.md). This lighting pass does not convert the observer into a playable district client; see the separate [server/client integration assessment](DISTRICT-SERVER-INTEGRATION.md).

SHA-256: `727ebb90f7c4239b1a3a3e6fde4bd713a971ba2b552444afe1a16888d7599ca3`.

[Machine-readable lighting validation](validation/city-night-lighting.json) · [Rebuild instructions](../maps/Benchmark1km/README.md). The preserved comparison images are under `test-results/city/night-before/`.
