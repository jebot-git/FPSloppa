# Bot team coordination validation

2026-09-12 · Godot 4.7.2 · Linux headless

**127 assertions plus the existing traversal and Assault-squad integration tests passed.** An eight-case team-mode sweep, four focused reruns, and two final timing/TF runs covered **43 simulated minutes** with eight bots and a spectator. Runs exercised TDM, CTF, KOTH, Freeze Tag, Instafreeze, TF with Quake weapons, and Assault with Doom/UT weapons.

## Implemented behavior

- Delayed, expiring team sightings; local visibility is still required to acquire and fire on an enemy. Reports never track hidden movement. Focus-fire calls yield to immediate close-range threats.
- Separate firing positions to protect injured allies, carriers and teammates performing an interaction. Escorts follow behind and to the sides. Carriers retain capture priority.
- Short-lived pickup offers to needier bots or humans, including declining incidental collection. Offers expire and urgent survival can override courtesy. Existing flag carry/capture rules remain unchanged; no direct flag-transfer mechanic was introduced.
- Timed defensive ambushes at partial cover, with approach-facing aim, crouched waiting and a cooldown. Geometry and roles determine availability; ambushes are not forced in every match.
- Occasional team-only contact, cover and supply callouts for humans, capped at one per team every 15 seconds. Network delivery excludes synthetic bot peer IDs.

The focused checks exercise real pickup collection, information isolation and expiry, all seven modes’ cover goals, cover during thaw/heal/repair/checkpoint/destruction, formation spacing, capture priority, and ambush waiting/expiry. The existing weapon, ability, movement and navigation regressions continue to pass.

## Match observations

Counts below are decision telemetry, not proof of successful suppression or subjective human-like play. “Offers” counts reservations, not confirmed collections; actual collection is covered by the focused tests. Latest available run per map is shown. Earlier KOTH/FT/IF sweep cases preceded the close-threat priority and bridge-recovery refinements.

| Map / mode | Seconds | Team score | Focus choices | Cover assignments | Pickup offers | Ambushes | Longest unintended pause |
|---|---:|---|---:|---:|---:|---:|---:|
| lqdm2 / TDM | 120 | [14, 13] | 195 | 11 | 6 | 4 | 2.0s |
| lqdm3 / CTF | 180 | [1, 6] | 111 | 7 | 7 | 0 | 1.0s |
| lqdm4 / KOTH | 180 | [42, 38] | 246 | 8 | 11 | 0 | 2.0s |
| lqdm6 / FT | 180 | [0, 0] | 16 | 0 | 14 | 0 | 2.0s |
| lqdm8 / IF | 180 | [5, 3] | 22 | 25 | 0 | 0 | 2.0s |
| as_hislop / AS | 180 | [0, 1] | 55 | 2 | 3 | 0 | 2.0s |
| as_frigate / AS | 180 | [0, 0] | 177 | 10 | 25 | 0 | 1.0s |
| tf_ironspan / TF | 300 | [1, 1] | 612 | 34 | 9 | 1 | 2.0s |

Both Assault maps reached the end of their objective lists. The latest Frigate run reached stage 2 without a team score being recorded before the time cutoff. Freeze Tag had no team elimination in its three-minute run; Instafreeze did score. The final five-minute TF run captured for both teams.

## Snag found and corrected

The first TF run exposed a 129-second engineer stall at `(-2.124006, -1.405652, -7.575234)`, under Ironspan’s thin bridge. A reproduction at that coordinate remained stationary while repeatedly trying to stand/move. A prone request released the hull and allowed normal movement back to dry ground. Recovery now checks vertically for a low slab and briefly uses the ordinary prone input. `bot_underpass.gd` verifies escape at the exact recorded position without a bot teleport, forced respawn, or custom collision bypass. The final five-minute TF run had a longest unintended pause of 2.0 seconds.

## Performance and limits

After the other tests finished, sequential runs measured the authoritative arena physics callback directly at 60 Hz, excluding the first 30 seconds:

| Case | Median tick | p95 tick |
|---|---:|---:|
| lqdm2, eight bots | 1.616 ms | 3.804 ms |
| tf_ironspan, eight bots | 1.563 ms | 3.524 ms |

These are local total simulation times, not a controlled before/after speedup or a dedicated-server capacity claim. The broad runs’ Performance monitor samples include startup and scheduling effects and are not used for these timings. Shared observations, reservations and cooldowns expire; geometry work remains at the existing planning cadence.

No runtime script errors occurred in the completed match or regression runs. The pre-existing one-ObjectDB-instance exit warning remains, as in the earlier baseline. Tests used copied native libraries to avoid interference from concurrent plugin builds, with bounded subprocess timeouts and reaped processes. These are headless practice-bot tests; no live VR or subjective human playtest was performed. No build, commit or publication was requested for this change.

See [BOTS.md](../BOTS.md) for mechanics and test commands and [the validation receipt](validation/bot-teamplay.json) for source hashes and raw-result paths.
