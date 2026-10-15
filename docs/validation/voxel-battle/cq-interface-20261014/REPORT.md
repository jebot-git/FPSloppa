# CQ menus and HUD — 14 October 2026

Implemented on `experimental/cq-voxelspace`. Local rendered validation only; not deployed and not evaluated through a live headset.

## Navigation

The CQ index contains Play, Deployment, Identity, Settings and active-match actions. Resume and Match appear during a match. There is no Field Guide, manual, library/importer or demo navigation route. The manual remains a launcher concern.

Play separates server browsing, direct connections and hosting. Hosting exposes the server port and fixed CQ map/objective description. Inapplicable map/mode/weapon selectors, frag limits and time limits have no CQ menu route. Teams and balance remain available; map/global-loadout proposals and TF class controls are absent.

Deployment retains class, skin, avatar calibration and confirmation. Primary, secondary and utility equipment have individual pages. Before joining, deployment displays a disabled join-first action. The compact mirrored avatar stage leaves confirmation visible at 960×640.

Settings separates audio, display, controls, VR/comfort, avatar calibration and haptics. Music, announcer and experimental legacy lighting controls are hidden. Disabled weapon cycling and duplicate offhand-fire bindings are absent. Shared legacy controls retain references where shared refresh code needs them; there is no player-facing CQ route to them.

## Artwork and text

The interface uses original CC0 Wenrexa UI Minimalism SciFi/Nesia PNGs as nine-slice panels and button states. Unitblock v0.81 by GGBotNet replaces CQ UI typography, including popups, skin selection, scoreboards, VR HUD and tank feed text. Only four used pack textures and the original TTF are retained. Provenance, license and hashes are in [asset sources](../../../../deathmatch/ui/cq/assets/SOURCES.md).

CQ world nametags use a single neutral Label3D, strip custom colour codes and allocate no coloured runs. Team shape markers and class icons remain. CQ identity fields no longer advertise colour codes; submitted names and CQ scoreboards use plain text. Other modes retain their existing nametag presentation.

CQ announcer setup allocates no player, bus or clips. Policy updates cannot re-enable it, and award queues remain empty. Announcer volume is absent from CQ settings.

## HUD

Desktop vitals, weapon/reload and ammo are separate translucent Nesia cards. Match status, notifications, hit feedback and scoreboard use the same font/palette. Low health retains a red warning. Loaded and reserve ammunition come from existing replicated magazine state; HUD reads do not mutate simulation state.

The head-relative VR HUD uses the same cached panel and font, matching clip/reserve data and semantic warning colours. It omits CQ's unused round timer. This remains a transparent, noninteractive stereo surface. Rendering uses existing Godot native canvas drawing; no simulation RPC, packet or C++ authority change is required.

## Validation

- `cq_menu.gd`: **62 checks passed**, actual Forward+ Vulkan rendering on Intel Arc A770 at 960×640. Covers navigation/back behaviour, layout widths and footer reach, font/popups, removed controls, quiet announcer policy, neutral names, calibration access, loaded/reserve state, low-health contrast and HUD card bounds. Screenshots accompany this report.
- Shared menu navigation: **28 assertions passed**. The fixture emitted shutdown resource-leak warnings; it is not reported as a clean lifecycle run.
- Shared non-CQ nametags: **12 checks passed**.
- Shared announcer mixer: **25 checks passed**, including ordinary-mode playback and policy handling.
- Shared announcer ENet regression: connection/policy/authorized-cue checks passed, but the map-rotation assertion failed because the fixture requests unavailable `lqdm2`. Server/client logs are retained; the complete runner is not reported as passing.
- `git diff --check` passed. No live service or VR client was restarted.

Screenshots use a local scene and supplied replicated-style fixture state. They do not establish headset legibility or live match behaviour.
