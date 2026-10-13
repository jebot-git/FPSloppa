# VRM → Quake MDL batch experiment

Run from the FPSloppa voxelspace worktree. Requirements: Blender 4.5.3 LTS, Python 3 with NumPy and Pillow, and Godot 4.7.2. No Blender VRM addon is required: the GLB glTF body is imported and VRM humanoid metadata is read directly.

```bash
git show main:deathmatch/avatars/models/manifest.json > /tmp/main-vrm-manifest.json
blender --background --python tools/vrm_to_mdl/bake.py -- /path/to/main/vrm /tmp/mdl-baked /tmp/main-vrm-manifest.json
python tools/vrm_to_mdl/export.py /tmp/mdl-baked experimental-assets/mdl --normals /path/to/anorms.h --source-dir /path/to/main/vrm
godot --headless --path /path/to/MDLAvatarConverter/app --script /absolute/path/to/tools/vrm_to_mdl/validate.gd -- /absolute/path/to/experimental-assets/mdl
godot --xr-mode off --path . --script tools/vrm_to_mdl/preview.gd --resolution 1600x1000
```

`bake.py` skips existing NPZ intermediates; delete those files to regenerate after changing the baker. It exits through Blender's Python execution; inspect logs for tracebacks as Blender may return zero after a script failure. The writer requires exactly 11 intermediates and verifies source SHA-256 values against the input manifest.

Use the canonical 162 direction table from [id Software's WinQuake/anorms.h](https://github.com/id-Software/Quake/blob/master/WinQuake/anorms.h). That external source is GPL-2.0; it is not vendored here. Only normal indices are written to the generated assets. The binary layout follows [WinQuake/modelgen.h](https://github.com/id-Software/Quake/blob/master/WinQuake/modelgen.h).

See `experimental-assets/mdl/README.md` for palette requirements, animation mapping, licensing and limits. Preview is standalone and does not modify the production VRM loading path. Its vertex shader decodes the generated MDL positions into a GPU frame texture and interpolates looped pose samples. The captured nonlooping death clip is only a pose inspection; gameplay would need a clamped frame cursor.

## Live gallery

```bash
godot --xr-mode off --path . --script tools/vrm_to_mdl/preview.gd --resolution 1600x1000 -- --live
```

Select Idle, Walk, Run, Attack, Pain or Death. Restart resets the clip; Pause freezes it; speed can be 0.5×, 1× or 2×. One-shot clips stop on their last frame. The live clock updates shader uniforms only; avatar vertices are interpolated on the GPU. Add `--smoke` to exercise all six selector choices, save `live-preview.png`, and leave the gallery open.

## 32-avatar simulated stereo map scene

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/stereo.gd -- --seconds 60 --keep-open
```

Uses sample_d_darkness, sample_e/f/g and both hair samples, in an 8×4 formation at the same seeded clear terrain point as the earlier VRM test. Every avatar uses a separate animation phase, with idle/walk/run distributed across the crowd. Two shared-world, parallel perspective cameras render at 2160×2376 each, with 64 mm eye separation and 90° FOV. It reuses the map's terrain, scenery, LOD, streaming and culling. This uses two desktop viewport passes rather than native OpenXR multiview; no XR frame pacing, AI, tracking or skeletons are attached. The 60-second interval starts after terrain and shader warmup. Eye readbacks happen afterward. Results are saved under `test-results/mdl-stereo/`; `--keep-open` retains the animated scene and the stereo display.

## Matched 16v16 comparison

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/match_compare.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/avatar-match-compare/vrm
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/match_compare.gd -- --representation mdl --simulate --seconds 120 --output res://test-results/avatar-match-compare/mdl
```

Run sequentially. The harness uses the same six accepted source avatars, verifies source hashes, and assigns the same model to the same bot ID and team. Both use 16v16 TDM, CS weapons, jetpacks, seed 1977, terrain, navmesh, physics and rendering. The comparison uses uncapped desktop simulated stereo at 2160×2376 per eye, 64 mm separation, and the same fixed 90° overview camera with observer input locked; no native XR runtime. VRM preparation is enabled and springs are disabled. Production VRM distance animation/mesh LOD policies remain enabled. MDL uses the experimental fighter-compatible `match_rig.gd`, with GPU-baked locomotion, fire, pain and death clips, approximate crouch height and matching CS weapon meshes. Neither asset representation affects combat collision.

Measurement begins after model preparation, navigation bake, terrain streaming and pending avatar mesh LOD tasks. Score limit is raised so it cannot truncate the 120-second interval. The wall-clock deadline is also enforced if the game cannot simulate 120 seconds in real time; both wall and simulated durations are recorded. Frame/GPU/renderer CPU timing, bot tick time, authoritative physics time, combat events and scores are saved. Two stereo viewport GPU/renderer CPU times are summed; desktop UI rendering is excluded from those two counters. Wall-frame timing includes all work. One match each is a paired scenario, not a deterministic replay or repeated-trial statistical study; inspect recorded combat divergence.

## Campaign military ranger VRM test

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/ranger_match.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/ranger-match/run
```

`ranger_match.gd` uses the same locked-camera 16v16 benchmark and reads three local source records from `test-results/ranger-match/input-models.json`. That manifest is retained with the validation receipt; source VRM binaries are not copied or redistributed. For this session Ranger Q is installed in the main campaign checkout, while the two Ranger 2022 source variants are read directly from their existing local Trash paths. Every source hash is checked before importing. The 32 bot IDs rotate through the three models (11/11/10), preserving CS TDM, jetpacks, prepass, spring-off and simulated stereo settings.

## 32 ranger VRMs: animation and shooting without AI

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/no_ai_shoot.gd -- --representation vrm --simulate --seconds 120 --output res://test-results/ranger-no-ai-shoot
```

Uses the same three ranger sources and simulated stereo settings, but a close 8×4 crowd at the earlier seeded clear location. All avatars alternate idle/walk/run every four seconds, staggered per actor, while firing real CS weapons at seeded random yaw/pitch. Locomotion is in place: visual velocities animate the rig while collision bodies stay still. Normal traces, recoil, hit effects, reloads, snapshots, collision and map streaming remain active. HP is replenished to maintain all 32 avatars. Reserve ammo is large; magazine reloads remain normal. The lifecycle-only actor-slot node performs no AI and creates no navmesh; it does not instantiate the original bot controller. Prepass is on, springs off; the camera/input are locked. This is not the same viewpoint as the distant live match, so subtraction from its frametimes is not an isolated AI-cost measurement. `no-ai.json` records firing counts, reloads, visibility, animation observations and the zero AI/nav counters.

## Weapon impact diagnostic

`profile_impacts.gd` runs the same no-AI crowd with nested impact timers. Use `--seconds 60 --output res://test-results/ranger-impact-final` and the same Vulkan/simulated-stereo launch options as above. It separates tracer construction, material assignment, lighting, particle enqueue, surface rays and audio, and records later effect updates. Diagnostic copies preserve the original effect logic; this does not optimize production effects. Inclusive parent/child scopes must not be summed.

## Pooled straight-tracer experiment

Run `profile_pooled_impacts.gd` with the same options as `profile_impacts.gd` for a sequential A/B comparison. It preallocates 64 persistent crossed-ribbon tracers before measurement, with a shared unit mesh and individual materials; firing reuses transforms/colors/visibility and lifetime. Production visual code remains unchanged. `pool.json` verifies capacity, emissions, fallback/eviction counts and preparation cost. `test_tracer_pool.gd` checks transformed geometry against the original plus fade, expiry, capacity reuse and multi-point fallback. Validation receipts are under `docs/validation/voxel-battle/ranger-no-ai-shoot/tracer-pool/`.

## Integrated runtime pooled FX

The production visual path now uses a shared 64-slot pool for all effect shapes. `runtime_pooled_match.gd` exercises it without diagnostic visual/arena overrides; use the same 120-second no-AI launch settings and `--output res://test-results/runtime-pooled-fx`. Historical allocation-heavy diagnostic baselines are pinned to `profile/legacy_visuals.gd`. Runtime design and main-branch adaptation instructions are in `docs/POOLED-WEAPON-FX.md`; portable checks are in `deathmatch/tests/pooled_weapon_fx.gd`.
