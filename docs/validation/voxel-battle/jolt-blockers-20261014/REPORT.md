# Jolt blocker triage and stair-ramp experiment

October 14, 2026. The selected Jolt prototype passes its functional fixtures.
**Live authority is not switched.** Original Godot parity remains a separate,
failed gate: three cast-distance disagreements remain, with independent geometry
checks supporting Jolt's results. [Reproduce the experiment](../../../../tools/collision_service/README.md#jolt-blocker-and-ramp-experiment).

## Findings and scope decisions

| Issue | Decision | Evidence / implemented candidate |
|---|---|---|
| Buried rays leaving the ground, 13 failures | Omit terrain back-face hits for rays | Front-face ray policy matches Godot; downward ground shots still hit. Body sweeps retain two-sided collision. This does not authorize ignoring buried players or spawn recovery. |
| False grazing cylinder ray, trace 77 | Real precision defect; fixed in the adapter | Double-precision cylinder intervals inside Jolt's broadphase avoid float quadratic cancellation. Tests retain genuine grazing hits and reject misses over 40/400/4,000 m segments. Other shapes use Jolt ray routines. |
| Extra 1 mm sweep radius | Omit inflation for nominal physical queries | It creates the trace 1251 hit on a trunk the actual sphere clears by 0.264 mm. Actor padding remains 1 mm; removing query inflation does not remove actor clearance. |
| Godot cast-distance quirks | Omit reproducing these numerical errors | Three remaining original cases match analytic geometry in Jolt. Godot results change when the same cast is segmented or translated near the origin. Original parity failures remain visible, not relabeled as passes. |
| Per-tread collision / special stair solving | Omit for authored flights by substituting ramps | 19 real-map flights traverse both directions without stair assistance; render descriptions are unchanged. Keep optional CS stepping for other small obstacles until those routes are verified. |
| Horizontal player shoving | Omit; use CS-style solid blocking | Built-in pushing caused dense-island overlap. Disabling side pushing preserves separation and cuts cost. Upward support contacts, stacking and moving-player carry remain enabled. |
| Contact overflow | Real safety condition; bounded handling tested | An intentionally tiny buffer triggers fail-closed movement. Retry with the normal bounded capacity resolves the same fixture. Integration must honor the failure before commit. |
| Crossing actors / moving supports | Real required behavior; solutions prototyped | Relative Jolt sweeps catch simultaneous crossings; support-velocity carry and player stacks pass multi-tick tests. This is not a complete rotating/mixed island resolver. |
| Vehicle hull/turret solids | Cannot omit | Compound ray cover, stable ID exclusion and high-speed hull CCD pass. Vehicle lifecycle, rotation and gameplay still need integration. |
| General rigid-body/joint/soft-body/fluid service | Omit from first gameplay service | Existing players/vehicles use kinematic control; water and road rules can remain typed gameplay tests. Their effects cannot be omitted, but they do not require a general physics simulation. |

## Validation and policy matrix

Release CTest passes **534 custom checks, 284 Jolt regression checks and 305
new blocker checks**. A separate Clang build instruments the full Jolt library
and all three suites with ASan/UBSan/float-cast-overflow checks; CTest passes.
LeakSanitizer remains disabled because this session uses ptrace.

The unchanged engine comparator uses the same distance, normal, ID, support and
velocity tolerances as the earlier comparison. No tolerance was widened.

| Original 2,368-case corpus | Failed cases |
|---|---:|
| Original Jolt policy | 18 |
| Front-face terrain rays | 5 |
| Plus precise cylinder rays | 4 |
| Plus nominal sweep radius, selected policy | **3** |

The selected sweeps use **1 µm collision tolerance**. A new ramp-map sample
exposed a 2.34 µm near miss accepted by the previous 10 µm tolerance. Tightening
it rejects that trunk; the next physical tree hit agrees with an independent
full-scene horizontal-cast certificate to **0.000924 mm**. The certificate excludes
terrain using conservative vertex height bounds, rejects any box candidates,
and checks every remaining upright cylinder analytically. Unsupported geometry
would fail certification rather than be skipped.

The ramp map's separate 2,368-case oracle retains one cast-distance disagreement
with Godot; that is the analytically certified case above. All its movement
comparisons pass. Its object-directed samples change because collider count/order
changes, so its failure count is not directly comparable with the original corpus.

Original residual cases:

- **1278:** Jolt's nominal sphere entry matches analytic trunk geometry. Godot's
  world-space long cast reports about 20 m travel; segmenting it reports about
  12.41 m, as does the near-origin fixture and analytic calculation.
- **1457:** Cylinder grazing entry matches analytic geometry. Godot's long
  world-space cast shifts on segmentation and translation; the fine segmented
  result is much closer to the analytic contact.
- **1470:** Sphere versus a large boundary box matches the exact flat-plane
  distance in Jolt. Godot is later by centimetres; shortening the cast does not
  make its result an exact physical reference.

`isolated_oracle.gd` records the six disputed primitive fixtures at their original
coordinates and near the origin, using margins 0/1/10 mm and 1/16/256 segments.
`functional_fixture_pass` is independent of `legacy_engine_parity_pass`;
`promotion_pass` and `production_enabled` remain false.

## Stair ramps: actual map and synthetic traversal

The test-only authoring helper validates exact semantic tread positions, removes
16 tread colliders per flight and inserts one **2.4 m wide, 18 cm thick tilted
box**. It joins the lower floor to the existing upper landing. Using a thin slab
preserves the area underneath; a solid wedge could block it.

- **304 tread colliders → 19 ramps**, reducing static primitives from 93,182 to
  **92,897**. Render descriptions are asserted unchanged. Meshes, LODs and draw
  calls are not modified. The live map is untouched; `--stair-ramps` opts into
  the test export only.
- Authored rise/run is 3.2 m / approximately 7.66 m, about **22.67°**, below the
  existing walkable slope threshold.
- **19/19 flights ascend and descend**, 95 ticks per direction, with stair
  assistance disabled, using the exported whole-map collision including nearby
  floors, walls, terrain and furnishings. The caller feeds CS gravity while
  unsupported; collision response alone does not provide locomotion gravity.
- Synthetic 32/64-actor ramp tests run 240 ticks each, also without stair
  assistance. Prone traversal beneath a low parallel ceiling passes; standing
  growth there is rejected. Ordinary walkable/steep slopes are tested separately.
- The earlier 20 cm stair/headroom failure was an invalid fixture: it provided
  about 1 mm less room than the actual collider required. With valid headroom,
  both legal stepped and ramp traversal pass. Over-height and genuinely blocked
  ceilings still reject traversal.

Ramps simplify contact handling and avoid repeated stair probes. They also change
collision/ballistic surfaces between visual treads. Finite-radius cylinders give
up to **14.2 cm foot lift above the continuous ramp surface** in the synthetic
traversal; the rendered foot-to-tread error needs visual review. Those are
explicit tradeoffs, not evidence that exact stair collision is universally wrong.

## Dense actors, required behavior and timing

All times are local i7-12700 CPU measurements, not VPS/server frametimes. Dense
islands use Jolt's **serial** `CharacterVsCharacterCollisionSimple`; the built-in
checker is not thread safe. Each island is driven inward for 90 ticks.

| 64-character dense island | Median / p95 | Minimum horizontal centre distance |
|---|---:|---:|
| Horizontal pushing enabled | 0.894 / 1.043 ms | **0.356 m**, substantial overlap |
| CS blocking, side pushing disabled | **0.386 / 0.496 ms** | **0.602 m**, separated 0.6 m bodies |

The 32-character controls show the same result. Vertical player stacks and
carrying an upper player on a walking lower player pass. A moving kinematic
platform test demonstrates the negative control: without support carry the
passenger stays behind; with it the passenger follows. Resolved velocity is
published back to the virtual character for subsequent support queries.

Relative-motion Jolt pair casts find crossings for 32/64 actor fixtures where
endpoint overlap is insufficient. A symmetric pair stop preserves actor order
and separation. The helper currently prepares shapes per call and is a geometric
proof, not an allocation-free general island commit implementation. Dense mixed
vehicle/actor islands and rotating contacts remain an integration gate.

Selected original-map batches use 24 repeats after warmup and return identical
ordered results at 32/64 commands with 1/2/4 workers. No counted allocations or
unresolved queries occur in that timed corpus. Median **64-command movement**
is 0.282 ms with one worker and 0.091 ms with four. These are isolated command
batches; they do not include server orchestration or replication.

## Remaining real deployment blockers

1. Bind the service into server authority and client prediction with the same
   manifest, controller parameters and query policy. Avoid a partially duplicated
   collision world disagreeing about cover or support.
2. Implement dynamic lifetime/generation handling, spawn/teleport clearances,
   rotating vehicle/turret updates and stable mixed-island commits. Preserve
   relative motion and support dependencies when scheduling work across CPUs.
3. Route road/water/runover, vehicle damage/destruction and other typed gameplay
   rules through the new transforms. Preserve their behavior; do not replace them
   with generic rigid-body simulation merely to change collision backends.
4. Repeat off-host 32/64-player full-combat, vehicle, utility and network tests on
   the VPS. This experiment does not establish sustained server capacity.

Existing Godot CS movement and jetpack contract suites pass **31 and 44 checks**;
these validate retained gameplay, not a Jolt binding that does not yet exist.
The vehicle-surface suite cannot create a UDP socket in this restricted sandbox
and fails during host setup before gameplay assertions. Related host-dependent
vehicle/frontier suites were not repeated after that known prerequisite failure.
This environmental limitation is distinct from a failed collision assertion.

Evidence: `report.json`, unchanged legacy/selected CSVs, whole-map flight results,
isolated oracles, ramp export metadata/traces, release and sanitizer logs, and
`legacy-gameplay/results.json`. Large world dumps are omitted; the runner
regenerates them, and the report records hashes and source provenance.
