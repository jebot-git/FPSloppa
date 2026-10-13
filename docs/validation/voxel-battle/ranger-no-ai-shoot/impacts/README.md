# Weapon impact CPU breakdown

Three sequential 60-second diagnostic tests progressively split the impact handler, tracer setup, and finally material versus shadow assignment. All use the same 32 ranger VRMs (11/11/10), alternating idle/walk/run, seeded random CS fire, stationary bodies, prepass on, springs off, no AI/navmesh, and the close fixed simulated stereo view at 2160×2376 per eye. Terrain streaming, culling and avatar LOD are retained. Warmup and post-run captures are excluded. This profiles existing behavior; no gameplay or production effect optimization was made.

Final repeat: 60.018 wall seconds, 59.983 simulated seconds, 2774 rendered samples, 8,592 shots, 300 reloads, zero deaths. All 32 avatars continued shooting and all AI/navigation counters remained zero.

The dominant operation is `node.material_override = m` in the tracer shape setup. It costs 2.720 seconds across 8,592 assignments: **65.57% of impact-handler CPU**, 0.3165 ms per shot on average, and 5.399 ms at p95 per rendered-frame bucket. This is 13.51% of measured authoritative physics callback CPU in this repeat. The adjacent shadow setting costs only 0.0008 ms per call. The timer measures elapsed time inside the Godot property assignment; it does not identify engine-internal causes such as render-thread synchronization or shader work.

| Impact stage | Impact CPU share | Mean per call | p95 per rendered frame |
| --- | ---: | ---: | ---: |
| Material override assignment | 65.57% | 0.3165 ms | 5.399 ms |
| Impact audio | 6.57% | 0.0679 ms | 0.491 ms |
| Tracer mesh build | 4.91% | 0.0237 ms | 0.333 ms |
| Lighting signal | 3.53% | 0.0170 ms | 0.233 ms |
| Material construction | 2.48% | 0.0120 ms | 0.167 ms |
| Surface ray | 1.13% | 0.0054 ms | 0.074 ms |
| Mesh assignment | 1.04% | 0.0050 ms | 0.069 ms |
| Add node to scene | 0.97% | 0.0047 ms | 0.065 ms |
| Transform and bookkeeping | 0.60% | 0.0029 ms | 0.040 ms |
| Particle enqueue | 0.57% | 0.0014 ms | 0.036 ms |
| Node construction | 0.46% | 0.0022 ms | 0.030 ms |
| Shadow assignment | 0.16% | 0.0008 ms | 0.012 ms |

The listed stages account for approximately 87.98% of the handler; the remainder includes recipe/definition preparation, loop arithmetic, bookkeeping and diagnostic timing overhead. Audio occurs only on confirmed surface hits (4,011 calls), while particle enqueue has two calls per impact. Frame p95 values are individual distributions and should not be summed. Sparse event stages have zero median per-frame cost because many frames contain no shots.

Total impact-handler CPU was 4.148 seconds, averaging 0.4828 ms per shot; p95 7.602 ms per rendered-frame bucket. Visuals are an inclusive parent of mesh/material/node/lighting/particle work. Tracer shape setup is also inclusive; parent scopes must not be added to their children. The first repeat found visuals around 90% of impact time and shape setup around 73%; the second found material/shadow property assignment around 66%, and the final repeat isolates material assignment as the cause of that measured cost.

Later effect updates, including multimesh particle updates, shape fading and expiry, run in `_process` outside the physics callback: mean 0.123 ms, median 0.123 ms and p95 0.268 ms. Deferred freeing and render/server work outside measured callbacks are not fully attributed to impact creation. These are elapsed CPU scopes, not isolated GPU costs. The final diagnostic frame median/p95 was 18.774/38.406 ms; the uninstrumented two-minute receipt remains the baseline.

The next optimization experiment should reuse tracer nodes and compatible material resources, setting their render properties during pool initialization instead of assigning a fresh override per shot. This is a recommendation based on the measured call site; pooling was not implemented or benchmarked here.

Validation checked CSV counts and frame/GPU/renderer percentiles, prepass/spring flags, all 32 shooting, zero AI/nav counters, and impact/material call counts equal to shots. Copied impact/visual functions match the originals after removing timers and normalizing whitespace/statement separators. Exact scripts, hashes, checks, frame samples, stereo images and logs are retained. The two earlier diagnostic passes are retained under `first-pass/` and `second-pass/`. All three processes exited with code 0; shutdown cleanup warnings/errors after saved results remain in the logs.

[Scopes](profile.json) · [Checks](checks.json) · [Frame samples](frames.csv) · [Stereo capture](preview.png)

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/profile_impacts.gd -- --representation vrm --simulate --seconds 60 --output res://test-results/ranger-impact-final
```

Requires the existing local ranger input manifest and original sources. Source avatar binaries are not copied or redistributed.
