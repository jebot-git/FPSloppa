# FPSloppa 0.14v — BSP triggers, aware bots and restored lighting

Bots can operate BSP map controls, server admins can change bot counts live, and Q1/LibreQuake-derived maps regain their authored lighting.

- Added RCON `bots <count>` for an exact bot count alongside human players, capped by server capacity. `bots 0` removes bots; human arrivals retain priority. The override survives map rotation.
- Bots account for Titanball hull protection when choosing enemies and weapons. They leave immune Titans alone when their available weapons cannot damage them.
- Bots resolve door controls through target chains, approach touch buttons and fire normal weapons at shootable switches/secret doors. They stop once activated, defer to close threats, and avoid activating crushers containing themselves or teammates.
- Shared BSP runtime now supports touch/shootable buttons, health-based doors, one-shot/repeating triggers, relays, counters, delays, killtargets, linked/start-open/toggle doors, two-stage secret doors, crushers and cyclic trains. DM1–DM7 retain their map controls. Arbitrary QuakeC scripts and animated light-style programs remain unsupported; switched lights are baked on for multiplayer.
- Fully rebuilt Q1 DM1–DM7 with full VIS and 4×4-sample RGB lighting. Removed conversion-added ambient floor/sun/bounce, corrected the display response and fixed full-bright ordinary faces with missing samples.
- Rebaked all four KOTH and all four CC derivatives without their conversion-added minimum light, preserving original sunlight and shipping geometry. Corrected sample-less faces and rebuilt caches for HiSlop, Confluence and Skyfracture. All 26 maps remain bundled.
- With headset/controllers only, the avatar body follows physical head yaw; tracked hips/chest keep priority. The held team radio rotates −90° around its local X axis to align its antenna with the grip.

## Downloads and compatibility

Linux client, Windows client, Linux dedicated server, Quest APK, Pico APK and self-contained source ZIP. Assets are bundled; separate asset/map-pack downloads remain retired. Android version code is 19. Use matching 0.14v clients and servers: the protocol is `fpsloppa-36-bsp-triggers`.

## Validation

An eight-bot DM6 deathmatch ran for five simulated minutes. A 6v6 Titanball round completed with team 0 winning after 683.68 simulated seconds. Focused checks exercised bot-fired secrets, physical button contact, crusher avoidance, RCON population changes, multiplayer movers, avatar tracking and lighting. See `docs/RELEASE-CLEANUP-0.14v.md` for the final build and package checks.

These are automated matches, not a human balance study. One DM6 bot had a temporary 13-second movement stall in the first run. No fresh headset or native Windows/Pico hardware test is claimed. Existing shutdown-only resource warnings remain.
