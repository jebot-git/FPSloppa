# Reviewed community maps

Reviewed 12 September 2026. Slipseer candidates must have a displayed rating of **at least 3/5**; unrated and lower-rated maps are excluded. Ratings alone do not establish redistribution rights.

| Installed adaptation | Author / source | Rating | Suggested players |
| --- | --- | --- | --- |
| `dm_lasercade_slop` — Lasercade | shysaur; [Slipseer](https://www.slipseer.com/resources/dm-lasercade.415/) | 4.67/5, 3 ratings | 4–8 (initial recommendation) |
| `dm_auhdm2_slop` — Painful Memories | Toni Jaume (Auhsan); [Quaddicted archive](https://www.quaddicted.com/files/maps/multiplayer/auhdm2.zip) | Not applicable to Quaddicted | 2–4 (author's recommendation) |

| `dm_anctomb_slop` — Ancient Tomb | RandyG; [Quaddicted](https://www.quaddicted.com/files/maps/multiplayer/anctomb.zip) | Not applicable | 3–6 (author) |
| `dm_anchall_slop` — Ancient’s Hall | Andrew “HamsterDeath” LeGalle; [Quaddicted](https://www.quaddicted.com/files/maps/multiplayer/anchall.zip) | Not applicable | 4–8 (estimate) |
| `dm_battlef_slop` — Battle Field | Adam Boyle; [Quaddicted](https://www.quaddicted.com/files/maps/multiplayer/battlef.zip) | Not applicable | 4–8 (estimate) |

All five authors explicitly permit using their levels as a base for additional levels and distributing the BSP. Their readmes are included **byte-for-byte** under `maps/Community/<id>/ORIGINAL-README.txt`. Every original embedded image is replaced by a separately licensed Makkon or LibreQuake texture; original player skins and other unrelated assets are excluded. Makkon records are unmodified. Geometry, collision, VIS, gameplay entities, pickup positions and original lighting data are retained; titles identify the adaptations, and original lighting is enabled in the Godot renderer. Lasercade's coloured `.lit` data is embedded in the BSP for automatic server downloads.

The maps appear in the Host/map catalog for DM, TDM, Instagib, Freeze Tag and Chainsaw Carnage. They have no authored CTF/TF/Assault objectives. They are not added to established server rotations before live balance testing. To try the supplied five-map list:

```cfg
set sv_gametype "dm"
set map "dm_lasercade_slop"
set dm_maplist "dm_lasercade_slop dm_auhdm2_slop dm_anctomb_slop dm_anchall_slop dm_battlef_slop"
```

`maps/community_dm_maplist.txt` also lists the IDs. FPSloppa proximity doors/lifts replace Quake-specific activation semantics; Lasercade's button/relay/counter scripting is not emulated, and animated arcade screens, waterfall frames and shootable-button frames use static counterparts. These are adaptations, not claims of identical Quake behaviour. Automated spawn/pickup/navigation/teleport tests and desktop rendering checks do not replace multiplayer playtesting.

```sh
python3 tools/makkon/fetch.py
python3 tools/community_maps/fetch.py
python3 tools/community_maps/build.py --bake
```

Source archive hashes, source URLs, rating evidence and licence decisions are recorded in `approved.json` and `review.json`. Installed maps carry per-texture hashes and notices under `maps/Community`. Unapproved source archives remain in ignored `local/` and are never packaged.

The reviewed Slipseer alternatives The Complex (4/5), The Block (5/5) and Experimental RC (4.5/5) did not include a clear map redistribution/adaptation grant in their downloads. They are held out. The Block also contains mixed third-party textures. Quaddicted mirrors many historical maps whose readmes allow only intact original archives, forbid modification, or require author contact. Those conditions are not bypassed by their availability on a download index; see the review record for individual decisions.

The dedicated `tf/` archive was checked separately: Amethyst, DeathX, FastFlag and Muskrat2. Their original TF goal logic and individual readme terms are recorded in [the map review](../../docs/MAKKON_MAP_REVIEW.md); none was silently converted into an incompatible two-flag mode. Archive inspection uses the system `unzip` executable.
