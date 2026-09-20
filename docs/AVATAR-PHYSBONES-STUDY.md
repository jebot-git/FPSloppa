# PhysBones-style secondary motion for FPSloppa

## Finding

A similar internal system is feasible and worth prototyping. The useful changes are independent chain jobs, bounded collision work and fewer engine transform accesses. Merely changing spring equations or naming the system PhysBones is not evidence of a speedup. This investigation uses public documentation; it does not inspect or reproduce VRChat's solver implementation.

VRChat documents multithreaded PhysBones, independent component scheduling, angle/hinge limits as cheaper alternatives to collisions, and bounded collision volumes. It also warns that automatic conversion cannot perfectly preserve old dynamics. [Official PhysBones documentation](https://creators.vrchat.com/common-components/physbones/).

Its mobile limits include 64 affected transforms, 16 colliders and 64 collision checks per avatar. These are useful comparison points, not appropriate limits to copy blindly into this game. [Official performance ranks](https://creators.vrchat.com/avatars/avatar-performance-ranking-system/).

## Measured workload

The bundled VRMs currently contain:

| Model | Spring chains | Simulated joints | Runtime colliders | Potential joint/collider pairs per update |
|---|---:|---:|---:|---:|
| sample_d | 22 | 60 | 28 | 1,040 |
| sample_f | 27 | 79 | 28 | 1,202 |
| sample_g | 25 | 86 | 28 | 1,356 |

Collider counts include distinct reference frames. Potential pairs are the sum of each chain's joints multiplied by its collider list, before rejection. They are not collision hits. A 32-avatar crowd using these models has 38,222 potential pairs each update. Full-body/eye/face tracker ownership does not reduce hair or clothing work, so both requested tracking mixtures must budget for all 32 secondary simulations.

The initial nearby Vulkan test spent approximately 15.8 ms/frame in secondary motion versus 4.3 ms in body IK. The first GDScript transform-buffer experiment preserved poses but regressed secondary cost to approximately 19.6 ms/frame. It remains disabled; its code and microbenchmark allow a native implementation to be compared later. Script recursion, array access and transform bookkeeping outweighed the saved Skeleton3D work in this workload.

A conservative collision bound was more successful. A joint's tail remains inside its length sphere after every collision correction. If that sphere, including the joint radius, cannot intersect the collider's enclosing sphere, the narrow collision call can be skipped. Capsule bounds include both endpoints. Original VRM narrow collision behavior is retained for all candidates; no authored collider is removed.

The headless microbenchmark's later comparison measured legacy → simplified spring steps at 479 → 240 µs (sample_d), 536 → 277 µs (sample_f), and 608 → 281 µs (sample_g), approximately halving this isolated cost. Conservative bounds alone measured 354, 433 and 492 µs respectively. These are per-avatar spring steps, not whole-frame FPS. See `tools/avatar_lod/benchmark_secondary.gd` and `validation/avatar-animation-secondary-micro.json`.

## Approximation prototype

Following approval to trade physical accuracy for cost, the runtime can collapse adjacent cosmetic segments in pairs. A skipped joint follows its animated parent instead of receiving a separate spring solve; the retained joint targets the longer rest-space span. Only real, unbranched ancestor paths collapse. Chains that contain humanoid body/eye/finger names keep their original simulation structure. Original imported resources and skeleton topology are not edited.

Simplified chains keep their four nearest collider bounds, re-ranked approximately every 125 ms with staggered refresh phases. This is a deliberate quality approximation: an omitted or rapidly moving collider can allow temporary clipping, and hair bends less finely. Conservative rejection still applies to retained colliders. The prototype is reversible and currently enabled only for desktop remote presentation; initialized XR, first-person and previews retain authored chain detail.

The initial nearby 32-avatar prototype reduces resident simulated joints from 2,389 to 1,809 and potential collision pairs from 38,222 to 6,052. These counts include inactive far avatars when used on Q1DM6. The final benchmark additionally disables all spring simulation, without changing body IK/face/mesh LOD, to measure the upper bound of savings.

## Proposed internal replacement

Before writing a custom native extension, prototype Godot's built-in `SpringBoneSimulator3D`, which already provides native spring simulation and dedicated collision nodes. This is an implementation candidate, not a measured gain; VRM coefficient/center conversion, chain simplification, scaling and modifier order still require validation. [Official Godot API](https://docs.godotengine.org/en/4.6/classes/class_springbonesimulator3d.html).

1. Compile VRM springs on import into immutable arrays: parent indices, rest axes, lengths, coefficients, collider assignments and independent chain groups. Keep original VRM parameters and an explicit fallback for unsupported structures. Rebuild only when configuration changes.
2. Capture animated parent poses and collider transforms on the main thread. A native Rust/C++ kernel receives value buffers; workers never touch scene nodes. Godot documents that active scene-tree access is not thread-safe. [Godot threading documentation](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html).
3. Batch multiple chains per job, and independent avatars across jobs; chains sharing animated ancestors or affected colliders require dependency ordering. Use a bounded pool, generation IDs and double buffers, discarding results for unloaded/teleported avatars. Apply final local rotations on the main thread once per skeleton callback. Avoid a task or a cross-language call for every bone.
4. Retain the existing spring integrator initially so that threading/packing gains can be measured independently of visual changes. Add cone/hinge constraints only through explicit configuration or a validated conversion. VRM spring metadata alone does not encode a safe cone that can replace all authored head/body colliders. Blanket collider removal would cause clipping.
5. Keep collision local to each avatar. Cross-avatar grabbing, global contacts, stretch/squish and network replication of cosmetic physics are outside this optimization. Use conservative broad-phase rejection and a configurable complexity budget with visible quality fallbacks, not arbitrary truncation of a chain.
6. Preserve tracked head/hands/body at their current cadence. Bound and interpolate secondary motion separately. Test the 50:50 and rounded-up 70:30 mixtures, unique complex VRMs, Quest hardware, teleports, nonuniform scaling and moving reference frames before making a native backend the default.

A speedup for a native parallel replacement is plausible, not yet measured. Even eliminating secondary simulation entirely cannot eliminate rig, IK, face, skinning, rendering and gameplay costs. Use the full-frame results in `AVATAR-ANIMATION-PERFORMANCE.md` to set the next target; do not extrapolate VRChat performance claims into a promised FPS gain here.
