# Final map and asset expansion — 0.22v

The content selection is closed. Future changes are limited to necessary fixes;
no additional maps or experimental conversions are planned for this expansion.

Requires FPSloppa 0.22v or later. Earlier binaries lack the converted Assault
objective support and expanded rotation capacity. The expansion is a data
archive, not an executable or a replacement game build.

## Contents

- 22 Tribes 2 Classic ST maps with prepared lighting, fog/weather and ambience.
- 14 converted DE maps with baked lighting and material penetration profiles.
- 31 classic arenas: 22 Q30 maps, six native Quake RCMD maps, three supplied BSPs.
- Seven ChaosUT KOTH maps, retaining fixed or rotating authored hills.
- Four UT Assault maps: Pumpfac, Skyville, Twintower, Atlantica.
- Prepared map scenes, lossless baked lightmaps, colour mip chains, BC7/ASTC
  colour variants, navigation, and ST vehicle/runtime assets.
- Original author notices, conversion provenance and validation reports.

Combined lists include the existing base maps first, followed by the new maps.
The 32 original base maps remain supplied by the game; this archive contains
78 new map BSPs. DE/ST maps also remain in the base bundle, as previously
requested. AS has six maps total, KOTH eleven, ST twenty-five and DE sixteen.
The ten retired RCMD Q2/Q3/Quetoo adaptations, legacy DE maps and excluded Dust2
variants are absent. Unfinished TF conversion experiments and other AS
candidates are excluded.

## Installation

Close the game. Extract the ZIP into the FPSloppa installation directory so
`maps/` sits beside the executable. For a source checkout, extract into `Godot/`.
On Android, use the game's external asset directory under
`Android/data/org.entryway.arena.quest/files/` (Pico uses `org.entryway.arena.pico`).
The matching game build provides the scripts and shared rendering resources.
Runtime-art copies in `deathmatch/` accompany the source assets; they do not
patch scripts or replace resources inside an older PCK/APK.

The archive replaces the standard `maps/*_maplist.txt` files with combined
rotations. Back up customized lists before extraction. It does not include or
replace `server.cfg`, preferences, recordings, downloaded player maps or music.
Explicit server-config map lists take precedence over the installed text lists.
All default lists fit the 0.22v limit of 128 maps.

`maps/FinalExpansion/manifest.json` contains the frozen selection and SHA-256
for every payload file; the release also includes the ZIP checksum. Original
source licenses remain in force; conversion does not relicense map artwork.

## Validation and limits

Objective validation exercises supported switches and destructible targets in
sequence, defender/future-objective rejection, and both attack/defend legs.
Connectivity validation is distinct from competitive balance or bot performance.
The classic arena report identifies partial route coverage and includes an
additional eight-map list whose spawn networks are fully connected. KOTH
Buttnutt has verified routes but its short combat test did not demonstrate hill
scoring. In the 90-second AS bot smoke tests, Atlantica reached stage 3 and
Skyville stage 2; Pumpfac and Twintower did not progress objectives, and
Twintower recorded no shots. Scripted objective acceptance passes all four,
but those short bot runs do not establish full-match AI performance. These
limitations remain visible in the included reports.

UnrealScript actors/effects are not executed. Missing retail texture packages
use documented project replacements. Chaos weapons become classic pickups;
warp zones use ordinary teleporters. Assault touch controls become native
switches, damage objectives become native destructible targets, and rotating
wall levers retain static artwork alongside the working objective control.
