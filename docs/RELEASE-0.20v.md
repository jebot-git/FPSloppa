# FPSloppa 0.20v — Tribes, native optimization and custom music

ST is now included with Stonehenge, Raindance and Katabatic. It combines Tribes CTF rules with skiing, jetpack energy, Light/Medium/Heavy armour, the personal arsenal, backpacks, stations, deployables, base defences, Scout and transport vehicles. Desktop and VR controls include targeting, beacons, remote cameras and a wrist-mounted PDA. Raindance has rain, Katabatic has snow, and all three maps use distance fog.

- Native C++ acceleration covers movement, bot queries, network packing, hit history and avatar tracking channels, with script fallbacks. Vehicle collisions damage and push players; replacement-armour hands stay attached to their sleeves.
- Vehicle and passenger demo playback now shares recorded timestamps and interpolation, including pause, seeking and variable playback rates.
- Place OGG files in the empty `bgm/` folder beside the PC game. Tracks play in filename order. Mode prefixes (`dm_`, `st_`, `tf_`), map names, named folders and local M3U/M3U8 playlists select the appropriate music. Map selections override mode selections, then global tracks. Title and lobby always use internal **Dead Air** and **Please Hold**. Other built-in BGM has been removed; gameplay is silent when no custom music matches. See `AUDIO.md`.
- The source package includes the CS 1.6 BSP30-to-BSP29 DE converter. Converted maps can carry embedded bomb sites, spawns and per-texture palettes; missing WADs can use the optional replacement-material routine. Original CS maps and WADs are not bundled.

Linux, Windows and Quest clients remain Vulkan-only; the Linux dedicated server has no graphics/audio drivers. All packages contain the required base assets: 35 maps and 11 CC0 avatars. ST armour includes attributed KEIV suit derivatives with their separate non-commercial terms; see the included asset notices.

Use matching 0.20v clients and servers. The protocol is `fpsloppa-68-st-native-main`, incompatible with 0.19v. Existing server configurations keep their current mode; choose `st` and an ST map, or add `st` to the allowed vote modes, to enable Tribes matches.

ST remains experimental: bot capture reliability and heavy 16-bot server workloads need further work. Quest is experimental, and Windows/Quest packages are cross-built; package checks do not replace device testing. This release does not include a fresh physical-headset validation.
