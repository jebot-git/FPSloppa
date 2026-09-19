# FPSloppa 0.15v — smoother transitions, map voting and rotating hills

This release combines the working main-branch gameplay fixes. CQ and district workers remain isolated on the experimental branch and use a separate release and protocol.

- Fixed map/lobby loading coordination so one delayed player does not hold ready players frozen. Improved collision prediction to reduce obstacle rubberbanding and camera shake.
- Added joystick scrolling and dropdown cleanup, plus a 3×3 ballot of map/loadout/mode combinations with generated map previews. Connected clients can import BSP maps; recognized filename tags select compatible server maplists, while untagged maps join DM/TDM/IG/FT/IF.
- Frozen FT/IF players fall to the ground. Player hitboxes now match the box-shaped placeholder more closely. Corrected portal/teleporter exit placement and facing.
- Assault weapons use normal pickup/respawn behavior with half the ordinary weapon respawn delay. Audited TF loadouts and nail weapons, increased sniper scope magnification, added team markers to nametags and enabled positional-audio Doppler.
- Titanball adds a ten-second pilot boarding lock, slower boarding transitions and verified armour protection. Ashfall extends only its middle checkpoint section by 50 m, with side balconies, an overpass, curved approaches, updated resupply stations and a slightly larger downward crush reach.
- KOTH hills rotate every 30 seconds among at least three positions. Rebuilt and rebaked the four KOTH maps, added the hill timer and a round-end gong.
- Added bounded emissive weapon/projectile illumination with BSP occlusion: at most two contributions on desktop and VR. Avatar receiver lighting and BSP import baking remain feasibility experiments.

## Downloads and compatibility

Windows client, Linux client, Linux dedicated server, Quest APK and self-contained source ZIP. Pico is excluded from this and future releases. Existing Pico controller compatibility code and historical downloads are retained. Assets are bundled; retired asset/map-pack downloads remain retired.

Use matching 0.15v clients and servers: protocol `fpsloppa-39-rotating-koth`. Quest Android version code is 20. Experimental CQ clients use their separate launcher and cannot join ordinary servers.

## Validation

Release validation covers gameplay regressions, the eight-client delayed-load transition, real ENet voting/KOTH/teleport tests, exported package content and asset hashes, Linux package startup, and Quest signature/manifest/ARM64 validation. Detailed receipts are in `docs/validation/release-0.15v.json`.

This release has not received a fresh native Windows or physical Quest/PCVR playtest. Headless prediction checks and automated bot tests do not establish headset comfort or full-match balance. Existing exit-only Godot resource diagnostics remain.
