# Prebuilt collapse, rubble cover and occupant damage — 2026-10-15

Collapse now reuses compact baked meshes and preallocated scene nodes. Partial ground-floor cover, positional collapse audio, dust, occupant damage and complete offset lamp-post removal are integrated with the existing authority and reliable collapse state. This remains an opt-in experiment (`--cq-destruction`).

- All 36 authored buildings have a compact baked animation mesh in `wall_topology.res`. Existing baked vertex attributes and shared materials are retained. The resource grows from about 375 KB to 1.49 MB compressed. The cosmetic shell is the intact authored building; old breaches are not re-cut into the short-lived animation.
- Each building's animation node, rubble mesh and static collider are prepared at setup. Twelve eight-piece wall panels are instantiated and lighting-converted once, then recycled. The impact no longer scans the entire site to extract a building mesh or constructs/converts fragment nodes.
- Up to eight broad rubble clusters remain: **3.4 m wide × 2.6 m deep**, with **1.6 m** standing-cover wall sections and **1.25 m** crouched-cover piles above the slab. Including their 0.12 m foundation clearance, tops reach approximately 1.72 m and 1.37 m. Tilted broken slabs replace the earlier tiny pyramid-like placeholders. Conservative box collision encloses each cluster; this is reactive cover, not rigid-body rubble.
- Every raised visual/collider footprint remains outside a **4 m radius** around every capture center, leaving the 3 m capture circle plus 1 m approach clearance. Central aisles remain clear. The flush slab overlay has no new collision and sits below the capture ring.
- A 2.4-second pooled soft dust effect and 3.5-second positional masonry/rumble cue accompany live collapse. The cue remixes the existing CC0 Thimras cannon-impact and denalwa thunder edits; source credits and reproduction recipe remain with the audio. The effects bus and distance attenuation apply. Late joiners receive cover without replaying old effects.
- The native authority immediately gibs every living, nonstaging player whose authoritative origin is inside the building volume, including either team, downed/spawn-protected players and seated occupants. Seats are released before death. There is no revive window or kill/XP credit. Vehicle centers inside receive **100 damage once**, regardless of team. The script fallback applies the same gameplay rules. Clients cannot invoke collapse damage through a network RPC.
- Lamp-post ownership now covers the full offset base/post/arm/head whenever its mounting volume intersects a building. The catalog includes two such fixtures; their complete near/middle triangle ranges are covered. Emissive heads hide with the building; independent fixtures remain. This fixes the previous bounds-only clipping that left floating parts.
- Rubble uses a sky/sun/weather lighting approximation, with a flush exposed-slab overlay, because the intact static bake still has a roof shadow. The surrounding static shadow and NVG lamp-source/navigation indexes remain intact-map approximations.

## Performance

Measured on the **Intel N95**, Intel ADL-N graphics, Godot 4.7.2 Forward+, 1280 × 720, V-sync/frame cap disabled. The same full-map profiling fixture and two repetitions from the [CPU/GPU diagnosis](../collapse-profile-20261015/README.md) are used. It forcibly removes a factory storey's support set, exceeding an ordinary impact's six-section limit. There are no players/AI in the graphics probe; native damage is tested separately.

| Full-collapse metric | Previous runtime extraction | Prebuilt, with enlarged cover/dust/audio |
| --- | --- | --- |
| Calling-thread setup + mesh replacement, wall duration | 28.46–29.04 ms | **10.27–10.32 ms** |
| Included main-thread execution | 26.75–27.30 ms | **7.46–8.65 ms** |
| Maximum initial frame interval | 30.70–32.06 ms | **12.54–12.99 ms** |
| Maximum GPU rendering in initial 20 frames | 3.12–3.21 ms | **3.14–3.41 ms** |
| Subsequent destruction-service `_process` p95 | 0.120–0.129 ms | 0.156–0.170 ms |

Synchronous preparation falls by roughly **64%**. Direct animation admission is tens of microseconds; site-wide damaged near/middle mesh replacement remains the main cost. Preparation of the pooled nodes, rubble and synthetic-fallback assets adds about **47 ms before play**, excluding the earlier resource load, architecture and integrity setup. GPU timestamps can lag and exclude uploads; Linux calling-thread execution counters have coarse update granularity, so tiny animation calls can report zero execution delta. Raw frame samples and event timings are retained in `frames-720.csv` and `profile.json`.

For the **i7-12700**, the same explicitly assumed 1.5–3× effective calling-thread improvement gives roughly **3.4–6.9 ms** of preparation rather than the old 10–20 ms planning range. No i7 or target-GPU benchmark was performed. These are focused fixture results, not populated 60 Hz, simultaneous-collapse, VR or first-ever shader-cache guarantees. The separate screenshot benchmark uses V-sync and preceding bombardment; its numbers are not the direct before/after comparison above.

## Verification

- **39 structural checks pass headless and graphically**, including prebuilt-node reuse, no new effect MeshInstance nodes at impact, real low/standing-height cover collision, overhead clearance, support failure, neighboring buildings, foundation/ramp behavior and reset.
- **187 catalog checks pass** across all 36 buildings: support lanes, both LOD masks, compact mesh triangle counts, nonempty cover, all capture clearances and whole post ownership.
- **42 real FPSAuthority/Jolt integration checks pass at 30/60 Hz**: inside player dies through spawn protection, the snapshot carries gibbed environmental death, the inside hull loses exactly 100 HP, outside entities survive, repeated collapse does not repeat damage.
- **915,888 native checks pass**, including the existing reference corpus and new downed/invulnerable/stress/seated collapse cases at both rates. Legacy collision-comparison diagnostics are retained in `checks.json`; they are not current test failures.
- **18 breach checks and 28 native ordnance-callback checks pass.** Both an early ENet client and a late joiner verify collapse, rubble activation, no client-side damage callback and reset restoration.
- A real audio-device mixer capture returns **4,096 samples, peak 0.240**, while dust is visible and the prepared animation mesh is active. Dummy audio yields no captured samples, so the audio assertion is run without `--audio-driver Dummy`. The 24 kHz mono PCM cue is finite, has peak 0.570, RMS 0.081 and negligible DC offset.
- Linux client and server native libraries were rebuilt; their source receipts match. Protocol is `frontier-27-collapse-cover`. No deployment was performed.

`rubble-close.png` shows the enlarged broken wall sections; `capture-clear.png` shows the dispatch capture circle surrounded by cover without an obstructing cluster. `collapse.png` and `collapsed.png` retain the factory overview. `render-results.json` and `server-results.json` are the separate full-map bombardment probe. `checks.json` contains test receipts.

Reproduce after rebuilding the native library:

```
Godot --headless --path . --xr-mode off --script tools/voxel_battle/bake_destruction_topology.gd
Godot --headless --path . --xr-mode off --script deathmatch/tests/cq_structural_collapse.gd
Godot --headless --path . --xr-mode off --script deathmatch/tests/cq_collapse_catalog.gd
Godot --headless --path . --xr-mode off --script deathmatch/tests/cq_collapse_damage.gd
Godot --path . --xr-mode off --script deathmatch/tests/cq_collapse_effects.gd
Godot --path . --xr-mode off --audio-driver Dummy --script tools/voxel_battle/profile_collapse.gd
Godot --path . --xr-mode off --audio-driver Dummy --script tools/voxel_battle/benchmark_destruction.gd -- --structural-collapse
```

For the existing ENet probe, start `cq_collapse_network.gd -- --role server`, then an early client and a client with `-- --label late` five seconds later. Map/round reset clears rubble and dust, stops the sound pool and restores the original collision, site meshes and fixture transforms.
