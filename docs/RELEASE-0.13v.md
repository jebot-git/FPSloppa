# FPSloppa 0.13v — TITANBALL protection and dedicated bots

TITANBALL now uses fixed cockpit protection: 200 HP, heavy-ordnance hull damage only, and no passive cockpit regeneration. Dedicated servers can fill vacant slots with bots, and bots navigate connected jump pads and elevators more reliably.

- Boarding grants 200 HP and a 200 HP maximum for every TF class. Living exit restores full normal class health and the saved weapon/armour; death ejection does not revive the pilot. The three-second exit lock remains. Medic passive regeneration remains a class ability.
- Only rockets, grenades/pipebombs, detpacks, Heavy primary fire, engineer sentries and Titan cannons can penetrate an occupied TB hull. Direct hull impacts or explosions on the hull are required; nearby splash stays excluded. Ordinary small arms cannot damage the pilot. Heavy projectiles retain their firing-time classification when the shooter changes class.
- Removed the `sv_tb_heavy_ordnance` server option. Legacy lines are ignored so older configs load without disabling protection. Cockpit regeneration remains off in normal matches; alternate policies are retained only in the research runner.
- Added `sv_bot_fill`: target total occupancy, including humans and bots, capped by `sv_maxclients`. A ready human replaces a bot when a server is full due to bots; bots refill vacancies after departures. Pending human joins reserve seats, bots cannot vote, and replacing a bot pilot releases the cockpit correctly.
- Improved bot navigation readiness, Vesper elevator boarding/riding/exits, and connected DM7 pipe/jump-pad routes. Navigation and bot population refresh on map rotation.
- Retained clean, self-contained Linux, Windows, Quest, Pico and source packages. Community Maps, Original TF Arenas and the separate Base Assets download remain retired. The 26 bundled maps are unchanged.

## Downloads

Linux client, Windows client, Linux dedicated server, Quest APK, Pico APK and self-contained source ZIP, with SHA-256 checksums and a build manifest. Android version code is 18; Quest/Pico remain locally signed experimental sideload builds. Protocol remains `fpsloppa-35-mode-loadouts`; use matching 0.13v clients and servers for the complete changes.

## Validation and limits

The fixed cockpit/default/configuration suites passed 196 checks. Twenty-four preceding matched 6v6 bot trials informed the selected rules; they do not establish human-team balance. Package, console-server and platform validation results are recorded in `docs/RELEASE-CLEANUP-0.13v.md` in the source download.

No fresh human VR, Windows, Quest or Pico hardware test is claimed for this release. Existing shutdown-only engine resource warnings remain. Prior ten-player remote TITANBALL profiling exceeded the 60 Hz server physics budget; bot fill is optional and this release is not a performance certification.
