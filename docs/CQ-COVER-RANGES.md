# CQ concealment and effective ranges

A prone player touching a deterministic grass tuft is spotted or acquired by ground observers at **25% of the usual range** (a 75% reduction). This applies to enemy name/class-icon spotting, bot perception and automated turret targeting. It does not reduce the prone player's own sight range. Standing/crouching or leaving grass restores the normal target range. Mounted players do not receive grass concealment.

The reduction multiplies the observer's existing daylight/night/NVG range. For example, daytime player spotting changes from 75/150 m to 18.75/37.5 m for standard/scout observers; standard NVG spotting at night changes from 50 m to 12.5 m. LOS and glare checks still apply. Previously acquired names/icons retain their existing ten-second team memory, which cannot be refreshed from outside the reduced range. Allied names/icons remain visible within 100 m.

**Recon aircraft are exempt:** their full 100 m cross-track flight corridor still reveals all eligible enemies regardless of grass, darkness, canopy, roofs or cloak. No recon detector logic was modified.

Grass contact is derived from the same seeded candidate positions, planting exclusions, rock/slope/height limits and float32 height interpolation as rendered tufts. It does not depend on client render distance, grass LOD, mesh residency or a client-supplied cover flag. A bounded 128-tile cache stores candidates and lazily evaluated roots. The resident server updates cover at 10 Hz at both 30 and 60 Hz simulation rates; standing cancels the modifier immediately in detection checks. The script fallback uses the same classifier.

| Weapon or detector | New capability |
| --- | --- |
| Technician T1 salvo launcher | 55 m/s, gravity 12 m/s², 15 s fuse; approximately 252 m maximum level-ground ballistic range, with an actual simulated arc crossing 200 m above the ground |
| Guided launcher | 40 m/s, 15 s lifetime: 600 m unobstructed travel; 500 m lock acquisition with the existing 1.5 s dwell |
| Light and heavy tanks | 40 m/s base velocity, 10 s projectile lifetime: 400 m nominal unobstructed travel, preserving inherited hull velocity |
| Automated turret | 150 m acquisition; 37.5 m against prone infantry in grass; projectile travel remains 160 m |

Damage, blast radius, salvo size, ammunition, reloads and vehicle cadence are unchanged. Ballistic maxima assume level ground, while terrain and obstacles can shorten actual reach. Guided flight path length can also include turns.

Both native and scripted rules are updated. Use matching client/server packages with protocol `fpsloppa-cq-frontier-24-cover-ranges`; native modules must be rebuilt. No live service deployment was made. [Validation](validation/voxel-battle/cover-ranges-20261015/README.md).
