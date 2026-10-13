# Integrated pooled weapon FX runtime verification

The production `deathmatch/experimental/visuals.gd` path ran for 120.024 wall seconds / 119.967 simulated seconds, with 7,051 frame samples. The harness overrides the bot lifecycle only; it uses the normal arena FX factory and contains no diagnostic visual, weapon or movement timers. It prewarms the normal FX instance before measurement.

32 ranger VRMs (11/11/10), prepass on, springs off, alternating idle/walk/run, seeded random CS firing, no AI or navmesh, same close formation and terrain/culling/streaming/LOD. Two desktop Vulkan Mobile views at 2160×2376 per eye, 64 mm eye separation, 90° FOV on Arc A770; native OpenXR is off.

| Timing | Median | p95 |
| --- | ---: | ---: |
| Frame | 16.338 ms | 27.604 ms |
| Combined stereo GPU | 2.676 ms | 3.856 ms |
| Authoritative physics per tick | 3.536 ms | 7.939 ms |

16,820 shots and 584 reloads; all 32 fired throughout, with zero deaths. Exactly 64 allocated nodes and one shared shape capacity; peak 32 active, zero evictions, all shots took the straight tracer fast path. All AI/nav counters were zero. CSV counts/percentiles, eye dimensions/distinct nonempty images, prepass/spring flags and pool invariants passed. Source snapshots and hashes are included.

The portable regression harness passed 391 checks covering straight/curved geometry, basis-preserving fade, cached sphere/torus scaling, resource identity, mixed capacity/FIFO overflow, clear/expiry, degenerate input and Doom/Quake/UT profiles. The older experimental prototype's geometry checks also passed after pinning its original allocation-heavy base implementation.

This is a production-path confirmation, not a new controlled A/B trial. The earlier [prototype comparison](../tracer-pool/README.md) separately recorded the instrumented before/after pair. No native-XR pacing or AI match speedup is asserted here. The process exited with code 0; post-result shutdown ObjectDB/resource cleanup warnings/errors are retained in `render.log`.

[Runtime design and main reuse](../../../../POOLED-WEAPON-FX.md) · [Result](result.json) · [Pool](pool.json) · [Checks](checks.json) · [Stereo capture](preview.png)

```bash
godot --xr-mode off --headless --path . --script deathmatch/tests/pooled_weapon_fx.gd
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/runtime_pooled_match.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/runtime-pooled-fx
```

Requires the existing local ranger manifest and original source files; avatar binaries are not redistributed. Main's adaptation patch was checked against its inspected visuals file without applying changes to that checkout.
