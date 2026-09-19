# Fixed-hill KOTH remodel study

Historical design study, reviewed 12 September 2026. The fixed-hill decision below was superseded on 19 September by [30-second rotating hills](KOTH-ROTATION.md).

Reviewed 12 September 2026. This is a map-design adaptation of the original Quake II OSP hill-holding idea to FPSloppa's existing two-team rules, not a port of OSP code or a claim to reproduce its exact scoring rules.

## Sources and limits

- [GamePro, August 1998, NetPro: Quake II Online Aftershocks](https://dondeq2.com/2019/01/21/netpro-quake-ii-online-aftershocks-by-dan-elektro/) describes finding, claiming and defending one focal location. It explicitly gives building interiors and a floating pirate-ship deck as possible hills. The scanned KOTH screenshot on page 32 shows a stone interior with an on-hill HUD message. The scan was inspected, rather than relying on the article's imperfect OCR. This supports a recognisable hold space, not necessarily a literal mound.
- [Contemporary Quake II FAQ](https://groups.google.com/g/alt.games.quake2/c/FTTxbYB7VMo) identifies King of the Hill as the defend-the-hill deathmatch modification and points to Orange Smoothie Productions.
- [ModCentral contributors' favourite mods](https://mrelusive.com/oldprojects/gladiator/reviews/ModCentral/Modcentral%20Favorite%20Mods.htm) describes accumulated hill time and custom maps. A contributor describes sniping at the hill from outside it: useful evidence that approach sightlines and off-hill pressure matter.
- [Orange Smoothie Productions, wiki-derived history](https://en-academic.com/dic.nsf/enwiki/2117087) places the Quake II KOTH project's origin in February 1998. Used for historical identification, not as a detailed rules specification.
- [Webman & Twist's map collection](https://dondeq2.com/2017/10/24/webman-twists-map-collection/) lists period KOTH maps including Plasma, Dirt Pile, Bishop to King Seven and Hamburger Hill. These are context, not maps that were downloaded or copied for this work.
- [Video: Quake 2 King of the Hill 15 – Part 2, TastySpleen Studios](https://www.youtube.com/watch?v=j4sKdzaGOZc), 6 May 2010. Inspected gameplay at 1:30–2:00 and extracted frames. **This is a duel event called King of the Hill, not footage of the OSP hill-holding mod.** Its two-player scoreboard and The Edge combat distinguish it. It informed only general Quake II observations about vertical combat, exposed crossings and rocket pressure. It is not evidence for OSP scoring or map objectives. Authentic OSP-mod video was not located in the reviewed results.

Reference screenshots and video excerpts were inspected locally and are not redistributed with the game.

## Design decisions (inferences from the study)

Keep one fixed landmark throughout a round. Give attackers several ways to pressure it, leave room to fight inside the score radius, preserve useful surrounding routes, and keep supplies outside the hold area. Avoid turning the objective into a fortified supply closet. Use level scoring floors even where the surrounding map has slopes, pits or catwalks.

The original FPSloppa team rules remain: one uncontested point per second, both teams present pauses scoring, normal hill limit and time limit. There is no attempt to introduce original OSP individual scoring. The former accumulated-points relocation and its network state are removed. Old `koth_move_points` config lines are accepted but ignored.

## Four derivatives

All four derive from ZungryWare's LibreQuake v0.09-beta sources. Their surrounding topology remains, with horizontal dimensions widened by 1.5 for team combat. Heights and entity linkage remain in the original scale. The new hill platforms, approach ramps and low corner cover are added geometry, not relocated markers alone.

| KOTH map | Source | Changed objective area |
|---|---|---|
| Solstice Crown | lqdm1, Solstice | Raised stone courtyard platform, four broad approaches; castle/garden loop retained. |
| Torture Crucible | lqdm2, Torture Pit | Dry lower chamber dais and ramps toward surrounding galleries; equipment outside the score circle. |
| Hyperborea Tribunal | lqdm3, Hyperborea | Temple-court platform and graded crossings toward the colonnade and outer grounds. |
| Alichar Overload | lqdm8, Alichar Sector | Enlarged upper industrial deck with three ramp approaches; lower level and lift routes retained. |

The hill radius remains 3 metres. Platforms extend beyond it; corner baffles sit outside the scoring circle. Nearby original pickups and starts are removed. New starts are selected from clear, level, capsule-sized positions with verified walking routes, then divided between teams using alternating pairs ordered by route length. Existing outer weapons, armour and health retain their supply role. None of these edits alter the original maps used by other modes.

Upstream Hyperborea also leaked when compiled unchanged with ericw-tools 0.18; Alichar's derivative did too. Exterior structural sealing beyond the authored geometry allows visibility/light compilation without replacing playable interior walls. Final BSPs have baked lighting, scene caches and navigation meshes. The existing LibreQuake-to-Makkon texture mapping is applied, with original donor texture records retained. The shared WAD contains only the four maps' used textures and animation companions (155 textures, about 5.1 MiB), not the full texture packs.

## Validation and remaining playtest work

Reproducible tools are in `tools/koth/`. `validate.gd` checks catalog/host/vote filtering, level hill floors, eight scoring-circle floor samples and every team spawn's navigation route. `rules.gd` checks legacy configuration, scoring beyond the old movement threshold, contention, takeover and snapshot stability. Bot matches use the normal physics/combat harness. See `maps/KOTH/VALIDATION.md` for final results.

These checks establish reachability and functioning matches, not competitive balance. Human matches, especially at 16 players and in VR, should assess spawn pressure, sightline dominance and whether the upper industrial deck needs another flanking connection.

Final verification: 75 geometry/catalog/menu assertions and 8 focused rule/transition assertions passed. Four three-minute eight-bot matches plus a final three-minute Hyperborea repeat passed without runtime errors. The dedicated-server/RCON regression passed, including the configured KOTH subset and 16-player capacity. All 220 entries in the refreshed local base-assets archive match its manifest; current KOTH files match those packaged entries. The broad legacy `post010.gd` run passed its fixed-hill assertions but initially failed its reused base-install checksum check while the asset archive was stale; the final archive was verified independently rather than treating that earlier broad run as a clean pass.
