# CQ reactive destruction and ordnance

Building destruction uses bounded wall breaches and deterministic structural integrity. Local damage creates entries while enough bearing support remains. Once a storey becomes unstable, its entire building collapses through a short reactive animation, with matching persistent geometry and collision removal. Destruction remains **opt-in** because changing a large site's batched mesh still causes a client hitch during concentrated bombardment.

Launch the server or an offline host with `--cq-destruction` after Godot's `--` separator. Clients receive the server setting automatically. For example:

```
Godot --path . --xr-mode off tools/voxel_battle/class_arena.tscn -- --cq-destruction
```

Host a local match, use the technician launcher or a vehicle, and hit an exterior wall. Eligible thin wall primitives are partitioned into sections at most 2.8 m wide. Ordnance with at least 60 base damage can remove up to six nearby visible sections per impact; the structural radius is local (0.75–4.5 m), independently of the wider player-damage radius. Subsequent shots can exploit the new opening. The first blast checks damage visibility before changing the wall, preserving cover for that impact.

The authored catalog has 36 buildings with 3,693 eligible sections. Scenery without a building/support definition, including the separate tents, remains intact. Every breach and collapsed-building ID persists until round/map reset. The breach cap remains 256 sections per round; collapsing a building removes its remaining structure without charging each remaining wall against that cap. There is no wall repair or damage accumulation in this experiment.

`structural_integrity.gd` derives bearing lanes on each storey from full-height exterior piers and the piers between windows. The base, pier and header pieces along a lane must remain intact for its bearing width to count. Authored door/window voids never count as columns. Each storey is checked independently, including upper storeys. The complete building collapses when either:

- Any storey retains **less than 45%** of its original bearing width (over 55% lost).
- Two adjacent perimeter sides of a storey each retain **less than 20%** (over 80% lost on each side).

Exactly 45% remaining is stable. These are tunable gameplay thresholds, not an engineering load simulation. A small hole can leave a stable building standing; widespread support removal cannot leave an intact roof and upper floors hanging forever.

Collapse disables all upper-floor, wall, contents and substituted stair-ramp collision immediately, preserving the ground foundation. A standing player loses floor support and falls through normal character movement. The visible remaining building sinks and tilts over 1.4 seconds using a collision-free mesh animation, then disappears. Neighboring buildings keep their geometry and collision. Authored ownership includes the observatory dome/telescope, the watchtower platform/flag and attached entry/hanging fixtures. Emissive fixture lenses disappear and restore with reset; independent street fixtures remain.

At most four nearby whole-building collapse animations run at once. Animation admission or distance culling never suppresses authoritative collapse. Both existing clients and late joiners receive explicit collapsed-building IDs with the breach state; late joiners see the final foundation rather than replaying an old collapse. Round/map reset restores all original meshes, collision and fixture transforms.

The authority removes original wall collision and builds static colliders for the surviving sections; subsequent hits reuse those colliders. Clients replace affected triangle ranges in the baked meshes and keep all color/irradiance channels. Destroyed sites use the modified middle mesh for their distant silhouette, so a solid far proxy cannot fill the hole. Unchanged sites retain their usual LODs. The affected middle mesh is more expensive than the old solid silhouette at distance.

Fragments come from the shared original `wall_shards.tscn` fixture. Eight pieces per admitted section follow a short transform animation and disappear; they never create physics bodies. Admission is capped at two panels per rendered frame, with 96 live shard meshes maximum and a 120 m camera-distance limit in gameplay. Cosmetic admission limits do not reduce authoritative breaches. Other clients receive a reliable, bounded full set of section IDs and collapsed-building IDs with map epoch and revision; late joiners restore collision without replaying old breakup effects. Reset restores both mesh and collision. Script and native authorities use the same destruction service; the native engine invokes the host callback after resolving ordnance damage.

[VoronoiShatter](https://github.com/robertvaradan/voronoishatter) is suitable as an offline authoring option for more complex, closed meshes. Its documentation recommends pre-fracturing and explains its manifold/CSG requirements. An isolated Godot probe generated a wall slab in about 129 ms, which is too costly for a synchronous impact. Existing buildings are already described as solid box components; this first prototype uses an original deterministic 2D Voronoi slab bake plus an offline triangle lookup rather than adding a runtime plugin dependency. No upstream plugin code or meshes are included.

Regenerate the original shard fixture and wall lookup after changing their source geometry:

```
Godot --headless --path . --xr-mode off --script tools/voxel_battle/bake_wall_shards.gd
Godot --headless --path . --xr-mode off --script tools/voxel_battle/bake_destruction_topology.gd
```

The lookup records source hashes and is checked against local authoring sources. Existing lighting bakes remain valid because intact building geometry is unchanged. Newly exposed edges reuse nearby baked vertex irradiance; lighting, baked shadows and navigation are not recomputed. Players and LOS queries use the new collision, but existing bot navigation has no newly baked routes through the gaps. Baked illumination/shadows, the static NVG lamp-source index and navigation remain approximations of the intact map; they are not rebuilt when a building collapses. Jagged persistent hole borders, dynamic lighting/source updates and navigation updates are further work.

Ordnance rules apply by default, independently of the destruction flag:

| Type | Blast radius | Behavior |
| --- | --- | --- |
| Rocket-tank barrage | **30 m** (was 20 m) | First-impact detonation, 152 base splash, linear falloff to the edge |
| Airstrike bomb | **35 m** (was 18.75 m) | 300 base damage, linear falloff to the edge |
| Other launchers, tank/turret ordnance and HE grenades | Existing radii | Friendly fire enabled |

All ordnance damages allied infantry, vehicles and deployable turrets through the normal armor, cover, grenade-to-hull scaling, incapacity and death rules. Projectile/energy small arms retain team protection. Existing self-damage scaling remains. Native collateral kills decrement the kill count and award no XP or objective points, matching script-authority scoring. Impact-fused rocket-tank missiles retain their correct native client visuals and travel sounds without relying on the removed arming delay.

[Current integrity/collapse validation and screenshots](validation/voxel-battle/structural-collapse-20261015/README.md). The full-map headless probe measured 0.595 ms to apply an entire failed factory storey's support set and collapse the building; disabling its 115 original colliders took 0.297 ms within that operation. The desktop probe still had about 32 ms of combined collapse setup/mesh work, so the feature remains opt-in. These are focused probes without players or AI, not server-capacity claims. [Earlier wall-only measurements](validation/voxel-battle/destruction-20261015/README.md) are historical.
