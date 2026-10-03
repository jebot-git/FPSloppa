# ST — TRIBES

ST is a dedicated two-team Tribes CTF mode. Select **ST — TRIBES → Stonehenge**
in Host/Practice. It forces the existing Tribes arsenal, armour, skiing, jets
and shared personal energy pool. The server, normal votes, lobby ballot,
server browser, scoreboard, demos and late join all recognize `st`.

```sh
godot --path . --xr-mode off -- --practice --no-bots --mode st
```

The initial dedicated terrain map is `ctf_stonehenge`. Its old ID is retained
for asset/hash compatibility, but its catalog tag is now **ST**, and its
network source name is `st_stonehenge`. Ordinary CTF/arena maps cannot enter
an ST rotation. Future imported `st_*.bsp` maps need flags and spawns for both
teams, each team's inventory and generator markers, and playable bounds.

ST maps cannot be selected or loaded in other modes, even through a configured
map list. The Tribes loadout remains selectable in DM, TDM, CTF, KOTH and FT
on those modes' maps. It retains armour, weapons, personal backpacks, skiing
and jets; selected equipment is supplied each respawn without team-energy
costs. Stations, deployables, command systems and vehicles require ST mode.

In VR, the PDA rests flat on the offhand palm, with its casing ahead of the
wrist and no forearm cuff. Heavy armour shoulder bridges and pauldrons are
hidden in first person; other players still see the complete armour.

## Match and equipment rules

- Touch the enemy flag to take it. Capture at your own flag while it is home.
  Touch your dropped flag to return it. Skiing pickups use swept movement and
  visibility tests; dead players and spectators cannot interact.
- Captures add one team point and five personal score points. Kills count
  normally; defending a flag or escorting its carrier within 80 m adds the
  classic defense bonus. `capturelimit` defaults to 5; `timelimit` also applies.
- Death, disconnect and team changes drop the flag with carrier momentum.
  Dropped flags fly, fall and bounce against the BSP. Return starts at 45 s,
  fading over 2.5 s. A short thrower-only pickup grace prevents immediate
  recatching. Desktop **T** tosses the carried flag.
- Each life starts in Light armour, with blaster, chaingun, disc launcher,
  repair kit and no backpack. Disc is selected. Favourites are bought at
  friendly inventory pads; death does not grant the saved expensive loadout.
- Existing Light/Medium/Heavy restrictions, weapon/ammo limits, backpacks,
  grenades, mines, repair gun and targeting laser remain in use. The armour
  HUD reads personal energy; armour condition is health.
- Approach a powered friendly inventory pad to open the reused buy wheel automatically (within 2.5 m, with line of sight). Main-hand stick click reopens it; vehicle stations use the same controls.
  It repairs and resupplies, charges team energy and credits paid trade-ins.
  Purchases preserve damage and personal jet charge.
- Each Stonehenge base has a damageable generator housing. Losing power
  disables that team's purchases, pad healing and ammunition service.
  Friendly repair-gun fire restores power. Generator state replicates to
  clients and demos. Friendly-fire policy applies to generator damage.

Finite team reserves remain the default from the previous loadout test:
5,000 per funded team slot, 700 replenished every 30 seconds, cap 700,000,
with reconnect/respawn farming prevented. `sv_tribes_infinite_energy 1` enables
the reference game's unlimited buying-energy option. This does **not** make
personal jet, weapon or pack energy unlimited. Empty reserves still permit
a basic emergency spawn; unpaid equipment cannot earn trade credit.

## Targeting laser and mortar

The **TARGETING LASER** is a separate utility from the damaging **LASER RIFLE**.
Hold primary fire to paint a surface or object. The server traces the weapon
aim every 0.2 seconds, up to 1,000 m, consuming 3 personal energy per trace
(minimum 5 to fire). It deals no damage. In VR it follows the weapon controller,
not the headset. The hit point becomes a team-only LASER target. Releasing fire,
switching weapons, death, team changes or aiming into empty sky removes it;
the short 0.45-second lease only bridges accepted traces.

A teammate with **Heavy armour and a mortar** sees a gold diamond at the target
and, if a valid trajectory exists, a green aiming ring with flight time. Aim
the mortar along that ring and fire. The same assistance supports the grenade
launcher and friendly target beacons. Switching your own targeter to a mortar
stops painting, so sustained laser guidance needs a teammate. Beacons persist
until disabled or destroyed.

The aiming display updates at 10 Hz, considers the eight nearest friendly
designations/beacons, and chooses one by view direction with a preference for
the previously selected target. It tries the low arc first, then the high arc,
rejecting blocked paths and arrivals before the shell arms. Mortar calculations
use about 74.16 m/s launch speed, 20 m/s² gravity, half the shooter's current
velocity and a two-second arming time. At equal elevation while stationary,
the ideal maximum range is 275 m. No valid arc means no green ring.

The laser supplies an aiming reference; it neither redirects the weapon nor
guides a shell after launch. A fired mortar follows its initial velocity and
gravity even if the laser moves. Hits before arming bounce; armed impacts
explode, with a 20 m blast radius. Heavy siege/escort bots also consume allied
designations and aim before firing.

## Image enhancer

Zoom belongs to the armour visor and works with **every Tribes weapon and
utility**, including the disc launcher, chaingun, blaster, plasma, grenade
launcher, laser rifle, ELF, mortar, repair gun, targeting laser, grenades and
mines. It is available in any mode using the Tribes arsenal. The laser rifle
still requires Light armour and an energy pack to equip; zoom adds no weapon,
damage, accuracy, range or energy bonuses.

Hold **alternate fire** (default right mouse button) to magnify the viewpoint.
**X** cycles **2× → 5× → 10× → 20×**; the mouse wheel cycles forward/backward
while zoom is held. X is rebindable as **Tribes zoom range**. Release alternate
fire to return to normal view. Range is remembered across weapon switches and
resets for a new session/map. The current Use/E and prone/Z bindings are retained.
Desktop mouse sensitivity scales with magnification and the held model disappears.

In VR, hold the **support-hand trigger**, then use **turn-stick up/down** to
change range. This chord takes priority over shoulder grenade selection.
The visor follows the head viewpoint; its thin green crosshair follows the
controller's shot ray and first obstruction, and disappears if that ray is
blocked or outside the view. It does not predict projectile drop or target lead.
Grip/trigger equipment interactions take priority over zoom. Menus, death,
tracking/focus loss, vehicle piloting and remote operation suspend zoom;
release the trigger before re-entering after an interruption.

The desktop view changes camera FOV using perspective magnification. VR uses
one head-centred **monoscopic digital visor image**, sampled separately through
each eye's unchanged runtime projection. It preserves tracked head/controller
poses but does not provide stereo depth inside the magnified image. The extra
world render is bounded to 1536² on desktop / 768² on Android and stops when
inactive; local hands, body, HUD and visor are excluded from that camera.
Physical headset comfort and compositor cost still need a live play test.

The [original manual, p. 37](https://www.the-flet.com/dynamix/t1/TribesManual.pdf)
identifies the armour-mounted image enhancer and its four ranges (original
E/Z controls). The supplied [weapons training gameplay, 4:54–5:06](https://www.youtube.com/watch?v=xFxPt05QqaA&t=294s)
shows the magnified view, hidden weapon and full-width/height green crosshair;
the overlay recreates those lines without a circular scope border. A small
range readout and controller-relative VR aiming are FPSloppa adaptations.

`deathmatch/tests/tribes_image_enhancer.gd` checks all twelve slots, range
projection, input routing, interruptions, equipment chords and handedness.
`deathmatch/tests/tribes_visor_render.gd` checks rendered magnification,
orientation, projection preservation and render suspension on OpenGL/Vulkan.
`deathmatch/tests/tribes_zoom_desktop.gd` exercises real game input, camera,
HUD, sensitivity and menu recovery in Stonehenge with a focused desktop window.
Results and screenshots are in `test-results/tribes-image-enhancer/`.

## VR interactions

Existing bindings and item-use logic are reused:

| Location/control | Action |
|---|---|
| Movement stick / jump click | Move / jump; keep the click held to ski, including while the weapon wheel is open |
| Weapon-hand A/X | Hold intrinsic jets |
| Right joystick click | Dominant-hand weapon wheel; inventory wheel on a station |
| Turn-stick up/down | Select shoulder grenade or mine, retaining the gun |
| Support-hand trigger; turn-stick up/down while held | Hold image enhancer; change zoom range |
| Offhand at shoulder, grip + trigger | Draw the selected grenade/mine; swing and release to throw |
| Offhand grip at the hip | Hold the repair kit; trigger uses it once; release stows it |
| Offhand grip at the pack control on chest | Trigger activates shield/jammer or selects repair gun |
| Offhand grip at the carried-flag chest tab | Swing and release grip to pass/drop the flag |
| Existing Use action | Activate/deploy the pack or use the repair kit when no active pack applies |
| Held deployable chest control + offhand trigger | Place the pack on the aimed-at surface within reach |
| Inventory → Sensor Network | View friendly remote cameras and sensor contact count |

Hip and chest attachments use the shared tracked-pelvis/leaning frame and
mirror for left-handed users. The kit uses the whole offhand hip recovery
area, with chest controls taking precedence where crouching brings them close.
Tracking loss, menus, death and respawn cancel held interactions. Authority
checks reach, pose, map/life/sequence, inventory and throw velocity.
The dominant hand keeps its weapon throughout these offhand interactions.
For grenades and mines, only that aiming hand draws a direction guide. Deliberate
offhand swings receive up to 4.8× speed assistance, capped at 40 m/s before adding
the player’s skiing velocity. Gentle releases still drop the held item.

## Assets and limits

The existing original weapon, pack, armour, banner and icon assets
are reused. ST has its own original [Skyward Relay music loop](audio/skyward-relay/README.md).
Small native meshes add a kit, pack control, flag tab and generator
status strip; they need no bitmap textures or added spring bones. Existing
armour/undersuit attribution and non-commercial restrictions still apply.
Stonehenge remains BSP29 with its existing mipmapped textures and caches.

Seven [deployables](TRIBES-DEPLOYABLES.md) now include remote stations, a
projectile turret, sensors, a jammer and camera viewing. Bots dynamically
reassign recovery, escort, defence, repair and attack jobs as the situation
changes. Healthy-base maintenance can place defensive turrets; repairers restore
friendly equipment and runners can clear exposed hostile turrets. Outdoor ski
routes and tower run-ups use unchanged player movement/energy rules. Low-speed
uphill movement releases ski for walking traction. [Adaptive tactics](ST-BOT-ADAPTATION.md)
add short coordinated pushes, failed-route memory, wider carrier screens, basic
flag standoffs and completed resupply trips.

[Fixed medium pulse sensors and independent inventory-station damage/repair](TRIBES-INFRASTRUCTURE.md)
are operational, with a shared desktop/VR scan/jam indicator. Vehicles, the full
commander interface, beacons and complete corpse/backpack recovery
remain absent. Generator housings use a 300-health approximation and
retain cover geometry when disabled. Godot collision and blast falloff retain
the documented adaptations. See the [complete gap audit](TRIBES-IMPLEMENTATION-GAPS.md).
Physical headset usability of the new remote equipment still needs a live test.

## Sources and verification

Rules were checked against the [Tribes manual, pp. 49–50 and 58](https://www.the-flet.com/dynamix/t1/TribesManual.pdf)
and the pinned [flag rules](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/game/flag-original.cs),
[spawn loadout](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/game/playerspawn.cs)
and [team-energy constants](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/game.cs).
The scripts are a maintained community base distribution, not an authenticated
retail extraction. Reference copies and new checks are in `test-results/st-tribes/`.

`deathmatch/tests/st_tribes.gd` covers rules, map isolation, two-handedness,
tracked leaning, request guards, base power and state validation.
`st_server.gd` exercises real dedicated configuration and ballots.
`tools/run_tribes_network.py` runs an ENet server, player and late spectator
with delayed/lost movement packets and checks base power and airborne flags.
Existing station, terrain, armour, arsenal, demo and ballot regressions also run.

Validation receipt: [ST checks, network results and limitations](validation/st-tribes-2026-09-27.json).

Fixed turret operation and expanded bot equipment/offence are described in [the steps 1–3 pass](ST-OFFENCE-DEFENCES.md). Inventory → Sensor Network → Base Turrets opens the control selection.
