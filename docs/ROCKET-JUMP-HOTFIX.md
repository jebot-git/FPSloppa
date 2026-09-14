# Rocket-jump validation — 14 September 2026

The rocket-jump follow-up reproduced another missed-shot path: a one-frame trigger tap during the last 200 ms of cooldown was discarded in both offline Quake and Doom. Packet retransmission alone did not address this. The rocket launchers now retain a primary trigger edge for up to 250 ms, firing once when ready. Their original cooldowns, ammo costs, collision, damage and blast impulses remain unchanged. Offline practice now uses the same acknowledged fire-edge path as multiplayer. Expiry, opening a menu, death and changing weapons cancel pending input.

A further report of a lost Doom shot after respawning led to a second reproduction: empty tracked weapon swings and kicks imposed a 300 ms firing lock before weapon processing. Quickly aiming downward or moving a tracked foot could therefore discard an otherwise ready rocket. Empty tracked swings now retain melee detection and its shared cooldown without locking ranged fire. Confirmed contact still imposes the firing lock; axes, fists and explicit desktop melee retain their existing swing behavior.

## Automated results

Run `python3 deathmatch/tests/run_rocket_jump_tests.py` from the workspace. The suite uses isolated user data and configuration, and requires permission to open local ENet sockets. Results and logs are in `test-results/rocket-jump-hotfix/`.

Both loadouts passed the final run. Each uses a real ENet server/client pair with seven rocket shots plus a normal-jump control. Cases cover floor-facing desktop aim, tracked barrels intersecting the floor, a moving hop followed by a simultaneous jump/rocket tap at four input phases, a dropped first edge packet, 100 ms of added input delay, and a 200 ms remaining cooldown. Each intended rocket fired exactly once, spent one rocket, caused self-damage and boosted the shooter. The owning client received authoritative jump height and health. Moving cases took off twice and returned to the ground.

| Flat-floor fixture | Quake rise | Doom rise | Quake self-damage | Doom self-damage |
| --- | ---: | ---: | ---: | ---: |
| Normal jump | 1.43 m | 1.43 m | 0 | 0 |
| Standing downward rocket, desktop aim | 6.71 m | 4.48 m | 57 | 59 |
| Standing rocket, low tracked hand | 4.85 m | 3.25 m | 56 | 58 |
| Moving jump plus rocket | 9.95–10.07 m | 9.03–9.41 m | 54–55 | 56 |

These are controlled fixture measurements from 100 health and zero armor, not guaranteed heights in a real map. Aim, trigger timing, velocity and overhead geometry affect the result. The moving trial includes a preceding ordinary hop; its total displacement is not a measurement of rocket-jump range.

Offline regression tests reproduce the original discarded tap and verify delayed firing after the fix. Expired taps, menu cancellation and weapon changes produce no delayed shot. Blast physics, input delivery, landing reconciliation, weapon variants and replication regressions also passed. Automated fixture shutdowns retain a one-ObjectDB-instance warning.

The tracked-melee fixture spawns a fresh player for each case. Before the fix, both loadouts lost a ready shot to an empty hand sweep and to a raised-foot movement, leaving a 300 ms cooldown. After the fix all four shots fire. Confirmed weapon contact still deals 10 melee damage and prevents a simultaneous shot. Existing axe/weapon melee and kick regressions also pass.

The final harness explicitly selects and asserts the weapon rules on both peers. Earlier runs that only supplied the practice loadout argument to a dedicated host did not reliably select the intended rules; their labeled comparisons are superseded by the table above. The retained pre-fix offline log independently demonstrates the cooldown failure with explicit Quake and Doom selection.

## Headset validation

The initial WiVRn run reproduced the user's report of remaining misses. Its recorded ready-to-fire presses succeeded; several other presses arrived during cooldown. Map weapon pickups were still enabled in that first probe, so its aggregate shot count must not be treated as a count of rockets.

After the buffer fix, the Doom and Quake sessions used only the rocket launcher, disabled pickups, and restored health after three seconds grounded without firing. Both recorded successful rocket-assisted jumps and completed with exit code 0. The wearer initially confirmed both, then reported one remaining Doom miss after respawning. The tracked-melee fix above addresses a separately reproduced cause of that remaining class of miss; the initial telemetry did not record enough post-step detail to prove the historical cause. The focused Doom follow-up recorded post-step melee/cooldown timing and exited with code 0. The wearer confirmed that the first rocket after respawning now fired correctly, including quick downward aim and jumping. Raw telemetry stays in ignored test results.

This validation uses Linux Godot and WiVRn. Actual Windows/VirtualDesktop execution and testing against an updated remote server remain outstanding. Multiplayer needs matching server code for the new input behavior.

The Linux and Windows replacement test builds in `Builds/Hotfix-0.11v/` were refreshed after both fixes, with updated SHA-256 manifests. The native Linux export passed separate Quake and Doom headless practice smoke tests: both reached match readiness and exited with code 0, without script/engine errors. These short packaged checks supplement the source headset tests; they do not establish Windows runtime compatibility. Nothing was published or deployed to the live server.
