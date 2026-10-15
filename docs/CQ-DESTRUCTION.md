# CQ reactive destruction and ordnance

Building destruction is feasible as a bounded wall-breach system. This prototype removes real collision and matching visual geometry, animates pre-baked fragments and synchronizes persistent openings. It deliberately keeps runtime CSG and rigid-body debris out of the gameplay path. Destruction remains **opt-in** because changing a large site's batched mesh still causes a client hitch during concentrated bombardment.

Launch the server or an offline host with `--cq-destruction` after Godot's `--` separator. Clients receive the server setting automatically. For example:

```
Godot --path . --xr-mode off tools/voxel_battle/class_arena.tscn -- --cq-destruction
```

Host a local match, use the technician launcher or a vehicle, and hit an exterior wall. Eligible thin wall primitives are partitioned into sections at most 2.8 m wide. Ordnance with at least 60 base damage can remove up to six nearby visible sections per impact; the structural radius is local (0.75–4.5 m), independently of the wider player-damage radius. Subsequent shots can exploit the new opening. The first blast checks damage visibility before changing the wall, preserving cover for that impact.

The map currently offers 3,769 sections across its named sites. Floors, roofs, stairs, terrain and load-bearing volumes remain intact. No collapse propagation, debris collision or dynamic building physics is attempted. Every opening persists until round/map reset. The cap is 256 destroyed sections per round. There is no health accumulation or repair of walls in this experiment.

The authority removes original wall collision and builds static colliders for the surviving sections; subsequent hits reuse those colliders. Clients replace affected triangle ranges in the baked meshes and keep all color/irradiance channels. Destroyed sites use the modified middle mesh for their distant silhouette, so a solid far proxy cannot fill the hole. Unchanged sites retain their usual LODs. The affected middle mesh is more expensive than the old solid silhouette at distance.

Fragments come from the shared original `wall_shards.tscn` fixture. Eight pieces per admitted section follow a short transform animation and disappear; they never create physics bodies. Admission is capped at two panels per rendered frame, with 96 live shard meshes maximum and a 120 m camera-distance limit in gameplay. Cosmetic admission limits do not reduce authoritative breaches. Other clients receive a reliable, bounded full set of section IDs with map epoch and revision; late joiners restore collision without replaying old breakup effects. Reset restores both mesh and collision. Script and native authorities use the same destruction service; the native engine invokes the host callback after resolving ordnance damage.

[VoronoiShatter](https://github.com/robertvaradan/voronoishatter) is suitable as an offline authoring option for more complex, closed meshes. Its documentation recommends pre-fracturing and explains its manifold/CSG requirements. An isolated Godot probe generated a wall slab in about 129 ms, which is too costly for a synchronous impact. Existing buildings are already described as solid box components; this first prototype uses an original deterministic 2D Voronoi slab bake plus an offline triangle lookup rather than adding a runtime plugin dependency. No upstream plugin code or meshes are included.

Regenerate the original shard fixture and wall lookup after changing their source geometry:

```
Godot --headless --path . --xr-mode off --script tools/voxel_battle/bake_wall_shards.gd
Godot --headless --path . --xr-mode off --script tools/voxel_battle/bake_destruction_topology.gd
```

The lookup records source hashes and is checked against local authoring sources. Existing lighting bakes remain valid because intact building geometry is unchanged. Newly exposed edges reuse nearby baked vertex irradiance; lighting, baked shadows and navigation are not recomputed. Players and LOS queries use the new collision, but existing bot navigation has no newly baked routes through the gaps. Jagged persistent hole borders, support-aware collapse, dynamically rebaked lighting and navigation updates are further work.

Ordnance rules apply by default, independently of the destruction flag:

| Type | Blast radius | Behavior |
| --- | --- | --- |
| Rocket-tank barrage | **30 m** (was 20 m) | First-impact detonation, 152 base splash, linear falloff to the edge |
| Airstrike bomb | **35 m** (was 18.75 m) | 300 base damage, linear falloff to the edge |
| Other launchers, tank/turret ordnance and HE grenades | Existing radii | Friendly fire enabled |

All ordnance damages allied infantry, vehicles and deployable turrets through the normal armor, cover, grenade-to-hull scaling, incapacity and death rules. Projectile/energy small arms retain team protection. Existing self-damage scaling remains. Native collateral kills decrement the kill count and award no XP or objective points, matching script-authority scoring. Impact-fused rocket-tank missiles retain their correct native client visuals and travel sounds without relying on the removed arming delay.

[Measurements, screenshots and validation](validation/voxel-battle/destruction-20261015/README.md). Headless collision work measured 0.39 ms for one breach and 2.33 ms for twelve coalesced impacts. Graphical mesh rebuilding remains the constraint: one first visible breach cost about 15 ms total setup/rebuild, and the twelve-impact burst about 31 ms. A worker-thread mesh build or offline damaged-state/chunk representation should be evaluated before making destruction a production default.
