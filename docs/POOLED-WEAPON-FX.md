# Pooled weapon effects

The voxelspace runtime now uses a bounded pool for weapon effect shapes in `deathmatch/experimental/visuals.gd`. Straight bullet tracers use one immutable crossed-ribbon mesh from `deathmatch/experimental/tracer_geometry.gd`. This replaces the successful profiling prototype with a normal runtime path, without any dependency on benchmark scripts or profiling timers.

## Runtime behavior

Each `WeaponEffects` instance prepares 64 reusable `MeshInstance3D` nodes and 64 individual materials. Material overrides and shadow settings are assigned once during preparation. Every slot also owns an `ImmediateMesh` for curved streaks. Rings and globes share cached torus/sphere meshes. Preparation is idempotent and happens in `_ready`; callers can invoke `prepare_shape_pool()` ahead of the first emission to move allocation into loading/warmup.

Straight tracers have twelve vertices: two crossed ribbons on a unit segment along positive local Z. A per-shot basis supplies direction, width and length; position supplies the start point. Both eyes see the same geometry and normal scene culling applies to the transformed mesh bounds. The fast path rejects empty, single-point, zero-width and coincident-endpoint streaks. It does not create a node, material or mesh per straight shot.

Curved beams rebuild their original world-space ribbon vertices into the acquired slot's reusable mesh. Mesh surfaces still change for these beams, but the node and material do not. Rings, globes and generic `shape()` calls use the same activation path. They preserve scale interpolation and linear alpha fading. Each material belongs to one slot, so fading one effect cannot fade other active effects.

All effect types share one active/free pool and one 64-shape limit. At capacity, `_acquire_shape()` reuses the oldest active slot. A new activation resets mesh (if necessary), transform, base basis, color, alpha, lifetime and scale endpoints. Expiry hides the node and returns the slot to the free list. `clear()` hides active shapes, empties particles and resets particle draw counts; it is safe to call repeatedly. Deleting `WeaponEffects` releases its child nodes and owned resources normally. Shape nodes returned by `shape()` are temporary leases: do not retain them after expiry, eviction or `clear()`.

The updater applies scale to the saved `base_basis`, rather than replacing `node.scale`. This preserves a tracer's direction, width and length while fading, and resets orientation correctly when the same slot later becomes a ring or globe. Pooled cosmetic nodes disable physics interpolation because their transforms are authored per effect, not integrated character motion.

Particle batches, illumination signals/recipes, sound, weapon hit detection, damage, collision, avatar updates, AI and map streaming are unchanged. Persistent nodes consume some idle memory in exchange for reduced allocation and material assignment during firing. This optimization addresses CPU effect creation; it does not promise fewer draw calls or cheaper GPU rendering.

## Integration and diagnostics

The existing `Arena._weapon_visuals()` loads `deathmatch/experimental/visuals.gd`; no arena or networking integration change is required. Its public `shape`, `streak`, `ring`, `globe`, `impacts`, `projectile`, `travel`, `burst` and `combo` call sites continue working. The optional final `base_basis` argument on `_activate_shape()` defaults to identity for ordinary shapes.

`shape_pool_report()` returns capacity, allocation count, active/free counts, activation and straight/curved tracer counters, eviction/peak counts and a slot uniqueness invariant. `reset_pool_stats()` resets only counters, retaining active effects and resources. These helpers do not read back the GPU or time runtime code.

```bash
godot --xr-mode off --headless --path . --script deathmatch/tests/pooled_weapon_fx.gd
```

The regression harness checks transformed straight/curved geometry, alpha fade, tracer basis preservation, cached primitive meshes, scale interpolation, node/material/mesh identity across reuse, mixed-effect capacity, FIFO eviction, clear/expiry, degenerate straight streaks and Doom/Quake/UT effect recipes and lighting signals. It passed 391 checks on the voxelspace branch.

A separate uninstrumented runtime test uses the actual production visuals through the normal arena factory, with 32 ranger VRMs, alternating animation and random CS fire, prepass enabled, springs disabled and no AI/navigation:

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/runtime_pooled_match.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/runtime-pooled-fx
```

This requires the local ranger input manifest and original avatar source paths. It prewarms the normal FX instance before timing and records `pool.json`, `no-ai.json`, frame samples and stereo images. It is simulated desktop stereo, not native XR frame pacing. The older profiling scripts retain `tools/vrm_to_mdl/profile/legacy_visuals.gd` as their frozen allocation-heavy baseline so historical comparisons remain reproducible after this integration.

[Prototype A/B receipt](validation/voxel-battle/ranger-no-ai-shoot/tracer-pool/README.md) records 80% less mean impact CPU per shot and 22% lower frame p95 in one instrumented pair. Those measurements describe the prototype comparison, not a guaranteed production/native-XR speedup. [Integrated runtime receipt](validation/voxel-battle/ranger-no-ai-shoot/runtime-pool/README.md) verifies the shipped runtime path separately.

## Reuse on main

The inspected main checkout already pools general effect nodes/materials and caches rings/globes. It also has newer soft smoke rendering, particle interpolation settings and muzzle/beam lighting logic. Replacing its entire visuals file with the voxelspace file would lose those differences.

`POOLED-WEAPON-FX-main.patch` adapts the pool and shared straight-mesh path to that main file while preserving its smoke setup and all `impacts`, projectile/travel/burst/combo logic. It adds the standalone geometry helper and portable regression harness. It was checked with `git apply --check` against the current main checkout; it has **not** been applied to main or merged. The patch targets the file content inspected during this work, so recheck it if main changes.

From the main checkout, with the voxelspace worktree still available:

```bash
git apply --check .worktrees/cq-voxelspace/docs/POOLED-WEAPON-FX-main.patch
git apply .worktrees/cq-voxelspace/docs/POOLED-WEAPON-FX-main.patch
godot --xr-mode off --headless --path . --script deathmatch/tests/pooled_weapon_fx.gd
```

For another checkout, copy the patch and use its actual path. No avatar, map, CS rules, bot, VRM, MDL or profiling files are required to port the runtime optimization.

If patch context has moved, port these changes manually:

1. Add `tracer_geometry.gd`, its preload, `straight_mesh` and pool counters.
2. Initialize the shared ribbon mesh and pool entries once; retain main's particle/smoke initialization.
3. Store `base_basis` on activation and use it for per-frame scaling. Keep the material override assigned only during preparation.
4. Use a transform of the shared mesh for two-point streaks and each slot's reusable dynamic mesh for curved streaks.
5. Preserve one shared FIFO capacity and main's effect clearing, smoke, illumination and weapon recipe code.
6. Run the portable regression harness and the branch's existing weapon/lighting checks. Benchmark its own workload before quoting a speedup.
