# FPSloppa 0.12v

This release fixes VR firing, movement and TITANBALL cockpit controls, softens bot aim, adds eligible-mode loadout voting, and cleans the release packages.

- Fixed imported weapon-audio loading that could crash exported clients when selecting loadouts or firing. Corrected Quake axe audio, projectile departure, shotgun feedback and rail trails; added dedicated flamethrower effects and sound.
- Improved delivery of brief trigger presses during jumping and immediately after respawning. Quake and Doom rocket firing passed live headset retests.
- Corrected tracked crouch/prone speed and locomotion animation response, landing prediction, and DM7 pipe push volumes. Both DM7 pipes passed the remote VR retest.
- Added variation to bot aim and acquisition delay, and conservative rocket/impact-hammer jump planning. Loadout voting is available in eligible lobby and in-game modes; TF/TB retain Quake loadouts and Assault retains UT.
- TITANBALL cockpit grips enable manual cannon controls: left stick adjusts lateral aim, right stick vertical aim, with inverted vertical input and a larger neutral deadzone. Neutral sticks hold aim. The cockpit shows cannon reticles and aim angles. Preparation uses the usual last-ten-second countdown sounds. Sniper helper beam removed and scope image enlarged/corrected for brightness.
- Preserved the Makkon replacement dictionary as raw WAD data instead of an unused imported scene, fixing access to replacement textures in exported builds.
- Packages use explicit runtime file selections. Removed build logs, demonstration video, development receipts and map-authoring payload from installed assets. Editable map sources and tooling remain in the source download. Corrected installer-invalid validation paths and verified installation into an empty directory.
- Retired the separate Community Maps and Original TF Arenas downloads from this and future releases. Pressureworks and Vesper Abbey remain in the bundled TF rotation; the base game still has 26 maps.
- Base Assets remains an internal APK build input. Linux, Windows and source ZIPs include maps/models directly; Quest/Pico APKs include their offline installer. The separate Base Assets download and thin APK option are retired. Android asset repair now works from the included archive without a download.

## Downloads

Linux client, Windows client, Linux dedicated server, Quest APK, Pico APK and self-contained source ZIP. Checksums and a build manifest accompany the downloads. Android version code is 17; these remain locally signed experimental sideload APKs. Protocol remains `fpsloppa-35-mode-loadouts`; update clients and servers together to receive the fixes.

## Validation and limits

Package integrity, exact bundled asset hashes, offline installation/repair and custom-file preservation are checked for this release. Linux/Windows resource packs and both Android vendor packages are audited; console server validation checks the dedicated runtime and gameplay startup. See the source archive's release-cleanup report for results.

Earlier live tests covered Linux VR through WiVRn and remote networking; the wearer confirmed corrected DM7 movement, Quake/Doom rocket input, cockpit split controls, preparation ticks and flamethrower appearance. The final inverted vertical input/deadzone and packaged 0.12v APKs have not had a fresh wearer test. Windows and Pico hardware were not retested. Remote 10-player TITANBALL profiling still showed server physics frames exceeding the 60 Hz budget; this release is not a performance certification. Existing shutdown-only OpenXR/audio resource warnings remain under investigation.
