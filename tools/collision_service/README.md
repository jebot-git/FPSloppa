# Experimental CQ collision service

A standalone C++17 implementation of the first milestone in
[the collision rewrite proposal](../../docs/CQ-COLLISION-REWRITE.md), evaluated
against exported authoritative map collision and real Godot queries. This is a
test service, with **no production, VPS, player prediction or native extension
binding enabled**. The branch runtime separately uses Godot’s integrated Jolt backend; see [runtime validation](../../docs/validation/voxel-battle/jolt-runtime-20261014/REPORT.md). No OpenNova source is copied.

## Run

For an isolated VPS test deployment, use
[the prepared bundle workflow](DEPLOYMENT.md). It packages the integrated runtime,
offline pinned Jolt sources, regression runner and optional 32/64-player capacity
tools without replacing the production release.

From this worktree's project root, with its normal Godot imports available:

```sh
python3 tools/collision_service/run.py --output /tmp/cq-collision-experiment --repeats 12
```

Requires Python 3, `g++` with C++17/threads, and Godot (`--godot` overrides its
path). Export/build artifacts and redirected Godot user data stay under the
output directory. A matching existing heightfield cache is copied read-only
from the normal project user-data directory; otherwise map generation builds
it in the redirected directory. Export errors and non-30-Hz movement oracle
steps abort the run. No listener, AI, renderer or gameplay server is started.

To rerun native benchmarks against an existing export:

```sh
python3 tools/collision_service/run.py --output /tmp/cq-collision-experiment --skip-export
```

Default exit zero means **evaluation completed**, not collision compatibility.
Inspect `report.json`: `parity.pass`, `parallel_results_identical`, malformed
input results and `promotion_pass`. Add `--require-parity` for exit 1 on a
failed compatibility/determinism/input-validation gate. `promotion_pass` also
requires completing the missing integration features, so is currently false.
Do not treat a successful build or fast batch as permission to switch backends.

Standalone kernel checks, without Godot:

```sh
cmake -S tools/collision_service/native -B /tmp/cq-collision-build -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/cq-collision-build -j 2
ctest --test-dir /tmp/cq-collision-build --output-on-failure
```

ASan/UBSan check (Clang was used in the recorded run):

```sh
clang++ -std=c++17 -O1 -g -pthread -fsanitize=address,undefined,float-cast-overflow \
  -fno-omit-frame-pointer tools/collision_service/native/tests.cpp -o /tmp/cq-collision-asan
ASAN_OPTIONS=detect_leaks=0 /tmp/cq-collision-asan
```

Leak detection was disabled because this session's ptrace environment prevents
LeakSanitizer from working; memory access, undefined behavior and float-to-int
checks remain enabled. GCC's shared sanitizer runtime was unavailable locally.

## Implementation and reuse

- `native/collision.hpp`: numerical vectors/shapes, static BVH, 16-cell terrain
  tile min/max bounds, exact heightfield triangles, analytic primitive rays,
  specialized primitive distances and GJK fallback. Translational conservative
  advancement supplies finite-radius sweeps, including initial overlap and
  relative actor motion. Approximate overlap escape, slide, stair and floor
  snap form an experimental flat-ended CS cylinder controller.
- `export_suite.gd`: deterministic real-map export, ray and safe/unsafe
  shape-cast oracles, and isolated `CharacterBody3D` movement in actual 30-Hz
  physics callbacks. The first callback may be skipped if it arrives at the
  engine's bootstrap frequency; accepted deltas are recorded and validated.
- `native/suite.cpp`: frozen world, private scratch/results/counters, persistent
  worker pool, stable command ordering, homogeneous 32/64-command batches,
  two warmups and configurable timed repetitions. Main thread participates in
  the worker count. No live scene objects are accessed by workers.
- `run.py`: orchestration, tolerance checks, deterministic CSV comparison,
  malformed-input fixtures, timing aggregation and report provenance.

Reuse the header as an interface library (`cq_collision` CMake target), or
adapt its plain structures to a future GDExtension service. Configure a `World`,
call `build()`, then keep **all world data immutable** while queries execute.
Give each worker its own counters and output. Rebuild only between query
phases. Object `motion` is a frozen displacement over a sweep, not velocity;
rotation during sweeps is not supported. IDs must be stable, with terrain ID 1
reserved; layer bit 1 identifies terrain. `move_character` currently queries
layers 1/2 and uses fixed prototype controller constants. It does not implement
CS acceleration, input, fatigue, jump or jetpack gameplay itself.

Always check `Hit.converged` / `Move.converged`. An unresolved sweep returns a
conservative blocked result and fails evaluation, rather than silently allowing
motion. Initial-overlap recovery uses candidate escape axes; it is not EPA.
Terrain is a two-sided triangulated surface, without solid-volume or hole
semantics. The recorded tests expose disagreement with Godot for buried rays.

The binary formats are little-endian, versioned `CQCOLL1\0` and `CQTRACE2`;
world header is 56 bytes, primitive records 172 bytes, trace records 296 bytes.
Shapes use orthonormal bases with scale folded into dimensions. The loader
checks counts, truncation, finite values, dimensions and basis validity.
Triangle fallback exists internally for terrain but is not an exported arbitrary
mesh format. Trace kind 0 is a ray; 1/2/3 are cylinder/sphere/capsule sweeps;
5 is a movement command. This is a local test interchange, not an untrusted
network protocol or hardened asset importer.

## Coverage and promotion limits

The unit suite covers thin-wall CCD, masks/exclusions, overlap recovery,
stair limits, ceiling/corner blocking, bridge rotation, capsule/sphere rays,
terrain finite hulls, stable tie ordering, relative crossing actors, player
support sweeps, random analytic checks and concurrent deterministic queries.
The real-map suite covers terrain rays/LOS, object rays/cylinder sweeps,
ordnance sphere sweeps, terrain capsule clearance and isolated slide/snap.
Eight authored tank **hulls** are static obstacles; turrets and vehicle dynamics
are not simulated. Undergrowth has no collision and is absent from the export.

Still required before deployment: fix oracle compatibility; add real engine
stair/ceiling/steep-slope and dense multi-tick combat trajectories; resolve
coupled player/vehicle islands and moving supports; implement dynamic lifetime
and map-generation handling; preserve road/water/runover and gameplay events;
provide matching client prediction; expand direct Jolt gameplay coverage; then repeat full
32/64-player off-host server tests. No server capacity conclusion follows from
these isolated command timings.

[Recorded results and failed gates](../../docs/validation/voxel-battle/collision-service-20261014/REPORT.md).

## Direct Jolt comparison

The optional backend links [Jolt 5.6.0](https://github.com/jrouwe/JoltPhysics/tree/e77f175595e64cb44218cc9d9d56fc365ad0e36a)
(MIT), pinned to `e77f175595e64cb44218cc9d9d56fc365ad0e36a`.
It uses `NarrowPhaseQuery` for rays/sweeps and `CharacterVirtual` for movement;
no custom narrow-phase math runs in the Jolt query path. Both executables
compile the **same** loader, worker pool, query ordering and CSV/timing harness.
CMake's `CQ_WITH_JOLT` option defaults off, leaving the standalone custom build
without a Jolt dependency.

After producing an export with `run.py`:

```sh
python3 tools/collision_service/compare_jolt.py \
  --inputs /tmp/cq-collision-experiment --output /tmp/cq-jolt-comparison --repeats 24
```

CMake fetches the pinned dependency when network access is available. For an
existing unmodified checkout of that exact revision, add
`--jolt-source /path/to/JoltPhysics`. A source tree retrieved through the GitHub
connector can instead provide `cq-source-manifest.json`, containing the pinned
revision and Git tree `files` entries (`path`, `sha`); every supplied blob hash
is verified before build. The recorded run verifies all 562 required dependency
files. Source stays outside the repository. `--build-dir` can reuse a CMake
build; `--jobs` controls compilation parallelism. Timed backends run sequentially,
alternating which runs first. `--require-parity` makes failed compatibility,
determinism or input rejection return nonzero; normal completion preserves
failed gates in `comparison.json`.

Jolt uses double world positions, deterministic floating-point settings,
assertions, default AVX2/SIMD options and no renderer/profiler/compute backend.
The report retains `CMakeCache.txt`. The custom backend uses the compiler's
default ISA; this is a comparison of these configured implementations, not an
ISA-controlled algorithm experiment. Shapes/characters and 2 MiB scratch per
possible worker are allocated before timing. Jolt allocator hooks supplement
the shared operator-new audit.

Terrain uses Jolt's 16-bit compressed `HeightFieldShape`, two-sample blocks and
reflection of reversed-X samples when the exported diagonal requires it. This
preserves diagonal/origin/scale without a multi-million-triangle mesh; native
fixtures check both diagonal conventions. Heights are not bit-exact after
compression. Boxes and cylinders use zero convex radius to preserve sharp
profiles. The initial comparison used a 1 mm extra sweep radius. The blocker experiment below removes that inflation and tightens cast tolerance.

The controller adapter teleports to each trace start, refreshes contacts,
captures contact-solver output velocity during `Update`, and snaps if unsupported
and moving downward. Supported downward velocity is cleared to match the
Godot result contract. Jolt otherwise retains desired velocity independently
of its resolved displacement. No Godot answers are read by the backend.
Stair climbing is disabled for this isolated slide/snap oracle, as in the custom
backend. A reusable persistent character is owned by each trace; it is never
queried simultaneously by two workers. This does **not** simulate interacting
players. Dynamic exported objects are explicitly rejected rather than silently
frozen.

Jolt's triangle/GJK/iteration fields are uninstrumented and must not be read as
zero work. Its unresolved count catches character contact-buffer overflow; it
is not the custom solver's convergence guarantee. Missing integration and failed
compatibility gates still prevent deployment.

[Direct comparison results](../../docs/validation/voxel-battle/jolt-direct-20261014/REPORT.md).


## Jolt blocker and ramp experiment

```sh
python3 tools/collision_service/test_jolt_blockers.py \
  --inputs /tmp/cq-collision-experiment --build-dir /tmp/cq-jolt-build \
  --output /tmp/cq-jolt-blockers-final --repeats 24
```

Configure the build with `CQ_WITH_JOLT=ON` first, as above. This runner compares
four query policies against the **unchanged** Godot comparator, runs independent
analytic and gameplay collision fixtures, re-exports a test map with ramp
colliders, and traverses every authored flight using Jolt. Failed legacy parity
and functional fixture acceptance have separate flags. Unknown parity failures
are not automatically accepted. Large world dumps/user data remain in the output
directory; no live map/server configuration is changed.

Current test-backend defaults: terrain rays ignore back faces; movement sweeps
retain two-sided terrain collision; cylinder rays use a double-precision interval
test inside Jolt's broadphase (other shapes still use Jolt's native ray routines);
sweeps use the nominal physical radius, with 1 µm collision tolerance. Character
padding remains 1 mm. `CQ_JOLT_RAY_BACKFACES`, `CQ_JOLT_PRECISE_RAYS`,
`CQ_JOLT_SWEEP_MARGIN` and `CQ_JOLT_SWEEP_TOLERANCE` reproduce the previous
experimental policies. These are test process options, not server settings.

`jolt_blockers.cpp` adds dense serial character islands, player stacking/carry,
relative-motion pair CCD, prone/crouch/stand clearance, slope/ceiling/stair tests,
vehicle hull/turret compounds and fail-closed contact overflow with bounded retry.
Character side contacts cannot push horizontally; upward support contacts still
carry players. Jolt's desired velocity is replaced with the captured resolved
velocity after each move so subsequent characters see the correct support speed.
This is a prototype contact policy, not a complete dynamic lifecycle or mixed
island implementation. `CharacterVsCharacterCollisionSimple` must remain serial.

`stair_ramps.gd` substitutes each exact authored flight's 16 treads with a single
2.4 m wide, 18 cm thick ramp slab in the test export. It validates the original
tread positions before mutation and asserts that render descriptions remain
unchanged. A thin slab preserves the area beneath the stairs. The exporter flag
`--stair-ramps` is opt-in for historical test exports. Runtime maps now enable the same helper by default, from `tools/voxel_battle/stair_ramps.gd`. The current map
has 19 flights (304 tread colliders → 19 ramp colliders). All 19 pass Jolt
ascent/descent without stair assistance. Optional 18/32 m step assistance stays
available for other CS obstacles; the tests do not justify removing it globally.

The restricted `verify_horizontal_cast.py` reference certifies the remaining
ramp-map grazing discrepancy using analytic cylinder intervals and conservative
exclusion of terrain/boxes. It rejects unsupported geometry rather than skipping
it. The six disputed primitive fixtures are also stored as plain JSON and C++
records; `isolated_oracle.gd` reproduces them near the origin and at world
coordinates with several segment lengths and margins.

[Results, omissions and real deployment blockers](../../docs/validation/voxel-battle/jolt-blockers-20261014/REPORT.md).
