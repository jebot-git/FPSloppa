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
- VR magazine reload: press **weapon A/X** (the reload binding) to eject.
  On MP5, AK-47, M4A1, M249, AWP and P90, you can instead hold **offhand
  trigger or grip** at the seated magazine and pull it clear by about 5.5 cm.
  Pull down for bottom-fed magazines, or up for the P90 top magazine. The
  M249 cover must be fully open; grab the box rather than the belt leader.
  The removed magazine stays in your hand until you release it, then drops.
  While held, a small floating count shows its remaining rounds, excluding the
  chamber. Guide it back into the well to reinsert that same magazine with its
  exact remaining load; this never tops it up from reserve. A seated M249 box
  still needs its belt laid. Releasing a retained magazine clears the count.
  Release it before drawing a replacement; pistols retain button ejection.
  A contextual pouch appears at the offhand hip when ammunition remains. Hold
  **offhand grip or trigger** anywhere around the offhand hip—front,
  side or rear—to draw a magazine, move
  it to the weapon's magazine socket and seat it. Release grip, then grab the
  slide, bolt or charging handle, pull it back and release to chamber. Inserting
  a magazine into an empty chamber still requires charging. A tactical reload
  retains its chambered round, including while the magazine is removed; inserting
  the replacement is enough to resume firing. Capacity still includes the chamber,
  without an extra round. Empty pistol slides remain locked until an offhand rack
  or one brisk sideways movement of the weapon hand releases them; either side
  works even with the gun rolled. The feed end of held ammunition points toward
  the controller's thumb end.
  Left-handed use mirrors the pouch and hand roles.
- VR AK-47: with a partly depleted magazine and reserve rounds, draw a replacement
  while the old magazine is still seated. Bump it forward against the magazine
  catch to knock the old magazine out, then seat the replacement. Rack only if
  the chamber was empty.
  The normal reload-button ejection remains available.
- VR MP5: pull the charging handle fully back, lift it into the locking notch and
  let go. After inserting the magazine, slap the handle downward with the free
  offhand to release it. Sideways palm swipes also count, using one fresh swept contact over a 20 cm region. Slow touches, withdrawal and tracking jumps cannot release it. A normal pull-and-release rack also chambers the gun.
- VR shotguns: draw individual shells from the pouch and insert them underneath
  the receiver. A fore-end grip overlapping the hip cannot draw a shell, and
  taking over the pump clears any carried shell. The **M3 requires a complete back-and-forward pump stroke** after
  each shot. For a normal two-hand stroke, keep weapon-hand grip held while
  operating the fore-end. **VR Controls → M3 Auto Offhand Hold** defaults to ON:
  keep offhand grip held and release weapon-hand grip to snap the gun into the
  offhand pump hold, even when already loaded. No re-grab is required. With this
  option OFF, bring the offhand to the empty gun’s pump and grab it explicitly. Swing
  briskly along the barrel axis, then reverse to close the action. Weapon-hand
  grip takes the gun back before firing. This cycles the action; shells still
  come from the pouch. The **XM1014 cycles automatically** between shots, but an
  empty gun still needs charging after the first shell is inserted.
- VR AWP: grip the bolt knob and **raise → pull → close → lock** after every shot.
  Follow the knob's upward arc before pulling, return forward, then lower
  it in one continuous motion, without pausing or re-grabbing. The final movement
  has generous position and angle tolerance and also samples the release frame.
  Forward travel alone cannot chamber a shot. Releasing the knob retains
  its physical position; re-grip it there to finish. Its existing scope is retained.
- VR M249: grip and **lift the hinged feed cover**, eject the old box using the
  reload binding, then draw and seat a new box. Grab its attached belt, lay the
  leader into the feed tray, where it latches even before grip release. Move the
  hand away, lower the cover, then pull and release the charging
  handle. A loose belt prevents closing the cover; an open cover prevents firing
  and chambering. Dropping the belt before seating it leaves it attached to the box.
- Alternate fire: toggle Glock semi/burst or the USP/M4 suppressor. In VR,
  bring the offhand within 16 cm of the USP muzzle, then press alternate fire
  to attach or remove its silencer. Finish handling the magazine or slide first;
  release and press again if the button was held during reloading or out of reach.
  With the AWP,
  hold alternate fire to zoom; looking through the existing VR optic also applies
  its scoped accuracy. The AWP retains the game's monocular scope, eye box,
  wall occlusion and render-layer behavior. **All CS weapons have no aiming
  laser**; use their aligned sights or the AWP scope.
- Knife damage uses the existing melee sweeps and collision checks. Desktop
  primary/alternate input selects slash/stab; in VR, swing the knife and use the
  alternate binding for the stronger stab. The knife follows the controller grip
  axis, with the blade emerging past the thumb and the hilt anchored in the palm.
  Trigger input alone cannot create VR
  knife damage.
- The weapon wheel includes all twelve weapons and their icons. Turn-stick
  up/down selects owned CS grenades in DE; return to center between selections.
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
animation follows separate handle lift and longitudinal travel, including the
closed-but-unlocked position. The MP5 handle remains raised in its locking notch
until released by a qualifying slap or a short rearward pull and release. Its
handle rotates around the cocking-tube axis when lifted, keeping its root
connected; visual and interaction positions share this transform. The M249 uses an articulated belt with
instanced linked rounds that follow the held leader while remaining attached
to the ammunition box. Detachable magazines disappear from the gun on ejection
or completed hand removal;
the local dropped magazine is cosmetic and expires after 2.5 seconds. Its mesh
retains the gun/held-ammunition scale on an unscaled physics body, so both button
ejection and hand release stay the same size after simulation steps. The M249
cover and its rear sight rotate together around the front hinge.

The M3 has no external charging handle; its pump remains the physical action.
The XM1014 retains its charging handle.

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
tracking loss and stale network input cancel active grabs and motion gestures.
An open AWP bolt or latched MP5 handle retains its mechanical position; the
player must release grip and deliberately resume the action. Holstering
retains the weapon's seated-magazine and chamber state. Visible ammunition, moving parts, haptics and mechanical sounds guide the local
player; floating weapon guide text is hidden except for the requested held-magazine
round count. Remote weapons show the replicated
action state. Magazine removal/insertion, rearward racking, action closure and
empty pistol slide lock each have distinct original sounds.

VR movement-stick click now jumps; the old conflicting slow-walk default is
unbound. Existing default bindings migrate once; customized bindings remain.
CS VR firing without an offhand supporting the gun multiplies spread and recoil
climb by **2.0 for long guns**. Pistols have no one-handed accuracy or recoil
penalty; their ordinary movement spread and firing recoil remain. The server checks the
tracked support-hand position and grip/trigger state. Desktop CS, bots and other
weapon loadouts keep their existing recoil. A recovered first shot is perfectly
accurate while stationary and grounded, including an unscoped AWP; shotguns and
unsupported VR long guns retain their normal spread. Follow-up shots retain the
existing bloom, random spread and VR climb until the weapon recovers. Accepted CS
shots emit their bullet and muzzle flash at the firing pose, then animate the gun
backward and toward the next server-generated spray direction on desktop and in
VR (the average pellet direction for shotguns). Random spread samples are reserved
one shot ahead; the next bullet uses them with the current movement, stance and
recovery. The gun holds its anticipated pose through automatic fire and settles
when firing stops.
Both rendered palms follow the prop while raw
controller poses continue to drive gameplay. The offhand snaps to the underside
of each gun's handguard and stays attached while grip remains held, with analog
hysteresis; firing and ordinary wrist drift do not release it. The arm solver
positions the elbow, and the prop owns the final wrist position and rotation.
This follows the separation of raw input and rendered hand attachment used by
raifslop's integration-branch fishing reel.

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

Grounded crouch multiplies both spread axes by 0.75; prone uses 0.45. These
bonuses combine with CS movement spread and VR support-hand penalties. They
do not apply while airborne or swimming, and do not change base damage.
`deathmatch/tests/cs16_accuracy.gd` verifies actual fired rays and damage for
all eleven guns, suppressed variants, standing/crouched/prone targets and the
shared armor tiers. Helmet purchases retain the project's shared armor model,
not location-specific CS1.6 armor rules.

The arena adaptation does not enable CS economy or round/bomb rules; those
are available separately in [DE mode](BOMB-DEFUSAL.md). It does not implement
a full weapon roster, caliber-specific inventory, armor types or exact GoldSrc recoil
and movement. Four shared arena ammunition families remain. Movement multipliers
are normalized to the existing movement speed; spread adds movement, airborne
and recovering sustained-fire penalties. Buckshot falloff/reload staging and
knife behavior are arena adaptations. There is no special first-slash or
backstab damage model. The AWP uses the existing single zoom behavior.

Eligible CS guns now support [material- and thickness-limited wall penetration](CS16-PENETRATION.md)
on all five authored DE maps, including their thin timber and sliding glass.
Maps without valid authored metadata retain normal wall blocking.

Fire, clip counts, burst scheduling, reload completion and firing modes are
server-authoritative. The new snapshot row is validated and bound to a player
life and weapon. VR reloads are derived from validated controller poses and grip
inputs on the server, with minimum stroke durations and reach/orientation checks. Swing gestures need
multiple fresh input samples, minimum speed and displacement, and reject
tracking jumps. Motion is measured relative to the head with an additional
controller-motion check to reject head-only movement. Offhand pump ownership
is accepted only for an attached M3 while the support grip is held and the
weapon grip is released. Offhand-held guns cannot fire.
Clients cannot submit clip counts or reload-complete events. Fire and reload
feedback currently waits for authority; network latency affects that feedback.
Clients and servers need matching protocol **`fpsloppa-52-defuse-snip`**.
Nothing here deploys a server automatically.

## Assets and validation

[Asset provenance](../deathmatch/weapons/cs16/CREDITS.md) and
[rebuild instructions](../tools/cs16/README.md) accompany the editable Blender
source. Receivers, stocks and handguards have slimmer profiles while physical
controls and sight landmarks retain their positions. One original 1024×512
atlas distinguishes worn steel, polymer, walnut, olive composite and brass;
Krita wear layers remain editable. The runtime shares a mipmapped texture,
including the M249 belt; no retail CS meshes, textures, sounds or manufacturer
photographs are bundled. Each mesh is
roughly 1,200–8,900 triangles, with separate moving components.

The trigger bows now open toward the muzzle on all eleven guns, including the
P90's separate trigger; the Glock safety tab follows its corrected face.
Rebuilt assets preserve sight landmarks, action pivots and detachable components.
See [trigger validation](validation/cs16-triggers-2026-09-27.json).

Validation scripts cover combat and reloads (`cs16.gd`), physical VR gestures and
interruption safety (`cs16_vr_reload.gd`, `cs16_actions.gd`), simulated-controller UI and pouch/action
renders (`cs16_reload_ui.gd`), all weapons used by bots
(`cs16_bots.gd`), real ENet replication (`cs16_network.gd`), model/action/scope
behavior (`cs16_art.gd`), and sight geometry and laser visibility
(`cs16_sights.gd`). The sight test casts through the **exported triangles**,
including transformed controller poses. Blender checks guard manifoldness,
component bounds adjacency and magazine/guard clearance. Bounds adjacency is
not a claim that all mechanical parts are welded into one solid.

Native Godot renders include both sides, an aiming view and an open action for
each gun, plus first-person captures on `de_dust2_rebuilt`. Subsequent physical
WiVRn feedback and the supplied `cst.mp4` recording informed the handling changes
below. The automated tests do not establish headset comfort; no live-server
deployment is part of this update.

The current action update is recorded in
[the validation receipt](validation/cs16-actions-2026-09-27.json). It covers
both handedness configurations, wrong-order actions, slow motions, tracking
jumps, interruptions and ammunition conservation. The real ENet scenario also
checks remote action progress and the extended 11-field snapshot, which adds
independent bolt lift and belt placement to the existing physical reload state.
Native renders inspect separate AWP stages, the MP5 latch and M249 belt.
The follow-up video-feedback changes and live WiVRn test are recorded in
[the feedback validation receipt](validation/cs16-video-feedback-2026-09-27.json).
Gesture thresholds still need a physical-headset comfort/playability pass.
The engine reports shutdown ObjectDB/resource warnings also seen in the baseline;
these runs do not establish a leak-free application shutdown.
