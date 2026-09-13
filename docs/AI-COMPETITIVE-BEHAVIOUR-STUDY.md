# Competitive behavior study and AI corrections

Study started 12 September 2026. Scope: the recorded remote ten-mode test, its server logs, competitive arena-shooter references, and controlled AI comparisons. These are behavior improvements, not a claim that the bots now play at league level. The earlier remote server remains stopped; subsequent network tests use loopback.

## What the recording establishes

Inputs: `test-results/remote-all-modes/all-modes.fpsdemo`, `server.jsonl`, `process.jsonl`, and [the rendered recording](../video-output/remote-all-modes-2026-09-12.mp4). The demo contains 13,835 valid frames and ten modes. Filter server records to epoch 3 onward to exclude two admission preflights. Eight separate ENet clients supplied bot commands; a ninth client spectated. They did **not** use the authority's practice-bot tick directly.

The previous rounds were approximately one minute each, with both Assault legs. Consequently, no capture in one round is evidence of poor objective throughput in that sample, not proof that a map cannot be captured.

| Observation | Evidence | Interpretation |
|---|---|---|
| KOTH clustering and stalled scoring | 26.1% of eligible teammate-pair time within 2m; 51.7% of active bot time nearly stationary; score 1–6 | All bots had the same center waypoint. Repeated contesting prevented the one-second uninterrupted ownership credit. Stationary holding itself is legitimate; identical jobs and positions are the problem. |
| CTF lacked attacks that completed | No flag takes in the remote round; all logged combat damage from Enforcers; two pickups | Goal allocation and equipment acquisition need work. The low whole-map crowding statistic does not disprove localized clumps seen by the spectator. |
| Rapid turning | Average accumulated yaw travel: DM 174°/active second, IG 204°, IF 217° | This includes legitimate combat turns and snapshot corrections. It is not a count of full spins, nor a stand-alone aim-quality metric. |
| One DM bot never left its initial position | Zero travel near `(-24,6,-16)` on qsrc_dm3 | Controlled tests reproduce an isolated navigation area near that raised spawn. This is distinct from a connection stall. |
| IF barely engaged | Two shot-effect events and one freeze in the recorded round | Target reacquisition, routes and rescue allocation are plausible contributors. Freeze events bypass ordinary damage accounting, so zero logged damage does not mean no freeze occurred. |
| TF made real objective progress | Take/drop/capture sequence, BLUE capture | Preserve class behaviors. Exclude `SUICIDE` from combat comparisons: class-selection/restart traffic contaminates raw damage totals. |
| AS made no stage progress | Both legs ran; stage stayed zero; 6,154 damage from Enforcers, 240 from a sentry | One-minute attacks, long routes and weak equipment confound a map-balance verdict. Test longer legs before changing objective health or layout. |

`audit.gd` derives spatial/orientation observations from snapshots. It excludes dead players and spectators and attempts to exclude frozen actors from active time. Pair crowding uses same-team, living, non-spectating pairs; it includes legitimate escorts and objective contests. Stationarity means movement below 0.3m/s between snapshots. Loading gaps are capped at 100ms; these metrics are descriptive, not packet-loss or reaction-time measurements.

## Competitive references and transferable models

References were read as player accounts and design precedents, rather than statistically representative samples of every league. Only the explicitly identified video excerpt was visually sampled. Rules differ: UT Domination maintains ownership after touching a point, whereas this game's KOTH requires physical presence. TF2's class/Über economy also differs from classic TF. No original game's weapon numbers or scoring rules were imported by this work.

### 1. Equipped skirmisher: DM, TDM, IG and CC

Wouter's QuakeWorld 4v4 guide prioritizes keeping the team equipped and alive, controlling useful areas, and recovering control together from multiple entrances. That supports supply sharing and coordinated pressure rather than chasing every frag. Those mechanisms already exist here and are retained. [Wouter van Oortmerssen, *QuakeWorld 4v4 strategy tips*, undated](https://strlen.com/maps/quakestrat.html).

Chris “DevastatioN” Felix's guide treats position as a relationship between weapons, room geometry and available options. Its hallway examples distinguish a position from which to wait/reload from a position from which to fire. It also warns against pursuing an opponent after the positional advantage reverses. This supports retaining weapon-distance selection and cover instead of replacing movement with permanent enemy chasing. [*DooM II Deathmatch Bible, Volume I*, especially Position and hallway examples, undated](https://www.doom2.net/dev/DooMStrategy.pdf).

**Applied:** keep existing item evaluation, courtesy, weapon matching, dodging and focus-fire reports. A nearby unowned weapon within 10m receives a modest priority boost while the bot owns only spawn equipment. This does not interrupt a flag carrier or fixed-loadout modes. Completed roam/search locations are temporarily avoided; a brief visibility interruption no longer restarts the same enemy's reaction delay. Lost targets still cannot be fired at through walls.

### 2. Carrier, anchor and attacking support: CTF

Vidje's competitive 4v4 guide describes a basic defender/mid/two-attacker split. Attackers should combine pressure, the mid should adjust to the situation, and a carrier should prioritize getting home. Support includes clearing interceptors and leaving resources to the carrier. The guide also emphasizes an emergency response when the team's own flag is stolen. [vidje, *QL CTF Guide — Positions*, 15 June 2015](https://plusforward.net/multipage/?page=3&pid=835).

The original Quake III bot implementation independently demonstrates separate orders for different flag states, allocation by team size, and exclusion of the carrier from orders to accompany itself. It is a structural precedent; no GPL source code was copied into the implementation. [id Software, `ai_team.c`, `BotCTFOrders*`](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/ai_team.c).

**Applied:** stable roster slots give four players one defender, one attacking support and two attackers. A death does not renumber all surviving roles. There is one leased close escort, with remaining teammates covering the home area, and one assigned touch-returner for a dropped friendly flag. A stolen flag remains a team emergency. These are rudimentary roles: there is no full route-level synchronized two-attacker push or learned interception model yet. TF retains its distinct timed flag-return rules and class policy.

### 3. Occupant, screen and retake: KOTH

Flash's early-2000s Domination guide describes ClanBase-style 5v5 play and explicitly rejects having everyone run to the nearest point. It assigns players to control points and extra support to the busier positions; frags do not score directly. The transferable principle is coverage and reinforcement, not UT's three-point scoring. [Flash, *Guide for Domination newbies*, early 2000s, republished 28 June 2025](https://digdilem.org/misc/ut/domination/).

**Applied:** select a nearby hill holder with a four-second assignment lease; replace a dead/frozen holder immediately. When that holder actually occupies the friendly-owned hill, support uses distinct floor-checked perimeter sectors. When control is lost, support moves to separate points inside the real scoring radius. Slots are checked for floor, hazards, height and sightline, with a bounded cache. No hill movement or scoring-rule changes are made.

### 4. Rescuer and cover: FT and IF

The World Freeze Tag League announcement establishes a competitive 4v4 context with team damage and a long automatic thaw timer. It is a rules reference, not evidence for one universally optimal rescue tactic. [World Freeze Tag League announcement](https://esreality.com/post/2262651/re-world-freeze-tag-league/).

**Applied inference:** make the local thaw a designated job, with one additional teammate eligible to cover it. Others retain fighting and movement choices. Assignments expire and are replaced on incapacity. This prevents every available teammate from choosing the same frozen body. It does not add hidden enemy knowledge or faster thawing. Multiple simultaneous frozen teammates can still compete for the same rescuer's priorities; a global rescue scheduler is future work.

### 5. Flexible specialist support: TF and AS

In djfivenine/m0lk's interview, Jaeger, cbear and Seagull describe why complementary roles protect a team's resources, and why those roles sometimes need to interchange according to health, position and losses. They disagree on how rigidly strong teams should label those jobs. That argues for temporary responsibilities with emergency replacement rather than permanent class rails. [*dj's Roaming Soldier Roundtable*, 2 August 2012](https://www.teamfortress.tv/268/djs-roaming-soldier-roundtable).

**Applied:** preserve the existing TF healing, repair, resupply, flag handling and class abilities, plus AS checkpoints/objectives. Shared reaction, navigation fallback and equipment changes apply, with regression tests. Full TF2 combo/flank tactics and UT Assault launch exploits are not claimed or implemented.

### 6. Deliberate facing and useful recovery: all modes

A competitive UT99 demo provides a useful visual counterexample to purposeless spinning: the sampled Deck16 sequence repeatedly uses the upper side of the central room, collects ammunition while retaining firing access, and changes position around a recognizable area rather than turning continuously without a tactical destination.

**Viewed sample:** frames at five-second intervals from source time 01:00–02:00, *ClanBase UT TDM Cup, May 2001 semifinal, -X-treme vs FB, Deck16][, POV -X-zubarFLY*. This is sampled visual evidence, not a full match analysis or reliable frame-by-frame aim measurement. [Participant's archive post, 14 March 2011](https://ut99.org/ut99.org/viewtopic.php?t=3146); [demo video](https://www.youtube.com/watch?v=8W8b2Zetf7k). The contact sheet and temporary excerpt are under `test-results/ai-study/`; they are not redistributed game assets.

A Quake CTF tournament organizer's linked VOD was also investigated, but YouTube returned “This video is unavailable”; no behavioral claims are attributed to watching it. [V1R7U4L, *Flagmaggedon Chile CTF Cup VOD*, 24 August 2015](https://www.esreality.com/post/2763491/vod-from-flagmaggedon-chile-ctf-cup/).

**Applied:** the network adapter seeds AI orientation from the client's previous local command rather than a delayed server snapshot. It uses elapsed time, clears cached commands on life changes, clears blocked actions, and no longer creates fictional teammate plans at their spawn positions. Core planning tries a bounded fallback beyond six unreachable top choices, temporarily suppresses failed routes, and attempts safe local exploration when no strategic route exists. Exploration has a short commitment window. It does not teleport bots, grant equipment or bypass physics.

## Validation and its limits

The durable [machine-readable receipt](validation/ai-competitive-study.json) distinguishes baseline, intermediate and final trials. `tools/ai_study/baseline/` preserves the starting AI and adapter; it is not a second production implementation.

- Full-physics practice comparisons use eight bots, fixed 60Hz simulation and reproducible random seeds. Goal changes, active idle samples, proximity, shots, pickups and objective events are collected. Fixed seeds reduce variation but do not make threaded physics/navigation perfectly deterministic.
- Real network comparisons run eight independent bot clients plus a spectator and a separate loopback server. Both mode rounds last 60 seconds after admission and restart. Peer IDs and team allocation can differ; score differences are not controlled estimates of win-rate improvement.
- Focused tests cover role allocation, holder replacement, legal scoring positions, stable CTF jobs, one escort/thawer, reacquisition, ordinary damage with every weapon profile, teammate information limits, pickup sharing and traversal.
- Test harness fixes: traversal fixtures now use the distributed Quake/TF maps; the CTF return test explicitly places the tested bot nearest the flag because returning is now assigned. A weapon test initially hit a wall-clock timeout; rerunning with fixed-FPS accelerated simulation completed its actual trials.

The initial network comparison reduced CTF yaw travel **189.2 → 90.7 degrees per active second**, and KOTH **138.7 → 90.9**. KOTH close teammate-pair time fell **22.3% → 7.2%**, with stationary time **42.7% → 35.6%**. CTF stationary time rose **20.5% → 26.2%**, partly consistent with the defender role but not proven entirely intentional. KOTH scores changed 3–8 to 4–1; neither run demonstrates healthy scoring throughput yet. These trials precede the final minor equipment/guard-facing adjustments; final practice results are tabulated below by the result summarizer.

The final independent network confirmation retained the improvement: CTF yaw travel was **93.6°/active second** and KOTH **80.2°/active second**. KOTH close-pair time was **9.8%**, compared with the 22.3% baseline. All ten processes exited 0 with no logged runtime errors. Scores remained CTF 0–0 and KOTH 3–6. This reinforces the spacing/orientation finding while leaving capture throughput unresolved. The second practice seed completed DM, CTF, KOTH, IF and TF; TF captured five flags and IF scored 4–3. Both baseline and changed AS practice runs reached stage 2/checkpoint 1 over the longer test, unlike the short original network recording.

## Performance findings and balance recommendations

The remote process monitor covers only the last approximately 265 seconds, mainly late CC/TF/AS. RSS stayed around **125.78–125.91 MiB**, median CPU was approximately **29.9% of one core** (p95 39.9%), with five threads, seven file descriptors and zero recorded UDP drops. This is reassuring for that short interval; it does not exclude a long-session leak. The stripped console engine's zero `physics_ms`/static-memory monitors are unavailable measurements, not zero-cost simulation. Nine real connections persisted through the recorded modes; repeated `player_joined` entries are map-readiness events.

The stock Godot loopback server warned about unreliable snapshots above the **1,392-byte MTU**, including a 1,418-byte packet. Audit snapshot sizes at 8 and 16 players with projectile-heavy profiles and VR poses, then consider quantization/deltas or bounded splitting. Do not infer WAN loss or blame the earlier remote host from this warning alone. No transport/protocol change is included here.

AI work remains bounded: normal route ranking checks six candidates; only an unsuccessful search extends to eighteen. Failed choices have a cooldown. Objective positions cache at most 128 entries, and role assignment does not perform pathfinding every physics frame. Planner/query/failure counters are available in bot telemetry. Profile isolated identical cases before treating exploratory p95 differences as server optimizations; some broad validation runs overlapped locally.

Recommended next balance tests, in priority order:

1. **qsrc_dm3 spawn and water exits:** reproduce the raised spawn near `(-24,6,-16)` and the water-exit stall near `(2.5,-7.16,-42.24)`. Local exploration improves recovery opportunities but does not certify connectivity. Check the navigation bake, usable doorway width and swim-to-shore route before changing global movement values.
2. **KOTH alichar:** measure uncontested ownership duration and approach deaths over longer mirrored matches. The hill is reached and frequently contested; wholesale increase of capture radius could intensify clustering. Try side-route equipment placement and distinct approach coverage in an experimental map variant if human tests confirm the bottleneck.
3. **CTF crownreach:** run five-to-ten-minute mirrored rounds and log flag approaches, takes, return progress and equipment at each death. The original sample was spawn-weapon dominated. Confirm whether weapons are reachable on useful approach routes before reducing defender strength or shortening the map.
4. **AS frigate:** allow the intended full attack time and track checkpoint/stage arrival independently of frags. Compare equipment acquisition and alternate entrances. No objective-health nerf is justified by a single short, Enforcer-dominated test.
5. **TF vesper:** retain the successful specialization, then test mirrored teams and several class mixes. Remove voluntary class-change deaths and environmental damage from weapon-efficiency comparisons.
6. **CC/IF:** separate hunger/environment damage from combat, and freezes/thaws from conventional damage totals. Raw damage or frag counts alone misrepresent those modes.

All test processes launched by the network harness are stopped and reaped in its cleanup path. Export shutdown ObjectDB warnings are recorded separately from live server errors. This work does not publish or deploy a release.

## Measured practice comparison

Eight bots, seed 7129, 180 simulated seconds per mode. A different random seed is retained separately in the receipt. These are AI behavior checks, not human balance estimates. DM/IG/CC use personal frags, so their team-score columns are inapplicable.

| Mode | Active idle, before → after | Close teammate pairs, before → after | Pickups, before → after | Team score, before → after |
|---|---:|---:|---:|---|
| DM | 17.0% → 16.0% | 0.0% → 0.0% | 78 → 92 | — |
| CTF | 0.0% → 0.0% | 0.6% → 0.5% | 7 → 6 | [0, 0] → [0, 0] |
| KOTH | 0.1% → 0.0% | 28.3% → 7.7% | 2 → 2 | [11, 20] → [10, 26] |
| IF | 11.1% → 10.3% | 10.2% → 7.8% | 0 → 0 | [1, 1] → [2, 2] |
| TDM | 0.6% → 0.7% | 1.0% → 1.2% | 109 → 111 | [22, 31] → [19, 30] |
| IG | 0.6% → 0.8% | 0.0% → 0.0% | 0 → 0 | — |
| FT | 33.1% → 14.9% | 1.2% → 3.0% | 47 → 73 | [0, 0] → [0, 1] |
| CC | 0.0% → 0.0% | 0.0% → 0.0% | 0 → 0 | — |
| TF | 0.4% → 0.0% | 2.5% → 1.3% | 11 → 12 | [2, 3] → [1, 3] |
| AS | 0.0% → 0.0% | 3.3% → 2.8% | 43 → 43 | [0, 0] → [0, 1] |

Idle here means the planner selected no strategic route; it excludes intentional holding and is different from snapshot stationarity. Low idle alone does not prove successful traversal. The qsrc_dm3 spawn/island issue persists, and three-minute CTF rounds still ended without a capture.
