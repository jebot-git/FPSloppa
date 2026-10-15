# Future weapon-tier reserve

Fourteen edited, unassigned single-shot effects. `reserve_blaster_01..08` are distinct unused C3Sabertooth takes, `reserve_plasma_01..04` are further humanoide9000 takes, `reserve_heavy_pistol` is the longer nioczkus report, and `reserve_pulse` is an isolated Johnnie_Holiday pulse. These are candidate sounds, not progression unlocks.

All are mono 24 kHz PCM16, with headroom, filtered sub-bass/treble and short edge fades. `manifest.json` records exact sources, recipes and hashes. [Source credits and CC0 terms](../../../deathmatch/audio/cq_field/SOURCES.md). [Pinned input URLs/hashes](../weapon_sources.json).

`.gdignore` keeps this offline authoring bank out of Godot resource scanning. The frontier packager explicitly removes this directory; none of these clips is assigned in `Field.SHOTS`. Move a chosen clip into the runtime audio directory and update the runtime manifest/weapon mapping when adding a tier.
