# CPU frametime and smoothness study — 2026-09-28

Implementation follow-up: [weapon caching, sliced clip preparation and remote interpolation](FRAME-SMOOTHNESS.md). The measurements below are the original pre-change study.

The strongest measured opportunity is eliminating repeated weapon-variant construction during play. Next are moving animation-clip baking out of visible frames and improving remote-avatar pose interpolation. VR avatar LOD offers a smaller steady CPU saving, but needs headset evaluation before changing its current conservative policy.

This is an investigation, with reproducible profiling tools and one repair to an outdated test helper. It does not implement the proposed gameplay optimizations. Full measurements are in [the receipt](validation/frametime-study-2026-09-28.json).

## 1. Cache complete weapon variants before gameplay

The native-renderer weapon factory probe measured every table slot in all four supported loadouts: first use in a fresh process, then two repeated passes. Models stayed alive for six process frames so deferred material warmup could finish. Times below are synchronous construction CPU milliseconds, median / maximum across slots:

| Loadout | First pass | Repeated passes |
| --- | ---: | ---: |
| doom | 25.90 / 72.32 | 0.08 / 13.91 |
| quake | 14.89 / 29.31 | 13.78 / 16.16 |
| ut99 | 13.66 / 29.54 | 13.76 / 14.49 |
| cs16 | 1.58 / 47.67 | 0.13 / 1.02 |

The repeated Quake/UT cost is larger than an entire 90 Hz frame budget (11.11 ms). Twelve follow-up probes on four representative weapons attributed 13.45–15.18 ms to `Art.variant_details()`, versus 0.02–0.03 ms to base scene instantiation and 0.06–0.08 ms to filtering. Variant decoration includes material tinting/duplication and added geometry; this experiment does not separate those individual operations. First-pass timings include process-local loading and preparation, not a cold OS filesystem cache. First-visible GPU pipeline compilation is excluded.

**Proposed change:** build immutable decorated meshes/materials or reusable visual templates once per loadout, slot and relevant visual settings during loading; equip by creating lightweight instances. Keep mutable action/reload state and per-instance materials independent. Existing `weapon_scenes` caches source scenes but the factory still decorates variants on each call. Warm the actual required arsenal before a match, with a bounded memory budget.

**Acceptance:** repeat construction comfortably below 1 ms on this machine, then verify weapon appearance, muzzle/sight metadata, filtering changes, independent reload states and remote/local weapon swaps. Measure actual equip-frame p99 as well as factory time. The 1 ms figure is a target, not an achieved speedup.

Sources: [weapon factory and decoration](../deathmatch/art.gd), [desktop weapon replacement](../deathmatch/arena.gd), [VR weapon replacement](../deathmatch/vr/rig.gd).

## 2. Move animation-clip preparation out of visible frames

Twenty-four direct clip bakes over three bundled avatars (140–167 bones) took a median **1.91 ms**, p95 **2.13 ms**, maximum **2.15 ms**. Each bake executes 21 procedural pose solves synchronously. Current code limits this to one bake per rendered frame, but that still consumes about 19% of an 11.11 ms budget before rendering or gameplay. Nearby avatars also warm clips, so preparation is not restricted to distant visible models.

**Proposed change:** persist common clips by avatar/content version, precompute common locomotion states during avatar preparation, and time-slice uncommon clip creation across frames with a small time budget. Preserve the previous valid animation until its replacement is ready. A worker implementation must operate on isolated data; the present baker mutates live rig/skeleton state and cannot simply be moved onto a thread.

**Acceptance:** first encounter with a new direction/stance produces no multi-millisecond bake spike; clip transitions preserve current blending, tracking and bone state.

Source: [clip cache and baker](../deathmatch/avatars/lod_clips.gd).

## 3. Interpolate remote poses between budgeted animation updates

Code inspection found remote IK caches that hold the same solved pose between 30 Hz or 15 Hz solves. Distant generic animation also seeks at 30/15 Hz. Moving a character root smoothly does not ensure its arms, feet and head move smoothly between those samples.

**Proposed change:** retain two cosmetic pose samples and interpolate at render rate, keeping expensive IK at its current cadence. Start with remote actors and explicit teleport/death/tracking reset handling. Keep local headset, controllers and held weapons on their existing current tracked-pose path. Evaluate the added remote-pose latency and avoid applying smoothing twice over the network interpolation.

Pickup bobbing is another smaller, direct candidate: rotation advances with render delta, but vertical bobbing reads the physics-updated `game.clock`. Give cosmetic bobbing a render-time phase while retaining simulation timing for gameplay and demo events.

**Acceptance:** recorded lateral motion, stairs, crouch, tracking and aim transitions at 72/90/120 Hz without stepped limbs or altered hitboxes. These are code-identified candidates; this study does not claim a measured perceptual improvement.

Sources: [pose solve cadence](../deathmatch/avatars/pose.gd), [generic animation sampling](../deathmatch/avatars/distance_lod.gd), [pickup bobbing](../deathmatch/arena.gd).

## 4. Extend remote-avatar budgeting carefully to VR

A rendered synthetic study used 16 avatars, three shared VRMs, eight full-body/face tracked and eight head/hands tracked, half speaking, with springs disabled. Scenarios ran in forward and reverse order, 360 measured frames per block after warmup:

| Scenario | Mean wall-frame ms, two blocks | p95 wall-frame ms | Measured rig + pose + eyes CPU ms/frame |
| --- | --- | --- | --- |
| Near, full detail | 7.91 / 7.63 | 8.96 / 8.65 | 2.82 / 2.58 |
| Distant desktop LOD | 5.31 / 5.59 | 6.32 / 6.90 | 0.67 / 0.71 |
| Distant synthetic XR policy | 6.20 / 6.10 | 7.67 / 7.58 | 1.41 / 1.39 |

The extra measured script work in distant XR policy is about **0.7 ms/frame** here. Wall-frame times include other work and scheduling; they are not total CPU timings. Morph timing is nested in eye timing and must not be added again. The synthetic XRCamera3D selects the XR policy but does not reproduce headset rendering, stereo projection or tracking latency.

XR currently opts out of generic distance LOD and protects avatars from the desktop offscreen sleep policy. **Proposed change:** first reduce remote facial update frequency by projected size and stagger updates. Then evaluate conservative remote-body LOD using headset-aware visibility, generous margins and hysteresis. Preserve local hands/body and readable opponent aiming. Per-eye visibility, mirrors, scopes and sudden head turns require live checks.

Sources: [animation budget](../deathmatch/avatars/rig.gd), [distance policy](../deathmatch/avatars/distance_lod.gd).

## 5. Keep projectile-heavy host simulation within budget

The existing server stress fixture continuously fires plasma, with bots disabled. Two runs per count, in reverse order, measured 240 ticks after 120 warmup ticks:

| Players | Peak live projectiles | Tick p50 ms | Tick p95 ms | Projectile helper mean ms/tick |
| --- | ---: | --- | --- | --- |
| 8 | 281 | 3.71 / 3.73 | 5.14 / 4.51 | 1.94 / 1.95 |
| 16 | 523 | 6.71 / 6.58 | 8.20 / 7.93 | 3.51 / 3.42 |

Projectile updates are the largest instrumented helper. Helpers include warmup; tick percentiles exclude it. These fixtures are not normal DE matches and omit rendering, bot decisions and real remote transport. Snapshot p95 was 0.69–0.74 ms at eight players and 1.12–1.17 ms at sixteen.

**Proposed change:** profile candidate generation, world sweeps and per-projectile dictionary/definition access before choosing the next optimization. Reuse tick-local data and improve broad-phase rejection where measurements justify it. Existing zero-rewind avoidance and projectile target broad phase already exist; they are not new opportunities. Preserve authoritative collision frequency, damage and ordering.

## Additional candidates needing measurement

- Cache CS model references and update cosmetic reload/suppressor state when it changes; the current render path finds model parts repeatedly.
- Update HUD text/status snapshots on relevant state changes or a modest cadence. Keep immediate hit indicators and tracked pointer motion responsive.
- Pool burst blood/audio resources where combat-frame profiles show allocation or preparation spikes. Surface marks and many particles already have batching and caps.
- Profile real Dust2/Train/Nuke sessions with bots, Steam Audio, remote joins and asset preparation. AI, audio and real map-specific work were not isolated here.

## Reproduction and limits

Run benchmarks sequentially, using separate temporary `XDG_DATA_HOME` directories and client config paths. Native runs require a display/GPU; server tests use a local ephemeral host.

```sh
godot --xr-mode off --path . --script tools/avatar_lod/frametime_study.gd
godot --xr-mode off --path . --script deathmatch/tests/weapon_construction_profile.gd
godot --headless --xr-mode off --path . --script deathmatch/tests/server_load_audit.gd -- 8 --profile --ticks 360 --client-config /tmp/fps-study.cfg
godot --headless --xr-mode off --path . --script deathmatch/tests/server_load_audit.gd -- 16 --profile --ticks 360 --client-config /tmp/fps-study.cfg
```

Godot 4.7.2, Vulkan Mobile, Intel i7-12700 / Arc A770. Avatar viewport: 1440×900, vsync off. Clocks and OS load were not controlled. No headset, standalone Android, thermal soak or live match was tested. Successful native probes reported an ObjectDB shutdown warning; server fixtures also reported five resources still in use at exit. The stale `_collect` override in the profiling helper was updated to match the production signature before collecting results.

Recommended implementation order: **weapon variants → clip preparation → remote pose interpolation → headset-validated avatar LOD**, followed by workload-specific simulation and UI/audio work. Judge changes by matched p95/p99 and worst equip/join frames, not average FPS alone.
