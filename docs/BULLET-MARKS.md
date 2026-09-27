# Bullet impact marks

Hitscan guns now send static-surface normals alongside their existing impact
endpoints. Clients render small, surface-aligned chipped holes. Misses, player
hits, movers, breakables, melee attacks and energy beams do not leave gunshot
marks. Shotgun endpoints and normals share one effect RPC per shot.

The implementation uses a single `MultiMesh` with 128 reusable quad instances,
one shader/material, no shadows or GI, and no per-hole node, timer or texture.
Procedural shading avoids an additional texture fetch or mipmap asset. Physics
interpolation is disabled for this static cosmetic batch. It is not simulated
or included in late-join snapshots and is excluded from the console server pack.

Work and visibility limits:

- 32 pending impacts; four accepted candidates per frame, with at most sixteen
  short corner rays to reject ledges, holes, bends and moving surfaces.
- Nearby overlapping hits merge instead of stacking coplanar geometry.
- Marks shrink away from 25 to 30 seconds and fade at 25–40 metres; new distant
  impacts are skipped. The oldest instance is overwritten when the pool fills.
- Changing maps frees the batch. Replay files preserve normals; old impact
  recordings still play without new marks.

This avoids the Mobile renderer's eight projected-decals-per-mesh limit, which
is unsuitable for repeatedly shooting one large BSP mesh. See the
[Godot 4.7 Decal reference](https://docs.godotengine.org/en/4.7/classes/class_decal.html)
and [MultiMesh reference](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html).
The tradeoff is that marks touching an edge or curved surface are omitted,
rather than projecting around that edge. GPU frame-time improvement over a
projected-decal implementation has not been benchmarked.

`deathmatch/tests/bullet_marks.gd` checks rendering, alignment, pool/queue bounds,
edge/mover rejection, authoritative contacts and recording compatibility, and
saves a native-renderer screenshot plus draw-call counts.
