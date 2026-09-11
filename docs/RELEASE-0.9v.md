# FPSloppa 0.9v

HiSlop joins the base maps as an experimental Assault (AS) train map, with ordered objectives, defensive sentries, role-swapping timed attacks, animated scenery and baked lighting. Enable AS just like TF using `sv_gametype`, `sv_gametypes` and its separate `as_maplist`. See AS.md for a complete server example.

## Gameplay and presentation

- TF abilities have clearer effects for healing, repair, sentry fire, grenades, napalm and flamethrowers. Grenades are thrown projectiles; ability cooldowns appear in the HUD. Spy cloak can copy an enemy's VRM appearance.
- Doom-inspired weapon and pickup sound revisions, with networked jump audio. AS uses ZillyMike's public-domain Mega Destruction theme.
- Announcer match-start, game-over, CTF, LMS and round-winner calls are removed. First blood and kill combinations/streaks remain; TF and AS objectives retain their completion call.
- Improved BSP lighting, missing-texture replacement rules and VRM shading. The scoreboard supports sixteen visible entries with team colours and TF classes; it is held to show. Menu suicide subtracts one frag.
- Player capsules no longer carry other players as moving platforms during respawns. World lifts still carry players. TF demo HUD and Spy visibility follow the selected replay player correctly.

## Builds and compatibility

Use matching **0.9v clients and servers**, protocol `fpsloppa-26-fortress-effects`. Android version code is **14**, retaining the package IDs and signing identity. Downloads include Linux, Windows, Linux dedicated server, Quest/Pico sideload APKs, source and external base assets. Maps and VRMs remain outside the Godot package; HiSlop is included in desktop/server asset folders and the standalone base-asset download.

The optional LibreQuake extra maps and two authored TF arenas remain available. Local ThreeWave, original TF, FortressOne/Turtler and Arcane Dimensions conversions are not published in the base game or source archive. New conversion scripts and instructions may be included; restricted BSPs are excluded. The legacy Arena Collection remains archived in 0.5v.

## Validation and limits

Eight-client AS and TF simulations exercise objectives, combat, abilities and recording/replay. HiSlop receives a fresh full VIS and supersampled BSPX light bake. Release checks cover mode configuration, exported Linux client/server joining, package contents, Android version/permissions/native libraries and signing/alignment. See `docs/validation/release-0.9v.json` for the completed results.

These are scripted integration tests, not human balance or autonomous route-completion certification. Windows, Quest and Pico builds are not physically tested in this release session; earlier hardware reports do not certify the new build. Godot's isolated shutdown resource warnings remain documented. More than sixteen players remains unsupported even though dedicated servers accept up to 32.
