# FPSloppa 0.5v

This release adds TF classes and VRM spy disguises, new arena maps, expanded VR controls, demos, optional voting lobbies, and improved online hit registration.

- TF: nine classes, visible class identifiers, VRM-aware Spy disguises/cloaking, and two original TF arenas in a separate pack.
- Arena Collection 1: 40 original BSP arenas, five per game mode, with LibreQuake textures, baked lighting and bot navigation. Distributed separately from the game package.
- VR controls: optional two-handed aim support without weapon-stat changes, binding configuration, and physical jumping. Existing left-handed and seated controls remain available.
- Match features: demo recording/playback with alternate viewpoints and a video helper; optional weapon-free voting lobby between rounds.
- Multiplayer: timestamp-bounded lag compensation, stronger hitscan/projectile handling, reordered-packet safeguards, and a 25 MB BSP transfer cap. VRMs retain their 25 MB cap. Dedicated servers accept up to 32 players, but **more than 16 is unsupported and not balanced or performance-tested**.
- Avatars and presentation: deferred VRM selection/loading, environment-aware avatar lighting, improved map lightmaps, and FPSloppa branding.
- AD compatibility: reproducible local conversion tools, static-mesh batching and Quake masked-texture fixes. Sixteen AD conversions passed local geometry/navigation/runtime checks. Converted AD, ThreeWave and original TF BSPs are not redistributed; only tools and instructions are included.

## Compatibility

All players and servers must use this release's protocol, `fpsloppa-17-lag-compensation`. Earlier clients are incompatible. Android application IDs and the existing local signing identity remain unchanged to preserve upgrade compatibility; version code is 10.

Linux PC, Windows PC, Linux dedicated server, Quest and Pico builds are supplied. The user's 0.3v hardware testing covered Quest 3 standalone, Linux PCVR via WiVRn, and Windows PCVR via SteamVR and Virtual Desktop. That testing does not certify this new release. Pico hardware remains untested. No new 72 FPS guarantee is made.

## Assets and installation

Maps and VRMs remain external. Desktop archives contain only the selected base assets; standalone users need the matching `FPSloppa-0.5v-Base-Assets.zip`, installed through the game's asset workflow or extracted into its external asset root. The release URL becomes available only after publication. Optional arena and TF packs install into the external `maps/` folder and include their own notices.

For local AD use, see `optional-ad-tools/README.md` and its validation report. AD maps retain original embedded art and notices. Unsupported single-player scripting, ambient sounds and external decorative models are omitted; LibreQuake supplies replacement fixtures. These asymmetric adaptations need further gameplay and device testing.

## Validation

See `docs/validation/release-0.5v.json` for build and release-check results, `NETWORK_TESTING.md` for the 20–100 ms lag simulations, and the map-pack validation reports. Local build verification is not a substitute for multiplayer testing on every headset/runtime.
