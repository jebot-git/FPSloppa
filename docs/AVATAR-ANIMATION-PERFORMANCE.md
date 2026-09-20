# Reducing close-range avatar animation cost

The Q1DM6 measurement shows why more aggressive mesh LOD is insufficient for a dense nearby crowd. At 32 avatars, rendered primitives fell from 659,541 to about 209,798 (68%), but mean frame time stayed at 26.00 → 26.26 ms. The final distribution was one near/full-IK avatar, 29 medium/30 Hz IK avatars and two generic-animation avatars. Measured GPU time was only 1.44–1.59 ms. This suggests CPU-side animation/presentation is important, but does not identify IK as the sole cause.

In contrast, the all-distant 32-avatar test improved from 26.62 to 9.56 ms, combining generic animation, fewer primitives and suspended face/hair updates. Those savings cannot be attributed to one subsystem or promised at close range. Both are isolated rendering workloads using three shared VRMs, not full matches or 32 unique custom models.

Sources: [Q1DM6](validation/cq-avatar-lod-32-q1dm6.json), [all-distant crowd](validation/cq-avatar-lod-32-performance.json).

## Recommended work, in order

1. **Measure and eliminate redundant bone work.** Add opt-in timings around pose solving, cached-pose replay, spring bones, morph composition and skeleton updates. The current IK code rewrites cached bone positions/rotations on skipped solve frames, repeatedly reads rest transforms and writes each finger's rest rotation immediately before its curled rotation. Cache immutable bone indices/rest transforms and limb lengths, reuse pose buffers, remove overwritten intermediate writes, and batch the final pose. Dirty checks must account for Godot's modifier reset semantics: skipping a required pose restoration can break animation even when the cached value is unchanged. Keep close tracked head/hands responsive at render rate. This is the first optimization to prototype because it can preserve the existing appearance.

2. **Use shared locomotion with selective close-range IK.** Evaluate a retargeted base locomotion clip once per model/stance/direction and phase bucket, or use native animation blending. Add per-avatar pelvis/foot contact correction and head/weapon-hand IK afterward. Solve only feet in contact or transitioning into contact; invalidate cached floor samples on stairs, platforms, jumps and teleports. For fully tracked VR bodies, apply tracked limbs directly and retain required constraints instead of substituting generic gestures. This attacks duplicated work while keeping nearby silhouettes, weapon grips and foot placement. Different skeletons, phases and tracked poses must not share an incompatible final pose.

3. **Compose facial morphs once, and update changed values.** `eyes.apply_morphs()` builds nested dictionaries and writes the bound shapes each eye update; speaking can invoke the same mixer again from the mouth update. Precompute the mesh/shape binding table, combine gaze/blink/expression/viseme input once per frame, and avoid uploading unchanged weights. Cache rest eye transforms. Keep speech and measured blinks smooth; a lower sampling rate should interpolate and be tested on visible faces. Silence alone should not repeatedly rebuild an all-zero face.

4. **Budget secondary motion independently of body detail.** Keep the close body and hands fully detailed while scheduling hair/clothing springs at a bounded fixed rate with interpolation. Cache collider transforms and reduce repeated collision queries within each avatar. Start with 30–45 Hz as an experiment, not an established safe setting. Cap catch-up steps and reset after teleports to avoid explosive spring motion. First-person head/hand tracking must remain unaffected. Physical headset tests are required before changing Quest defaults.

5. **Stop cosmetic work for avatars that cannot contribute to the view.** Use conservative visibility bounds plus a grace period, retaining the last pose and current network/gameplay state. Suspend animation, face and springs for persistently hidden/off-screen avatars; warm the latest pose before they reappear. Include mirrors, spectator cameras, scopes and both XR eyes when deciding visibility. This helps nearby players behind walls, but cannot improve the worst case where every close avatar is visible.

If profiling still shows script dispatch and transform conversion dominating after these changes, move the measured pose kernel to a native extension using packed arrays. Native code should be a measured next step; a server rewrite would not reduce client-side animation cost.

## Validation and acceptance

Repeat the same Q1DM6 scene with 16 and 32 avatars, then add a genuinely near-only crowd, different VRMs, speech, hair, tracking, stairs and moving platforms. Toggle one subsystem at a time; record mean/p95/p99 CPU and wall-frame times, bone/morph write counts, initial-bake spikes and allocation counts. Keep geometry and scene conditions fixed. Diagnostic runs with hair or IK disabled can isolate cost but are not shippable visual settings.

Compare rendered poses, grips, facial expressions and transitions against the baseline, including scopes, death/respawn, first-person, mirrors and XR cameras. A reasonable desktop acceptance target is to bring the current 26 ms scene below a 16.7 ms frame budget, but that is a target, not an estimated or achieved gain. Device-specific VR budgets require measurements on the actual headset.

## Implemented close-range work (2026-09-20)

The shared runtime now caches rest rotations and eye frames, reuses pose storage, removes overwritten finger writes, and replays only the hip translation (all required bone rotations still restore on modifier frames). Tracked feet no longer cast redundant procedural floor rays. Movement invalidates cached contact heights. Face/eye/viseme bindings compile once into flat channels; the eye modifier composes them once per frame, uploading only changed weights. Runtime bind edits must call `rebuild_bindings()`.

Secondary motion uses conservative sphere/capsule bounds to reject impossible joint/collider pairs. A desktop approximation additionally collapses adjacent eligible cosmetic segments in pairs and retains four nearest colliders per chain, re-ranked every 125 ms with staggered refresh phases. Humanoid body/eye/finger chains are protected, and imported resources/skeleton topology stay unchanged. Skipped joints inherit their parent motion. This trades fine bending and collision accuracy for cost; rapid movement or an omitted collider may allow clipping. Full chains restore when approximation is disabled. Desktop remote cosmetics have a bounded 45 Hz interpolated scheduler, with one catch-up step maximum and resets on teleports, large orientation jumps, suspension and long stalls. Secondary cadence changes are disabled for first-person, preview and initialized XR contexts. The exact collision rejection and redundant-work removal still apply there.

Hidden/off-screen avatars skip body modifier, face and spring work after 0.5 seconds. Generous visibility bounds include extended arms and prone motion; secondary viewport cameras keep actors awake. XR bypasses screen culling. Wake-up takes the latest tracking sample and refreshes pose/floor state. Network state and gait continue updating while cosmetic work sleeps. This is visibility-based culling, not a new wall-occlusion system.

Shared near-range base locomotion is **not enabled**: tracked and head/hands-only bodies retain their existing individual IK and cadence. The profiling priority changed because hair/clothing dominated both mixes. Existing distant shared clips remain intact. The GDScript spring transform-buffer prototype matched poses but regressed frame time, so `buffered_animation` defaults off and allocates no buffer in gameplay. A native replacement is assessed in [the PhysBones study](AVATAR-PHYSBONES-STUDY.md).

## Mixed tracking results

32 rendered avatars, three shared VRMs, 1440×900 Vulkan Mobile on Intel Arc A770 / i7-12700, vsync off. Both phases retain identical mesh/distance LOD. Half the avatars speak independently of tracking ownership. The remainder use head-and-hand tracking, rather than cheaper desktop-only motion. 23/32 fully tracked avatars rounds the 70% case up to 71.875%.

| Scene | Fully tracked | Runtime | Mean | p95 | p99 |
|---|---:|---|---:|---:|---:|
| Nearby | 16/32 | Comparison baseline | 36.81 ms | 39.33 ms | 41.43 ms |
| Nearby | 16/32 | Optimized + simplified springs | 27.70 ms | 36.65 ms | 38.75 ms |
| Nearby | 16/32 | Optimized + springs disabled | 15.65 ms | 17.09 ms | 17.82 ms |
| Nearby | 23/32 | Comparison baseline | 38.15 ms | 40.94 ms | 42.38 ms |
| Nearby | 23/32 | Optimized + simplified springs | 28.45 ms | 37.46 ms | 39.97 ms |
| Nearby | 23/32 | Optimized + springs disabled | 15.96 ms | 17.14 ms | 19.14 ms |
| Q1DM6 | 16/32 | Comparison baseline | 29.51 ms | 32.91 ms | 34.60 ms |
| Q1DM6 | 16/32 | Optimized + simplified springs | 22.17 ms | 30.64 ms | 33.45 ms |
| Q1DM6 | 16/32 | Optimized + springs disabled | 11.67 ms | 14.73 ms | 16.34 ms |
| Q1DM6 | 23/32 | Comparison baseline | 29.65 ms | 32.99 ms | 35.66 ms |
| Q1DM6 | 23/32 | Optimized + simplified springs | 21.19 ms | 29.60 ms | 30.72 ms |
| Q1DM6 | 23/32 | Optimized + springs disabled | 11.59 ms | 14.85 ms | 15.91 ms |

The near case keeps all 32 at tier 0; no avatar slept. Q1DM6 uses 1 near, 26 medium and 5 generic avatars, with occasional edge-of-view cosmetic suspension. This FOV/workload differs from the older untracked Q1DM6 test above, so its absolute times must not be compared directly to that run. These are render-only synthetic fixtures, not 32 network clients, unique custom models or a headset session. Script metrics are nested (morph composition is included in eyes) and do not separately instrument engine skeleton/skinning work.

Near morph writes fell from 624/frame to about 42 at 50:50 and 54 at 70:30. Nearby simplification reduces resident simulated joints from 2,389 to 1,809 (24%) and potential collider pairs from 38,222 to 6,052 (84%). Far inactive residents retain full structures until their simulation wakes; Q1DM6 resident counts therefore differ.

The final optimization toggle improves mean frame times approximately 25% nearby and 25–28% in Q1DM6. The conservative-only earlier comparison improved means about 11–13%; its artifacts are retained separately. **Simplified springs still do not reach the 16.7 ms desktop target, and p95 remains high.** Approximate collider selection, script simulation and transform application remain candidates for native implementation.

The baseline includes the earlier face and pose paths; only the two optimized rows isolate turning spring physics off. Disabled runs confirm zero spring integration ticks and zero measured spring time. They preserve face/body settings, meshes and LOD, although medium-range 30 Hz IK naturally executes on a smaller fraction of frames when FPS increases. Disabling springs saves roughly another 10–12 ms/frame versus the simplified runtime. At 23/32 fully tracked, the no-spring mean is 15.96 ms nearby (p95 17.14 ms) and 11.59 ms in Q1DM6 (p99 15.91 ms). This is a diagnostic ceiling for savings, not a decision to remove secondary motion in gameplay or proof of headset performance. Synthetic tracking and three shared models do not establish headroom for arbitrary custom VRMs or a full live match.

Data: [near](validation/avatar-animation-mixed-near.json), [Q1DM6](validation/avatar-animation-mixed-dm6.json), [disabled buffer experiment](validation/avatar-animation-buffer-experiment.json), [spring microbenchmark](validation/avatar-animation-secondary-micro.json).

Reproduction:

```sh
godot --xr-mode off --path . --rendering-method mobile --rendering-driver vulkan --script tools/avatar_lod/benchmark_animation.gd -- /tmp/animation-near near
godot --xr-mode off --path . --rendering-method mobile --rendering-driver vulkan --script tools/avatar_lod/benchmark_animation.gd -- /tmp/animation-dm6 qsrc_dm6
godot --headless --xr-mode off --path . --script tools/avatar_lod/benchmark_secondary.gd
godot --xr-mode off --path . --rendering-method mobile --rendering-driver vulkan --script tools/avatar_lod/test_animation.gd
```

`rig.animation_optimized=false` exposes the comparison path; `animation_metrics.gd.enabled` turns on script timings. `rig.secondary_motion_enabled=false` disables all secondary integration for the comparison. These are runtime diagnostics. Profiling is off by default. Admission limits, gameplay simulation, networking, custom VRM acceptance and authored materials are unchanged. Shared near-range locomotion and a native spring backend remain unimplemented; the current changes preserve individual tracked IK.

## Final validation

Main and experimental each pass 1,245 animation/spring/morph/visibility checks and 1,082 existing mesh/LOD/scope/XR-guard checks under Vulkan. Headless IK, local-body, stance, death, facial-expression, eye/bot and tracking/audio fixtures pass on both. The tracking/audio test now treats absent visemes on custom VRMs as optional, while retaining full bundled-model assertions. See [validation results](validation/avatar-animation-validation.json).

Existing ObjectDB exit warnings remain (one in most fixtures, up to four in tracking/audio); these checks do not establish that the application is leak-free. Actual Quest/headset play, arbitrary custom-model visual quality, moving-platform contact and live-match timing remain unverified. The simplified collider refresh can still contribute to frame-time spikes; the native solver investigation should include that work, not just the integrator.
