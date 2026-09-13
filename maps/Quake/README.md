# Base Quake multiplayer arenas

The seven source ports `qsrc_dm1` through `qsrc_dm7` are the base DM, IG, FT and TDM selection. Instafreeze shares the IG maplist. DM7 is included in the base rotation as requested.

These are the existing reviewed ports from John Romero's Quake map-source release: DM1–DM6 and bonus multiplayer DM7. **Map geometry is GPL-2.0**; retain `COPYING-GPL-2.0.txt`, `ORIGINAL-README.txt`, and the complete original/adapted sources provided here. Texture artwork is separately credited to LibreQuake, Makkon and the existing generated replacement-art sources. The adapted WAD and texture dictionary are included. No commercial Quake texture data is shipped.

All seven passed current spawn/collision, mover, teleporter and water traversal checks. DM6's previous swimming failure was caused by concurrent water probes entering a submerged teleporter and telefragging; the water test now isolates hydrodynamics from teleport triggers, which retain their separate traversal test. No map geometry or swimming behavior was changed to obtain that result.

Each map was also exercised with eight production bots in DM, IG, FT and TDM for 45 simulated seconds per combination. These are compatibility checks, not a balance certification. Rebuild/source instructions remain in `tools/quake_source/README.md` in the repository.
