# TITANBALL: hull protection and revised weapon-spawn rerun

13 September 2026 · Three complete visible 6v6 rounds · Ashfall Boulevard · seed 7129.

Historical comparison: following this study, the user retained TF/Quake as the
only TB loadout. UT/Doom tests and their temporary pickups are retired.

The same map, bots, route, preparation, timers, stations and numerical cannon/armour settings were retained. This rerun combines direct-hull-contact pilot protection, linked cannon heat and revised classless pickup placement. It therefore measures the combined configuration, not the isolated effect of any one change.

## Match outcomes

| Configuration | Previous distance | Revised distance | Revised winner | Checkpoints | Pilot occupancy, before → after | Deaths, attackers / defenders |
|---|---:|---:|---|---:|---:|---:|
| TF / Quake | 287.1 m | 299.3 m | Defenders | 2/2 | 38.9% → 40.7% | 232 / 168 |
| UT99, classless | 155.3 m | 232.3 m | Defenders | 2/2 | 27.4% → 34.8% | 371 / 254 |
| Doom, classless | 300.0 m | 261.7 m | Defenders | 2/2 | 53.7% → 39.8% | 336 / 251 |

![Matched route progress](../test-results/titanball/simulation/contact-r2-before-after.png)

Active times exclude preparation. Checkpoints grant +3 minutes after rear clearance. Raw endpoints within the existing 2 cm delivery tolerance count as delivered. The precise active times and checkpoint awards are in the [summary](../test-results/titanball/simulation/contact-r2-summary.json).

## Pilot survival

| Configuration | Mean observed tenure, before → after | Median, before → after | Revised boardings | Revised tenures under 1 s |
|---|---:|---:|---:|---:|
| TF / Quake | 2.61 → 3.01 s | 2.07 → 2.05 s | 130 | 6.9% |
| UT99, classless | 2.32 → 1.82 s | 0.96 → 0.67 s | 184 | 65.8% |
| Doom, classless | 2.67 → 1.55 s | 1.63 → 0.73 s | 247 | 62.8% |

These are active cockpit tenures, clipped at the end of preparation and match end. A pilot still alive when the round ends is right-censored; these are not fitted life-expectancy estimates. Every recorded departure was caused by death, rather than accidental voluntary exits.

The UT aggregate needs context: it now reaches the more dangerous final section. For boardings before 155 m, mean tenure rose from 2.36 to 5.21 s and median from 0.98 to 2.03 s. The revised final section added 87 tenures averaging 0.87 s; the original run never reached it. This comparison still contains differing fights and durations within that region, rather than a controlled counterfactual.

Every recorded pilot damage event in the revised matches had verified hull contact. Direct bullets/beams, projectile contacts and explosions on the actual hull can hurt the pilot. Nearby splash, melee, ongoing burning and environmental damage do not pass through. Authoritative forced death retains its bypass. Projectile sweep contacts carry the struck hull identity; independent explosions use a 4 cm physics contact tolerance. Ordinary on-foot splash is preserved.

## Cannon contribution

| Configuration | Previous cannon kills | Revised kills / defender deaths | Revised logged damage | Share of attacker→defender logged damage | Damage per piloted second | Fired rounds | Damaging direct events / rounds |
|---|---:|---:|---:|---:|---:|---:|---:|
| TF / Quake | 27–32 | 35 / 168 (20.8%) | 5,260 | 20.8% | 13.5 | 842 | 64.5% |
| UT99, classless | 9 | 18 / 254 (7.1%) | 2,879 | 10.4% | 8.6 | 548 | 71.7% |
| Doom, classless | 26 | 36 / 251 (14.3%) | 4,778 | 17.8% | 12.5 | 922 | 71.6% |

Logged damage is post-armour and can include overkill. Damaging direct events per round are a damage-connection measure, not aim accuracy: protected targets and collateral splash differ. The original TF direct cannon label was SENTRY, shared with engineer sentries, so its 27–32 cannon kills are a conservative range and its 5,442 combined damage is only an upper bound. Revised direct and splash cannon damage both use TITAN CANNON, with a separate blast flag. UT/Doom have no engineer sentries.

The cannons provide measurable support, but cannot independently keep a pilot alive under concentrated fire. In UT their contribution is relatively small beside Shock Rifle fire. Their fixed narrow horizontal coverage, slow X-axis aiming and cover limit opportunities; a damage increase only helps shots they can actually take. The logs do not directly measure psychological suppression, missed enemy shots or displacement caused by cannon fire.

Each side now has one shared heat reservoir, cooldown and lock for both barrels. A firing volley charges 12.5 once, including a volley with one obstructed barrel. At 100 heat both barrels lock; the opposite side remains independent. The cockpit has two corresponding meters, and both states replicate to clients. The prior unobstructed eight-volley burst budget is preserved.

Peak recorded pair heat / overheat entries: TF / Quake 87.1 / 0, UT99, classless 65.0 / 0, Doom, classless 62.5 / 0. These matches did not sustain enough continuous eligible firing to make thermal lockout the main limitation. Dedicated tests exercise full paired overheating and recovery.

## Weapon placement adjustment

The baseline preparation samples exposed an access imbalance: one attacker versus six defenders acquired an upgraded gun. Revised UT/Doom fixtures add a shared basic weapon rack at every spawn point across the three attacker stages and defender base: 16 racks, plus the existing 24 advanced weapon caches and 24 adjacent ammo pickups. All 64 coordinates match between the two profiles and pass navigation reachability assertions.

UT racks carry Shock Rifles; Doom racks carry Chainguns. Each life must physically collect its weapon; weapon-stay lets teammates collect it too, and an already owned rack cannot refill ammunition repeatedly. All twelve bots are armed before the gate opens. Advanced caches unlock at 60 s and use normal 30 s respawns. The two outer UT sniper caches become Miniguns; one exposed middle-route sniper cache remains near route distance 152 m. Both teams can use every pickup.

These are runtime classless test placements. The distributed TB BSP retains its normal pickup-free TF layout. See the [64-position manifest](../test-results/titanball/simulation/contact-r2-pickup-layout.md) and [placement plot](../test-results/titanball/simulation/contact-r2-pickup-layout.png).

The change fixes initial gun access, but also biases the bots toward the always-available basic weapon. UT pilot deaths were 181 Shock Rifle and three Enforcer; the original 47 sniper pilot deaths became zero. Interpret the classless results as these specific pickup-and-bot configurations, not a representative ranking of every UT/Doom weapon. Weapon selection, scarce advanced pickup control and late defensive terrain remain intertwined.

## Armour and damage tuning

Armour stays at 200 with tier-2 absorption; cannon damage stays at 12 per barrel, with a 0.5 s interval, 60 m range and 1.25 m splash. Raising permanent armour from 200 to 400 would leave health loss unchanged for individual hits of up to 400 raw damage: the existing rule absorbs half, limited by the reservoir, and restores the reservoir after each hit. The controlled regression verifies this through the real armour function.

A separate 10% pilot damage reduction would ideally extend survival under steady fire by about 11%, subject to rounding and discrete volleys; changing absorption from 50% to 60% would instead be roughly a 25% extension. Neither is implemented. Increasing cannon damage from 12 to 14 would add 16.7% raw damage for successful shots, without changing their firing coverage. These are arithmetic estimates, not simulated balance outcomes. The TF finish is already very close, so a global buff needs stronger evidence than one run per configuration.

## Validation and limits

- 37 pilot-protection checks and 25 cross-loadout contact/rack/armour checks passed.
- 11 linked-heat, 60 robot gameplay and 21 cannon/crush checks passed on the final runtime code.
- 102 ordinary combat, hit-detection and weapon-variant regression checks passed.
- Real ENet server plus two clients passed 65 checks, including independent replicated pair heat/locks. Native Vulkan rendering verified the two cockpit meters.
- All 56 completed-match integrity checks passed, including team counts, preparation, boarding/replacement, pickups, pilot contact flags and cannon pair IDs.
- Each round ran in a visible Vulkan Mobile observer window at requested 4× playback with a fixed 1/60 s gameplay step. Captures from TF, UT and Doom were inspected. No script errors occurred. Existing MultiMesh interpolation warnings and small ObjectDB cleanup warnings remain in native logs.

One round per profile cannot establish win rates, isolate the three simultaneous changes, or establish human/Quest performance. Coordinated medic protection remains limited in these bots. No headset test or performance claim is made.

[Combat measurements](../test-results/titanball/simulation/combat-contact-r2.json) · [Baseline measurements](../test-results/titanball/simulation/combat-baseline.json) · [Runtime source hashes](../test-results/titanball/simulation/contact-r2-source-hashes.json) · [Reproduction protocol](../tools/titanball/simulation/README.md)
