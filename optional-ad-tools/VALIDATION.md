# AD local adaptation validation

Validated on 2026-09-10 with Godot 4.7.2, Linux. No headset frame-rate claim.

Screened 26 non-test top-level maps from AD 1.80 patch 1; excluded 12 test maps and all prop BSPs. Installed 16 local arena adaptations. Eight exceed byte/geometry budgets; two fail suitable navigation screening.

Final game-runtime checks passed on all 16 maps: 245 spawn positions, 7695 spawn-to-objective/pickup routes, and 962,886 finite nondegenerate render triangles. All retain an embedded RGB bake and fit the 25 MB cap. Twenty masked-material batches retain transparent pixels. CC/IG pickup suppression and TF/CTF/KOTH objective registration passed.

| Map ID (prefix `ad_arena_`) | MB | Suggested experimental modes |
|---|---:|---|
| `ad_ac` | 11.24 | DM, TDM, IG, FT |
| `ad_akalakha` | 7.87 | DM, TDM, IG, FT, KOTH, CC, CTF, TF |
| `ad_chapters` | 7.46 | DM, TDM, IG, FT, KOTH, CC, CTF, TF |
| `ad_crucial` | 17.53 | DM, TDM, IG, FT |
| `ad_dm1` | 3.83 | DM, TDM, IG, FT, KOTH, CTF, TF |
| `ad_dm5` | 7.24 | DM, TDM, IG, FT |
| `ad_e1m1` | 5.53 | DM, TDM, IG, FT, CTF, TF |
| `ad_e2m2` | 7.20 | DM, TDM, IG, FT, CTF, TF |
| `ad_e2m7` | 5.59 | DM, TDM, IG, FT |
| `ad_metmon` | 4.62 | DM, TDM, IG, FT, KOTH, CC, CTF, TF |
| `ad_mountain` | 7.16 | DM, TDM, IG, FT, KOTH, CTF, TF |
| `ad_obd` | 8.21 | DM, TDM, IG, FT, KOTH, CC, CTF, TF |
| `ad_s1m1` | 5.13 | DM, TDM, IG, FT, KOTH, CTF, TF |
| `ad_scastle` | 5.04 | DM, TDM, IG, FT, CTF, TF |
| `ad_zendar` | 10.16 | DM, TDM, IG, FT, KOTH, CTF, TF |
| `start` | 13.25 | DM, TDM, IG, FT, KOTH, CC, CTF, TF |

Bot movement checks ran for 600 physics ticks per map with three bots. Teleports/respawns were excluded from movement distance. These establish basic movement, not competitive AI or complete map coverage.

- `ad_arena_ad_akalakha`: 158.3 m combined movement.
- `ad_arena_ad_dm1`: 203.3 m combined movement.
- `ad_arena_ad_zendar`: 201.6 m combined movement.

Graphical previews inspected Ak-Alakha, Crucial Error, Place of Many Deaths and Zendar. The preview caught and prompted a fix for palette-index-255 cutouts (cobwebs/vines) in the importer and baked-light shader. Original-map regression `dm_cindercoil` passed 171 navigation routes plus geometry, floor and light-bake checks; the baked-light unit test passed, including masked/opaque material behavior.

## Excluded non-test maps

- `ad_azad`: After removing PVS: 24672228 bytes; excessive geometry lumps [12, 13]. Game limits retained.
- `ad_end`: No connected component with eight clear positions; Godot errors or nonzero exit 1; see log
- `ad_grendel`: After removing PVS: 13613366 bytes; excessive geometry lumps [13]. Game limits retained.
- `ad_lavatomb`: After removing PVS: 19175602 bytes; excessive geometry lumps [13]. Game limits retained.
- `ad_magna`: After removing PVS: 24028508 bytes; excessive geometry lumps [13]. Game limits retained.
- `ad_necrokeep`: Godot errors or nonzero exit 0; see log
- `ad_sepulcher`: After removing PVS: 39371720 bytes; excessive geometry lumps [3, 12, 13]. Game limits retained.
- `ad_swampy`: After removing PVS: 23853960 bytes; excessive geometry lumps [13]. Game limits retained.
- `ad_tears`: After removing PVS: 76275492 bytes; excessive geometry lumps [12, 13]. Game limits retained.
- `ad_tfuma`: After removing PVS: 19508919 bytes; excessive geometry lumps [13]. Game limits retained.

`ad_end` lacks an eight-position connected arena. `ad_necrokeep` triggers a Godot navigation corridor error and remains quarantined, even if some individual paths appear to work. No geometry or upload limits were increased.

## Local outputs and limits

External maps live in `maps/`; private originals/notices are under `maps/AD-NOTICES/`. The full preparation, per-map validation, final-runtime, bot and screenshot artifacts are in the selected `AD-Local` output directory. Default rotations were preserved; use the optional `<mode>_ad_maplist.txt` files or `ad-maplists.cfg` after local playtesting.

These are simplified, asymmetric arena adaptations. Unsupported AD scripts, encounters, external decorations and ambient sounds are omitted. Embedded art retains its original rights; new flame fixtures use LibreQuake. No converted AD BSP is included in Git or public release packages. Standalone performance, full traversal of every original region and competitive balance remain unverified. See [conversion instructions and rights](README.md).
