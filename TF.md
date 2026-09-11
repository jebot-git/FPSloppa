# TF — Team Fortress adaptation

TF is an optional two-team objective mode built on FPSloppa’s arena combat. Select **TF · TEAM FORTRESS** when hosting or starting practice. In a match, open **TF CLASS…** to queue a class; it applies at your next respawn. **E** on desktop, or the movement-hand **A/X** button in VR (mirrored with left-handed controls), uses the class ability and also operates nearby doors. Weapons retain tracked 6DoF aim. Everyone uses the same 0.30 m radius / 1.65 m hit capsule, regardless of class, VRM or disguise.

Each player has a readable class-name badge and class colour above their name. Team colours remain independent. Badges obey walls and disappear on death. A disguised spy deliberately presents the copied class/name/team to enemies; teammates still see SPY. The scoreboard and player identity used for gameplay remain authoritative.

| Class | Health / armor | Speed | Loadout and adaptation |
|---|---:|---:|---|
| Scout | 75 / 25 | 125% | Pistols, shotgun, fist. Three-second sprint; ten-second cooldown. |
| Sniper | 90 / 25 | 90% | Railgun, pistols, fist. Rail costs two bullets and deals 90 before armor instead of instagib. Four-second focus raises it to 150 and halves movement; twelve-second cooldown. |
| Soldier | 150 / 100 | 85% | Rockets, shotgun, fist. Aimed grenade with visible 1.2-second fuse; eight-second cooldown and one rocket cost. |
| Demoman | 120 / 75 | 95% | Rockets, shotgun, fist. Throws one visible pipe grenade with gravity and world bounce; use again after 0.7 seconds of arming to detonate. One rocket; eight-second reuse cooldown. |
| Medic | 110 / 50 | 110% | Slower plasma, pistols, fist. Aim at a teammate within six metres to heal 35 HP and extinguish; two-second cooldown. Regenerates three HP per second. |
| Heavy | 200 / 150 | 65% | Chaingun, shotgun, fist. Four-second brace reduces incoming combat damage by 35% and halves movement; twelve-second cooldown. Hazards bypass brace. |
| Pyro | 125 / 75 | 100% | Plasma mesh becomes an eight-metre flamethrower; shotgun and fist. Burning lasts three seconds. Aimed napalm grenade costs 20 cells with a ten-second cooldown. Fire resistance. |
| Spy | 90 / 25 | 105% | Pistols, super shotgun, fist. Disguise copies the nearest enemy’s validated VRM and identity, without invisibility. Dedicated servers may select cell-powered invisibility instead. Rear fist attacks deal at least 120 before armor. |
| Engineer | 100 / 75 | 100% | Pistols, shotgun, fist. Choose sentry or dispenser in the class menu. One of each, 60 cells apiece, three-second construction and 120-second lifetime. Aim at a damaged friendly building to repair 40 HP for ten cells. |

Spy disguises instantiate the copied VRM separately: the spy keeps their own skeleton animation, full-body tracking, hands, eye/blink tracking and voice-driven visemes. The existing host-mediated VRM download provides the model; the 25,000,000-byte model limit is unchanged. Until that verified asset is available, the spy keeps their own model. Screen-door cloaking affects the actual skinned meshes and weapons, hides enemy name/class badges and suppresses shadows; teammates see a tinted ghost and the true SPY badge. Firing a gun, dealing melee damage, taking damage, carrying a flag, changing class, or the copied player disconnecting removes the disguise. Missed swings, kicks and ordinary tracked hand movement do not reveal the Spy. The disguise has no fixed expiry. Voice chat still identifies the real speaker.

Sentries fire at visible enemies up to 18 m away, respect spawn protection and are fooled by an enemy-team disguise. Bullets, rails, projectiles and explosions can destroy buildings. Dispensers restore health, armour and class ammo once per second to teammates within 3 m. Buildings have 150 HP, cannot obstruct player movement, cannot be placed in walls or on spawns/flags, and disappear when their owner leaves or switches team/class. Build/repair and all class actions are server-authoritative and bounded by cooldowns and ammo. Ordinary weapon pickups are ignored in TF to preserve class roles; health/ammo/armor pickups and team resupply remain useful. Supply refills to the class loadout limits, never grants a new weapon.

TF keeps the classic distinction from ordinary CTF: defenders cannot touch-return a dropped flag (it returns after 30 seconds), and a team can score even while its own flag is away. Capture points may differ from flag homes. `capturelimit` counts captures, not individual frags. This implementation omits QuakeC scripting, infection, concussion movement, MIRV clusters, original reload/clip rules, armor types and every historical TF map variant. Grenades launch from the weapon and use server-authoritative swept collision, gravity and bouncing. Soldier and napalm grenades detonate on player impact or their 1.2-second fuse; the demoman pipe uses manual detonation after arming (30-second safety fuse). The HUD shows the action name and remaining cooldown, including the pipe’s arming state. It is an independent adaptation, not an exact port or Valve product.

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

Existing BSPs also work with fallback flag locations and team spawn allocation, although dedicated TF layouts are preferable. Map and custom VRM transfers use the existing external `maps/` and `vrm/` directories. Use matching TF-enabled clients and servers (protocol 26 / `fpsloppa-26-fortress-effects`).

The two generated arenas contain original geometry, not decompiled or traced layouts. Their MAP sources and generator are CC0; textures are BSD LibreQuake assets with notices and provenance. Ironspan has three base entrances, sniper galleries, dry flanks and a canal beneath its bridge. Relayworks has separate elevated flag rooms and ground-level capture areas, twin ramp approaches, a central tunnel and two flanks. Both have four team spawns and resupply per side.

Original **2fort5** and **Well6** conversions are local/server-only. 2fort5’s [original notice](https://www.filefactory.org/tf/file/1807) expressly prohibits redistributing modified versions without permission; [Well6’s readme](https://www.filefactory.org/tf/file/703) gives no clear derivative redistribution grant. Only conversion tools and LibreQuake donors were offered publicly, archived with 0.5v. See [0.5v archived extras](https://github.com/jebot-git/FPSloppa/releases/tag/0.5v). Native TF team spawns, flags, capture goals and resupply are adapted; original team 1 is blue, team 2 red. QuakeC-dependent doors, destructible grates, trigger chains and special scoring are not reproduced.

Automated validation does not establish headset frame rate, long-match balance or comfort. These additions need playtesting on PCVR, Quest and Pico; the owner’s prior 0.3v device results remain specific to that version.


The forty-map Arena Collection 1 and ThreeWave, TeamFortress and Arcane Dimensions conversion tools are archived exclusively with [0.5v](https://github.com/jebot-git/FPSloppa/releases/tag/0.5v). They are no longer included or maintained; see [the archive policy](docs/ARCHIVED-EXTRAS.md).

Current TF effects/grenade and eight-player AS test results: [TF/AS validation review](docs/TF_AS_TEST_REVIEW.md).

## Physical VR abilities

Enable **Settings → Bindings → Physical TF abilities / AS buttons** (on by default).
The existing **Use** action remains available for every class.

| Class | Physical control |
| --- | --- |
| Engineer | Slap a friendly building with either hand to repair 40 HP for 10 cells. Withdraw before another slap; the one-second repair cooldown still applies. Grip + offhand trigger uses the selected construction tool / aimed repair. |
| Medic | Touch a teammate with a short hand stroke to heal 35 HP and extinguish them. Withdraw before repeating; the two-second cooldown remains. |
| Soldier / Demoman / Pyro | Hold support grip and press the offhand trigger to arm a grenade. A small grenade and release hint appear in that hand. Swing and release grip to throw; a stationary release drops it. Releasing the trigger during a throwing stroke also releases it. |
| Demoman with a deployed pipe | Grip + offhand trigger detonates the pipe after its existing arming delay. |
| Scout / Sniper / Heavy / Spy | Grip + offhand trigger activates the existing sprint / focus / brace / cloak ability. |

Controls follow weapon-hand selection and the remapped **support** / **offhand fire**
actions. Offhand trigger alone still fires the second pistol. The default support-grip
push-to-talk binding remains active while gripping; remap PTT if you prefer separate
controls. The ability chord suspends support-hand aiming and second-pistol firing
until released.

Grenades retain their existing ammo costs, damage, fuse and cooldown. The fuse starts
on release; holding beyond ten seconds cancels. Opening a menu, losing tracking or
headset focus, dying, respawning, or leaving gameplay cancels a held grenade without
spending ammunition. Contact and projectile actions are checked by the server,
including team, life, map, cooldown and world obstruction. TF flag pickup, carrying,
capture and resupply retain their existing rules.

Burning TF players emit visible flames until afterburn expires or is extinguished. The affected player sees an orange screen cue; VR uses the view edges and a BURNING HUD label.

The default is `set sv_tf_spy_invisibility "0"`. Set it to `"1"` on a dedicated server for the original Quake TF alternative: invisibility instead of disguise. The ability toggles cloak, using one cell on activation and one cell per second thereafter. Visible spies regenerate one cell per second up to 50; running out forces visibility. This follows the two undercover modes described in the [original TeamFortress 2.8 readme](https://www.filefactory.org/tf/file/2); the exact resource rates are FPSloppa tuning. Clients receive the server policy and the class menu describes the selected ability.

VR fists have no trigger attack; use physical melee. Desktop fist attacks remain available. Melee that is rejected by friendly-fire or spawn-protection rules does not reveal the attacker. Damaging enemy structures also reveals a Spy.
