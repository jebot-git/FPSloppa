# CQ squads, deployment map and radio — 14 October 2026

Implemented on `experimental/cq-voxelspace`. Candidate only: the live service and WiVRn session were not changed. Paired client/server protocol is `fpsloppa-cq-frontier-21-squads`.

## Behaviour

Each team has Alpha, Bravo, Charlie and Delta squads, each limited to eight members by the native authority. Humans must join a squad before deployment. Class selection and death lead to the tactical map; class, loadout and calibration remain accessible there. Initial deployment requires calibration confirmation. Death waits for an explicit deployment choice after the respawn delay.

The map displays POI ownership, capture/contest rings and same-squad positions. Clicking a POI or squadmate marker selects that destination, as does the selector. A selection ring identifies the chosen marker. Enemy player positions are absent. Ineligible destinations show an explanation and cannot deploy. See [overview](deployment-map.png), [selected POI](controlled-poi.png), and [selected teammate](squad-buddy.png).

The C++ authority accepts controlled, uncontested POIs and living same-squad teammates outside combat. Firing, launching a grenade, melee/airstrike emission and taking damage impose an eight-second combat lock; vehicle damage also locks its occupants. Buddy requests bind to the current player life. Tank drivers are excluded. An allied transport buddy permits deployment only into a free passenger pod, reserved atomically without replacing the driver. Ground destinations require safe collision, slope, water, bounds and occupancy checks.

Team insertion remains available for initial entry and fallback deployment. Bases lie on opposite map sides; squad anchors are spaced 96 metres apart, with safe-position probes. Changing squad is limited to staged or dead players. Automated clients are assigned to the least populated squad.

One radio press/hold selects squad voice. Release and press again within 0.32 seconds to hold team voice. Native membership determines CQ team and squad routing. Receivers reject invalid scopes and clear buffered squad audio after membership changes. Desktop and VR indicators show the active channel.

## Native ownership

`authority_squads.cpp` owns capacity, admission, deployment and seat allocation. Native action 11 joins a squad; action 12 requests a destination. Snapshot section 15 carries 17 bytes per player for identity, life, squad and combat deadline. The bounded native validator and independent client decoder validate it. UI eligibility previews cannot authorize a spawn. Dead-player input queues continue to drain while awaiting deployment.

## Validation

- [Native golden checks](core-tests.json): **910,087 passed**, including full 64-slot squad capacity, stale-life requests, POI/terrain rules, combat locks and transport seats. Existing collision diagnostics are included in that result.
- [ASan/UBSan](sanitizers.log): the same **910,087 checks passed**.
- [Real Jolt squad checks](squad-jolt.log): **505 passed**, including actual capture, collision-safe deployment, combat and manual respawn.
- [Existing Jolt regressions](full-suite.json): **33,891 checks passed** across functional, terrain, entity, transport and VR fixtures; corresponding logs are retained here.
- [Rendered map/radio checks](map-radio.log): **36 passed**, including actual POI and teammate marker clicks, death navigation, combat/vehicle eligibility, double press, native-team privacy, Opus stream scope and membership-buffer invalidation.
- [Rendered menu/HUD regression](menu-hud.log): **62 passed**. Screenshots inspected at 960×640 using Forward+/Vulkan.
- [Final tracked jungle ENet load runs](final-32-64.json): **32 and 64 clients**, 301 measured ticks each, **zero disconnects**, accepted input fractions **100%** and **99.9635%**. These are short ten-second measurements following warmup, not sustained production capacity certification.
- [Actual arena integration](arena-integration.json): desktop and tracked-pose clients passed squad assignment, death, respawn and team-change checks alongside combat/equipment. A four-bot 600-tick run passed, with 19 existing authored navigation warnings.
- [Radio guards](radio-guards.log): 13 assertions passed; this isolated fixture reports six ObjectDB objects remaining at process exit.

The rebuilt portable Linux server receipt is [retained](linux-server-build.json). Final source hashes are in [source-sha256.json](source-sha256.json). The [legacy four-peer ENet radio regression](legacy-radio.log) passed all four roles; teammate and enemy fixtures each report two ObjectDB instances remaining at exit.

## Remaining live validation

The new flow targets the resident native CQ authority. Legacy script-only hosting has not been migrated to this deployment flow. No real headset/microphone ergonomics, remote installation, live network impairment, or sustained 64-player session was exercised here. The CQ audio permission checks use accepted native membership fixtures; the four-peer ENet regression exercises the existing non-CQ radio wire and codec. Live VR double-press timing and map interaction still require confirmation.
