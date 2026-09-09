# FPSloppa 0.2v — VR improvements, weapon whip and configurable servers

Every weapon now provides an ammo-free weapon whip: swing it in VR or press **F** on desktop. It deals 10 damage before armor with a 0.8-second cooldown and one target per swing. VR requires deliberate motion and recovery; resting a weapon against another player causes no contact damage. Damage, walls, spawn protection and cooldown are checked by the server.

Dedicated servers can opt into **16 players** using `set sv_maxclients "16"` in `server.cfg`; the default is eight. In-game hosting remains limited to eight total players. Avatar catalogs support the larger roster. Servers also support ordered map rotation through `sv_maplist`, preserving connected clients across map changes.

## VR and gameplay fixes

- Correct controller wrist orientation and local finger curls; improve body orientation calibration, native tracker handling and OSC burst reception. Tracked players see their avatar body from the shoulders down.
- Align held weapons with controller grips and distinguish shotgun/super-shotgun visuals.
- Keep the player capsule aligned with bounded headset movement in the playspace.
- Replace the wrist HUD with a compact floating health, armor, ammo, match timer and frags-remaining display. Save adjustable smooth-turn speed and snap angle.
- Make controller rays stop at menu surfaces, improve voice menu selection, and allow callsign editing with the VR keyboard or client config and username fallback.
- Enable voice by default in push-to-talk mode; request Android microphone and supported vendor tracking permissions.
- Balance weapon sound levels, add hit sound/screen feedback, improve projectile hit detection and stair viewpoint smoothing, and hide non-rendering trigger brushes responsible for white boxes on lqdm1.
- Use full-rate shading for PC VR to keep streamed imagery and the HUD clear. Android retains XR variable-rate shading.

## Packages and compatibility

Linux and Windows PC clients, Linux dedicated server, source, and experimental Quest/Pico APKs are provided with SHA-256 checksums. Extract the whole PC/server ZIP; keep executable and PCK together. Use the VR or Desktop launcher as appropriate.

All clients and servers must update together: protocol **entryway-dm-10-melee** is incompatible with older releases. Android version code is **6**. These APKs use a new local development signing key; installing over an APK with a different signing key requires uninstalling that older build first. The private key is excluded from the repository and release packages.

## Validation and limits

Seventeen source regression suites passed, including melee, combat, tracking, IK, VR UI, room-scale movement, permissions, stairs, weapon setup and projectile hits. Separate ENet processes verified melee replication. The exported dedicated server admitted 16 clients with complete avatar catalogs and rejected an extra client; an in-game host admitted only eight total players. Exported Linux client/server connection, server config validation, voice relay and source map rotation checks passed. Both ARM64 APKs passed manifest, signature, alignment, protocol, current script and raw asset checks.

A Quest Pro wearer using WiVRn confirmed menu alignment/recentering, corrected wrists/fingers, turn controls, audio, microphone and rendering. The PC session rendered 2520×2772 per eye around 72 Hz. These checks do not establish standalone Quest/Pico behavior, native SteamVR tracker compatibility, or WAN/load performance. The new physical weapon-whip thresholds have automated coverage and have not yet been tuned in a wearer test. The installed vendor plugin's unsupported audio face-tracking source still prevents native face/blink initialization on this WiVRn session. See [the live test record](../LIVE_VR_TEST.md).
