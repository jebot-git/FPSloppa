# Pooled tracer optimization experiment

A fresh baseline and experimental pooled path each ran sequentially for two minutes using the same three ranger VRMs (11/11/10), 32 avatars, prepass on, springs off, zero AI/navmesh, alternating idle/walk/run and seeded random CS fire. Both use the same fixed close formation, terrain streaming/culling/LOD, Vulkan Mobile renderer on Arc A770 and simulated stereo at 2160×2376 per eye, 64 mm separation and 90° FOV. OpenXR is disabled. Measurement starts after preparation/warmup; captures follow measurement.

The experiment preallocates 64 persistent tracer nodes and individual materials, with a shared immutable unit crossed-ribbon mesh. Each straight tracer reuses a slot and changes its transform, color, visibility and lifetime. It preserves the original world geometry, width, linear alpha fade and capacity eviction behavior. Multi-point streaks retain the original path. Audio, surface rays, lighting, particles, hit traces and avatar simulation are unchanged. The production `deathmatch/experimental/visuals.gd` remains unchanged; this is an opt-in test harness.

| Timing | Baseline median / p95 | Pooled median / p95 |
| --- | ---: | ---: |
| Frame | 18.134 / 37.868 ms | 16.849 / 29.531 ms |
| Combined stereo GPU | 2.673 / 3.971 ms | 2.711 / 3.940 ms |
| Combined stereo renderer CPU | 0.897 / 1.353 ms | 0.870 / 1.105 ms |
| Authoritative physics per tick | 3.782 / 14.800 ms | 3.782 / 8.591 ms |

Median frame time fell 7.09%; p95 fell 22.02%. Average rendered throughput was 47.80 versus 56.65 frames/s. GPU time and draw counts remain similar; this improves CPU impact creation rather than reducing draw calls. Median draws were 567/569, and median primitives 1,116,868/1,117,202.

Mean impact CPU per shot fell from 0.4809 to 0.0948 ms (**80.29% reduction**). Impact p95 per rendered-frame bucket fell from 7.520 to 1.252 ms. Mean impact visuals fell from 0.4341 to 0.0511 ms (88.23% reduction). Pooled emission itself averages 0.0070 ms per tracer. The baseline material override assignment consumed 5.331 seconds; the pooled measured interval has zero tracer material construction or override assignment calls.

Effect-update CPU remains small: baseline mean 0.119 ms per callback / p95 0.266 ms, versus pooled total mean 0.127 ms / p95 0.259 ms. The pooled total includes particle updates, the original shape path and pooled tracer fading/expiry. Movement/collision mean call time remained 0.0685/0.0682 ms. Physics median is unchanged while its firing-related tail improves.

Both runs sustained fire through all four 30-second intervals and all 32 avatars stayed alive. Baseline: 120.027 wall / 119.967 simulated seconds, 16,820 shots, 584 reloads. Pooled: 120.042 wall / 119.983 simulated seconds, 16,832 shots, 584 reloads. Twelve extra shots occur with one additional simulated tick at the wall deadline; this is a live paired workload, not a deterministic replay.

Pool preparation took 5.957 ms before measurement. All 16,832 measured emissions used the pool, with zero fallback or capacity eviction, peak 32 active out of 64. Persistent resident objects trade some idle memory for reduced allocation and property assignment during firing. Median static memory was 186.88/187.14 MB and video memory 547.67/547.43 MB.

Geometry checks compare every transformed vertex with the original two-point mesh across several directions, and exercise half-life fading, expiry, overflow/oldest replacement, unique active slots, reuse and multi-point fallback. Checks passed in a headless harness. Both benchmark receipts passed CSV count/percentile checks, identical avatar source assignments/camera/stereo/seed settings, zero AI/nav counters, sustained shooting, distinct nonempty eye captures, pool invariants and matching emissions/shot counts. Source snapshots, hashes, input metadata and verification logs are included; original VRM binaries are not redistributed.

Both paths are instrumented diagnostics. The pooled path avoids timers for removed operations, so frame improvements include some reduced diagnostic overhead. One sequential pair does not establish a repeated-trial production or native-XR speedup. Timers are inclusive; do not add parent and child scopes. Per-tick, per-shot and per-render-frame values are different units. Both processes exited with code 0, then emitted shutdown cleanup warnings/errors after results were saved: baseline 13 and pooled 16 ObjectDB instances, with three resources still in use in each. Logs retain these messages.

[Comparison](comparison.json) · [Checks](checks.json) · [Baseline](baseline/result.json) · [Pooled](pooled/result.json) · [Pooled capture](pooled/preview.png) · [Geometry check](geometry-check.log)

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/profile_impacts.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/tracer-pool-compare/baseline
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/profile_pooled_impacts.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/tracer-pool-compare/pooled
godot --xr-mode off --headless --path . --script tools/vrm_to_mdl/test_tracer_pool.gd
```

Requires the existing local ranger input manifest and original sources. Run the rendered benchmarks sequentially.
