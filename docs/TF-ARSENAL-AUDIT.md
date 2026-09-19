# TF arsenal audit — 2026-09-19

The class inventory now has one definition shared by spawn loadouts and class
information. TF and Titan mode share these class weapons. The reference is
[QuakeWorld Team Fortress's class documentation](https://github.com/QWTF/server/blob/master/TF-readme.TXT)
and [weapon implementation](https://github.com/QWTF/server/blob/master/weapons.qc).

| Class | Equipped weapons |
| --- | --- |
| Scout | Axe, shotgun, nailgun |
| Sniper | Axe, nailgun, sniper rifle (shell ammunition) |
| Soldier | Axe, shotgun, super shotgun, rocket launcher |
| Demoman | Axe, shotgun, grenade launcher; remote pipe grenade remains an ability |
| Medic | Axe, shotgun, super shotgun, super nailgun; healing remains an ability |
| Heavy | Axe, shotgun, super shotgun, shell-fed assault cannon |
| Pyro | Axe, shotgun, flamethrower, incendiary cannon |
| Spy | Knife, tranquilizer, super shotgun, nailgun |
| Engineer | Spanner, railgun, super shotgun; cells power construction |

Pyro's rocket slot is an incendiary cannon, as in the
[reference Pyro implementation](https://github.com/QWTF/server/blob/master/pyro.qc):
three rockets per shot, 18.75 m/s, 30–50 direct damage and ignition, with a small
radial fire burst. It no longer behaves like Soldier's rocket launcher.
Heavy fires five 8-damage hitscan pellets every 0.1 seconds using shells.
Engineer fires a 25-damage piercing projectile. Spy's tranquilizer deals 20 damage
and halves movement speed for five seconds; the remaining duration is replicated.

This remains FPSloppa's adaptation: health, armor, movement, abilities, models,
melee mechanics and grenade controls are retained. There is no new assault-cannon
spin-up mechanic, separate sniper autorifle, or separate medic medikit weapon.
Knife/spanner use the existing melee system; healing and building repair use the
existing abilities. The inventory audit is not a claim of a complete historical port.

## Nails

| Rules | Nailgun damage | Super nailgun damage | Ammo per shot | Interval |
| --- | --- | --- | --- | --- |
| Ordinary Quake | 9 | 18 | 1 / 2 | 0.1 s |
| TF / Titan classes | 18 | 26 (Medic) | 1 / 2 | 0.1 s |

Ordinary Quake values agree with
[id Software's source](https://github.com/id-Software/Quake/blob/master/qw-qc/weapons.qc).
TF previously inherited those lower base-game damage values. Both nail weapons
have zero random spread and travel at 31.25 m/s. Existing collision radii remain
0.035 m and 0.045 m; these already give more clearance than Quake's point nails.
Swept player collision adds that radius to the player's hit volume, including
movement between ticks. Tests verify hits just inside the collision boundary,
misses outside it, fast-crossing targets, wall blocking, and a single damage
application per nail. The super nailgun can now fire its last single nail with
ordinary nailgun damage and cost; this flag survives demo serialization.

## Scope, identification and audio

The physical UT sniper lens uses a 6-degree field of view, down from 12 degrees
(approximately twice the magnification). Desktop TF and UT sniper zoom uses
18 degrees. The VR headset projection is unchanged.

Team nametags carry a small red diamond or blue circle. They retain depth testing
and disappear with death/cloak, use the Spy's apparent team for enemies, and
are omitted outside team play.

Doppler was disabled on spatial sources and the camera. Both now track motion.
The [Steam Audio stream wrapper](https://github.com/stechyo/godot-steam-audio/blob/master/src/stream.cpp)
forwards Godot's playback rate to the inner mixer. Captured output from a 660 Hz
tone measured approximately 799 Hz approaching and 564 Hz receding at 60 m/s;
listener motion was also verified. Both Steam Audio and stereo passed.

## Validation

Passing fixtures: `tf_arsenal`, `fortress`, `mode_weapon_policy`, `spy_rules`,
`weapon_variants` (71 checks), `requested_changes` (including Titan bot weapon
eligibility), `team_nametags`, `weapon_optics_fx` (23 checks), and `audio_doppler`.
The TF runner includes `tf_arsenal`. Audio capture requires a real audio driver;
render inspection requires a graphical display. Screenshots are generated at
`test-results/tf-audit/team-nametags.png` and
`test-results/weapon-variants/scope-through-lens.png`.

These checks cover mechanics, rendered fixtures and actual mixed audio; a live
multiplayer/headset balance and comfort playtest remains outstanding. Tests still
emit the existing ObjectDB shutdown leak warning. No exported builds are replaced.
