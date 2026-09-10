# ThreeWave local conversion tools

This optional download contains the converter and 15 BSD-3-Clause LibreQuake
texture assets. It does **not** contain ThreeWave BSPs, id Software textures,
Quake code, sounds, models, or the commercial game's maps.

Obtain the original `3wctfc.zip` client archive separately:
https://github.com/Jason2Brownlee/ThreeWaveCTF/blob/main/bin/3wctfc.zip
The original author's current archive page is https://threewave.com/threewave-ctf.

ThreeWave is used here for non-commercial local testing and server use, as
specified by the project owner. Converted BSPs are intentionally excluded from
the GitHub repository and release downloads. Only these tools, instructions,
and LibreQuake texture assets are published. Keep the original ThreeWave
readme and observe its non-commercial terms; no ThreeWave map is relicensed
as BSD, CC0, or as part of FPSloppa's authored code.

The converter processes only `ctf2m1` through `ctf2m6`. It excludes the id-authored
`ctfstart`, `ctf2m7`, and `ctf2m8`, plus the older pack with its stale beta notice.
Authors: Dave “Zoid” Kirsch; John “Tattoo” Schultz; Dale “midiguy” Bertheola;
Ogre “El_Ergo” De Latoya; Hexadecimal; Alexander Bernecker. Retain their original
archive/readme. No ThreeWave asset is relicensed as LibreQuake.

Run:

    python3 convert.py /path/to/3wctfc.zip --output /path/to/FPSloppa/maps

Rescan folders in the game, then add desired `threewave_ctf2m*` IDs to
`maps/ctf_maplist.txt`. The converter refuses to overwrite existing maps.
It replaces every mip level, preserving BSP structure and texture dimensions.
`ThreeWave-local-conversion.json` records both source and result hashes and
texture provenance. FPSloppa reads native red/blue flag and team-spawn entities.
Doors (including secret doors) use proximity activation; QuakeC scripting,
button chains and the ThreeWave grapple/runes are not implemented.

The LibreQuake subset comes from the v0.09-beta developer WADs. Original
BSD license and contributor notices are retained alongside the converter.
The authored conversion script is offered under CC0 1.0:
https://creativecommons.org/publicdomain/zero/1.0/ . This applies to the script
only and grants no rights to ThreeWave map assets.
