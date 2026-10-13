# UT99 avatars: animated shooting stereo tests and real XR preview

These shooting receipts predate the accepted constrained head/neck/arm solver and the five additional stock base models. They do not measure the current solver. See [current skin and IK validation](../ut99-skins/README.md).

All shooting runs used Arc A770, Godot 4.7.2 Mobile Vulkan, two independent 2160×2376 eye viewports, 90° FOV, 64 mm IPD, seed 1977, stationary fighters, alternating original idle/walk/run animations, production CS shots/reloads/collision/pooled impact effects, and no AI or navigation polygons. All seven World Leaders skins were assigned cyclically. Synthetic validated headset/controller poses drove weapon aim and vertex arm deformation. Terrain streaming was settled for every measured frame. Screenshot capture happened after measurement. These are desktop stereo passes, without native headset pacing or WiVRn encoding.

| Run | Wall duration | Frame median / p95 ms | Combined eye GPU median ms | Physics per tick median ms | Arm updates per rendered frame median ms |
| --- | --- | --- | --- | --- | --- |
| Previous 32 ranger VRM, prepass, springs off, pooled FX | 120 s | 16.338 / 27.604 | 2.676 | 3.536 | unmeasured |
| UT99 32, controller arms on | 120 s | 9.536 / 19.966 | 2.003 | 4.939 | 0.262 |
| UT99 32, deformation off control | 30 s | 4.527 / 19.302 | 2.281 | 4.919 | 0.030 |
| UT99 64, controller arms on | 120 s | 121.234 / 140.979 | 4.273 | 9.554 | 0.517 |

The previous ranger baseline is [runtime-pool/result.json](../voxel-battle/ranger-no-ai-shoot/runtime-pool/result.json). It used the earlier map and a different avatar set. The 32-avatar UT99 median is 41.6% lower and combined GPU median 25.1% lower, but this is a workload comparison, not a controlled causal measurement of avatar format. The earlier MDL stereo receipt measured animation without production shooting/physics and is not equivalent.

The arm on/off control directly measures about 0.232 ms additional arm update CPU time for 32 models. Its shorter window and physics/render cadence shifted the frame median substantially; do not interpret the 5 ms median difference as deformation cost. Mean wall interval per rendered sample was about 8.65 ms on and 8.10 ms off.

The 64-avatar run sustained only 1,130 rendered samples in 120 seconds (~9.4 renders/s), with 6,618 physics ticks and 110.3 simulated seconds. Delta-derived frame timings are not identical to wall intervals when simulation falls behind. GPU median stayed 4.27 ms, arm updates 0.52 ms, while authoritative physics per tick nearly doubled. Multiple physics ticks per rendered frame and heavier shooting/physics work are consistent with CPU saturation; these counters do not isolate every engine subsystem. The 64-entry effects pool stayed bounded and valid but evicted 1,336 effects at capacity. This scale is not yet viable for smooth VR and needs further profiling/optimisation. Production server limits remain unchanged; the 64-slot arena is benchmark-only.

[checks.json](checks.json) independently verifies CSV sample counts, settled streaming, and reported medians. Each run folder includes its original result, compressed frame samples, stereo screenshots and log. Shutdown cleanup warnings appear after completed reports; measured runs did not contain script failures. Source fingerprints and snapshots retain provenance; live head deformation was added in a separate preview shader after these benchmarks.

## Historical live WiVRn-Pro head and arm preview

Run from this worktree:

```sh
godot --xr-mode on --rendering-method mobile --rendering-driver vulkan --path . tools/ut99_avatar/xr_preview.tscn
```

At the time of this capture, the native separate window contained all seven model choices, original animation clips, live tracking status and recentering. A headset panel mirrors that viewport. Headset position/orientation drives a preview-only vertex head mask; controllers drive the existing two-segment arm approximation. The remainder uses UT99 vertex animation, without skeleton/full body, facial, eye, or finger tracking. Recenter sets the current headset height to 1.65 m eye height and yaw to the model forward direction. No fabricated poses substitute for missing tracking.

OpenXR identifies WiVRn v26.9-pro1-cqp1 and Meta Quest Pro. The [window capture](xr-preview.png) shows head and both controllers live, with validated arm poses and changing headset samples. The later [tracking receipt](xr-preview-live.json) records 6,151 fully tracked frames before the controllers lost tracking; the headset remained tracked. [OpenXR startup log](xr-preview-startup.log) records the actual WiVRn runtime and controller grip poses. The current production-solver preview replaces that experimental head shader and includes the five base models. The app also updates `test-results/ut99/xr-preview-live.json` once per second. The angular/positional head mask and generic arm classification are prototypes: large controller reaches and some poses visibly pinch shoulders or deform adjacent geometry. This preview makes those limitations inspectable, rather than implying a fully rigged model.

[Detailed recorded 64-avatar frame-cost breakdown](shoot-64-arms/BREAKDOWN.md) includes per-tick versus per-render accounting, wall throughput, stale counters and limits on attribution.

[Current 120-second 64-avatar Forward+ category profile](shoot-64-forward-profile/README.md) measures the accepted constrained solver with shooting, no AI and actual wall-clock frame intervals.
