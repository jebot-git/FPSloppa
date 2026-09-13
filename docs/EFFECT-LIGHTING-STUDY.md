# Weapon and explosion lighting: feasibility study

**Decision (September 13, 2026): do not implement.** The subsequent prototype was withdrawn and its game-code changes removed. This document retains the historical feasibility findings, not an active implementation plan.

Examined September 13, 2026. **A small, shared pool of unshadowed omni lights is the best first implementation to test.** The existing materials already respond to them. The important work is event coverage, selection and a combined budget with map lighting. This study adds a reproducible rendering probe; gameplay lighting and defaults are unchanged.

## Current behavior

- `deathmatch/arena.gd::_play_shot_fx` creates a new light for eligible **local** shots: energy 2.4, radius 2.7 m, lifetime 55 ms. It is attached at the viewmodel/VR muzzle and deleted with a timer. Remote actors animate firing but do not receive this light. The slot-number condition also does not consistently represent weapon types across profiles.
- `_projectile_end`, `_impacts`, and `deathmatch/experimental/visuals.gd` mostly create emissive meshes, streaks and particles. They do not add corresponding explosion/projectile lights. A brighter particle is not itself illumination of the nearby wall; Godot documents that material emission needs an appropriate indirect-lighting technique to affect other objects. [Godot lighting overview](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)
- `deathmatch/maps/baked_light.gdshader` supplies baked light through `EMISSION` and sets live-light `ALBEDO` to `base * 0.10`. It is a lit shader, so realtime lighting works, with deliberately restrained strength. Raising all light energies is likely to affect avatars more strongly than walls.
- `deathmatch/avatars/lighting.gd` enables ordinary per-pixel lighting on StandardMaterial avatars and the arena policy on MToon. MToon's arena `light()` caps accumulated direct response at 0.55. This helps avoid washed-out models, but leaves less headroom in already-lit areas. Do not remove that cap globally merely to strengthen flashes.
- MapRuntime selects up to **eight** nearby map lights on PC or **four** on Android at 5 Hz. Effect lights currently sit outside that budget. Some static surfaces are batched across broad map areas, which increases the number of light volumes potentially touching one mesh.

Godot Mobile supports **eight omni lights per mesh**, separately from its spot-light limit. Exceeding the limit can cause visible lights to disappear or pop. An effect pool added on top of the current eight map lights would therefore be unsafe even if its GPU timings looked inexpensive. [Godot light limits](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)

## Measured feasibility

The new [probe](../tools/effect_lighting/README.md) rendered a controlled room with the actual baked-map shader and eight shipped VRM instances: samples D, F and G. It uses sustained lights so the cost is not diluted by frames between flashes. This is a material/overlap experiment, not a map or match benchmark.

Hardware/software: Intel Arc A770, Linux, Godot 4.7.2 Fedora build, Vulkan Mobile, 1280×800, 4× MSAA, one view, no shadows. Three blocks reverse variant order, with baselines at both ends; **5,400 measured frames**. Values below are medians of block medians.

| Background lights | Effect lights | GPU render time | Increase over matching baseline | Draw calls |
| --- | --- | --- | --- | --- |
| 0 | 0 | 0.423 ms | — | 28 |
| 0 | 2 | 0.590 ms | 0.167 ms | 28 |
| 0 | 4 | 0.724 ms | 0.301 ms | 28 |
| 0 | 8 | 1.036 ms | 0.613 ms | 28 |
| 4 | 0 | 0.743 ms | — | 28 |
| 4 | 2 | 0.890 ms | 0.147 ms | 28 |
| 4 | 4 | 1.033 ms | 0.290 ms | 28 |

An additional 4-background + 8-effect case measured 1.047 ms, but exceeds the per-mesh limit. Its small increase over eight total lights must **not** be interpreted as twelve lights being almost free. The engine may omit contributions.

Screenshots show warm/cool changes on avatars and the surrounding surfaces using unchanged production shaders: [baseline](../test-results/effect-lighting/dim-0.png), [four lights](../test-results/effect-lighting/dim-4.png), [four lights with background lighting](../test-results/effect-lighting/lit-4.png). Surface response is subtle, consistent with the 0.10 live-light multiplier. Draw counts stayed equal, but pixel lighting still increased GPU work.

The first dim baseline was unusually slow at 1.177 ms; all five later dim baselines were 0.422–0.423 ms. The aggregate median includes the first sample; raw per-frame data and block p95 values are retained in the [receipt](validation/effect-lighting-study.json). These small desktop deltas do not establish a Quest/Pico cost, stereo cost or thermal/frame-budget guarantee. Models were static and occupied a modest fraction of the view; close-up hair, particles and large BSP batches can cost more.

## Implementation choices

| Approach | Environment and player response | Cost / limitations | Assessment |
| --- | --- | --- | --- |
| Pooled unshadowed omni lights | Existing baked, PBR and MToon shaders all respond | Extra per-pixel lighting; finite per-mesh budget; light can cross walls | Recommended first step |
| One shadowed explosion light | Adds actual occlusion around walls and characters | Additional shadow rendering; moving players invalidate useful cached work | Optional PC experiment after the unshadowed version |
| Emissive particles / glow | Makes the effect itself brighter | Does not provide the required surface response by itself | Keep as the visible effect, paired with a light |
| Emissive decals / projected patches | Can fake a flash on selected nearby surfaces | Projection/masking and extra work; awkward on moving avatars and around corners | Possible impact accent, not the general solution |
| Custom bounded flash array in shaders | Can add independent flash response beyond the static-light budget | Requires integration into baked, MToon, ordinary PBR/import and transparent paths; manual culling/occlusion; shader arithmetic can run over large surfaces | Fallback if profiling proves engine lights unsuitable |
| Per-vertex light approximation | Can be cheap on suitable geometry | Coarse BSP polygons miss localized flashes; cannot assume existing custom MToon `light()` behavior survives vertex shading | Poor default for these maps |
| Dynamic GI / screen-space indirect lighting | Broader indirect response | Mobile does not support VoxelGI, SDFGI or SSIL | Unsuitable for the supported baseline renderer |

The engine documentation confirms the Mobile GI restrictions and its support for decals/glow. Custom shader light functions execute per light per pixel; vertex-lighting modes bypass them. These facts inform the alternatives above; relative performance beyond the measured omni-light cases remains an engineering estimate. [Renderer feature table](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), [Spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)

## Proposed first implementation

1. Add a client-only effect-light manager alongside `deathmatch/effects/combat.gd`. Preallocate a bounded set of lights; reuse entries and update fade envelopes centrally. Allocation must never scale with shotgun pellets, particles, or every segment of a beam. Disable hidden/expired slots completely. Headless servers allocate none.
2. Share selection with MapRuntime. Trial **two effect slots** first, within a combined maximum of eight active omni lights on PC and four on Android. Four effect slots can be a PC quality candidate. Reserving slots reduces background-light capacity, so compare each map before choosing permanent reservation versus replacing low-priority map lights. Preserve baked lighting and evaluate imported unbaked maps separately. Neither fading nor preemption may temporarily exceed the hard active budget.
3. Prioritize nearby explosions, local muzzle flashes, nearby remote muzzle flashes, then travelling energy projectiles. Keep incumbents briefly to avoid slot chatter. Merge nearby overlapping blasts into one bounded pulse rather than summing unlimited energy. Use a light volume's possible screen influence, not just whether its origin is on screen: a light behind the camera can illuminate a visible wall.
4. Process shot/explosion events immediately. The existing 5 Hz map-light cadence is too slow for a 55 ms flash. Fade active effects every rendered frame; rescore longer-lived projectile candidates at a lower rate. Start with roughly 2–3 m / 55–80 ms for muzzles and 6–8 m / 180–280 ms for ordinary explosions. These are candidate tuning values, not validated gameplay defaults. Travelling projectile lights should be optional and lower priority on standalone VR.
5. Set shadows off, specular contribution to zero, bake mode disabled, and no indirect-light contribution. Use engine distance fade and a short range. Cull masks can exclude unnecessary visual layers, but actual layer assignments must first distinguish map, avatar, viewmodel and effect meshes. These settings reduce unwanted work/appearance; setting specular to zero is not a measured promise of a shader optimization. [Light3D properties](https://docs.godotengine.org/en/stable/classes/class_light3d.html)
6. Reuse existing cosmetic event paths: `_play_shot_fx` for local and remote muzzles after prediction/deduplication gates; `_projectile_end` for terminal effects before discarding relevant projectile metadata; `_variant_combo_fx` for shock combos; projectile presentation for selected moving lights. Classify by weapon profile/projectile kind, not numeric slot comparisons. Preserve replay behavior and clear the pool on map/session changes. No new gameplay RPC or authoritative damage change is needed for the initial design.
7. Begin with the current materials. If flashes are too weak on a particular surface, test a bounded map response separately from avatar energy. Simply increasing the map shader's albedo also increases sun and map-light response. A truly independent effect-only response needs an explicit shader signal; an OmniLight has no application-defined "this is an explosion" input in the existing material.

Unshadowed lights can leak through thin walls. Short ranges and conservative room/visibility rejection can reduce this, but a single camera ray is not a substitute for per-surface shadows and can wrongly reject a light illuminating a visible corner. Treat wall leakage as an explicit visual tradeoff. Do not add per-particle raycasts or full shadow maps to every light in an attempt to hide it.

## Acceptance work before enabling a default

Test all weapon profiles, both hands, remote fire, prediction deduplication, replay, sustained plasma/rocket traffic, overlapping explosions and map changes. Check that the pool stays within its shared cap, high-priority bursts are admitted immediately, expired lights disappear, and missing projectile metadata produces a sensible fallback.

Compare off/two/four effect lights in crowded actual BSP views, dark passages, doorway/wall impacts, water, and close-up MToon/PBR/transparent avatars. Keep map-light allocation identical when measuring incremental GPU cost; run the proposed shared-allocation policy as a separate visual comparison. Check both baked-lighting presets and unbaked imports. Measure GPU and CPU p95/p99, first-use stutter and native stereo frame times on the target headsets under match load and thermal soak.

The first implementation should expose a client graphics setting such as **Effect lighting: Off / Low / High**. The measured result supports prototyping Low with a small pool. It does not yet support promising negligible cost or changing the shipped standalone default.
