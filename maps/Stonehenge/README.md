# Stonehenge — BSP29 terrain study

An experimental recreation of **Starsiege: Tribes Stonehenge**, designed on the
assumption that the Tribes movement test loadout supplies skiing and an energy
jetpack. Select **ST — TRIBES → Stonehenge** in the source build.
The installed map ID is `ctf_stonehenge`. It is optional and is not added to the
shipped map rotations or the 0.18v release.

The self-contained [BSP29 map](../ctf_stonehenge.bsp) contains geometry, all four
texture mip levels and embedded RGB lighting. Its editable source is
[ctf_stonehenge.map](ctf_stonehenge.map), with [stonehenge.wad](stonehenge.wad).

## Layout and movement assumptions

- 704 × 704 m of asymmetric terrain, cropped around the reference mission's
  600 × 600 m playing area. Horizontal scale is preserved: one Tribes metre is
  one game metre, or 32 Quake units.
- Flags are approximately 448.5 m apart, including their elevation difference.
  The blue flag is about 17 m higher than the red flag, as in the reference.
- Two concrete inventory bunkers, separate open flag gantries, two forward
  tower positions and the large neutral central arch use seven recovered
  structure anchors. Architectural dimensions and details are approximate.
- Eight clear team spawns per side face the bunker exits. Native CTF flags
  retain two unobstructed flight axes. Each team has two functioning inventory
  stations instead of the former placeholder health pickups.
- Invisible collision bounds enclose a 700 × 700 m playable area, two metres
  inside the terrain edge, from -24 to 320 m elevation. The jet ceiling prevents
  flying over the perimeter; navigation is baked inside these bounds.
- Three planning corridors are recorded in `probes.json`: western valley,
  eastern valley and midfield. Their sampled terrain lengths are about 569,
  715 and 393 m. They include natural climbs, bowls and launch ridges. They are
  route candidates, not recovered competitive Tribes ski routes.
- Base entries, flag platforms, roofs and tower tops assume jetpack access.
  There are no added arena stairways or teleports to flatten this design into
  the existing walking rules. ST supplements the walking cache with basic outdoor jet/ski routes.

The **TRIBES · classic arsenal** loadout supplies skiing, sustained jets, personal
energy and the dedicated arsenal. See [movement controls](../../docs/TRIBES-MOVEMENT.md)
and [CTF station/economy rules](../../docs/STONEHENGE-CTF.md). The existing TF class
menu saves station favourites. Walk onto a friendly pad to open the inventory
wheel on desktop or VR; B and the weapon wheel also allow manual access.

`info_tribes_inventory` entities provide runtime stations; `info_playable_bounds`
provides identical invisible collision on servers and clients, without relying
on sky faces (the importer omits those). In ST, generator housings power the inventory pads and support damage and repair.
Fixed medium pulse sensors are powered, damageable and repairable; fixed turret
sockets remain decorative. Inventory stations take independent damage and repair.
See [base infrastructure](../../docs/TRIBES-INFRASTRUCTURE.md). Seven portable deployable
types, including automated remote turrets, are available through the inventory
system; see [deployables](../../docs/TRIBES-DEPLOYABLES.md) and
[ST rules](../../docs/ST-TRIBES.md).

## Reference fidelity

Terrain comes from the [Stonehenge heightmap in Levi Zoesch's mapping
repository](https://github.com/levizoesch/tribes.mapping/blob/main/v1.0.8/heightmaps/CTF/Stonehenge.png).
That repository identifies the height scale as 170 and sample spacing as 8 m.
The source PNG and its MIT notice are retained here. Its orientation and datum
were checked against ground markers in the [KingTomato Stonehenge paintball
mission](https://github.com/kingtomato/tribes.maps/blob/master/paintball/PB_Stonehenge.mis).
Reference URLs, revision IDs, hashes and the selected object records are in
`references.json`.

The available mission is a community variant. Its additional paintball cargo
and bridge network are omitted. Original retail interior meshes were not
available for direct comparison, so the bunkers, gantries and monolith are
brush reconstructions rather than exact conversions. The finite crop replaces
the original engine's repeating terrain. No rain or distance fog is added.

The initial 8 m terrain compile exceeded BSP29's edge limit. The installed
version uses **16 m shared-vertex triangles**, quantized to 1/32 m. Against the
bilinearly sampled reference, 30,976 samples at 4 m spacing measured a mean
absolute height difference of **1.22 m**, a 95th percentile of **3.54 m** and a
maximum of **10.51 m**. These are substantial local differences: exact original
ski lines are not preserved. Structure anchors retain their reference positions.
Phong-baked sunlight softens terrain lighting; physical collision remains the
same piecewise-planar surface.

## Rebuilding and checking

Requires Python with NumPy/Pillow, ericw-tools 0.18.1 and Godot 4.7.2. The included
WAD makes regeneration independent of the larger local texture archives.

```sh
python3 tools/stonehenge/build.py --compiler /path/to/ericw-tools/bin
godot --headless --xr-mode off --path . --log-file test-results/stonehenge/prepare-engine.log --script tools/stonehenge/prepare.gd
godot --headless --xr-mode off --path . --log-file test-results/stonehenge/acceptance-engine.log --script tools/stonehenge/acceptance.gd
godot --path . --xr-mode off --rendering-method mobile --rendering-driver vulkan --script tools/stonehenge/preview.gd
```

The builder checks a sealed draw hull, BSP29 header and the project's 25 MB
import limit, then registers only this optional CTF entry. `-noclip` omits
unused Quake player hulls: FPSloppa collides with the BSP draw triangles.
Full VIS and lighting are compiled. The open landscape is largely visible at
once; the cached importer batches it into a small number of material surfaces.

Preparation writes compressed raw, BC7 and ASTC caches, verifies unchanged
geometry/collision across texture compression, and bakes conservative ground
navigation. The reduced navigation merge raster avoids overlapping edge keys
on the large terrain. All caches are disposable and keyed to the BSP hash.

Acceptance checks actual importer collision against terrain samples, clear
spawn/equipment capsules, swept landings at 30/60/100 m/s, flag flight paths and
native CTF take/capture behavior. Swept collision tests do **not** establish
ski momentum, energy balance, multiplayer prediction or headset comfort.
Rendered views and detailed logs are under `test-results/stonehenge/`; the
retained validation receipt is `validation.json`.

The original terrain acceptance run passed 60 checks, including 769 terrain samples, 18 swept
landings, 12 flag flight paths and flag captures by both teams. The standalone
OpenGL previews rendered 60,501 primitives in seven draw calls; this is not a
headset performance measurement. All eight embedded textures have four mip
levels. The compiler also emits one unused missing-texture slot, referenced by
no faces. The original native test reported texture/ObjectDB leaks at process shutdown;
no navigation synchronization warnings occurred in the final run.

Retained views: [red base](preview-red-base.png), [terrain overview](preview-overview.png).

## Credits

Original Stonehenge map and Starsiege: Tribes: Dynamix/Sierra. This is an
unofficial layout/terrain study, not an original-layout or exact-retail claim.
Heightmap reference repository: Levi Zoesch Sr., MIT (see `heightmap-MIT.txt`).
Mission-reference archive: KingTomato, paintball adaptation of Stonehenge.
Reconstructed brush architecture and build tooling: FPSloppa contributors.

Textures retain their original records and notices: Makkon materials by Ben
“Makkon” Hale (palette/LUT credit ptoing; included license and project permission)
and LibreQuake BSD-3-Clause. `texture-sources.json` identifies every texture.
The collection is not collectively CC0.
