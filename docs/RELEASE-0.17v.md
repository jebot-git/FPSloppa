# FPSloppa 0.17v — bomb defusal, physical reloads and Cindercoil

DE adds round-based bomb defusal with team-specific CS-inspired purchases, five
classic-layout BSP29 map studies, surface planting and VR defusal interactions.
The bomb is visible on its carrier's chest; only surviving terrorists can recover
a dropped bomb. Dead players can spectate and talk to each other separately from
living players. Weapon pickups require Use and replace the occupied slot.

- Added CS-inspired weapons with rebuilt models, aligned sights, chamber actions,
  existing knife/scope mechanics, grenades and an optional virtual stock.
- Added the persistent joystick weapon wheel and contextual hip magazine pouch.
  VR reloads use offhand magazine insertion, racking, pumping and box-lid actions.
- Added Cindercoil, a circular ascending Titanball route with inner traversal
  tunnels, towers, overpasses and resupply stations.
- Added optional arena jetpacks with megahealth pickup timing and improved arena
  weapon respawn rules, death drops, lobby voting and stair prediction.
- Added native optional avatar spring simulation, tracking/hip attachment fixes,
  rendering optimizations and complete texture mip chains. Map caches retain BC7
  desktop and ASTC mobile compression.
- Added static foveation controls and gaze-driven fovea-size controls when the
  runtime exposes supported eye tracking. Quad-view rendering is not implemented;
  runtime and headset support still determine the available foveation path.
- Fixed desktop grenade holds releasing between input packets and unintentionally
  firing the holstered weapon.
- Restored the original soundtrack; DE alone receives the new orchestral cue.
  The optional Amiga soundtrack and the global recomposition are removed.

## Downloads

Linux and Windows clients, Linux dedicated server, Quest APK, self-contained
source and the standalone master server. The clients include 32 base maps and
three base avatars. The DE maps are original layout studies with documented
fidelity limits, not converted Valve map binaries.

Use matching 0.17v clients and servers: protocol `fpsloppa-45-de-utility`.
Quest Android version code is 22. Existing configurations remain usable; DE
and experimental jetpacks are configured as described in the included guides.

## Validation

Release checks cover gameplay, tracking fixtures, DE objectives and pickups,
physical reloads, texture imports, compressed map caches, local networking,
the console server, archive contents and signatures. See
`docs/validation/release-0.17v.json` for the final results.

Linux rendering and automated VR input fixtures are tested locally. This release
does not claim a fresh native Windows or physical-headset playtest. Eye-tracking
transport availability and live VR comfort still require hardware validation.
