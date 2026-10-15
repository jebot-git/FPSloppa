# Reactive building destruction experiment — 2026-10-15

Historical wall-only prototype. [The structural-integrity revision](../structural-collapse-20261015/README.md) adds building collapse and supersedes its structural limitations.

[Implementation, controls and limitations](../../../CQ-DESTRUCTION.md).

Verified on Godot 4.7.2 / Jolt. The graphical run used Vulkan Forward+, Intel ADL-N integrated graphics, 1280 × 720. These are short full-map rendering/collision probes without players or AI; another local desktop test was open. Frame wall times include rendering/presentation wait and are not isolated GPU timings or a 64-player/VR capacity claim.

| Probe | Result |
| --- | --- |
| Full map catalog | 3,769 wall sections from 1,446 thin wall primitives |
| Headless first breach | 0.390 ms |
| Headless twelve coalesced impacts | 2.330 ms, 24 sections destroyed |
| Graphical first impact, collision + animation setup | 6.273 ms |
| First site mesh rebuild | 8.676 ms |
| Twelve coalesced impacts, collision + animation setup | 10.598 ms |
| Coalesced site mesh rebuild | 20.127 ms |
| Settled intact frame wall time | mean 15.722 ms, p95 27.147 ms |
| Settled breached frame wall time | mean 13.488 ms, p95 14.123 ms |
| Settled draw calls | 5 intact, 6 breached |

The settled comparison is noisy and does not demonstrate a destruction speedup. The explicit update timings above expose the hitch omitted by the settled averages: about 15 ms for the first visible breach and 31 ms for twelve impacts together. Moving topology classification offline reduced the earlier coalesced mesh rebuild from about 64 ms to 20 ms; persistent colliders and animation admission limits reduced the cosmetic/collision burst from about 72 ms to 11 ms. This remains an opt-in prototype, with client mesh work still the main blocker to enabling it by default.

Validation:

- Native standalone authority: **915,862 checks pass**, including the existing 64-player deterministic replay and script-generated golden references. Added 30/60 Hz coverage for friendly ordnance/grenades, small-arm protection, collateral scoring, 30 m impact-fused rocket-tank projectiles, environmental callbacks and an allied airstrike target 25 m away.
- **28 end-to-end FPSAuthority/Jolt checks pass on each Linux client and dedicated-server library**, covering a rocket-tank impact before two seconds, actual collision opening, client snapshot projection and the impact-fused barrage classifier at both 30 and 60 Hz.
- **18 destruction fixture checks pass:** human-width section generation; opt-in gate; retained adjacent collision; matching visible/physical hole; float bake-channel alignment; far LOD; eight non-physical fragments; duplicate-state idempotence; damage threshold; actual 170 cm capsule traversal; repeated collision-body reuse; epoch/reset restoration; accumulating breaches without deleting floors.
- Two real ENet clients pass: an early client and a late joiner both receive revision 1, enabled state, broken section `[1]` and clear passage collision. They do not need the experiment launch flag.
- Existing script-authority airstrike suite: **54 checks pass**. Existing battery suite: **66 checks pass**. Deployable turret suite: **39 checks pass**, including allied ordnance damage and current 150 m target-range boundaries. These older arena fixtures retain their exit-time ObjectDB/resource cleanup warnings. Their expectations now cover friendly bombardment, extended airstrike radius and impact fuses; stale eight-vehicle expectations were updated to twelve, and the salvo assertion compares the frozen predicted footprint rather than requiring its coarse raycast ground intersection to equal the laser marker.
- Client/server native builds and source receipts pass. Editor import reports no script errors. No VPS deployment was performed.

VoronoiShatter source inspected at commit `cfce8cfbd492a6bd31b8cf5fdc66f7b8e8a71a6c`. A separate upstream-project probe with 16 samples on a 2.8 × 3.5 × 0.24 m BoxMesh produced 24 fragments in 129.448 ms using the headless renderer. The one-shot upstream probe also reported resource/ObjectDB cleanup warnings. This establishes an authoring option, not a gameplay-time fracture budget. The shipped original eight-fragment slab fixture baked in 2.248 ms; topology indexing baked separately in 1.284 seconds.
