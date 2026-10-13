# Three military ranger VRMs: two-minute 16v16 benchmark

Completed 120.015 seconds of wall-clock measurement, advancing 109.83 seconds of simulated match time. Final Red/Blue score: 39/48. There were 1,076 rendered frame samples, averaging 8.97 frames/s over the interval.

The campaign work in the main checkout installs military_ranger_Q. Two original military_ranger_2022_combine_2 variants were also located in local Trash and read directly, without restoring, modifying or redistributing their VRM binaries. Their duplicate embedded titles are distinguished by original filenames and SHA-256 in `input-models.json`. The three sources were assigned cyclically to the same 32 bot IDs:

| Source | Instances | Source triangles |
| --- | ---: | ---: |
| ranger_q | 11 | 8,379 |
| ranger_2022_433888 | 11 | 16,779 |
| ranger_2022_198356 | 10 | 16,779 |

Same 16v16 TDM, CS loadout (four snipers/team), jetpacks, seed 1977, terrain, navigation and uncapped simulated stereo setup as the earlier comparison. Two 2160×2376 views use 64 mm eye separation and the locked overview camera at (0,260,170), looking at (0,15,0), FOV 90°. Native OpenXR is off. Production avatar distance animation/mesh LOD and map culling/streaming remain enabled.

VRM surface/index preparation is on. Each ranger model has two material surfaces, unchanged by surface compilation; index optimization was applied. All 32 rigs have secondary motion disabled, and these models instantiate no spring systems. Preparation, navmesh bake, terrain streaming and avatar mesh LOD generation are excluded. Readback/capture happens after measurement.

| Measurement | Median | p95 |
| --- | ---: | ---: |
| Frame | 108.95 ms | 139.63 ms |
| Stereo GPU | 2.56 ms | 3.91 ms |
| Renderer CPU | 0.73 ms | 0.94 ms |
| Authoritative physics per tick | 11.26 ms | 36.27 ms |
| Bot AI per tick | 6.10 ms | 31.41 ms |

Median draw calls: 523; primitives: 661,628. Renderer CPU is lower than the earlier six-model VRoid VRM match (0.73 versus 1.80 ms), while frame time stays close (108.95 versus 113.14 ms) and stereo GPU is similar (2.56 versus 2.77 ms). These are individual live matches with differing combat outcomes; model changes alone cannot be credited with a precise causal speedup. Physics catchup can run several ticks per rendered frame, so per-tick time must not be directly compared or added to frame-level timings.

No engine errors or warnings occurred during this run. Frame CSV counts/medians, source hashes, model counts, fixed camera and distinct nonempty eye captures were checked. Exact run/bot harness snapshots accompany the receipt. A separate diagnostic scope profile is saved under `profile/`; it is not the baseline measurement above.

[Result](result.json) · [Samples](frames.csv) · [Checks](checks.json) · [Stereo capture](preview.png)

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/ranger_match.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/ranger-match/run
```

Requires the local input manifest under `test-results/ranger-match/input-models.json` and the original local source files. Original asset bytes are not included here.

[Simulation cost diagnosis](profile/README.md): AI consumes about 70% of measured authoritative CPU time; steering dominates typical frames and planning/pathfinding dominates spikes.
