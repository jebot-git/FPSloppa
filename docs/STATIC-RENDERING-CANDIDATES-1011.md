# Recommendations 10 and 11 — closed without integration

The user reviewed the visual differences and declined further implementation on 13 September 2026. Offline cubemap reflections (10) and directional lightmaps with normal maps (11) remain isolated experiments. Recommendations 12–14 will remain unexplored.

[Final visual comparison](../test-results/candidates1011/comparison.png) · [Structured results](validation/candidates1011.json)

The completed suite covered Vesper and Pressureworks in Classic and Contrast lighting: 84 render records, 12,600 measured frames and 32 additional offset captures. It compared baseline, neutral controls, reflections, directional normals, stronger normals, combined effects and restored baseline. Cubemap orientation and directional-response fixtures passed; neutral and restored controls matched the baseline. Geometry and reported draw counts remained unchanged.

The visual benefit did not justify pursuing the prototypes. Reported additional texture memory was approximately 5.23 MiB for reflections, 6.98 MiB for directional normals and 9.23 MiB combined per tested map. Desktop GPU timings were noisy and do not establish a Quest performance budget. These were Mobile/Vulkan desktop captures, not headset or continuous-motion shimmer tests.

The normal companions were experimental interpretations of painted colour, not source-supplied PBR assets. Directional shading used an estimated direct-light fraction; reflections used local LDR cubemaps with ordinary mipmaps and approximate box projection. These limitations constrain conclusions about other possible implementations. The completed runs retained a common one-ObjectDB shutdown warning.

Experiment code is retained under `tools/lighting_experiment/candidates1011/`, with captures and intermediate assets under `test-results/candidates1011/`. Neither effect was incorporated into production shaders, map caches or distribution packages. The receipt records concurrent changes from other map work separately; tested TF BSPs and the production baked-light shader, atmosphere and base manifest matched their pre-experiment hashes.
