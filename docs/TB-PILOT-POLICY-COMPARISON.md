# TITANBALL cross-policy balance assessment — 2026-09-14

**Preferred human-playtest candidate: heavy-ordnance restriction ON, fixed 200 HP cockpit, passive cockpit healing OFF.** This offers the strongest tested compromise between pilot usability, accumulated defensive damage, and increasingly difficult progression. It is not a demonstrated 50/50 team balance.

This assessment combines the 12 ordnance-enabled and 12 unrestricted matches on identical current production/runner source and Ashfall map hashes, with seeds 7129–7131 for each combination. No new matches or gameplay changes were needed for this comparison. Every arm retains the hull-contact requirement, excludes nearby splash, and uses the same 6v6 TF roster, armour, turrets, stations and timers. Healing is 10 HP/s; Medic passive regeneration remains additive.

## All eight options

| Heavy-ordnance restriction | Cockpit option | Mean active duration¹ | Observed range | Pilot tenure mean / median | Deaths within boarding lock² | Attacker wins |
|---|---|---:|---:|---:|---:|---:|
| ON | Class HP | 12:33 | 10:42–14:23 | 9.71 / 4.32 s | 37.1% | 3/3 |
| ON | Class HP + healing | 10:47 | 9:27–11:58 | 10.68 / 3.93 s | 30.2% | 3/3 |
| ON | 200 HP | 9:34 | 8:49–10:39 | 11.55 / 4.70 s | 7.2% | 3/3 |
| ON | 200 HP + healing | 8:33 | 7:40–8:59 | 17.29 / 6.30 s | 7.8% | 3/3 |
| OFF | Class HP | 14:42 | 12:57–16:00 | 3.77 / 2.50 s | 59.5% | 2/3 |
| OFF | Class HP + healing | 14:50 | 13:51–15:56 | 4.32 / 2.46 s | 65.4% | 3/3 |
| OFF | 200 HP | 13:11 | 10:26–15:41 | 5.17 / 3.37 s | 41.2% | 3/3 |
| OFF | 200 HP + healing | 12:19 | 11:23–14:11 | 6.29 / 3.70 s | 34.8% | 3/3 |

¹ Includes one defender timeout at 16:00 in unrestricted class HP. Preparation excluded. ² Share of pilot deaths occurring within three seconds of actual boarding during active play; not the share of all boardings.

## Why the preferred option

With ordnance enabled and 200 HP without healing, mean pilot tenure was **11.55 seconds**, median **4.70 seconds**, and only **7.2% of pilot deaths occurred within the boarding lock**. The strongest unrestricted alternative, 200 HP plus healing, reached **6.29 seconds**, **3.70 seconds**, and **34.8%** respectively. Both won 3/3 matches. The ordnance rule protects the pilot from routine small-arms attrition; the health cap gives all classes a consistent buffer against the allowed weapons.

The preferred option averaged **4:42 for the first 200 metres**, followed by **4:52 for the final 100 metres**. Its observed completion range was **8:49–10:39**. This preserves a harder defensive finish while leaving room for organized human defenders to slow the push. Its slowest trial had **5:21** remaining after both checkpoint extensions, versus **1:49** for unrestricted 200 HP plus healing. That is timing headroom, not a prediction of how much human defense will improve.

Leaving regeneration off lets defenders retain the value of individual successful heavy-weapon impacts. Adding healing with the restriction enabled increased mean tenure to **17.29 seconds**, raised the manned share from **66.4% to 74.2%**, and reduced mean delivery to **8:33**. It is the most forgiving tested attacker option and is less compelling as the initial balance setting when the bots already deliver reliably.

Class-health options retain an incentive to reserve the cockpit for Heavy. Heavy already has 200 HP, so human class selection could make the class-HP-plus-healing option resemble the strongest treatment for the pilot while exposing other classes to much quicker deaths. The bot averages mix six fixed classes and therefore can understate this selection effect. Uniform health reduces that particular source of deviation.

## Deviations and uncertainty

- **Human defense could be much more effective.** Bots continue making ineffective small-arms hull attacks with the filter enabled. Humans could choose penetrating weapons, concentrate volleys, prepare ambushes and attack replacement pilots. The ordnance-enabled timing may therefore be optimistic for attackers.
- **Human attack could also improve.** Organized escorts, pilot handoffs and manual turret control could defeat positions that stall bots. Neither direction can be assigned a reliable percentage from this sample.
- **Run-to-run variation matters.** The preferred option varied by 1:50 across three seeds; unrestricted 200 HP plus healing varied by 2:48, and unrestricted 200 HP alone by 5:15. These are observed ranges, not bounds on future games or proof of statistical superiority.
- **Win counts are weak evidence here.** Attackers won 23/24 runs. The only defender victory was 18.4 cm short of the endpoint, so treating 2/3 as evidence of a balanced class-health policy would overinterpret the stopping tolerance. Arrival at 290 metres and survival metrics are less sensitive.
- **Pilot experience still needs a human test.** A 4.70-second median is short even in the preferred option. The filter and cap reduce immediate boarding deaths; they do not establish that cockpit control will feel satisfying.

If the heavy-ordnance rule must remain disabled, **200 HP + 10 HP/s healing** is the fallback. If coordinated human defense proves overwhelming with the preferred setting, the existing ordnance-enabled healing option is the next tested survivability step. Neither change should be justified by bot win counts alone.

## Validation and status

Both input reports passed 136 integrity checks each (**272 total**). The heavy-policy telemetry was reanalyzed to count deaths from actual boarding time, and its previously reported aggregate statistics remained unchanged. Production/runner source hashes and all 24 raw JSON hashes were verified; the same map is used throughout. No older navigation-version trials were mixed in. No game setting, server or release was changed.

[Combined machine-readable comparison](validation/tb-pilot-policy-comparison.json), [ordnance-enabled report and plots](TB-PILOT-HEALING-ONLY-TEST.md), [unrestricted report and plots](TB-PILOT-UNRESTRICTED-TEST.md).
