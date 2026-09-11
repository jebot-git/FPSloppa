# FortressOne local conversion and acceptance tools

These tools adapt four pinned BSP29 maps from the official FortressOne map repository: Bam4, Openfire, 2mach1 and 2castle1. The source URLs, revision and hashes are in `sources.json`. No original BSPs, models, sounds or textures are included here. Tools are CC0; the supplied texture WAD is LibreQuake material under the accompanying notices.

**Converted maps are not cleared for redistribution.** Keep downloads and conversions outside the public repository and release packages. Availability in FortressOne does not establish permission to redistribute a retextured derivative. Bam4 and 2mach1 have no derivative grant in their supplied readmes; Openfire's package lacks an author readme; 2castle1 permits free sharing with credit but does not explicitly address modified versions. H4rdcore, Xpress, Aztec1 and Rock2 were excluded because their readmes expressly prohibit unapproved modification.

From the Godot project directory:

```sh
python3 tools/fortressone/fetch.py ../Builds/FortressOne-Local/sources
python3 tools/fortressone/convert.py ../Builds/FortressOne-Local/sources/bam4/bam4.bsp --output ../Builds/FortressOne-Local/maps
# Repeat conversion for openfire, 2mach1 and 2castle1.
python3 tools/validate_converted_traversal.py --directory ../Builds/FortressOne-Local/maps --results test-results/fortressone-traversal
python3 tools/validate_fortressone_playtest.py ../Builds/FortressOne-Local/maps
```

The graphical test needs a working display/GPU and runs the current Godot project. Both runners return a failure status for rejected maps. The graphical test captures both teams' spawn and flag views, checks native TF objectives and class resupply, audits bot walking routes and simulates three bots for 20 seconds. This does not establish headset performance, long-match balance or network interoperability.

The converter verifies the reviewed source hash, enforces the 25 MB BSP limit, substitutes every embedded mipmap with LibreQuake pixels, fills missing texture slots, preserves geometry/collision/lightmaps, normalizes TF aliases and adds native flags/capture zones and spawn-room resupply. It uses embedded entities rather than executing FortressOne `.ent` overrides or QuakeC. Output JSON records each objective adaptation. Classic scripted team barriers, special button chains and Quake-specific scoring are not reproduced. Original readmes remain alongside downloaded sources; retain these with any local test installation.

Base-map acceptance requires traversal, usable objective routes, visual review **and** a suitable redistribution grant. No map is automatically promoted by these tools. See `docs/FORTRESSONE_MAP_REVIEW.md` for results. To regenerate the 24 wider architectural views and inspect flag rooms without standing inside the flag model, run the graphical runner with `--preview-only`.

## Turtler inspection

`turtler` is pinned in `sources.json`. Fetch its BSP and `.ent` together and run the existing converter. The BSP sets both flags to owner 2; the converter applies only the flag ownership correction from FortressOne's verified entity sidecar. Its existing lightmaps are enabled. Original custom model/sound assets are not copied; the game supplies native flags and effects.

The archive package has no map-specific readme/license, and the repository README supplies no redistribution grant. It remains local only, not a base TF map. The local conversion passes traversal and native TF capture/drop/resupply checks, but fails the complete bot walking-route acceptance check. See `docs/TURTLER_REVIEW.md`.
