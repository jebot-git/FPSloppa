# FPSloppa 0.21v — Weapon presentation, VR menus and bot workers

- Refined weapon geometry, textures, moving mechanisms and emissions across loadouts, with targeted polygon reductions and preserved CS sight alignment.
- Reworked weapon reports and mechanical sounds, normalized levels, map ambience, and a looping high-pressure music cue. Custom BGM overrides ambience; `win_` tracks replace the pressure cue.
- Reorganized menus for VR, with subcategories and consistent joystick/drag scrolling. Tribes viewpoint zoom includes desktop and VR overlays.
- Jolt is the default 3D physics engine. Avatar import/runtime caching and surface compilation reduce repeated work; VRM remains the accepted upload format.
- Updated CS haptic profiles and Bluetooth disconnect handling, plus OpenXR and Steam Audio shutdown fixes.
- Katabatic turret foundations and bot routing refinements.
- Prevented native AI from using a disconnected target between perception updates.
- Optional authenticated bot worker moves AI to a separate Linux process or host. The authoritative server retains physics, combat and objectives; local AI resumes when the worker disconnects. Human players retain slot priority.

Downloads: Linux and Windows PC clients, experimental Quest APK, Linux dedicated server, Linux bot worker, master service, and source. Dedicated server and bot worker share one console-only runtime and ship both launchers; neither needs desktop or VR drivers. See SERVER.md for keys, configuration and remote tunnel setup. The bot service is disabled by default.

In a local 16-bot Katabatic comparison, moving AI to the worker reduced median server gameplay-callback time from 5.46 to 3.35 ms and p95 from 24.14 to 4.08 ms. Including measured worker transport callbacks, mean time fell from 8.03 to 4.13 ms. These are server callback measurements, not complete frame times; the worker uses a lower AI rate, the matches were not deterministic replays, and WAN performance remains untested.

Use matching 0.21v clients and servers (protocol `fpsloppa-71-native-special-trace`); 0.20v clients are incompatible.

Existing Katabatic pathing limitations remain; offloading AI does not itself fix navigation. Windows and Quest are cross-built and package-verified; no new physical-headset or vest test is claimed for this release. See docs/validation/release-0.21v.json for checks and remaining limitations.

Asset-specific license notices are included. ST armour retains its separately documented non-commercial terms.
