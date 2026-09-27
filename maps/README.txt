FPSloppa external map library

Place BSP29/BSP2 files directly in this folder, then choose ASSETS -> RESCAN.
Leave the .bsp extension on the file; maplists refer to the filename without it.
Each mode has its own <tag>_maplist.txt (dm, tdm, ctf, koth, ig, ft, cc).
Server config <tag>_maplist settings override the corresponding file.

Downloaded and uploaded BSP files persist as custom_<SHA256>.bsp. Validated
Godot scenes are cached under cache/; no executable scene is sent over the
network. Base cache/ and navigation/ files are provided for faster loading.
Only known default assets are included in release archives; personal imports
are never repackaged by the release builder.

Optional packs: copy their BSPs here, preserve their readmes/licenses, and add
the map IDs to the modes in which you want to play them. Default game maps and
textures are LibreQuake BSD-3-Clause; see LibreQuake-COPYING.txt and credits.

Assault layouts
The default as_hislop and as_frigate maps use the expanded layouts.
Only full-size HiSlop and Frigate are distributed for AS. Tiny variants are
excluded from the distribution catalog and asset bundles.

Team Fortress layouts
Only tf_pressureworks and tf_vesper are distributed for TF and appear in its
default rotation. Their sources, screenshots and notices are in Pressureworks/
and VesperAbbey/. LibreQuake maps remain available for the other game modes.

Makkon textures by Ben "Makkon" Hale are used in the expanded Assault maps and
reviewed community adaptations. See Makkon/Makkon_License.txt and per-map
texture-sources.json; these assets are not BSD/CC0. Community Lasercade and
Painful Memories are available for DM-family modes; community_dm_maplist.txt
is an opt-in list for playtesting. Author readmes are in Community/.

Additional reviewed Quaddicted adaptations: Ancient Tomb by RandyG, Ancient’s Hall by Andrew “HamsterDeath” LeGalle, and Battle Field by Adam Boyle. Original readmes and per-texture credits are retained in maps/Community. Makkon Industrial/Metal textures by Ben “Makkon” Hale (palette/LUT: ptoing) also theme the maintained LibreQuake maps and Ironspan/Relayworks; see maps/Makkon and the separate Makkon licence. Only used original texture records are packaged.

CTF Studies: six newly authored adaptations of original ThreeWave CTF1-CTF6.
ctf_tideworks, ctf_crucible, ctf_confluence, ctf_deepvault, ctf_crownreach,
ctf_skyfracture are native CTF maps. See CTFStudies/README.md for sources,
material licences and limitations. Original reference assets are not included.

TITANBALL layout
The TB rotation contains tb_ashfall (Ashfall Boulevard), a sealed original
ruined-city BSP, and tb_cindercoil (Cindercoil), a circular climbing industrial
road with connecting tunnels and overpass towers. Both preserve the 350 m TB
route and standard spawn/checkpoint/resupply rules. Editable MAP/WAD, build
manifests and notices are in Ashfall/ and Cindercoil/.
This does not add any maps to the TF rotation.

Classic Dust2 reconstruction (experimental)
de_dust2_rebuilt is an independently brushed BSP29 study for DM-family modes.
Source MAP/WAD, build notes and validation are in Dust2Rebuilt/. Select it for
practice or add it to a personal mode maplist; default rotations are unchanged.
This is an approximate classic layout, with no bomb-defusal rules.

Classic DE expansion
Nuke, Inferno, Aztec and Train are original BSP29 layout studies for DE.
See ClassicDE/README.md for source, build steps, attribution and fidelity limits.
