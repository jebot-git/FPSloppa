# Downhill safety and ski-to-jet inputs

This change is confined to `experimental/st-raindance`. ST remains excluded
from release. Shared movement physics and armour statistics are unchanged.

The final downhill input pass could re-enable skiing after obstacle avoidance
had deliberately selected walking traction. It now preserves braking/flanking
phases and requires an active, clear route. A cached probe checks both intended
travel and existing sideways drift through a speed-dependent braking horizon.
It follows successive terrain surfaces, checks body-width clearance, and
rejects hazards, unsupported drops and abrupt box/roof tops. Re-anchoring each
segment on the observed slope avoids falsely tracing underground at valleys.

A separate slope-triggered launch retained full walking input. At moderate
speed this diverted too much jet thrust sideways to oppose gravity. It now
uses the existing airborne thrust-allocation helper to reserve sufficient lift.
Starting an ordinary outdoor flight also requires more than 25% fuel;
low-energy bots walk/recharge instead of starting futile hops. Existing
airborne corrections and obstacle vault inputs remain available.

## Controlled comparison

The same real-physics two-hill fixture was run against the source snapshot from
before these changes and the final code, with per-frame jet-input timing.

| Armour | Before travel | After travel | Before/after jet time |
| --- | ---: | ---: | ---: |
| Light | 9.28 s | 8.67 s | 3.28 / 3.28 s |
| Medium | 7.48 s | 7.48 s | 2.82 / 2.82 s |
| Heavy | 7.33 s | 7.33 s | 2.77 / 2.77 s |

Light completes the route 6.6% sooner with the same jet firing time. It finishes
with 27.42 energy rather than 34.20 because the shorter traversal provides less
recharge time. Peak horizontal speed remains about 97.5 km/h. All three armour
classes still have two ground departures, so this does not demonstrate a single
seamless valley flight or improved match capture reliability.

An earlier takeoff experiment was rejected: it improved Light traversal but
increased jet time from 3.28 to 3.52 seconds. The final implementation retains
the original takeoff timing and corrects input allocation instead.

## Validation

43 assertions pass: 19 downhill/launch-safety, seven speed-control, seven
recorded Raindance routing, six carrier-recharge and four obstacle-control
checks. All three ski-chain armour cases and all four recorded carrier-escape
fixtures pass. The escape times to 100 m separation are 9.35/9.72 seconds on
Raindance and 18.28/8.28 seconds on Stonehenge, with at most 0.49 seconds of
continuous slow movement. These are replay fixtures, not full-match averages.

Godot checks exit successfully without script errors. The existing one-object
shutdown leak warning remains in the fixture logs.

Evidence is in `test-results/st-ski-safety`; final chain measurements are
`chain-lift.json`, the unchanged-game baseline is `chain-measured-before.json`,
and full source snapshots preserve the compared implementations. Failed and
rejected experiments are retained separately. The initial baseline run that
failed to save into a missing output directory is excluded from the results.

A fresh 8v8 Stonehenge match, seed 9417, is launched in
`test-results/st-ski-safety/live-stonehenge-9417` with Vulkan live view, speed
display, recording, navigation telemetry, 20-minute/five-capture limits and
both existing 600-second inactivity cutoffs. Its eventual `result.json` is the
match outcome; startup verification is not a completed match result.
