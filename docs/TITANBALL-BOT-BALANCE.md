# TITANBALL: visible 6v6 bot comparison

13 September 2026 · Ashfall Boulevard · one complete round per configuration.

This records the original `live-*` baseline. The follow-up with hull-contact
protection, linked heat and revised pickup placement is documented in
[TITANBALL combat rerun](TITANBALL-COMBAT-R2.md).

**The UT trial strongly favoured defenders. TF was a close defender win; Doom
attackers delivered the robot with 3:39 remaining.** These are exploratory
results for the tested bots and pickup layout, not measured human win rates.

| Configuration | Winner | Route completed | Checkpoints | Active time | Pilot occupancy | Deaths: attackers / defenders |
|---|---|---:|---:|---:|---:|---:|
| TF classes + Quake | Defenders | 287.1 / 300 m | 2 / 2 | 16:00 | 38.9% | 256 / 141 |
| Classless UT99 | Defenders | 155.3 / 300 m | 1 / 2 | 13:00 | 27.4% | 286 / 75 |
| Classless Doom | Attackers | Delivered | 2 / 2 | 12:20.6 | 53.7% | 195 / 147 |

All times exclude the one-minute preparation period. Checkpoints grant three
minutes each, so UT expired sooner after failing to clear checkpoint two. Doom's
raw end distance was 299.988 m, inside the mode's existing 2 cm delivery tolerance.

![Route progress across the three live rounds](../test-results/titanball/simulation/comparison.png)

## What changed and what was tested

Production bots now assign a nearby attacker to board via ordinary ladder/jump
input, stay seated, replace a dead pilot, escort the advancing robot, and
intercept it as defenders. A visible pilot receives additional combat priority;
normal perception and line of sight still apply. Ground defenders avoid the foot
kill zone, elevated defenders retain safe positions, and supply goals use actual
universal dispensers. Classless bots also consider nearby weapon upgrades.

The focused objective regression passed **10/10** checks. The existing robot
regression passed **60/60**, including normal loadout policy and combat/route
behaviour. The completed match records passed **42/42** integrity checks for team
counts, class/rule isolation, preparation, boarding, pilot replacement, combat,
pickups and completed rounds. All **384 pilot departures** across the three
rounds coincided with pilot deaths; bots were not abandoning the seat through
accidental jump inputs.

All three matches ran with a visible 1280×800 Vulkan Mobile observer window on
Intel Arc A770 / Godot 4.7.2 Fedora. The requested playback was 4×, with a retained
1/60-second gameplay step. Screenshots were saved once per simulated minute and
visually inspected. This was not a headset or frame-time benchmark.

## Where the advantage appeared

**TF:** attackers cleared checkpoint one at 2:47 and checkpoint two at 8:40.
Pilot occupancy fell from about 71% before the first checkpoint to 35% between
checkpoints and 29% in the final section. They finished only 12.9 m short, despite
losing substantially more players. This suggests a defender lean in this trial,
with increasing late-route pressure as intended, rather than an impossible
attacker objective.

**UT:** checkpoint one fell at 2:41, slightly faster than TF. Progress then nearly
stopped around 140–155 m. Pilot occupancy after checkpoint one was about 16%.
The sniper rifle accounted for **190 of 286 attacker deaths**. Attackers repeatedly
lost upgraded weapons; among alive, unseated player samples, **56.8% of attackers
had only starter equipment**, versus **12.8% of defenders**. This is a strong
hold in the tested setup, associated with ranged weapon control and short pilot
survival. The data does not isolate weapon damage from weapon availability.

**Doom:** checkpoint one fell at 2:33 and checkpoint two at 6:30. Attackers
maintained 53.7% pilot occupancy and delivered with 219.4 seconds to spare,
consistent with the intended ability to finish when manned for roughly half the
round. Starter weapons remained effective: Dual Pistols accounted for 200 of
342 deaths. Alive, unseated starter-equipment samples were 45.9% for attackers
and 62.9% for defenders. This trial favoured attackers, although defenders still
inflicted more deaths and slowed the final approach.

The robot spent only **5.6 / 3.4 / 5.1 seconds** both manned and effectively
stationary in TF / UT / Doom, respectively. Those totals include initial
acceleration ticks and do not distinguish every kind of obstruction. They argue
against a persistent geometry blockage explaining the results. Alive bots had
empty/idle goals in at most 0.6% of sampled seconds. This does not imply perfect
navigation or tactics, but the objective loop functioned through genuine combat.

## Comparable setup and important limitations

The same 300 m BSP, robot combat/motion, 60-second preparation, fixed timer,
checkpoint extensions, forward spawns and universal stations were used. The TF
teams each had scout, soldier, demoman, medic, heavy and engineer. Classless
players used 100 health, 100 armour and starter weapons on each life. The map's
normal TF rules and distributed BSP were not changed by the classless fixture.

UT and Doom each received 24 temporary weapon caches and 24 adjacent ammo
pickups, with identical seeded positions. Eight weapons occupy each route third;
some caches are in sheltered side rooms. All 48 positions in each profile passed
navigation reachability assertions. Ordinary pickup collection and 30-second
respawns remained active. Either team could take them. No superweapons,
translocator or optional Doom railgun were included. See the
[placement table](../test-results/titanball/simulation/pickup-layout.md) and
[harness protocol](../tools/titanball/simulation/README.md).

Placement counts do not guarantee equal access. Immediately before the gate
opened, just one attacker had acquired an upgraded gun, while all six defenders
had one, in both classless runs. The closed hangar limits attackers' preparation
access; defenders can gather weapons while moving into position. This is a
material confound when comparing classless profiles with TF's issued loadouts.
The starter-equipment percentages above use actual slot ownership, correctly
recognising UT's slot-1 Bio Rifle as an upgrade.

The bots also have limited coordinated support. Only three one-second TF samples
recorded a heal goal, so this trial should not stand in for a coordinated human
medic team. Bot aiming, class composition, pilot selection and pickup-control
feedback all affect the outcome. A shared random seed is a reproducibility aid,
not proof that profiles experience identical random events.

Before changing the production map or timer, useful follow-ups would be matched
preparation weapon access, additional pickup seeds, and alternate TF rosters or
stronger support coordination. The clearest present tuning concern is **UT's
ranged weapon control in the middle section**, rather than a universal defender
advantage across all three configurations. No balance values were changed after
these results.

## Retained evidence

- [Validation receipt and summary](validation/titanball-bot-balance.json)
- [Raw TF match](../test-results/titanball/simulation/live-tf-7129.json),
  [UT match](../test-results/titanball/simulation/live-ut99-7129.json),
  [Doom match](../test-results/titanball/simulation/live-doom-7129.json)
- [TF late-route live capture](../test-results/titanball/simulation/live-tf-7129-0960.png),
  [UT middle hold](../test-results/titanball/simulation/live-ut99-7129-0600.png),
  [Doom final approach](../test-results/titanball/simulation/live-doom-7129-0780.png)
- [Objective regression](../test-results/titanball/simulation/objective-tests.json),
  [existing gameplay regression log](../test-results/titanball/simulation/gameplay-regression.log)
- [Runner and reproduction instructions](../tools/titanball/simulation/README.md)

The final native runs had no script exceptions. They did emit MultiMesh
interpolation warnings. Shutdown reported two retained ObjectDB instances for
TF/Doom and 22 instances plus four resources for UT. These cleanup diagnostics
are retained in the logs; this work does not claim to resolve them.
