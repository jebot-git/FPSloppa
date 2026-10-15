# CQ reactive destruction and ordnance

Building destruction uses bounded wall breaches and deterministic structural integrity. Local damage creates entries while enough bearing support remains. Once a storey becomes unstable, its entire building collapses through a short reactive animation, with matching persistent geometry and collision removal. Destruction remains **opt-in** while concentrated bombardment and simultaneous collapses are evaluated. Collapse meshes and fragments are prepared before play; damaged site meshes still rebuild at runtime.

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

Collapse disables all upper-floor, wall, contents and substituted stair-ramp collision immediately, preserving the ground foundation. Every live player inside the building volume takes immediate, armor/invulnerability-bypassing gibbing damage, including downed players and vehicle occupants, regardless of team. Vehicles whose centers are inside take 100 hull damage once. This runs through the native authority during its impact callback, with a script-authority fallback; clients never apply gameplay damage. There is no kill/XP credit for environmental collapse. The prebuilt building shell sinks and tilts over 1.4 seconds using collision-free animation, then disappears. It is a cosmetic intact-shell approximation; old wall breaches are not re-cut into this transient mesh. Neighboring buildings keep their geometry and collision. Authored ownership includes the observatory dome/telescope, the watchtower platform/flag and attached entry/hanging fixtures. Emissive fixture lenses disappear and restore with reset; independent street fixtures remain. Whole offset lamp posts whose mount volume intersects a building are explicitly owned, including their base, arm and head; clipping to only the room bounds had left parts floating.

Each collapse leaves up to eight deterministic ground-floor rubble clusters with static collision: 3.4 m wide by 2.6 m deep, with 1.6 m standing-cover wall sections and 1.25 m crouched-cover piles above the slab. The central passage stays clear. Every raised cluster's complete visual/collider footprint must remain at least **4 m** from every capture center (3 m capture radius plus 1 m clearance), so rubble cannot obstruct a capture circle. Rubble is prepared during map setup, replicated by collapsed-building ID and removed on reset. Rubble and a flush, noncolliding slab overlay use an exposed sky/sun/weather approximation because the old ground-lighting atlas still contains the intact roof shadow.

A pooled 2.4-second soft dust effect and a positional 3.5-second masonry-impact/rumble cue accompany live collapses. Late joiners receive persistent rubble without old sounds or dust. Audio uses the effects bus; cosmetic distance/voice limits never suppress damage or rubble.

At most four nearby whole-building collapse animations run at once. Animation admission or distance culling never suppresses authoritative collapse. Both existing clients and late joiners receive explicit collapsed-building IDs with the breach state; late joiners see the final foundation rather than replaying an old collapse. Round/map reset restores all original meshes, collision and fixture transforms.

The authority removes original wall collision and builds static colliders for the surviving sections; subsequent hits reuse those colliders. Clients replace affected triangle ranges in the baked meshes and keep all color/irradiance channels. Destroyed sites use the modified middle mesh for their distant silhouette, so a solid far proxy cannot fill the hole. Unchanged sites retain their usual LODs. The affected middle mesh is more expensive than the old solid silhouette at distance.

Fragments come from the shared original `wall_shards.tscn` fixture. Twelve panels of eight pieces are instantiated and lighting-converted before play, then recycled. Eight pieces per admitted section follow a short transform animation and become hidden; they never create physics bodies. Each building's compact baked animation mesh is loaded from `wall_topology.res`, with its node also created before play. No whole-site triangle classification or mesh construction occurs in `animate_collapse()`. Admission is capped at two panels per rendered frame, with 96 live shard meshes maximum and a 120 m camera-distance limit in gameplay. Cosmetic admission limits do not reduce authoritative breaches. Other clients receive a reliable, bounded full set of section IDs and collapsed-building IDs with map epoch and revision; late joiners restore collision without replaying old breakup effects. Reset restores both mesh and collision. Script and native authorities use the same destruction service; the native engine invokes the host callback after resolving ordnance damage.

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

[Prebuilt collapse, cover, damage and performance validation](validation/voxel-battle/prebuilt-collapse-20261015/README.md). The [earlier integrity experiment](validation/voxel-battle/structural-collapse-20261015/README.md) and [CPU/GPU diagnosis](validation/voxel-battle/collapse-profile-20261015/README.md) are historical baselines. These are focused probes, not server-capacity claims.
