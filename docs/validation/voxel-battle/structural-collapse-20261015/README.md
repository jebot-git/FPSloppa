# Structural collapse — 2026-10-15

The earlier wall-only experiment left upper floors standing regardless of support loss. The revised destruction service enforces storey-level integrity and a persistent whole-building collapse state. [Rules and implementation](../../../CQ-DESTRUCTION.md).

- **28 integrity checks pass headless and in the graphical runtime:** a local breach remains stable; failure on an upper storey collapses only its building; floors/roof/ramp collision is removed; foundation remains; real standing-capsule support disappears; neighboring geometry and collision remain; near/far meshes agree; collapse animation is nonphysical, finite and idempotent; attached light lenses hide and restore; reset restores the structure; adjacent-side failure and exact 45% threshold boundaries are covered. Headless rendering does not retain MultiMesh transform buffers, so actual lens transform assertions are verified separately with Vulkan.
- **112 full authored-catalog checks pass:** all 36 buildings have bearing lanes on every storey and are initially stable; both rendered LODs have collapse masks; the observatory and canopy watchtower masks cover their full rooftop additions; unregistered tent shells remain intact. There are 3,693 eligible wall sections.
- **18 existing breach checks pass.** The original traversal fixture now initializes a real Fighter collider before testing movement; this fixes its previously incomplete capsule setup.
- **28 FPSAuthority/Jolt callback checks pass at 30/60 Hz:** native ordnance still invokes the common destruction path and preserves client barrage classification. C++ and native wire formats are unchanged in this revision; existing validated client/server libraries are reused.
- **Two real ENet clients pass:** the early client observes stability then collapse; the late joiner receives the already-collapsed building. Both verify removed upper collision, retained neighboring floors and restored collision after the server resets. Revision 3 is received by both. Game protocol increments to `frontier-26-structural-collapse` for the expanded destruction RPC.

Full-map probe: Godot 4.7.2, Jolt, Intel ADL-N integrated graphics, Vulkan Forward+, 1280 × 720. The existing local desktop fleet test was also open. No AI/players were simulated in the probe; these are not 64-player or VR performance claims.

| Operation | Time |
| --- | --- |
| Headless: apply the complete failed factory-storey support set and collapse | 0.595 ms |
| Included collider disable work: 115 original bodies | 0.297 ms |
| Graphical: apply support loss, admit animations and collapse | 21.287 ms |
| Included whole-building animation extraction and collision work | 14.448 ms |
| Graphical: replace affected site meshes | 10.467 ms |
| Intact settled frame wall time | mean 13.481 ms / p95 13.879 ms |
| Collapsed settled frame wall time | mean 15.137 ms / p95 26.624 ms |

The forced-storey probe removes an entire support set in one operation, exceeding an ordinary single impact's six-section limit. Client setup plus mesh work still causes roughly a 32 ms hitch. Intact/collapsed draw counts and triangle counts are not directly comparable as a speedup: a damaged site's solid far proxy is replaced by the detailed middle mesh, and residency/temporary animation changes the rendered population. Server collider membership and stair ramps are cached before play, avoiding a scan of the full scene during collapse. Render meshes retain the existing vertex bake channels. Static lighting/NVG lamp-source and navigation updates remain future work.

`intact.png`, `collapse.png` (mid-animation) and `collapsed.png` (persistent foundation) show the same factory view. The scope is deterministic, reactive whole-building removal; there are no rigid-body shards, physical load solving or cascading damage to neighboring buildings.

Reproduce:

```
Godot --headless --path . --xr-mode off --script deathmatch/tests/cq_structural_collapse.gd
Godot --path . --xr-mode off --script deathmatch/tests/cq_structural_collapse.gd
Godot --headless --path . --xr-mode off --script deathmatch/tests/cq_collapse_catalog.gd
Godot --headless --path . --xr-mode off --script tools/authority_core/destruction_functional.gd
Godot --path . --xr-mode off --script tools/voxel_battle/benchmark_destruction.gd -- --structural-collapse
Godot --headless --path . --xr-mode off --script tools/voxel_battle/benchmark_destruction.gd -- --structural-collapse
```

For the ENet probe, run `deathmatch/tests/cq_collapse_network.gd -- --role server`, then one client immediately and another with `-- --label late` after five seconds. All processes exit after verifying reset. No deployment or new capacity test was performed.
