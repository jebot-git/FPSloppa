# Collision service rewrite experiment — October 14, 2026

The isolated rewrite is implemented and tested. **Do not promote it:** 26 of
2,368 Godot comparisons fail, and coupled dynamic movement/integration remain
unfinished. The live Godot collision path, native extension and VPS were not
changed. [Source and reproduction instructions](../../../../tools/collision_service/README.md).

## Correctness

- **534 native checks pass**, including CCD, stairs, recovery, ceiling/corner,
  rotated bridge, terrain, relative crossing actors and support sweeps.
- CMake release build and CTest pass. Clang ASan/UBSan/float-cast-overflow checks
  pass with no diagnostics. LeakSanitizer was disabled because the session uses
  ptrace; GCC's shared sanitizer runtime was missing.
- Six malformed world fixtures are rejected: bad magic, truncation, invalid
  shape kind, invalid basis, nonfinite height and excessive grid dimensions.
- All six 32/64-command × 1/2/4-worker runs produce byte-identical ordered CSV
  results. **Zero unresolved queries**; zero counted `operator new` calls
  inside query execution. This audit does not instrument direct malloc or
  unrelated engine/worker scheduling allocations.
- Real map: **93,182 primitives**, **2,030,625 height samples**, eight static
  authored vehicle hulls. Terrain diagonal was inferred using an isolated
  nonplanar cell; probe residual is 1.21 mm.
- **2,342/2,368 oracle cases pass.** All 512 downward terrain rays, 512 terrain
  LOS rays, 256 terrain cylinder sweeps and 256 capsule sweeps pass.

| Failed category | Cases | Finding |
|---|---:|---|
| Object-directed rays | 13/256 | All start underground and cross upward out of the heightfield. Native two-sided triangles report that exit; Godot skips it despite `hit_back_faces=true`, then hits an object. Earliest distance, ID and normal differ. |
| Object cylinder casts | 1/256 | Native hit falls 14.8 cm before Godot's safe/unsafe interval. |
| Ordnance sphere casts | 3/256 | Two grazing trunk cases differ substantially; one boundary case is 1.19 cm outside the interval. These remain unresolved compatibility failures. |
| Isolated CS slide/snap | 9/64 | Nine velocity mismatches; six also exceed position tolerance. Maximum position error 12.55 cm; maximum velocity error 4.84 m/s. Support flags match. |

Tolerances: 1 cm ray-distance error, ray normal vector difference 0.02 and
matching stable IDs; native cast time must fall inside Godot's safe/unsafe
interval with 1 cm slack; movement position 3 cm, velocity 0.05 m/s, exact
support flag. No failure is waived or hidden. Shape-cast oracle intervals can
be relatively wide for long casts; unit tests independently check analytic
CCD distances. `terrain-exit-diagnostics.json` records the negative start
height and below-to-above crossing for all 13 ray failures.

## Local CPU measurements

Intel i7-12700, GCC 16.2.1, Godot 4.7.2, Linux. No rendering, AI or networking.
Native timings include persistent pool dispatch/wait, with two warmups and
12 repeats. Data load/build is outside query timing (about 80–95 ms). Request
preparation is also outside native query timing. Median and p95 are wall
milliseconds per **64 commands**, not 64 players for a whole tick.

| Command kind | 1 worker p50 / p95 | 2 workers p50 / p95 | 4 workers p50 / p95 |
|---|---:|---:|---:|
| Rays | 0.733 / 0.960 | 0.264 / 0.445 | 0.209 / 0.338 |
| Cylinder sweeps | 3.810 / 4.638 | 2.081 / 2.484 | 1.222 / 1.553 |
| Sphere sweeps | 0.119 / 0.133 | 0.058 / 0.171 | 0.032 / 0.170 |
| Capsule sweeps | 0.095 / 0.109 | 0.049 / 0.109 | 0.026 / 0.040 |
| CS slide/snap | 1.341 / 1.368 | 0.692 / 0.857 | 0.423 / 0.480 |

On the same exported queries, sums of serial Godot calls in groups of 64 have
medians of 0.546 ms for rays, 3.901 ms for cylinders, 8.731 ms for spheres and
3.414 ms for capsules. All 64 measured movement calls total **9.585 ms**;
there is only one such group, so it is not a repeated median. Godot movement
is measured after a separate zero-motion warmup; cold movement calls total
4.787 ms but perform different work and are not the comparison workload.
Accepted movement callbacks all record exactly 1/30 second, with no script
errors. Engine query timings include query-parameter construction. Native
repetitions run in a separate process with hot data. These are useful local
kernel comparisons, with different overheads and failed compatibility cases;
they are **not equivalent whole-server benchmarks**.

The four-worker movement batch is about 3.2× faster than one worker. Cylinder
sweeps remain the largest measured native batch and need further narrow-phase
work. Small sweep batches have scheduling tails that can outweigh parallel
savings; one worker's ray result is slower than the Godot serial group here.
Use raw distributions rather than assuming every command benefits equally.

## Next decision

Keep the prototype behind the test suite. First settle buried-ray policy,
reproduce the four cast disagreements as isolated engine fixtures, and match
controller contact/velocity behavior. Then implement stable dynamic island
resolution, support transport, road/water/runover and client/server bindings.
Direct Jolt remains an untested alternative. Only a later full gameplay/network
run on the 12-vCPU VPS can establish sustained 64-player capacity.

## Evidence

`report.json` contains environment/source hashes, all failed cases, tolerances,
per-query engine timing arrays, native timing summaries and input SHA-256.
`results.csv` is the shared deterministic result set; `traces.bin` retains the
oracle commands. The 24 MB world dump is deliberately omitted: regenerate it
with the exporter and verify its hash from the report. `oracle.log`, CTest and
sanitizer logs retain validation output. Six `batch-*.json` files retain the
individual worker/batch results, including 32-command runs.
