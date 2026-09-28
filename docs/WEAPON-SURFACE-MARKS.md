# Weapon surface marks

All damaging weapon slots in Doom, Quake, UT99, CS 1.6 and Tribes now have a
surface-mark profile. Alternate fire uses its resolved weapon definition, as do
TF class overrides. The procedural artwork stays in the existing shared mesh
batch; no texture downloads are required.

| Mark | Weapons |
| --- | --- |
| Bullet hole | Pistols, shotguns, conventional automatic weapons, ballistic snipers, flak |
| Cut | Knife, axe, chainsaw, Ripper blades |
| Dent | Fist, weapon whip, spanner, impact hammer |
| Scorch | Rockets, grenades, disc launcher, mortar, mines, Redeemer, flame/incendiary weapons, DE HE grenades |
| Energy burn | Plasma, BFG, railgun, blaster, lightning, shock, pulse, laser, ELF |
| Bio splash | Bio rifle, including charged globs |
| Small puncture | Nails, tranquilizer darts, TF engineer's projectile railgun |

Repair, targeting and translocator tools deliberately leave no damage marks.
Player hits keep their existing blood effects. Movers, breakables, deployables,
misses and projectile cancellation cannot leave suspended world marks.
Explosions use six short occluded probes, emitting at most three nearby marks;
projectiles stamp actual contacts, including blade/flak bounces and bio adhesion.

The rendering limits remain 128 instances, 32 pending marks, four placements
per frame, four corner probes per placement, 30-second lifetime and 40-metre
camera range. Duplicate contacts of the same style merge. The native renderer
measured one additional draw call for the complete 128-instance batch.

Authoritative surface events include their style and normals in demo recordings.
Older three- and four-argument impact events remain readable. New events validate
style IDs, array lengths, finite positions and unit normals.

Validation: `deathmatch/tests/surface_marks.gd` exercises the actual firing and
projectile paths across every arsenal and UT alternate mode, plus TF overrides,
misses, player-hit exclusion, explosions and cancellation. The native
`deathmatch/tests/bullet_marks.gd` checks placement, limits and demo compatibility.
`deathmatch/tests/mark_styles_visual.gd` renders the seven materials at one scale.

Local rendered evidence: [decal style sheet](../test-results/weapon-decals/styles.png).
See [validation receipt](validation/weapon-decals-map-corrections-2026-09-27.json)
for test counts and remaining unrelated penetration failures.
