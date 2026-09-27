# DE bot recording review

Reviewed sampled sequences from the five original six-round recordings and
cross-checked their match telemetry and serialized demo states. In Train,
defenders repeatedly selected nearby spawn points instead of their bomb sites.
In Nuke round one, Bot 11 held the recovered bomb away from either site from
34.15 to 42.35 seconds, preventing normal gunfire.

## Fixes

- Give each DE defender its own reservation key. The generic planner previously
  multiplied a site's score by 0.35 for every teammate using `de:site`, even
  though those teammates were covering different positions and different sites.
- Reject defense positions outside the navigation mesh. Dust2 and Train could
  choose clear-looking points beyond a ledge or behind a train with no route,
  then fall back to cycling through spawn goals.
- Keep perception running during planting and defusing. Bots interrupt the
  interaction when they see an enemy, put the bomb/cutters away, and use ordinary
  weapon controls. They resume the objective after the threat clears.
- Stow a recovered bomb on the bot's chest while traveling, and clear abandoned
  defuse controls. Human/VR bomb-handling behavior is unchanged.
- Include enemy, firing, ammunition, reload, holster, target and waypoint state
  in future live-series telemetry to make similar reports diagnosable.

## Validation

Six rounds per map, 6v6, side swap after round three, seed 7129. The before/after
simulations use ordinary 60 Hz gameplay physics with real-time pacing disabled;
there are no forced kills, teleports or round outcomes. “Spawn exit” means
moving more than eight metres from the first live-round position.

| Map | Longest exit before | Longest exit after |
| --- | ---: | ---: |
| Dust2 | 5.02 s | 4.93 s |
| Nuke | 5.82 s | 4.42 s |
| Inferno | 7.18 s | 4.47 s |
| Aztec | 8.45 s | 4.48 s |
| Train | 9.43 s | 4.47 s |

All 30 rounds completed; exits over seven seconds fell from five to zero in
this seeded comparison. This is a regression sample, not a guarantee against
every possible bot stall. Raw samples and comparison are in
`test-results/de-bot-review/`. Separate 60-second real-time ENet verification
clips for Train and Nuke are in `recordings/de-bot-fixes-2026-09-26/`; these are
short clips, not additional complete six-round recordings.

The interaction regression exercises real perception and real gunshots after
interrupting planting, recovery while traveling, interrupted/abandoned defusal,
and successful defusal once the threat clears. Existing DE planting, weapon,
tactics and teamplay checks also run alongside map traversal checks.
The standing-weapon fixture now settles its CharacterBodies before shooting;
previously the AWP trial could miss every shot with an unintended airborne
spread penalty. All twelve weapon trials pass with normal grounded physics.

## Counter-terrorist bomb pickup

The authoritative recovery rule already requires the terrorist role. Added
coverage for CT Use, tracked-hand grip and bot input with either team attacking,
plus positive controls for terrorist recovery. Three real ENet clients verify
that a nearby CT's Use request is rejected before and after roles swap, while
the surviving terrorist can recover and plant normally.

## Site markings

All ten sites now have a ground cross and a red A/B wall letter. Added the eight
missing crosses, moved floating/obstructed signs onto backing walls, corrected
mirrored wall UVs, and added baked light at Train's shaded markings. Floating
guide text remains absent. The paint uses non-emissive red palette entries;
the previous RGB source quantized to orange-brown. BSP checks verify texture
faces, palette color, solid backing and letter orientation; native captures
verify visibility. See
`test-results/de-site-markings/index.html` and the validation receipts.
