# 32 ranger VRMs: alternating animation and random fire without AI

Completed 120.023 seconds of wall measurement, advancing 119.95 simulated seconds, with 5,972 rendered frames. The same three ranger sources as the prior 16v16 run are assigned 11/11/10 across 32 avatars. Surface/index preparation is enabled and springs are disabled. Source hashes and assignments are included; original VRM binaries are not redistributed.

Two desktop Vulkan Mobile viewports render at 2160×2376 per eye, 64 mm eye separation, 90° FOV, on Intel Arc A770. This is simulated stereo with OpenXR disabled, without headset frame pacing. The fixed camera is at (37.42462,21.7,12.02122), viewing a close 8×4 formation. Terrain streaming, scenery, culling and production avatar LOD remain active. Measurement starts after terrain/model/shader warmup; image readback occurs afterward.

The original AI controller is never instantiated. A lifecycle stub performs no decisions, perception, planning, steering or navigation bake. Recorded AI calls, AI timing samples and navmesh polygons are all zero. Every avatar alternates idle/walk/run every four seconds, staggered across the formation. Locomotion is animated in place with stationary collision bodies. Each avatar picks seeded random yaw and pitch every 0.8–2 seconds and holds the actual CS fire input. Real traces, recoil, impacts, damage, collisions, snapshots and ordinary magazine reloads remain active. HP is replenished to preserve all 32 avatars and reserve ammunition is large.

| Measurement | Median | p95 | p99 |
| --- | ---: | ---: | ---: |
| Frame | 17.553 ms | 36.638 ms | 43.554 ms |
| Combined stereo GPU | 2.810 ms | 4.159 ms | 4.691 ms |
| Combined stereo renderer CPU | 0.898 ms | 1.365 ms | 1.594 ms |
| Authoritative physics per tick | 3.578 ms | 14.110 ms | 16.224 ms |

16,820 shots and 584 reloads occurred, with zero deaths. Every avatar exceeded its first magazine; the lowest per-avatar count was 76 for a sniper. Shots in successive 30-second simulation intervals were 4,288, 4,304, 4,044 and 4,184, confirming sustained fire. All 32 avatar centers remained within both eye frustums; rear avatars can occlude one another. All three animation states were observed. Median draws: 569; primitives: 1,116,820. 57.22% of frames exceeded 16.67 ms. Average throughput was 49.76 frames/s, distinct from the inverse of median frame time.

The previous live ranger AI match measured 108.95 ms median / 139.63 ms p95 frame time. This test uses a much closer camera, stationary avatars and different combat input, so it demonstrates the remaining no-AI workload but does not isolate an exact AI cost by subtraction. Physics timing is per tick, GPU/renderer timing is the sum of the two eye passes, and frame timing is wall time for the rendered frame; those values should not be added or subtracted as disjoint costs.

An initial run was excluded after validation found rifle reserve slot zero was empty: rifles stopped after their first magazine. Its local output remains under `test-results/ranger-no-ai-shoot-ammo-depleted/`. All results in this receipt come from the corrected full repeat. CSV counts and frame/GPU/renderer percentiles, 32 assignments, sustained shooting, zero AI/nav counters, prepass/spring flags, and distinct nonempty 2160×2376 eye images were checked. The engine exited with code 0. After results and captures were saved, shutdown emitted seven ObjectDB instance and three resource-in-use cleanup warnings/errors; they are retained in `render.log`.

[Result](result.json) · [Workload verification](no-ai.json) · [Frame samples](frames.csv) · [Checks](checks.json) · [Stereo capture](preview.png)

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/no_ai_shoot.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/ranger-no-ai-shoot
```

Requires the local ranger manifest under `test-results/ranger-match/input-models.json` and its original source paths. Exact measurement scripts and SHA-256 records accompany the receipt. The receipt verifier records this workstation's paths.

[Separate physics subsystem diagnosis](profile/README.md): movement/collision is the largest aggregate no-AI physics contributor, while shooting impact effects drive the larger bursts.

[Weapon impact breakdown](impacts/README.md): tracer material override assignment dominates impact creation CPU.

[Pooled tracer experiment](tracer-pool/README.md): a fresh two-minute pair cuts impact CPU cost by 80% and frame p95 by 22%.

[Integrated runtime verification](runtime-pool/README.md): production pooled FX, 391 regression checks and a two-minute no-AI run.
