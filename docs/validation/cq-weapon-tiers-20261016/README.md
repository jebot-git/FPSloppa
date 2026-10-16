# CQ weapon tiers and authoring refresh — 2026-10-16

Implemented on `experimental/cq-voxelspace`. See [render gallery](gallery.png), [burst/scout detail](detail.png), [asset statistics](assets.json) and [test results](results.json).

The requested weapon sources now cover three primary tiers per class plus the two secondary pistols, repair tool and restored designator. The original carbine geometry remains. New tier data, unlock selection, 17-slot ownership/ammunition and CQ frame version 3 are wired through the native authority and client. The client/server protocol changes require matching builds.

Stationary shots have no spray or random bloom. Running adds deviation; supported grip reduces physical recoil. Native and client use shared authored muzzle/sight sockets. Burst rifle fires three-shot bursts with fixed 1.5x modeled optic; railgun has a bounded local 150m enemy tracking display. Initial weapon numbers are provisional balancing values.

All rebuilt weapon finishes use a gunmetal luminance palette with baked occlusion, one 1024px atlas and one material. Budget is 5,000 triangles normally and 7,000 for complex models, including reload pieces; the burst rifle is 6,801 and scout pistol 6,716 triangles. Complex source meshes bypass planar dissolve, and local aperture clipping preserves disconnected source islands. Missing source materials, backend-specific Blender material outputs and slide material inheritance were corrected during visual review.

Magazine centres and extraction axes now follow individual source layouts, including bullpup receivers, SMG stock/guard/handguard, diagonal insertion, handle-fed pistols, side-mounted Massacre pack and bottom minigun box. The scout magazine is separated from its authored lower grip surfaces. The beam rifle retains its source power cell and sampled FBX receiver/grip animation. Charging-handle/magazine overlap resolves to the nearer physical control. Native tests cover extraction/reinsertion with both handednesses and model-specific axes.

Validation: 267,204 native checks, including a 64-player/3,600-tick replay; 125 Godot tier/asset/animation/protocol checks; pinned source hashes and GLB budgets; Linux client, Linux server and Windows native builds; Vulkan visual captures. No headset playtest, Windows runtime playtest, release packaging or deployment was performed. Final alignment, eye relief, magazine reach and thermal display readability still require an in-headset review.

Rebuild instructions and source provenance: [asset notes](../../../tools/cq_assets/SOURCES.md), [new source pins](../../../tools/cq_assets/tier_sources.json).
