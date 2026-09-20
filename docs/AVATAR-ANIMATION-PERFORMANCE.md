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

These are proposals. The branch integration includes the existing mesh/distance animation system and its compatibility safeguards; it does not claim to implement or benchmark these new close-range optimizations.
