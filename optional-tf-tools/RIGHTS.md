# Local TF map conversion

No original Team Fortress BSP, model, sound or texture is included here.

Obtain `2fort5.zip` (including `2fort5.txt`) and `well6.zip` separately. Archived original author readmes are available at:
- https://www.filefactory.org/tf/file/1807 — John Cook and Devin Jenson, 2fort5. Its notice permits original distribution with the readme but expressly forbids modified redistribution without the owner's permission.
- https://www.filefactory.org/tf/file/703 — Jim Kaufman, Well6. No clear permission to redistribute derivatives is supplied.

Therefore FPSloppa does not distribute converted versions. Keep conversions for local testing and non-commercial server use, retain the original notices, and obtain permission before offering a converted-map download publicly. Automatic map transfer to connecting players is distribution too: restrict these local test servers to your authorized private testing audience. The original TF code's freeware provisions are not treated as a blanket map license. No original TF code is used in FPSloppa.

```sh
python3 convert.py /path/to/2fort5.zip /path/to/well6.zip --output /path/to/TF-Local/maps
```

The script refuses overwrites. It replaces every embedded texture mip with LibreQuake indexed pixels, preserves geometry and light data, and substitutes native TF team spawns for the old deathmatch fallback spawns. `TF-local-conversion.json` records source/archive/output hashes and texture provenance. Archive text notices are copied unchanged. Use `--asset-root /path/to/TF-Local` and a TF-only server configuration pointing at `tf_original_2fort5 tf_original_well6`.

FPSloppa adapts native team spawns, flag items, separate capture goals and resupply points. Standard proximity doors and lifts replace scripted behavior. QuakeC trigger chains, team door locks, grate detpacks and non-CTF TF map logic are not reproduced. Validate conversions in the game before use; run the repository's geometry test with `--tf --local-tf /path/to/TF-Local/maps`.

`convert.py` and `texture_replace.py` are original project tools under CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/). The included WAD is a small BSD-3-Clause LibreQuake v0.09-beta subset. Its original license, contributor notices and texture provenance are retained. These grants apply only to the tools and LibreQuake assets, never to the input TF maps.
