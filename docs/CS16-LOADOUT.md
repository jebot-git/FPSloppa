# CS 1.6 arena loadout

Choose **CS 1.6 · arena adaptation** in the Host/Practice weapon selector, or set
`sv_weapon_rules "cs16"` in the server configuration. This is an alternate arsenal
for the existing arena modes. The default remains Doom. TF/TB, Assault and the
fixed-loadout modes retain their required weapons.

Players spawn with the knife and USP, with 60 total pistol rounds. Existing map
weapon entities provide the rest of the arsenal:

| Map pickup | CS weapons |
| --- | --- |
| Shotgun | M3 Super 90 + Desert Eagle |
| Super shotgun | XM1014 |
| Nailgun | MP5 Navy + Glock-18 |
| Super nailgun | M4A1 + P90 |
| Grenade launcher | M249 |
| Rocket launcher | AK-47 |
| Lightning gun | AWP |

Dropped weapons grant only the dropped gun, without the map pickup's companion.
The existing death-drop policy excludes the starting knife and USP.

## Controls and presentation

- Fire uses the existing desktop mouse/VR trigger binding. Glock, USP and Desert
  Eagle require a fresh press per shot; automatic weapons can be held.
- Desktop reload: **R**. Empty guns automatically reload when ammunition remains.
  Shotguns load one shell at a time; firing interrupts a shell reload when a
  shell is already loaded. Bots use the same timed reloads.
- VR magazine reload: press **weapon-hand grip** (the reload binding) to eject.
  A contextual pouch appears at the offhand hip when ammunition remains. Hold
  **offhand grip** (the support binding) anywhere around the offhand hip—front,
  side or rear—to draw a magazine, move
  it to the weapon's magazine socket and seat it. Release grip, then grab the
  slide, bolt or charging handle, pull it back and release to chamber. Inserting
  a magazine alone cannot fire the gun. Empty pistol slides remain locked until
  this manual rack. Left-handed use mirrors the pouch and hand roles.
- VR shotguns: draw individual shells from the pouch and insert them underneath
  the receiver. The **M3 requires a complete back-and-forward pump stroke** while
  gripping its fore-end after each shot; the support hand may stay gripping
  through firing and pumping. The **XM1014 cycles automatically** between shots,
  but an empty gun still needs charging after the first shell is inserted.
- VR AWP: grip its bolt handle, pull back and return forward after every shot.
  Releasing halfway does not complete the cycle. Its existing scope is retained.
- VR M249: grip and **lift the hinged feed cover**, eject the old box using the
  reload binding, draw and seat a new box, grip and lower the cover, then pull
  and release the charging handle. The open cover prevents firing and chambering.
- Alternate fire: toggle Glock semi/burst or the USP/M4 suppressor. With the AWP,
  hold alternate fire to zoom; looking through the existing VR optic also applies
  its scoped accuracy. The AWP retains the game's monocular scope, eye box,
  wall occlusion and render-layer behavior. It has **no laser guide**, matching
  the other sniper rifles. Other CS guns retain the existing VR laser guide.
- Knife damage uses the existing melee sweeps and collision checks. Desktop
  primary/alternate input selects slash/stab; in VR, swing the knife and use the
  alternate binding for the stronger stab. Trigger input alone cannot create VR
  knife damage.
- The weapon wheel includes all twelve weapons and their icons.
- HUD ammunition is **loaded / reserve** and shows reloading or the selected
  firing mode. The loaded count is part of the existing shared ammunition total.

Original Blender meshes have weapon-specific receivers, furniture and magazines,
closed trigger guards, explicit palm anchors, hollow muzzle openings and aligned
physical sights. Pistols use notch sights; the MP5 has a bored diopter drum; the
AK has an open rear notch; shotguns/M4/M249 have aperture sights. The P90's
integrated sight housing has a real through-channel. The AWP uses its scope.
Sight axes are parallel to the shot axis, with the normal physical height above
the bore; they do not alter projectile direction or remove close-range parallax.

Slides and automatic bolts cycle on accepted shots. In VR, the M3 pump and AWP
bolt follow the physical offhand stroke; they cannot cycle on a timer. The AWP
animation includes bolt lift during the pull, without requiring a separate
wrist-twist gesture. Detachable magazines disappear from the gun on ejection;
the local dropped magazine is cosmetic and expires after 2.5 seconds. The M249
cover and its rear sight rotate together around the front hinge.

The pouch appears only when a replacement magazine or shell is available. Its
Blender-authored canvas model has an open lined mouth, sewn binding, webbing and
belt loops. With hip tracking, it stays on the pelvis through head turns and
leans; without it, the existing headset-based hip estimate is used. The recovery
area covers the offhand belt side, mirrored for handedness, and excludes the
chest, lower leg and opposite hip. Pull ammunition at least 12 cm relative to
the hips before seating it; moving the whole body cannot complete the draw.
[Rendered pouch preview](images/magazine-pouch.png) and [tracking behavior](../TRACKING.md#hip-tracking-leaning-and-attachments).
Releasing carried ammunition before insertion cancels it without spending ammo.
Ejection preserves remaining rounds in the existing shared ammo pool; magazine
and shell insertion never create ammunition. Menus, holstering, hand switching,
tracking loss and stale network input cancel unfinished gestures. Holstering
retains the weapon's seated-magazine and chamber state. Contextual hints and
haptics guide the local player; remote weapons show the replicated action state.

## Reference values and adaptations

Numeric references were checked against the weapon definitions and routines in
[ReGameDLL_CS, revision 4a50c42](https://github.com/rehlds/ReGameDLL_CS/tree/4a50c42e85fd3778c2b7d24731c7d30c83bbab01/regamedll/dlls).
The game implementation is independent and uses FPSloppa's existing combat path.

| Weapon | Base damage | Shot cycle | Capacity | Desktop/bot reload |
| --- | ---: | ---: | ---: | ---: |
| Knife | 25 slash / 65 stab | 0.40 / 1.10 s | — | — |
| Glock-18 | 25 | 0.20 s | 20 | 2.20 s |
| USP | 34 / 30 suppressed | 0.225 s | 12 | 2.70 s |
| M3 Super 90 | 9 × 20 | 0.875 s | 8 | 0.55 s/shell |
| XM1014 | 6 × 20 | 0.25 s | 7 | 0.30 s/shell after entry |
| MP5 Navy | 26 | 0.075 s | 30 | 2.63 s |
| AK-47 | 36 | 0.0955 s | 30 | 2.45 s |
| M4A1 | 32 / 33 suppressed | 0.0875 s | 30 | 3.05 s |
| M249 | 32 | 0.10 s | 100 | 4.70 s |
| AWP | 115 | 1.45 s | 10 | 2.50 s |
| Desert Eagle | 54 | 0.30 s | 7 | 2.20 s |
| P90 | 21 | 0.066 s | 50 | 3.40 s |

Glock bursts space three shots by 0.10 seconds and gate the next burst for 0.50
seconds. Both shotguns use a 0.55-second reload entry. Suppressor changes take
2 seconds. Guns use 4× head damage before the existing armor system. Distance
falloff converts the reference's 500-unit interval to 12.7 game metres.

This does not implement CS's economy, round/bomb rules, wall penetration, full
weapon roster, caliber-specific inventory, armor types or exact GoldSrc recoil
and movement. Four shared arena ammunition families remain. Movement multipliers
are normalized to the existing movement speed; spread adds movement, airborne
and recovering sustained-fire penalties. Buckshot falloff/reload staging and
knife behavior are arena adaptations. There is no special first-slash or
backstab damage model. The AWP uses the existing single zoom behavior.

Fire, clip counts, burst scheduling, reload completion and firing modes are
server-authoritative. The new snapshot row is validated and bound to a player
life and weapon. VR reloads are derived from validated controller poses and grip
inputs on the server, with minimum stroke durations and reach/orientation checks.
Clients cannot submit clip counts or reload-complete events. Fire and reload
feedback currently waits for authority; network latency affects that feedback.
Clients and servers need matching protocol **`fpsloppa-45-de-utility`**.
Nothing here deploys a server automatically.

## Assets and validation

[Asset provenance](../deathmatch/weapons/cs16/CREDITS.md) and
[rebuild instructions](../tools/cs16/README.md) accompany the editable Blender
source. The models reuse one mipmapped CC0 metal texture from the existing
arsenal; no retail CS meshes, textures, sounds or manufacturer photographs are
bundled. Runtime scenes and shared texture total about 3.3 MiB. Each mesh is
roughly 1,200–7,100 triangles, with separate moving components.

Validation scripts cover combat and reloads (`cs16.gd`), physical VR gestures and
interruption safety (`cs16_vr_reload.gd`), simulated-controller UI and pouch/action
renders (`cs16_reload_ui.gd`), all weapons used by bots
(`cs16_bots.gd`), real ENet replication (`cs16_network.gd`), model/action/scope
behavior (`cs16_art.gd`), and sight geometry and laser visibility
(`cs16_sights.gd`). The sight test casts through the **exported triangles**,
including transformed controller poses. Blender checks guard manifoldness,
component bounds adjacency and magazine/guard clearance. Bounds adjacency is
not a claim that all mechanical parts are welded into one solid.

Native Godot renders include both sides, an aiming view and an open action for
each gun, plus first-person captures on `de_dust2_rebuilt`. No physical headset
playtest or live-server deployment was performed for this loadout.

The reload update passed 478 combat, physical gesture, model/action/scope,
sight/laser and controller/UI checks, plus the wheel and bot scenarios.
The real ENet scenario covers both timed
reloads and physical magazine, M3 pump and M249 cover/box/charging sequences.
The broader `export_resources.gd` audit stopped at the already-missing
`maps/cache/lqdm4.scn` before reaching its weapon section; the CS scenes and shared
texture were loaded and checked directly by the art tests and native renders.
The engine reported shutdown ObjectDB warnings (also present in the baseline);
these runs do not establish a leak-free application shutdown.
