# Shared avatar LOD and animation

Gameplay VRM avatars enable the shared controller when attached by `Fighter.set_avatar`. The independent CQ desktop also enables it by default, with its existing `avatar_lod: false` profile switch for comparison. Picker previews retain their original animation. Dedicated servers never construct these visual rigs.

Mesh LOD generation uses one background job with a bounded queue and input budgets. Only simplified index buffers are installed: original vertices, normals, skin/morph arrays and MToon materials are preserved. Instances of a decoded VRM share generated mesh resources. Generated levels retain at least 15% of source indices and 16 triangles per surface. Oversized inputs retain their original meshes. The installer uses Godot 4.7's packed surface representation; engine upgrades must rerun the exact-array tests.

Desktop animation uses full IK nearby, 30 Hz IK at nominal 6–18 m, generic clips at 30 Hz beyond 18 m and 15 Hz beyond 45 m, with hysteresis and camera magnification accounted for. Generic locomotion is retargeted to each model and blended at transitions; head/arm aim remains per avatar. Distant face/hair simulation pauses and resumes on return. Scope zoom restores detail. LOD-enabled avatars remain visible beyond the former 65 m cutoff.

Local first-person bodies retain their original IK. XR cameras retain the previous remote-IK cadence and skip generic clip preparation/application; mesh LOD still applies. This avoids inadvertently promoting all distant XR bodies to full-rate IK during integration. Physical headset/per-eye tuning remains unvalidated. Death uses the existing death solver.

The controller's timing and mesh-selection changes are cosmetic. Hitboxes, damage, network authority and production player limits are unchanged. CQ-specific motion replication stays in the experimental branch. The shared implementation works with main's existing replicated avatar state and loadouts.

See [close-range animation proposals](AVATAR-ANIMATION-PERFORMANCE.md) for measured limitations and the next optimization priorities.

## Validation commands

```sh
godot --xr-mode off --path . --rendering-method mobile --rendering-driver vulkan --script tools/avatar_lod/test_runtime.gd -- /tmp/avatar-lod-runtime
godot --headless --xr-mode off --path . --script deathmatch/tests/local_body.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/vr_ik.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/avatar_stances.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/death_animation.gd
godot --xr-mode off --path . --rendering-method mobile --rendering-driver vulkan --script tools/avatar_lod/benchmark.gd -- /tmp/avatar-lod-dm6 32 qsrc_dm6
```
