# TF and eight-player Assault validation — 2026-09-11

Tested the current working tree using Godot 4.7.2 on Linux. This is a local source-tree validation, not a newly exported or published release.

Final result: **PASS** — 78 TF gameplay assertions, 20 graphical assertions, the TF map/network suite, 64 AS rule assertions, and all nine processes in the eight-client AS scenario. The final AS run recorded movement and firing from all eight clients, five combat deaths, and unanimous BLUE victory (`0:1`).

## TF

- All nine class loadouts, movement multipliers and common hitboxes; class selection/respawn; medic healing; sniper focus; heavy brace; pyro ignition; engineer building/destruction; spy reveal/disguise rules; TF flag capture/return rules.
- Soldier, demoman and pyro grenades launch at the weapon, travel under gravity, and retain the appropriate fuse/detonation behavior. Swept collision catches a thin wall during a 200 ms simulation step; player impact applies authoritative damage. Ammo, dead-player and spectator guards pass.
- The real ENet server and two clients validate class selection, custom VRM upload/download for spy disguises, sentry replication, pipe launch velocity, moving projectile snapshots, arming time and detonation cooldown.
- Spawn/flag/capture connectivity checks pass for Ironspan and Relayworks.
- Forward Mobile graphical checks load actual VRMs, validate all class badges, friendly/enemy cloak behavior and reveal restoration. All twelve ability effect types render. A 90-effect burst stays within the 64-effect cap, and all effects expire. The saved effects and class-badge images were visually inspected.

Two production fixes resulted from testing:

1. Pipe arming and fuse timestamps now cross the network as remaining durations, preventing different client/server clocks from producing incorrect arming state. The HUD consumes that state and names the action, including `USE DETONATE PIPE: READY` once armed.
2. Effect-expiry callbacks now hold a weak reference to their node. Evicting older effects at the 64-effect cap no longer causes callbacks to access freed nodes.

The final checked TF logs contain no script/engine errors or failed assertions. Godot still reports one or two ObjectDB instances at test shutdown; that pre-existing cleanup warning is not presented as a fully clean leak audit.

Current implementation limits: this test covers class badges and cloaking, not a shirt/hair team-tint shader; that shader is not present in the current implementation. Cooldown feedback is HUD text, not a separate graphical meter.

## Assault: dedicated server plus eight clients

`tools/hispeed_concept/eight_player_test.py` launches nine separate Godot processes: a dedicated server and eight ENet clients, each with an independent user profile. The map is the actual HiSpeed concept BSP, SHA-256 `af9d23ae64f764b4ed768b6f297797665fbe707c8483a3d6d43ba1c3f2a1a495`.

The scenario checks:

- Eight-player roster, automatic 4-versus-4 allocation, pistol-only initial spawns, and absence of TF classes in AS.
- Movement and pistol fire from all eight clients through the production input RPC and authoritative simulation.
- Four simultaneous scripted duels on the train roof. Test setup grants rocket launchers to exercise both hitscan and projectile replication; normal initial-spawn loadouts are checked before that setup. Production combat performs damage, deaths, scoreboard updates and client-requested respawns.
- Both ordered objectives, including simultaneous touches by multiple attackers, without double advancement.
- First-leg completion, automatic attack/defend swap, reset objectives and turret ownership, and use of the recorded first-leg time budget.
- Friendly turret damage rejection and attacker destruction replicated to all eight clients.
- A faster return assault, with every client acknowledging the same winner and score.

The independent AS rule test also passes, including actual targeting/damage checks for all three static turrets: 119 visible target positions hit and 62 occluded positions protected.

This is a short, controlled LAN functional test. Objective positions and the clock are set by the harness to exercise transitions; it is not an autonomous full-map navigation playthrough, Internet-latency test, long-session soak, human balance test or headset frame-rate measurement. A movement assertion was corrected to measure maximum displacement during the test rather than final displacement, so returning near a starting position is not counted as failed movement.

## Reproduction and evidence

```sh
python3 tools/validate_fortress.py
Godot --path . --xr-mode off --rendering-method mobile --script res://deathmatch/tests/fortress_visuals.gd
python3 tools/hispeed_concept/eight_player_test.py ../Builds/HiSpeed-Concept/maps/tf_hispeed_concept.bsp
```

Use the installed Godot 4.7.2 executable in place of `Godot`. UDP access is required for the network runners; the visual test needs a display/GPU.

Evidence under `test-results/`:

- `fortress-validation.json`, `tf-projectiles-fixed.log`, `tf-network-{server,scout,spy}.log`
- `tf-current-visuals.log`, `tf-ability-effects.png`, `tf-class-badges-close.png`
- `as-current-rules.log`, `hispeed-sentries.json`
- `as-eight/RESULT.json` and the nine per-process logs; server metrics include per-client acknowledgements and combat counts
