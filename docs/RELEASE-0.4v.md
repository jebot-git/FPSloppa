# FPSloppa 0.4v

This release adds mirrored left-handed controls independently of weapon-hand selection, plus seated height compensation that suspends when body tracking is active.

- **IG — Instagib:** infinite-ammo railgun, 1.5-second firing interval, piercing instant kills, wall occlusion and spawn protection. Uses the CC0 sniper mesh from the existing Oldschool AFPS weapon set with an original rail sound.
- **FT — Freeze Tag:** lethal combat freezes players. A teammate within 1.5 m and line of sight thaws them after three uninterrupted seconds. Freezing the opposing team earns a point and resets the round. Environmental deaths respawn normally.
- **CC — Chainsaw Circus:** chainsaw only; health drains by 3 per second after spawn protection; actual enemy chainsaw health damage heals up to 100. All map pickups and physical melee attacks are disabled by the mode. BSP files are unchanged.

Maps and VRMs move outside PCK/APK into accessible `maps/` and `vrm/` folders. Dedicated servers retain player uploads there. Mode-specific maplists support independent rotations and map votes. See [installation and server setup](EXTERNAL-ASSETS.md).

Five additional LibreQuake arenas are offered separately with author readmes, licenses and complete texture replacement provenance. BSP import now filters degenerate render/collision triangles. ThreeWave conversion tools are offered separately; converted ThreeWave BSPs remain local and are not distributed through this repository or release.

Use matching 0.4v clients and servers; the network protocol changed.

The owner confirmed 0.3v playable on Quest 3 standalone, Linux PCVR with WiVRn, Windows PCVR with SteamVR, and Windows PCVR with Virtual Desktop. This does not constitute hardware validation of 0.4v. Pico 4 and other PCVR configurations remain untested. Automated checks cover gameplay, VR input/seated state, menus, BSP parsing/collision and independent-process network transfers; they do not establish headset frame rate or comfort.
