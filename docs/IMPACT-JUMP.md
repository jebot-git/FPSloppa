# UT Impact Hammer jump — 2026-09-13

Hold primary fire to charge the hammer, aim at the floor, then jump and release primary together. A full charge takes 1.5 seconds and stays armed while held. Floor contact alone does not discharge it. A nearby opponent can trigger the charged piston. In VR, aim the weapon hand downward and use the same jump/release sequence.

The previous implementation fired automatically at full charge, applied recoil even when striking opponents, and charged no health for a surface jump. Its 1.6 m trace left little room to release after leaving the floor.

The new primary surface trace reaches 2.5 m while player/building damage retains its existing 1.6 m reach. Hitting world geometry, including moving brush collision, pushes away from the aim direction, adds to existing jump velocity, and deals 36 self-damage before normal armour absorption. Uncharged/charged impulses span 8–12 m/s within the existing movement limits. Grounded wall impacts also provide a small lift. Alternate surface hits use a longer trace and smaller distance-scaled impulse/damage. A miss, player hit or deployable hit cannot grant surface recoil. A hand blocked by geometry still uses the normal firing-clearance rejection.

Menu/input blocking, weapon switching, death and stale input cancel a held charge. No new RPC or client authority is introduced; existing input, movement snapshots and damage replication carry the behavior.

## UT99 reference and adaptation

The reference is the original UnrealScript [ImpactHammer.uc](https://github.com/Slipyx/UT99/blob/master/Botpack/ImpactHammer.uc), especially its firing state and surface-hit handlers: primary stays held, surface impact charges a fixed base damage cost and sends momentum backward; secondary scales surface damage and momentum with distance. [Pawn.uc](https://github.com/Slipyx/UT99/blob/master/Engine/Pawn.uc) applies a grounded upward component and adds momentum to velocity. FPSloppa adapts these mechanics to its shared metre-scale movement, charge timing and armour system; it does not reproduce UE1 physics or UT99 difficulty/hardcore damage modifiers exactly.

## Validation

Run `python3 deathmatch/tests/run_impact_jump_tests.py`.

- 20 focused checks: held charge, release timing, partial charge, floor/wall/miss behavior, armour, fatal self-damage, cancellation, melee reach/contact, alternate strike and synthetic tracked-hand aim.
- 71 existing weapon-variant regressions passed.
- Separate real ENet server/client processes tested held charge, authenticated jump/release inputs, authoritative launch and owner-observed position/health for desktop and synthetic tracked-hand input.
- No script/runtime errors; all processes exited successfully and were reaped.

In the synthetic flat arena, measured apex above the floor was 1.43 m for a normal jump, 9.37 m for a fully charged timed jump, 6.33 m for a partial charge and 3.50 m for a charged discharge without jumping. These are measurements under FPSloppa physics, not claims about UT99 jump heights or multiplayer balance.

Receipt: [impact-jump.json](validation/impact-jump.json). Logs: `test-results/impact-jump/`. No physical headset test or remote deployment is claimed.
