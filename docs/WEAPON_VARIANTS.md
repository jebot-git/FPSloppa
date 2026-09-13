# Experimental weapon rules

Doom remains the default for unrestricted modes. TF requires Quake I and Assault requires UT99; their Host weapon selector is locked. The Host screen now has a **WEAPON RULES** selector for
Doom, Quake I and UT99. The same choice applies to practice bots. For dedicated
servers use `set sv_weapon_rules "quake"` or `set sv_weapon_rules "ut99"` in
`server.cfg`; `--weapons quake` / `--weapons ut99` overrides the file. A practice
launch can use `--practice --mode tf --map tf_ironspan --weapons quake` or
`--practice --mode as --map as_frigate --weapons ut99`.

The server applies the required arsenal on TF/AS mode changes, including votes and rotation. Other modes resume the configured preference.
Clients receive it before loading pickups, and recordings retain it. Matching
clients and servers are required (protocol `fpsloppa-35-mode-loadouts`).
Instagib, Instafreeze and Circus of Carnage retain their dedicated original weapon behavior.

## Quake I

| Weapon | Behavior |
| --- | --- |
| Axe | 20 damage, 0.5-second cycle; VR uses physical swings, desktop uses primary attack |
| Shotgun | Six 4-damage pellets; one shell; 0.5-second cycle |
| Super shotgun | Fourteen 4-damage pellets; two shells; 0.7-second cycle; falls back to shotgun with one shell |
| Nailgun / super nailgun | Physical nails at 31.25 m/s; 9 / 18 damage; one / two nails every 0.1 seconds |
| Grenade launcher | Gravity, floor/wall bounce, 2.5-second fuse; 120-point radial explosion |
| Rocket launcher | 31.25 m/s rockets; 100–120 direct damage plus radial damage to other targets; self splash and rocket jumping |
| Lightning | 30 damage per cell, 0.1-second cycle, 18.75 m reach; submerged firing discharges the remaining cells |

TF keeps its nine classes, speed/health/armor, abilities, building repair, grenades,
flags and resupply. Loadouts use Quake shotgun/nail/grenade/rocket slots. Heavy uses
the super nailgun; pyro retains the existing short-range flamethrower and ignition;
sniper retains the TF sniper override. Engineer cells still power construction.
This is a weapon experiment, not a complete historical Team Fortress port.

## UT99

Alternate fire defaults to **right mouse** on desktop and the **support-hand
trigger** in VR. It is separately configurable as `alt_fire` in Bindings. Physical
TF abilities and the shoulder radio take priority while those interactions are
active. Primary fire remains the weapon-hand trigger / left mouse. The Quake axe is
swing-only in VR: neither trigger fires it. Its physical sweep follows the blade
position and registers at most one hit per swing, with a half-second cooldown.
The UT impact hammer retains its trigger-based charging and alternate strike.

| Weapon | Primary / alternate |
| --- | --- |
| Impact hammer | Hold charge, aim down, then jump and release for an impact jump; surface strikes cost health / smaller distance-scaled surface boost |
| Bio rifle | Arcing, surface-sticking sludge / hold and release a larger glob, consuming more energy |
| Enforcer | Accurate single shots / faster, wider-spread fire |
| Shock rifle | Beam / traveling orb; shooting an orb makes a radial shock combo |
| Flak cannon | Eight bouncing metal fragments / arcing explosive shell releasing fragments |
| Minigun | Controlled fire / faster, less accurate fire |
| Rocket launcher | Hold and release up to six rockets / hold and release bouncing grenades |
| Pulse gun | Fast energy bolts / short-range continuous beam |
| Redeemer | Slow, large-radius warhead / steer the warhead with the weapon's aim |
| Sniper rifle | Long-range shots with head damage / desktop zoom; in VR, look through the physical scope |
| Ripper | Bouncing blades with head damage / explosive blades |
| Translocator | Throw a disc / relocate to a clear destination; drops carried flags |

Scroll or use VR weapon cycling to reach every owned weapon. Desktop keys 8, 9,
and 0 select sniper, Ripper and translocator respectively. Existing BSP maps have
fewer weapon entities than UT99: shock caches also grant the sniper rifle, and
minigun caches grant the Ripper outside Assault. Pickup labels list both. Assault has separate weapon caches; see [the original-map pickup comparison](ASSAULT-PICKUPS.md). Quake grenade-launcher
entities provide the bio rifle. Translocator is issued at spawn outside Assault.

**Assault disables the translocator** to preserve ordered routes and objectives.
Weapons use the same authoritative sentry/objective damage and team protection
as the existing game. A destroyed objective, doors, role swaps and round budgets
continue through the existing Assault system.

## Deliberate adaptations

These are independent gameplay approximations within FPSloppa, not binary- or
frame-exact ports. Movement, armor, health pickups, melee gestures and mode
abilities remain FPSloppa's. UT ammunition is grouped into four existing pools;
the Redeemer costs ten rockets. UT uses a single Enforcer. There is no rocket
lock-on, possessed Redeemer camera, or hammer projectile-deflection mechanic.
VR sniper alternate fire does not change headset field of view. Guided warheads
follow weapon aim instead of moving the player's viewpoint. TF balance should
be assessed with players before making this a server default.

Projectile paths use physics delta, continuous swept collision and existing
moving-target hit tests, team rules, wall clearance and splash occlusion. Charged
weapons cancel on menu opening, disconnect timeout, death, weapon switch or map
reset. A server-wide ceiling of 256 variant projectiles bounds work and traffic;
firing that would exceed it consumes no ammunition. Local immediate-fire reports
are predicted, with authoritative confirmations deduplicated. Charged reports
wait for the server to confirm release.

## Physical VR sniper optic

Bring either eye behind the UT sniper scope; no button is required. The optic
uses a separate 12-degree camera aligned to the actual firing line, showing a
reticle inside the rear lens. The headset projection stays unchanged. The eye
window allows 2.5–34 cm of relief, fading towards 3.4 cm of lateral offset.
Per-eye shading keeps the other eye from seeing the magnified image sideways.
World rays between the eye, optical housing and shot origin reject wall peeking.

Only the local held sniper creates this view: 512² pixels on PC, 384² on Android,
with updates disabled outside the eye window, in menus, with lost tracking or a
blocked weapon. Its camera excludes the local gun/lens layer to avoid recursive
rendering. This remains a monocular optic; remote weapon models do not render
extra cameras.

The comparison fixture tested a head-following zoom camera, the selected weapon
axis camera and duplicate stereo optical passes. A three-degree gaze turn shifted
the head-following view 132 pixels from the firing line; the weapon-axis view
stayed centered. Two passes approximately doubled GPU cost in this small fixture
(about 0.15 versus 0.07 ms on the Arc A770 in the final run). This is an isolated
render measurement, not a full-map or headset performance guarantee.

## Assets and references

Models reuse the existing licensed FPSloppa gun meshes, with distinct per-weapon tints, drums,
barrels, scopes, reservoirs and disc details. Quake axe uses Price’s CC0
Stylized Woodcutting Axe (266 triangles), with its cutting edge aligned forward; UT impact hammer adapts the
existing CC0 Drummyfish chainsaw receiver into a forward-facing pneumatic ram.
Blender fittings use flared receiver collars, bevels and recessed bores, coloured
with each weapon’s palette. The optical housing is actually hollow. TF Pyro uses TheJosh’s CC0 flamethrower
(2,932 triangles) across all three rulesets; other classes keep their normal
weapons. It has a 1024px mipmapped diffuse texture and shared model-space grip
and muzzle anchors for desktop, VR, remote avatars and demo playback.
Sources, authors and modifications are retained in `deathmatch/weapons/experimental/`. Effects echo the originals through independently recreated shapes and palettes:
Quake has iron nails, smoke/fire rocket trails, coarse amber explosion particles
and jagged pale-blue lightning. UT has purple shock cores and combo rings, green
bio splashes and pulse beams, hot flak fragments, spinning metallic Ripper blades
and large warm Redeemer shock waves. These effects are cosmetic, with ceilings
of 512 particles and 64 temporary shapes shared across the client. They are not
instantiated by the dedicated server. Fifty short mono 22.05 kHz
clips occupy approximately 0.64 MB; they derive from the existing Freedoom
BSD-3-Clause and Kenney CC0 recordings, with original procedural resonances.
They target -17 dBFS RMS subject to a -1 dBFS peak ceiling, use positional SFX
volume and never the music bus. Rebuild with `python3 tools/prepare_weapon_variants.py`.
Hashes, measured levels, sources and original notices are in
`deathmatch/audio/experimental/`. No commercial Quake or Unreal audio/models are
included. The console server excludes these visual and audio assets.

Behavior references: [id Software's original Quake QC](https://github.com/id-Software/Quake/blob/master/qw-qc/weapons.qc)
and the original Epic UnrealScript source archived for
[Shock Rifle](https://github.com/Slipyx/UT99/blob/master/Botpack/ShockRifle.uc),
[Flak Cannon](https://github.com/Slipyx/UT99/blob/master/Botpack/UT_FlakCannon.uc),
[Rocket Launcher](https://github.com/Slipyx/UT99/blob/master/Botpack/UT_Eightball.uc)
and [Pulse Gun](https://github.com/Slipyx/UT99/blob/master/Botpack/PulseGun.uc).
Implementation is independent; reference source code is not copied. Visual
references include [Quake particles](https://github.com/id-Software/Quake/blob/master/WinQuake/r_part.c)
and [UT shock projectiles](https://github.com/Slipyx/UT99/blob/master/Botpack/ShockProj.uc).
The optic follows Godot’s [separate viewport camera](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
and [per-eye XR transforms](https://docs.godotengine.org/en/stable/classes/class_xrinterface.html#class-xrinterface-method-get-transform-for-view).

## Validation

- `deathmatch/tests/weapon_variants.gd`: damage, ammunition, fuses, bounces, fast
  crossing targets, rocket jumping, combos, charge cancellation, TF loadouts and
  resupply, special-mode isolation and default Doom preservation.
- `python3 deathmatch/tests/run_weapon_variants.py`: separate ENet server/client
  tests on TF Ironspan and Assault Frigate, including input, projectile replication,
  sentries, captures, destructive objectives and role swaps.
- `deathmatch/tests/weapon_variants_visual.gd`: renders a model comparison and
  reads every weapon sound. Comparison: `test-results/weapon-variants/weapons.png`.

- `deathmatch/tests/weapon_optics_fx.gd`: 18 checks, actual lens render, axis/head
  camera comparison, either-eye poses, eye window, wall blocking, inactive updates,
  recursive-render exclusion and cosmetic pool limits/expiry.
- `deathmatch/tests/melee.gd` and `physical_rig.gd`: physical axe hits without
  trigger, single-hit/cooldown rules, server rejection of trigger attacks, both
  axe aliases, desktop attack preservation and UT hammer input preservation.
- `python3 deathmatch/tests/run_weapon_variants_console.py`: all 70 combat checks
  in the console-only runtime; no graphical/audio assets or new FX script bundled.
- `deathmatch/tests/weapon_hammer_visual.gd` (append `-- axe` for axe): three-angle
  model inspection. Outputs: `impact-hammer.png`, `axe.png`, `scope-through-lens.png`
  and `weapon-effects.png` under `test-results/weapon-variants/`.

Validation receipts: `docs/validation/weapon-variants.json` and
`docs/validation/weapon-model-replacements.json` (source inspection, triangle
counts, 25 model-integration checks, physical melee and console regressions).
These checks establish mechanics and integration. Live VR ergonomics and
multiplayer balance still need a playtest; no live headset test is claimed.

### Sniper and sentry model replacements (2026-09-12)

The CC0 FFMStudios sniper replaces the UT99 sniper and the TF Sniper class weapon across Doom, Quake and UT99 profiles. The original hollow optic is retained; its two opaque lens caps are removed so looking through the rear lens activates the existing magnified camera. Controller grip, short aim guide, wall clearance and authoritative muzzle use the same model anchors. Desktop, remote avatar and demo model selection refresh on class changes. Ordinary Doom/Quake railgun art is unaffected.

Tech Knight's CC0 gatling replaces the gun on TF and Assault sentries. Its six barrels point along the existing targeting pivot. The shared muzzle anchor sets firing effects; the base retains team colour. Range, damage, half-second fire interval, sound and wall checks are unchanged. It does not create an extra weapon pickup.

The sniper is 890 triangles (910 before removing glass caps); the turret gun is 2,198. This fits the newer 2–3k-triangle hammer/flamethrower assets, though the original AFPS base meshes are much simpler. Compressed runtime scenes together are about 55 KiB. Original palette/metal colours are preserved, and no new texture pack or rendering pass is needed. Conversion is reproducible through `tools/weapon_sources/sniper_turret_blender.py` and `import_refined.gd`; source files stay out of game/server exports.

Validation: `docs/validation/sniper-turret-models.json`; render: `test-results/weapon-variants/sniper-turret.png`. The scope was checked in rendered Godot tests and the controller poses in simulated XR; live headset comfort has not been retested for these models.
