# Design references

Consulted September 10, 2026. Reference art and original map data are not shipped.

- **QuakeWorld Aerowalk:** https://www.quakeworld.nu/wiki/Aerowalk . Reviewed the gameplay discussion and lightning-room screenshot. Its separate armor/mega control points informed dispersed supplies and multiple approach heights. New routes use ramps instead of depending on teleport tactics or QuakeWorld air control.
- **QuakeWorld DM6:** https://www.quakeworld.nu/wiki/Dm6 . The guide's discussion of a small number of powerful resources informed distinct armor/weapon rooms and alternative circulation routes. The collection does not copy DM6's rooms or item coordinates.
- **SkullTag:** https://zdoom.org/wiki/Skulltag_features . Reviewed its multiplayer/respawn and compatibility behavior as a reminder to design around the actual game's pickup, movement and spawn rules. The new maps require no ACS scripts, SkullTag-specific actors or weapon-stay assumptions.
- **FortressOne:** https://www.fortressone.org/ . Reviewed the class descriptions and the first gameplay screenshot's broad fortified entrances, split exterior paths and clear team identity. These informed spacious TF approaches, sheltered resupply and strong base colour; none of the screenshot's geometry was traced.
- **Original TF entity specification:** original TeamFortress v2.8 `tfortmap.txt`, consulted locally with the prior local map conversions. The new collection uses FPSloppa's already-supported native team/flag/resupply/capture entities, without original QuakeC trigger chains.
- **LibreQuake:** https://github.com/lavenderdotpet/LibreQuake and https://github.com/lavenderdotpet/LibreQuake/releases/tag/v0.09-beta . Existing developer WADs, contributor notices and map sources were inspected for the project's masonry, industrial panelling, trim and floor scale. Only licensed texture pixels are reused; new geometry is independently generated.

The broader Doom II/SkullTag influence is compact room-and-courtyard circulation, readable supplies and short return-to-combat routes. DoomWiki's requested MAP07 page was unavailable during research, so no claims here depend on that page or a newly watched Doom demo. No recorded demo was used as evidence of the new maps' competitive balance.

The revised lighting uses ericw-tools' documented supersampling, dirt/occlusion, bounce and embedded RGBLIGHTING options: https://ericwa.github.io/ericw-tools/doc/light.html . These compiled values now illuminate the generated arenas in Godot, with a brightness lift for VR. Original Doom/Quake architectural cues are layered panel bands, stepped masonry entrances, contrasting sky courts and shaded corridors; no original texture pixels or map geometry were copied.
