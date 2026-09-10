# TF — Team Fortress adaptation

TF is an optional two-team objective mode built on FPSloppa’s arena combat. Select **TF · TEAM FORTRESS** when hosting or starting practice. In a match, open **TF CLASS…** to queue a class; it applies at your next respawn. **E** on desktop, or the movement-hand **A/X** button in VR (mirrored with left-handed controls), uses the class ability and also operates nearby doors. Weapons retain tracked 6DoF aim. Everyone uses the same 0.30 m radius / 1.65 m hit capsule, regardless of class, VRM or disguise.

Each player has a readable class-name badge and class colour above their name. Team colours remain independent. Badges obey walls and disappear on death. A disguised spy deliberately presents the copied class/name/team to enemies; teammates still see SPY. The scoreboard and player identity used for gameplay remain authoritative.

| Class | Health / armor | Speed | Loadout and adaptation |
|---|---:|---:|---|
| Scout | 75 / 25 | 125% | Pistols, shotgun, fist. Three-second sprint; ten-second cooldown. |
| Sniper | 90 / 25 | 90% | Railgun, pistols, fist. Rail costs two bullets and deals 90 before armor instead of instagib. Four-second focus raises it to 150 and halves movement; twelve-second cooldown. |
| Soldier | 150 / 100 | 85% | Rockets, shotgun, fist. Aimed grenade with visible 1.2-second fuse; eight-second cooldown and one rocket cost. |
| Demoman | 120 / 75 | 95% | Rockets, shotgun, fist. Places one visible pipe charge within four metres; use again after arming to detonate. One rocket; eight-second reuse cooldown. |
| Medic | 110 / 50 | 110% | Slower plasma, pistols, fist. Aim at a teammate within six metres to heal 35 HP and extinguish; two-second cooldown. Regenerates three HP per second. |
| Heavy | 200 / 150 | 65% | Chaingun, shotgun, fist. Four-second brace reduces incoming combat damage by 35% and halves movement; twelve-second cooldown. Hazards bypass brace. |
| Pyro | 125 / 75 | 100% | Plasma mesh becomes an eight-metre flamethrower; shotgun and fist. Burning lasts three seconds. Aimed napalm grenade costs 20 cells with a ten-second cooldown. Fire resistance. |
| Spy | 90 / 25 | 105% | Pistols, super shotgun, fist. Six-second cloak copies the nearest enemy’s validated VRM and identity; fourteen-second cooldown. Rear fist attacks deal at least 120 before armor. |
| Engineer | 100 / 75 | 100% | Pistols, shotgun, fist. Choose sentry or dispenser in the class menu. One of each, 60 cells apiece, three-second construction and 120-second lifetime. Aim at a damaged friendly building to repair 40 HP for ten cells. |

Spy disguises instantiate the copied VRM separately: the spy keeps their own skeleton animation, full-body tracking, hands, eye/blink tracking and voice-driven visemes. The existing host-mediated VRM download provides the model; the 25,000,000-byte model limit is unchanged. Until that verified asset is available, the spy keeps their own model. Screen-door cloaking affects the actual skinned meshes and weapons, hides enemy name/class badges and suppresses shadows; teammates see a tinted ghost and the true SPY badge. Attacking, taking damage, carrying a flag, changing class, or the copied player disconnecting removes the disguise. The disguise can remain after the six-second cloak expires. Voice chat still identifies the real speaker.

Sentries fire at visible enemies up to 18 m away, respect spawn protection and are fooled by an enemy-team disguise. Bullets, rails, projectiles and explosions can destroy buildings. Dispensers resupply nearby teammates. Buildings have 150 HP, cannot obstruct player movement, cannot be placed in walls or on spawns/flags, and disappear when their owner leaves or switches team/class. Build/repair and all class actions are server-authoritative and bounded by cooldowns and ammo. Ordinary weapon pickups are ignored in TF to preserve class roles; health/ammo/armor pickups and team resupply remain useful. Supply refills to the class loadout limits, never grants a new weapon.

TF keeps the classic distinction from ordinary CTF: defenders cannot touch-return a dropped flag (it returns after 30 seconds), and a team can score even while its own flag is away. Capture points may differ from flag homes. `capturelimit` counts captures, not individual frags. This implementation omits QuakeC scripting, infection, concussion movement, MIRV clusters, original reload/clip rules, armor types and every historical TF map variant. Grenades are aimed ground deployments with a fuse rather than a recreation of Quake’s grenade physics. It is an independent adaptation, not an exact port or Valve product.

## Maps and hosting

Build the optional packs with `python3 tools/package_tf.py` after map validation. This verifies all four embedded texture mips against LibreQuake, writes the two ZIPs under `../Builds/`, and installs the two original arenas into the source project’s external maps folder.

Install the optional **Original-TF-Arenas** ZIP into the game’s external folders. It supplies `tf_ironspan` and `tf_relayworks`, bot navigation and a suggested `tf_maplist.txt`. Back up an existing TF rotation before replacing it. Select a map and TF in the host menu, or configure:

```text
set sv_gametype "tf"
set sv_gametypes "tf ctf dm"
set tf_maplist "tf_ironspan tf_relayworks"
set capturelimit 5
map tf_ironspan
```

Existing BSPs also work with fallback flag locations and team spawn allocation, although dedicated TF layouts are preferable. Map and custom VRM transfers use the existing external `maps/` and `vrm/` directories. Use matching TF-enabled clients and servers (protocol 15).

The two generated arenas contain original geometry, not decompiled or traced layouts. Their MAP sources and generator are CC0; textures are BSD LibreQuake assets with notices and provenance. Ironspan has three base entrances, sniper galleries, dry flanks and a canal beneath its bridge. Relayworks has separate elevated flag rooms and ground-level capture areas, twin ramp approaches, a central tunnel and two flanks. Both have four team spawns and resupply per side.

Original **2fort5** and **Well6** conversions are local/server-only. 2fort5’s [original notice](https://www.filefactory.org/tf/file/1807) expressly prohibits redistributing modified versions without permission; [Well6’s readme](https://www.filefactory.org/tf/file/703) gives no clear derivative redistribution grant. Only conversion tools and LibreQuake donors are offered publicly. See `optional-tf-tools/RIGHTS.md`. Native TF team spawns, flags, capture goals and resupply are adapted; original team 1 is blue, team 2 red. QuakeC-dependent doors, destructible grates, trigger chains and special scoring are not reproduced.

Automated validation does not establish headset frame rate, long-match balance or comfort. These additions need playtesting on PCVR, Quest and Pico; the owner’s prior 0.3v device results remain specific to that version.
