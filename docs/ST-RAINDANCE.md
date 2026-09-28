# Separate ST / Raindance experiment

Work is isolated in `experimental/st-raindance`, based on release `8b19bd9`.
The release checkout and its CS map converter are untouched. This branch restores
ST registration, Tribes arsenal selection, server configuration and map download
classification. It adds Raindance to the dedicated ST map rotation; ordinary CTF
does not acquire either Tribes map.

## Reference review

The supplied playlists mix original base gameplay, tutorials, and later mods.
This pass inspected sampled frames and short successive frame sequences, not
complete narrated playthroughs. Exact reviewed timestamps and pinned source
hashes are in `tools/raindance/references.json`. Downloaded video stays in ignored
`test-results/st-raindance/references`; it is not game content.

- [1999 Raindance capper POV](https://www.youtube.com/watch?v=3vi7vkBsz1U):
  rolling gullies, separate open flag shelf, broad inventory bunker, repair and
  resupply during an attack. The 6:20–6:48 sequence shows a repair stop followed
  by a return to the flag-tower approach.
- [SectionFX Raindance match](https://www.youtube.com/watch?v=KAme8SNiNmQ):
  2:20–2:41 shows the tower/bunker relationship, exposed approaches, sloping base
  exterior and the single-room inventory interior. The structures provide cover
  without enclosing the flag itself.
- [Supplied Dangerous Crossing match](https://www.youtube.com/watch?v=4wyEAlg2bp4):
  useful for terrain travel and indoor support context; not Raindance geometry.
- [Basics part 1](https://www.youtube.com/watch?v=NOxGRipenxA) and
  [part 2](https://www.youtube.com/watch?v=DQkmXGQfNt8), from PL30909161BBD66F02:
  inventory refitting, armour/backpack choices, deployment and repair. Existing
  ST systems already provide these; this pass focuses on reaching and using them.
- [Return our flag](https://www.youtube.com/watch?v=KxwORDvppaQ), from the added
  [PL77357CF594E22A2A playlist](https://www.youtube.com/playlist?list=PL77357CF594E22A2A):
  pursuit and flag recovery in later footage. Its HUD/vehicle presentation is
  not used to infer original movement, damage or equipment constants.

Design inference from these references: preserve momentum during coordinated
approaches, screen ahead of carriers, predict a moving carrier's interception
point, and treat shelf entry clearance separately from simply seeing a flag.
The existing documented armour/energy constants remain unchanged.

- [SectionFX Stonehenge match](https://www.youtube.com/watch?v=2B9Y688lDuI):
  the 9:18–9:51 sequence follows direct combat from the stand into the nearby
  gully around a dropped flag, then back toward the tower. This supports
  prioritising a visible defender or pursuer over optional equipment damage.

## Raindance reconstruction

`tools/raindance/build.py` builds BSP29 brushes, reusing the Stonehenge convex
brush writer and original mipmapped project texture records. The heightfield
comes from [tribes.mapping](https://github.com/levizoesch/tribes.mapping), pinned
to commit `4ca392c73b210d52b77572f5f66571291bc8a4f7`. The archived
[Raindance mission](https://library.theexiled.pwnageservers.com/file.php?id=2018)
supplies flag, base, bridge and defence anchors. Terrain is sampled at 16 metres
for BSP29 limits, with shared quantized vertices and original asymmetric hills.

The playable reconstruction includes eight spawns per team, flags approximately
639 metres apart, covered lateral flag shelves, sloped inventory bunkers, ammo
stations, generators, roof sensors, base/bridge fusion turrets, forward missile
turrets, a central bridge, vehicle-pad landmarks and invisible mission bounds.
Interior doorway and shelf samples use `info_tribes_navigation` entities;
collision-tested graph edges remain authoritative. Stonehenge's legacy portal
fallback still works.

This is an experimental reconstruction, not a byte-identical conversion.
Interior dimensions, generator floor arrangement, textures, collision capsules
and vehicle pads are adapted. Vehicles are not functional. Source height data
and mission references are retained locally for study; no original Tribes DIS
meshes or retail textures are bundled. Existing Makkon/LibreQuake texture notices
are copied into the local map source folder.

## Bot changes

- Attack groups match estimated arrival times and keep their ski routes. A
  group no longer creates a stationary rally objective. Flag emergencies and
  timeouts still release the commitment.
- Forward escorts look farther ahead at skiing speed. Chasers lead public flag
  carrier motion by a bounded interval; they never read the enemy bot's route.
- Tower approaches reject the final direction if a shaft/support blocks it.
- Light/Medium flight control approaches shelf height with bounded vertical
  speed. Heavy armour retains an early ballistic climb because its smaller
  thrust surplus cannot recover a late ascent. The recorded Heavy foothill replay
  completes in 13.53 seconds in the full 42-check suite. Switching
  to a flag run requires foot clearance, not just a torso sight line. The old
  controller could switch below a shelf lip or land on the roof above it.
- Layered terrain samples retain traversable ground beneath bridges. Covered
  waypoints trigger a fresh approach from the actual floor. A missed elevated
  corridor also replans after a substantial fall rather than waiting underneath
  to recharge and climb back up.
- Initial inventory trips survive a short detour away from the spawn roof.
  Role emergencies still interrupt refitting. Launch hills reject hollow roofs.
- Fast outdoor travel can pass beside a terrain waypoint when the onward
  corridor is clear. Airborne changes of direction use actual directional jets;
  stick input by itself has no air steering in the shared movement model.
- Flag exits check descending clearance and preserve incoming momentum where
  possible. A supported landing is required before switching out of tower flight.
- Moving launches are reconsidered on the way to a staging point. Previously
  the 100 m tower planner committed before its <75 m moving-launch window opened.
- Support prioritises a currently visible player covering a grab or escape over
  optional fixture damage. Hidden or remembered enemies do not trigger this.
- A nearby attacker now screens a currently observed flag defender before the
  pickup; another runner continues the grab. This support job releases when the
  observed pressure clears. Carriers periodically glance behind while preserving
  world-space escape steering; normal FOV, LOS and reaction still gate fire.
- Observed missile batteries add exposure cost to the initial descending exit.
  The planner does not read the turret's private target or hidden fixtures.
- Light cappers can choose a higher approach at 48/72/104 m. Existing approaches
  retain their staging destination out to 160 m instead of repeatedly cancelling
  a stage outside the initial 100 m tower-planning radius.
- Final run-ups use the ordinary slope-based ski rule even below walk speed.
  The previous above-walk prerequisite prevented gravity from accelerating a
  downhill start. The full recorded-position suite now passes, including the
  Heavy foothill regression identified by comparing with the original bot code.
- A flag approach accounts for the exit direction. Rolling launches reject
  approaches pointing sharply away from home; lateral or homeward passes retain
  their speed. Staging costs account for avoiding a reversal beside the defender.
- Healthy carriers can use the existing disc-jump action on a clear flat or
  downhill escape. It consumes real ammunition and self-damage, checks nearby
  allies, and rejects wounded carriers. Availability does not mean it happened
  in every match; passive counters record actual attempts.
- Exit clearance crosses the stand before tracing the descent. Low-energy
  carriers use the ordinary terrain/portal route instead of an ambitious turn.
- Pass receivers steer toward the predicted meeting point and arrival time
  instead of chasing the flying flag backward. This uses ordinary movement,
  jets and touch rules; stationary human receivers require no bot brain.
- No movement, health, energy, damage or aim bonuses were added.

## VR changes

- Failed deployable placement preserves the held pack. Release and press the
  trigger again after aiming at a valid surface; successful deployment consumes
  the pack exactly once.
- Pack/ammo transfers use the same torso-to-hand world-clearance solver as throws.
- Releasing the chest flag with a still hand stows it. Swing and release to pass;
  skiing velocity alone cannot trigger a throw. The existing drop action remains.
- Client holds expire before the ten-second authority lease. Reset/death/map
  changes clear stale controller motion.
- Both left- and right-handed tracked hip/chest attachment paths are exercised
  by production pose/RPC tests. Automated poses are not a physical-headset comfort
  or tracking-quality assessment.

## Run and validate

```sh
python tools/raindance/prepare_sources.py --assets-root /path/to/existing/FPSloppa
python tools/raindance/build.py --compiler /path/to/ericw-tools/bin
godot --headless --xr-mode off --path . --script tools/raindance/prepare.gd -- --raw-only
godot --headless --xr-mode off --path . --script tools/raindance/acceptance.gd
python tools/tribes/run_live.py --map ctf_raindance --speed 4 --seconds 1800 --seed 9289 --record --output test-results/st-raindance/live
python tools/tribes/report_match.py test-results/st-raindance/live --output test-results/st-raindance/live/analysis.json
python tools/tribes/report_batch.py test-results/st-raindance --output test-results/st-raindance/run-ledger.json
```

Builder inputs live in local `maps/Raindance`: `reference-heightmap.png`,
`raindance.wad`, and `texture-sources.json`. The WAD is assembled from the existing
Stonehenge texture set plus grey industrial panels in the shipped Makkon pack.
No texture pixels are edited; all four source mip levels are retained. Runtime
scene caches and navigation are generated, not source-controlled.

The harness accepts `--map ctf_stonehenge` for regression testing. Every contested
match terminates if no capture occurs in its first 600 game seconds. Each capture
also arms a 600-second deadline for the next pickup; a timely pickup clears that
window and a later capture rearms it. Tests cover exact boundaries and late events.

The Vulkan spectator displays the watched bot's horizontal speed in km/h using
replicated velocity. Recordings are silent 1280×800 MP4 with server-time anchors;
new anchors include the displayed speed. `travel.json` samples attacks/carries
once per game second; `samples.json` retains broader five-second diagnostics.
`combat.jsonl` uses the existing damage hook to record passive test-only evidence.
Each run retains options, source hashes, map/nav hashes and a tracked source diff.
The launcher refuses to overwrite an existing run. The silent observer disables
microphone capture for the session and retains the last valid server clock at
disconnect. Early recordings may log a PulseAudio input shutdown error; this
is separate from game-script errors and did not corrupt their MP4 files.

The navigation bake removes one fully covered redundant triangle after checking
its footprint. It refuses unknown over-owned-edge topology rather than silently
removing useful navigation. The final Raindance mesh has 27,335 polygons.
Receipts and remaining limitations are recorded in
`docs/validation/st-raindance-2026-09-28.json`.

## Latest route and match findings

| Map / seed | First contested capture | Score at 20 minutes (Red–Blue) | Evidence |
| --- | --- | --- | --- |
| Stonehenge / 9295 | 2:20.9 | 1–0 | `stonehenge-through-9295` |
| Raindance / 9295 | 9:42.5 | 1–0 | `recorded-raindance-through-9295` |
| Stonehenge / 9296 | 2:52.3 | 1–0 | `recorded-stonehenge-final-9296` |
| Raindance / 9296 | 3:29.3 | 3–0 | `raindance-final-9296` |

The first recorded Raindance capture is a real recovery relay: the first carrier
reaches midfield and dies at 536.62 s, a teammate recovers at 541.03 s, and scores
at 582.50 s. `recorded-raindance-through-9295/review/first-capture.mp4` and its
adjacent JSON anchor receipt show that sequence. The next seed also contains a
successful intentional pass at 767.72 s, catch at 768.67 s, and capture at 812.02 s.
The second seed is a headless authority run; the first relay has video evidence.
The latest Stonehenge recording also shows a four-carrier recovery chain ending
at 172.27 s; its `review/first-capture.mp4` isolates the final exchanges. All four
listed runs had further pickups after captures and completed their 20-minute
duration without triggering the new inactivity cutoff. The full ledger retains
25 completed 6v6 iterations, including the earlier failed runs.

The pre-change Raindance 9294 recording exposed two grabs with homeward velocity
of -42.2 and -48.7 km/h: fast movement, but initially away from the capture base.
The first three 9295 grabs have +41.1, +37.0 and +42.1 km/h homeward velocity.
These are individual examples explaining the approach change, not an isolated
statistical effect. `report_match.py` now reports homeward pickup velocity,
progress toward home, and whether a drop happened while the carrier was alive.
A living drop must not be counted as a carrier death.

The reference footage supports using gullies to preserve momentum, making a
wide approach to an exposed stand, and fighting around dropped flags. The local
recording still shows more slow terrain corrections and more predictable pursuit
than the sampled human matches. Captures remain sparse and the two latest
Raindance seeds favour Red; contested Blue-side reliability and longer-lived
support coordination remain priorities. No claim of globally optimal routes is
made. All sixteen unopposed Raindance spawns complete a real pickup and capture
in 127.65–294.75 seconds; that check is separate from combat viability.

## Iteration evidence and limits

`docs/validation/st-raindance-2026-09-28.json` is the compact run ledger. Full
local evidence is under `test-results/st-raindance/<run>`; failures are retained.
The runs use actual 6v6 authority, normal equipment purchases, ordinary physics,
and real flag touches. Spawn-to-capture and recorded-state replays are separate
unopposed diagnostics, not proof of contested success.

Earlier Stonehenge recordings (`recorded-stonehenge-9287`) have a stale spectator
speed field and legacy client-local video timestamps. Their server events remain
valid. The first capture was re-aligned by the visible round countdown in
`review/calibration.json` and `review/first-capture-corrected.mp4`. Do not use
legacy anchors as authority time. Later full recordings use replicated velocity
and server snapshot time. The `recorded-raindance-window-9289/speed-audit.json`
comparison has 29 samples within 120 ms, median absolute speed difference
0.0043 km/h, maximum 7.70 km/h; these are nearby snapshots, not identical instants.

Rejected experiments include unrestricted high-ridge approaches before the
controller fixes, indiscriminate replanning after small falls, and several Heavy
launch changes that did not pass the recorded foothill replay. The final
Heavy-specific climb restores the full recovery suite; the rejected variants
remain recorded in local logs. Failed experiments are retained in the ledger.

Recordings are sampled and compared visually against the referenced original
matches. They are not a statistical reconstruction of competitive win rates or
proof that routes are globally optimal. No original HUD speed was inferred from
camera displacement. The reconstructed base geometry and BSP collision differ
from the original engine, and physical-headset comfort remains untested here.

## Momentum, carrier priorities and entrance follow-up (28 September)

The normal-speed seed 9297 previews both reached the 600-second first-capture
cutoff at 0–0. Their movement records showed flag approaches repeatedly settling
near walking speed, with large losses around launch staging. The forward jet
controller previously targeted the current speed, so its acceleration input
vanished near walking speed. It now targets useful horizontal jet speed while
reserving thrust for terrain clearance, keeps ski held through open-air landings,
and spends surplus energy accelerating clear descending approaches. Sharp turns
retain their separate steering input. Armour, weapon damage and shared movement
physics are unchanged.

Downhill travel enables skiing before the alignment check. Uphill travel uses
jets when speed, headroom and energy permit, otherwise walking traction. A
recharging bot now walks up a supported slope at normal input strength instead
of creeping while waiting for its jet reserve. Precise stops and turns toward
an uphill destination still use their intended direction; a velocity-only
slope override failed tower and doorway recovery tests and was removed.

ST carriers can plan only delivery, nearby home-flag recovery, or protected
holding while the home flag is stolen. Generic combat cover, enemy pursuit and
ally-assistance candidates cannot replace those objectives. Carriers and fast
travellers skip optional equipment attacks and use recent visible threats for
short defensive fire: immediate threats, enemies ahead in the travel lane, or
a bounded return-fire window. Navigation regains its view between those bursts.
Energy weapons cannot spend a carrier's flight reserve. Optional siege and
construction role changes discourage diverting a fast attacker; essential
base repairs remain urgent.

Healthy Medium/Heavy carriers may relay to a healthy, sufficiently charged Light
who is ahead toward home and has a better homeward speed. A fast Heavy keeps the
flag when that transfer would slow delivery. The throw searches feasible flight
times with the ordinary impulse limit, inherited velocity, collision checks and
observed enemy pressure. Moving catches and a receiver cooldown prevent turning
back or immediately throwing the flag back. The existing injury-based emergency
pass remains available. Stopped carriers request recovery after eight seconds
(twelve for Heavy), while moving detours retain the longer progress budget and
intentional home-flag holds remain exempt.

Outdoor obstacle probes follow anticipated body travel, including airborne
descent and capsule width, at a bounded polling rate. Low barriers use ordinary
jump/jet inputs; tall barriers select a persistent clear flank and brake before
impact. Close probes now include the feet: Raindance's 0.8 m bridge curb was
below the previous chest-height ray. Replays of the observed bridge carrier and
attacker recover 25 m of objective progress in 2.98 and 3.95 seconds. The isolated
1.2 m barrier test retains 22 m/s; the 12 m wall test uses a flank with no stopped
interval. These are controlled collision tests, not contested-match averages.

Tower launches now check the full climb for an overhead roof before taking
control from doorway navigation. Covered bots leave through the real exit;
a launch that enters a bunker records its failed stage instead of repeating it.
Launch selection also rejects downhill slopes whose fall direction would pull
a skier across the intended corridor. Both bunker-to-roof repair replays leave
the room and reach the actual repair approach without sustained ceiling contact.

Raindance had a 0.74–1 metre floor edge at both bunker entrances, exceeding the
0.42 metre walking step. All 18 baseline entry cases failed. Broad convex ramps
now cover the full apron, with refreshed floor-height portals, collision,
lighting and walking navigation. Entry validation covers three lanes, all three
armours and a six-bot group on each team. Every authored navigation portal also
has a supporting-floor collision check. Generated BSP/cache/navigation assets
remain local to this experimental checkout.

The isolated four-second flight test improves a walking-speed approach from
11 to 18.72 m/s (39.6 to 67.4 km/h), consuming ordinary jet energy; an existing
28 m/s landing preserves that speed. These are controlled physics fixtures,
not claims about average contested-match speed. Faster experimental tower
controllers and an extra launch-stage detour were rejected after full-route
regressions. Tower approaches remain the main speed limitation.

The intermediate open-travel-only comparison finished Stonehenge at 1–1 with
its first capture at 279.82 seconds; Raindance still hit the 600-second cutoff.
That comparison predates the carrier-priority, slope and entrance changes.
Fresh normal-speed 6v6 previews use 20-minute limits and retain both inactivity
rules; a running preview is not a completed validation result. The focused test
receipts, code/map hashes and run locations are recorded separately in
`docs/validation/st-momentum-2026-09-28.json`. Raw replays, unsuccessful experiments
and recordings remain under ignored `test-results/st-speed`.

The subsequent pre-obstacle seed 9298 runs finished Stonehenge at the 600-second
no-capture cutoff (0–0) and Raindance at twenty minutes (1–1, first capture at
552.53 seconds). They do not validate the later handoff, curb or roof corrections.
Final controlled validation passes 442 focused checks and 18 unopposed capture
cases. New seed 9300 normal-speed, recorded 6v6 previews were started on both
maps from commit `a9edbd3`, with Vulkan spectators and both inactivity cutoffs.
Their result files, when present, are the completion authority; the receipt only
records their startup verification.


### Carrier approaches and two-flag recovery (2026-09-28)

The seed 9300 previews completed twenty minutes at 1–1 on both maps without
script errors. Stonehenge's final two-flag stalemate exposed spare cappers and
repairers targeting the enemy flag on their own carrier, effectively becoming
extra escorts. Existing chasers also struggled with the raised bunker entrance.
These recordings predate the following fixes.

During a two-flag stalemate, a full powered six-player team now retains one
carrier and one escort and sends four players to recover its home flag. A power
outage can reserve one eligible repairer, leaving three chasers. Smaller living
teams prioritise recovery, including the last non-carrier teammate. Recovery
preempts shopping, scavenging and generic cover goals; a bounded flag-pass catch
remains valid. Dropped flags switch chasers to touch-return, and ordinary roles
resume when possession changes. Other support bots no longer target the flag
already held by a friendly carrier.

Raindance's observed carrier bunker entry was caused by sideways ski drift
preventing an aligned launch. Light and Medium now start ordinary directional
jets to correct that drift before entering the bunker. Heavy keeps its original
ballistic control because its smaller lift surplus cannot support that burn.
Four recorded approach variants capture in 4.42–6.03 seconds without entering
the bunker. Stonehenge's outdoor wall avoidance no longer overrides nearby
covered entry or a verified raised portal. Both recorded hold approaches now
reach the entrance, in 56.1 and 34 seconds; this does not imply a fast approach.

Carrier routes rank ordinary and alternate terrain corridors by estimated
travel time, accounting for turns, momentum, climbs, energy and covered passages.
A valid current route is retained unless the replacement saves at least 15%
and 1.5 seconds. Flag exits use the same cost. This is a bounded planning
heuristic, not a global fastest-route guarantee. The synthetic real-physics
comparison selects a 120.62 m route over a 104 m covered route and arrives 0.2
seconds earlier. Shared movement physics and energy limits are unchanged.

Validation passes 289 focused checks, four recorded approach cases, two
Stonehenge hold replays, four escape replays and 18 unopposed capture cases
(16 Raindance spawns and one per Stonehenge team). The receipt is
`docs/validation/st-carrier-recovery-2026-09-28.json`. Fresh contested recordings
are needed to assess stalemate frequency; role assertions alone cannot prove
that every carrier can be recovered.
