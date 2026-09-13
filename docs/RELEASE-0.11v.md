# FPSloppa 0.11v

TITANBALL adds a TF-class robot escort mode through Ashfall's ruined city. This
feature release also updates the arena collection, static lighting, weapon
loadouts, bot objectives and network transport.

## Gameplay and maps

- TITANBALL uses TF classes and Quake weapons. Attackers pilot the robot along a
  roughly 300-metre route while defenders prepare ambushes. A one-minute setup
  precedes the fixed ten-minute round; each of two checkpoints adds three minutes
  and advances attacker spawns. The cockpit monitor carries the HUD and distance
  to the goal.
- Boarding restores class health and requires the belly ladder to be extended.
  Pilots must remain aboard for three seconds, then can jump to leave. Cockpit
  protection supplies permanent 200 armour; direct hull impacts and explosions
  on the hull hurt the pilot, while nearby splash does not. Linked cannon pairs
  share heat, and moving feet crush defenders and their deployables.
- The base distribution contains 26 maps: seven Quake deathmatch arenas, six CTF,
  four KOTH, four Chainsaw Circus, Pressureworks and gothic Vesper Abbey for TF,
  full-sized HiSlop and Frigate for Assault, and Ashfall for TITANBALL.
- The optional community pack contains 53 maps in seven categories. It excludes
  TF maps and Tiny Assault variants. TF distribution contains only the two
  original arenas. Historical conversion tools remain in the 0.5v release.
- Quake and experimental UT loadouts provide additional weapon choices where
  supported. UT Impact Hammer charging, contact attacks and impact jumps have
  dedicated physics and network regression coverage.

## Rendering, audio and networking

- Vulkan is the supported client renderer on PC, Quest and Pico. Baked ambient
  occlusion, improved lightmaps, static material effects and default skyboxes
  improve map presentation. Fog rendering and its graphics control are removed.
  Classic/Contrast lighting remains selectable.
- Desktop BC7 and Android ASTC 4x4 texture caches preserve full texture resolution;
  lightmaps and glow masks remain uncompressed. ASTC 8x8 is not used. Imported
  BSPs retain their supplied baked lighting; the importer does not generate a
  fresh AO bake automatically.
- The robot has heavier mechanical footsteps and crushing effects. Music receives
  a 12 dB reduction with finer volume control.
- Network changes include smaller snapshot packets, acknowledged input handling,
  bulk asset transfer improvements and public/team voice routing. The Linux
  dedicated server uses a separate console runtime.

## Downloads and compatibility

Use matching **0.11v clients and servers**, protocol
`fpsloppa-35-mode-loadouts`. Android version code is **16**, retaining the existing
package IDs and signing identity. Downloads include Linux and Windows clients,
Linux dedicated server, Quest and Pico APKs, source, Base Assets, Original TF
Arenas and Optional Community Maps. Standalone APKs include the current base assets.
The avatar, UT and experimental Quake MDL converters have their own repositories
and releases, linked from the project README.

## Validation and limits

The final Linux client joined the new console server successfully. Independent
PC package audits and both Android APK checks passed, including vendor manifests,
Vulkan policy and 16 KiB native-library alignment. The optional pack passed 53 map
checks and 374 installer checks. Publication verifies every archive and upload
checksum. See [release validation](validation/release-0.11v.json).

Earlier validation includes 106 Impact Hammer checks, TITANBALL simulations and
a live remote test of all eleven modes with twelve clients plus a visible
spectator, followed by a sixteen-player capacity hold and voice/rejoin tests.
Some remote peers had 300–400 ms latency and the server recorded eight UDP drops
during TITANBALL; this remains a performance limitation. See
[the remote report](REMOTE-LIVE-20260913.md).

TITANBALL remains experimental: the latest three 6v6 bot simulations all ended in
defender wins and do not establish human balance. Earlier Quest 3 wearer tests
confirmed correct rendering/tracking without shimmer, but these final binaries
have no fresh physical Windows, Quest or Pico test. Isolated Godot shutdown
resource warnings remain. The final two rendering experiments were evaluated and
rejected; they are not incorporated.
