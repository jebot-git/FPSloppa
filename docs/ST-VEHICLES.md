# ST vehicles — Scout, LPC, HPC and Tribes 2 additions

Wildcat, Shrike and Havoc now use this same lifecycle and control scheme. See
[Tribes 2 Classic](ST-T2-CLASSIC.md) for their roles, build instructions and limits.

Implemented in `experimental/st-raindance`, 29 September 2026. ST remains
excluded from the release branch. All three original vehicle roles now have a
playable implementation; autonomous bot purchasing/piloting remains later work.

Both existing Raindance vehicle-pad landmarks have powered purchase terminals.
Use the inventory wheel at a friendly terminal to select a vehicle. Purchases
reserve up to three hulls **of each type** per purchasing team; this prototype
limit permits 18 hulls across both teams. A craft becomes boardable after three
seconds. The server rejects blocked pads, insufficient energy, disabled stations,
stale map/life requests and duplicate purchases before charging. Stonehenge has
no newly invented vehicle station.

| Vehicle | Team energy | Passengers besides pilot | Hull HP¹ | Forward speed | Ceiling / lift |
| --- | ---: | ---: | ---: | ---: | ---: |
| Scout | 600 | 0 | 90.9 | 50 m/s | 25 m / 10 m/s |
| Light Personnel Carrier (LPC) | 675 | 2 | 227.3 | 25 m/s | 15 m / 6 m/s |
| Heavy Personnel Carrier (HPC) | 875 | 4 | 303.0 | 25 m/s | 15 m / 6 m/s |

¹ Damage is converted to the game's Light-armour 100 HP scale. The pinned data
scripts give both transports the same top speed; the HPC has slower acceleration,
turning and strafing in this adaptation. Transport pitch/bank limits are
0.175/0.25 radians. They take half blaster/laser-rifle damage and reduced landing
impact damage. Friendly-fire policy applies; repair beams restore type-specific
maximum health. Occupied vehicles are hot targets for missile turrets.

Only Light armour can pilot. Passengers can wear Light, Medium or Heavy armour.
Use near an empty seat to board: a reachable empty pilot position has priority
for a Light player; otherwise the nearest reachable passenger station is chosen.
Either team may board/steal a vehicle. Its current team follows the pilot, while
the purchasing team's type-limit reservation remains until the hull is removed.
Flag carriers cannot board in any role, and occupants cannot collect flags or
refit armour while mounted.

| Action | Desktop | VR |
| --- | --- | --- |
| Buy | Click vehicle in terminal wheel | Select in existing hand-following wheel |
| Board / leave | Use | Existing Use binding |
| Pilot thrust | Movement keys | Movement stick, relative to craft controls |
| Pilot turn | Mouse yaw | Turning stick horizontal |
| Scout aim / lift | Mouse pitch / jetpack binding | Dominant controller aim / turning stick up-down; centre holds altitude |
| Transport rise / land | Mouse pitch / jetpack binding | Turning stick up / down; centre holds altitude |
| Scout rockets | Fire | Dominant trigger |
| Passenger weapons | Normal aim, weapon selection and fire | Normal tracked weapon aim, wheel and trigger |
| Passenger equipment | Existing equipment controls | Shoulder grenades and hip/chest equipment |
| Eject | Jump or Use | Jump or Use |

Transports have no built-in Scout rocket launcher: passengers provide the
firepower, retaining normal ammo, cooldowns, armour energy and projectile velocity
inheritance. Passenger inputs cannot steer the aircraft. VR chest-pack activation
is separate from the Use action so it cannot accidentally eject the passenger.
Personal armour energy recharges during flight; passenger jet input does not burn
it. Pilots cannot fire personal weapons or invoke physical item interactions.

All occupants follow distinct points on the banking/pitching hull. The rendered
hull and local camera share one sampled transform each display frame. Hosts
interpolate physics ticks; network clients use a bounded snapshot history with
a gently corrected render clock. Collision bodies remain authoritative, and
rendering no longer moves passenger colliders or applies a second interpolation
pass to the hull. Avatars and visible attachments follow that same frame through
graphics-only offsets, restored on ejection. Mounted cameras ignore old
stair/prediction offsets. Ejection checks capsule clearance and the
path to the exit, retains craft velocity and adds upward separation. A three-second
reboarding lock prevents accidental recapture. Death, respawn and disconnect
release only the affected seat. Hull destruction releases every occupant; loss
of the pilot leaves passengers aboard the descending craft for another pilot to
board. Unoccupied hulls expire after 120 seconds; occupied transports do not.

The server uses a swept collision hull with bounded turning, thrust, collision
and ram damage. Unpiloted craft descend to land; altitude limits follow terrain.
VR vehicles use analog lift with an 18% deadzone, independent vertical braking
and ceiling approach braking. Releasing the stick brings vertical speed to zero.
Horizontal thrust and strafing remain on the movement stick. Desktop flight
controls retain their existing behaviour. Scout rockets follow the dominant
controller independently of the hull. VR hull pitch is cosmetic: up to 0.12
radians nose down with forward speed, and 0.10 radians nose up during ascent
only with horizontal input below 0.1 and horizontal speed below 1 m/s.
Pitch never changes VR thrust direction or vertical speed.
Scout rockets alternate mounts every two seconds, inherit half the craft
velocity, accelerate from 65 to 80 m/s and use the existing ST blast path.
Thin-wall collision and blast occlusion have regression coverage.

## Assets and limits

The models were remodeled in Blender MCP against the original manual illustrations
and in-game screenshots. The Scout has a narrow fuselage, thin swept wings,
forward canards and paired rear fins. LPC/HPC use bronze sloping nose armour,
dark raised centre cowls, recessed passenger bays and connected lift pods; HPC
has four pods and a larger raised aft hull. The common bronze/gunmetal atlas has
original panel seams, access covers, vent grilles and fine surface grain. Small
faces use plain metal to avoid stretched panel markings. Purchase icons match
the revised silhouettes.

These are independent approximations with a refinished CC0
[Kenney Space Kit](https://kenney.nl/assets/space-kit) keel. Retail geometry and
texture pixels are not included. Working seat, control and muzzle positions and
flight/collision parameters are retained. Static detail is batched into one mesh
with five material surfaces, plus two separate control grips (three meshes/seven
surfaces per vehicle). Editable Blender source is
`tools/tribes/vehicle-sources/vehicles.blend`; generation scripts and
[credits](../deathmatch/vehicles/tribes/CREDITS.md) are included. Native compressed
Godot scenes and mipmapped hull textures/menu icons avoid runtime asset import.
All three use the original synthesized turbine loop, with speed-driven pitch.
Team panels recolour after theft; HUD labels identify type, health, speed and
pilot/passenger role.

The flight controller is an independent Godot adaptation, not a port of the
original engine's Flier integration. Acceleration, collision response, hull and
seat geometry, interaction reach, type limits and abandoned-craft timeout are
explicit prototype choices. Original `maxEnergy` is not interpreted as flight
fuel. Headset orientation stays under the existing camera controls; no comfort
settings were added.

Network authority covers purchases, seats, hull motion, rockets and damage.
Snapshots have bounded, finite-value validation, reject duplicate occupants and
support older Scout recordings without passenger fields. Protocol is
`fpsloppa-67-st-command`; matching experimental clients/server are required.
Clients interpolate craft/seats without vehicle-specific input replay prediction,
so high-latency responsiveness needs testing.

Actual headset ergonomics, dedicated seated pilot poses, physical cockpit-stick
manipulation, and autonomous bot flight/transport tactics remain outstanding.
Passengers currently use standing avatar poses at their deck stations. No
contested human vehicle match or VR headset session was run in this pass.

## References

Mechanics were independently implemented from the
[original manual, pages 47–48](https://www.the-flet.com/dynamix/t1/TribesManual.pdf)
and pinned community copies of original scripts:
[Scout](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/vehicles/scout.cs),
[LPC](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/vehicles/lpc.cs),
[HPC](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/vehicles/hpc.cs),
[boarding/ejection](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/vehicles/vehicle.cs),
[stations](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/stations/vehiclestation.cs).
These repository copies are not authenticated retail binaries. No retail artwork
is included in the game. Visual references also include the
[original-game screenshot gallery](https://www.old-games.ru/game/screenshots/733.html). Reference download hashes are in the validation receipts.

## Validation

The transport suite has 93 checks covering both actual Raindance pads, costs,
class restrictions, full capacities, personal fire, guided VR throws, chest packs,
flight bounds, independent ejection, stale lives, death/disconnect, damage/repair,
type limits and old recordings. A four-process ENet test exercises both transports
with a pilot, Heavy passenger and spectator (37 checks). Scout gameplay (55),
Scout ENet lifecycle (17), ST rules (59), recording validation (17), and VR
equipment regression (27) bring the total to 305 checks.

Vulkan screenshots cover empty and occupied decks, cockpits, passenger views and
the purchase wheel. These are graphical/synthetic tests, not headset validation.
Final logs have no script errors. The existing ObjectDB fixture-shutdown warning
remains (one instance headless, two in the final graphical preview).

```sh
godot --headless --xr-mode off --path . --script deathmatch/tests/st_transports.gd
python3 tools/tribes/test_transports_network.py
godot --xr-mode off --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --path . --script tools/tribes/transports_preview.gd
```

Logs, screenshots and references: `test-results/st-transports`.
Tracked receipt: [validation/st-transports-2026-09-29.json](validation/st-transports-2026-09-29.json).
The earlier [Scout receipt](validation/st-vehicles-2026-09-28.json) records its
previous source state.

## Rebuilding the vehicle artwork

1. Run `python3 tools/tribes/vehicle_texture.py`, then
   `godot --headless --xr-mode off --path . --script tools/tribes/vehicle_texture.gd`.
2. Execute `tools/tribes/vehicle_models.py` in Blender. Set `VEHICLE_PROJECT` to
   the worktree path when using a different checkout. The default is the current
   experimental worktree. `scout_model.py` and `transport_models.py` are subset
   entry points to the same current builder.
3. Run `import_scout.gd` and `import_transports.gd` through headless Godot to
   regenerate the compressed scenes, mipmaps and menu icons.
4. Run `scout_preview.gd` and `transports_preview.gd` with Vulkan for occupied,
   pilot and passenger views. Earlier Blender designs are archived only in
   ignored validation evidence, so they cannot accidentally rebuild stale art.

The 29 September design pass reran Scout and transport gameplay checks (148
checks), inspected all three in Vulkan and audited texture mipmaps/material
batching. The 305-check receipt above records the preceding mechanics pass;
network mechanics were not changed or re-tested by this art-only revision.
Design evidence: `test-results/st-vehicle-design`; tracked receipt:
[st-vehicle-design-2026-09-29.json](validation/st-vehicle-design-2026-09-29.json).

## VR transport follow-up

The 29 September controls/smoothing regression covers both dominant hands,
authoritative input validation, analog ascent/hover/landing, menu blocking,
shared hull/camera poses, ejection cleanup and retained Scout/desktop controls.
It exercises 60 Hz simulation against 72/90/120/144 Hz rendering and jittered
20 Hz snapshots. The four-process ENet test now uses tracked VR pilot input,
including descent and hover, with an independent armed passenger and spectator.
Evidence is in `test-results/st-transport-vr`; see
[the follow-up receipt](validation/st-transport-vr-2026-09-29.json).

## Scout controller aim and command follow-up

The next controls pass extends stick lift to the Scout, with raw dominant
controller rocket aiming and cosmetic pitch on all VR craft. Both-handed input,
independent rocket direction and pure-versus-lateral ascent have regression
coverage. See [PDA and remote controls](ST-COMMAND.md) and its validation receipt.

## Remaining Tribes 2 roles

Beowulf, Thundersword and Jericho are available alongside the existing fleet.
They use the same native purchase, authoritative seats, collision, damage,
network snapshots, repair and ejection lifecycle, and the shared ST panel atlas.
Role references: https://playt2.com/guides. Physics and balance are adapted to ST.

| Vehicle | Energy | HP | Crew | Role |
| --- | ---: | ---: | --- | --- |
| Beowulf | 1100 | 600 | Light pilot + gunner | Ground-following grav tank; ballistic mortar |
| Thundersword | 1250 | 500 | Light pilot + bombardier + tail gunner | Gravity bombs; independent rear blaster |
| Jericho | 1500 | 850 | Light driver + gunner | Ground vehicle; deployable inventory and defensive turret |

Use boards, movement steers, Fire operates the assigned weapon, and Jump or Use
exits. Heavy and Medium crew can occupy weapon seats. The tank/bomber pilot can
fire the main weapon when its crew seat is empty; an occupied crew seat takes
over, preventing duplicate firing. Gunner aim follows mouse/headset weapon aim.
Ground craft follow terrain and ignore flight lift; Jericho cannot strafe.

Jericho's driver presses Fire while stopped on level ground to deploy or pack
up. Holding Fire does not repeatedly toggle. A deployed base stays in place and
persists while unoccupied. Its rear service point permits friendly refits and
provides the same team-funded healing/ammunition service as fixed inventory.
Enemies cannot use it or board it while deployed. Its turret fires at visible
enemies within 60 m when no gunner is aboard; a gunner takes manual control.
This adaptation does not add Source/Torque physics or retail asset fidelity.
The six models are original meshes with original ST atlas artwork.

`deathmatch/tests/st_t2_vehicles.gd` covers purchasing, crew roles, ballistic
shots, deployment, service restrictions, snapshots and destruction. The ENet
transport harness with `T2_VEHICLES=1` covers Havoc and all three added vehicles.
