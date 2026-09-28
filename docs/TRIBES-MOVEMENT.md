# Tribes movement test on Stonehenge

Select **ST — TRIBES → Stonehenge**, or use the dedicated
Stonehenge launchers in the Linux test bundle. This loadout equips light-armour
movement by default and intrinsic jets. Stonehenge ST spawns Light with a
blaster, chaingun, disc launcher and repair kit, without a purchased backpack.
The **TRIBES ARMOUR…** button reuses the TF class menu to queue light, medium
or heavy armour, weapons and backpacks as station favourites on Stonehenge.
Walk onto a friendly inventory pad to purchase them. Other maps without stations
retain the respawn/base-area test refit. It does not
depend on `sv_jetpacks` or a pickup. DM, TDM, KOTH and FT can also select it;
the established fixed loadouts in DE, TF, TB, AS, IG, IF and CC remain enforced.

## Controls

| Action | Desktop default | VR default |
| --- | --- | --- |
| Walk / direct jets | WASD | Movement thumbstick |
| Jump, then ski while held | Space | Movement thumbstick click |
| Sustained jets | Q | Weapon-hand A/X |
| Brake on the ground | Release Space | Release movement thumbstick click |

Jump and jet bindings are configurable in Controls. Skiing follows the held
jump binding; a physical VR jump still performs a jump. Skiing does not imply
crouching or grant a crouch accuracy bonus. The headset keeps its tracked
orientation: terrain never pitches or rolls the camera.

The desktop and VR armour indicator becomes **ENERGY**, showing the remaining
jet reserve and a gauge scaled to that class’s capacity. Health represents
armour condition. The status line shows class, speed, WALK / SKI / JETS /
RECHARGING, and a queued class when different. Remote class badges identify
armour; the existing jetpack model shows replicated exhaust.

## Movement and energy

Walking accelerates toward 11 m/s. Skiing carries tangential momentum, gains
speed downhill and loses it uphill. Releasing ski restores walking traction.
Airborne movement keys provide no free air acceleration: hold jets to steer.
Jet thrust adds to velocity, without a landing speed clamp or the arena
jetpack's eight-second cooldown / 48 m travel budget. Boosted jumps and blast
impulses also feed the same velocity.

With a purchased energy pack, the light-armour profile has **60 energy**, drains **25 per second** while
jetting, and regenerates **11 per second**, including during thrust. This models
base armour recharge of 8 plus an equipped energy pack's 3. From full energy,
continuous thrust lasts approximately 4.29 seconds; released jets recharge from
empty in approximately 5.45 seconds. At exhaustion, jets wait for 3 energy
before automatically resuming if still held. The unmodified CTF spawn kit
recharges at 8/second (about 3.53 seconds of continuous thrust and 7.5 seconds
to recharge from empty). Grounded jets initially prioritize
lift. Airborne input divides thrust between lift and horizontal acceleration;
horizontal assistance tapers as speed in the requested direction reaches 22 m/s.

Numerical reference: Andrew / floodyberry's firsthand reconstruction of
[Tribes 1 physics constants](https://floodyberry.wordpress.com/2008/02/20/tribes-1-physics-part-one-overview/)
and [movement / energy behaviour](https://floodyberry.wordpress.com/2008/02/24/tribes-1-physics-part-two-movement/).
The Godot implementation is original project code, not copied retail source.

This is a **Tribes-inspired playable test**, not a claim of an exact original
engine port. It uses the existing Godot capsule and swept collisions, bounded
120 Hz substeps, held frictionless slope travel rather than the original jump
script's micro-bounces, and an explicit low-energy restart threshold.
Energy-consuming weapons, backpacks and ST deployables are implemented.
Bots use outdoor skiing and staged tower approaches; competitive route planning
remains incomplete. Physical VR crouching and the existing capsule
are retained for all classes, and walking uses the class’s forward speed in
every direction. The loadout now supplies a dedicated Tribes arsenal. See [personal equipment](TRIBES-LOADOUT.md) for weapons, packs and test adaptations.

## Armour classes and team supply

Tribes uses a fixed class damage profile plus a **depleting armour condition**
(`maxDamage`), with a separate rechargeable energy cell. It does not use an
additional consumable Quake-style armour pool. The test therefore represents
condition as health and reuses the armour HUD slot for jet energy.

| Class | Health | Energy | Walk m/s | Jet force / mass | Drain / second | Gun slots | Cost |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| Light / Peltast | 100 | 60 | 11 | 236 / 9 | 25 | 3 | 175 |
| Medium / Hoplite | 152 | 80 | 8 | 320 / 13 | 31.25 | 4 | 250 |
| Heavy / Myrmidon | 200 | 110 | 5 | 385 / 18 | 34.375 | 5 | 400 |

With the energy pack equipped, all classes recharge at 11/second, including during thrust; other packs use 8/second before active-pack drain.
Jump impulses are 75/9, 110/13 and 150/18; horizontal jet taper speeds are
22, 17 and 12 m/s. Blast impulse scales inversely with class mass. Light's
accepted movement profile is unchanged. Health normalizes the reference
0.66 / 1.0 / 1.32 durability to the existing 100 HP light baseline.

The dedicated arsenal applies weapon-specific class resistances. Ordinary health pickups repair class condition to its maximum; armour pickups cannot add a second pool. See [personal equipment](TRIBES-LOADOUT.md).

On Stonehenge, fixed stations use the [CTF inventory and energy rules](STONEHENGE-CTF.md):
5,000 initial energy per active team slot, 700/30 seconds replenishment, paid
Light spawn kits, equipment trade-ins, gradual repairs and ammunition service.
The desktop and VR station wheel shows the authoritative shared reserve.
Personal jet energy is separate. Heavy armour is purchased at a station;
saving a favourite does not grant it on respawn.

Other maps without stations retain the earlier prototype: 5,000 per team,
selected equipment charged on respawn and refits within 5 m of a friendly spawn.
FFA uses a third shared reserve. New matches reset the economy.

Reference: the public [Tribes 1.41 base scripts](https://github.com/shayk-siege/t1.41-base/tree/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/armors),
[damage handling](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/game/player.cs),
and [team-energy constants](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/game.cs).
This is a maintained community base-script distribution, not an authenticated
retail 1.11 extraction. The original finite-resource settings include 5,000
energy on joining and 700/30 seconds, but default team energy in that source is
infinite. Stonehenge deliberately enables finite reserves and protects starting contributions
against reconnect/respawn farming. Its emergency Light kit prevents an empty
reserve from blocking respawns; unpaid equipment has no trade-in credit.

## Authority, lifecycle and collision

The server owns energy, movement and damage. Clients send only held controls,
guarded by the current life; they cannot assign fuel. Local prediction uses the
same controller and replays outstanding movement against authoritative energy
and contacts, excluding time the server has already simulated while holding an
older input. Camera correction is smoothed through the existing view offset.
Menus, tracking loss, input timeout, death, freezing and respawn clear or block
held thrust. Loadout changes clear momentum and prediction history.

The current tick's swept path is used for pickups and CTF flags, including
line-of-sight checks for flags. This prevents high-speed passes from skipping
small pickup volumes. Wall collisions discard incoming normal velocity instead
of renormalizing the result, preventing collision-generated speed boosts.

## Running and validation

Source desktop test:

```sh
godot --path . --xr-mode off -- --practice --no-bots --map ctf_stonehenge --mode st
```

For WiVRn, start the headset connection and use `--xr-mode on` or the bundled
`Stonehenge-VR.sh`. Neither launcher starts a public server. Dedicated local
servers can use `sv_gametype "st"` and
`map "ctf_stonehenge"`. The network protocol is
`fpsloppa-58-st-tribes`; matching clients and servers are required.

Tests: `deathmatch/tests/tribes_physics.gd`, `tribes_stonehenge.gd`,
`tribes_demo.gd`, `tribes_armour.gd`, and `python3 tools/run_tribes_network.py`. Results are retained
under `test-results/tribes/`. The terrain test runs 27 compiled-map segments at
30, 60 and 100 m/s; it is not a complete competitive-route or headset comfort
assessment. Stonehenge retains its existing 16 m terrain grid and approximate
architecture. The user validated the initial light-armour skiing and jet feel in VR. The new
armour classes have automated movement, combat, economy, HUD, multiplayer and
replay coverage; class tuning still needs a headset playtest.
