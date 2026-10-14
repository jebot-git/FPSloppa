# Direct Jolt versus custom collision — October 14, 2026

The direct Jolt test backend is built and measured against the same map and
Godot oracle as the custom service. **Jolt is the stronger candidate for the
next shadow integration experiment**, particularly for cylinder collision and
movement. Neither backend passes every compatibility gate, and no live backend
or VPS settings were changed.

[Implementation and reproduction](../../../../tools/collision_service/README.md#direct-jolt-comparison).

## Test contract and validation

Both executables use the same loader, frozen world, traces, worker pool,
32/64-command groups, two warmups, timing boundaries and CSV result schema.
Timed processes run sequentially, alternating backend order. This run uses
24 measured repetitions per batch and 1/2/4 workers including the main thread.
The inputs contain **93,182 primitives, 2,030,625 terrain samples and 2,368
queries**, including 64 independent 30-Hz slide/snap commands. Eight vehicle
hulls are static fixtures. There are no interacting characters, AI, renderer,
networking, server orchestration or gameplay effects.

- Custom native checks: **534 pass**. Direct Jolt checks: **284 pass**, including
  primitive analytic comparisons, CCD, floor/ceiling/wall velocity, rotated
  bridge and cylinder support, initial overlap, masks, worker-independent reset
  and both nonplanar heightfield diagonals.
- Release CTest passes both suites. A separate Clang build instruments the
  **whole Jolt library and both unit executables** with ASan, UBSan and
  float-cast-overflow checks; CTest passes without sanitizer diagnostics.
  Leak detection is disabled because the session's ptrace environment prevents
  LeakSanitizer from working. See sanitizer configure/build/test logs.
- All six worker/batch configurations return identical CSV results **within
  each backend**. No equivalence between the two backends is assumed.
- Zero counted query allocations after warmup in both backends. Jolt's allocator
  hooks are counted alongside operator new; preallocated scratch use is excluded.
- Both binaries reject bad/truncated world headers. Other world validation is
  shared with the custom harness; the previous report retains six malformed
  fixtures. Jolt rejects exported nonzero object motion and unsupported masks
  instead of pretending to support dynamic objects.
- No character contact-buffer overflow is reported. Jolt does not expose all
  internal iteration/convergence conditions through this adapter; its zero
  unresolved count is **not** the custom solver's convergence guarantee.

Jolt is [5.6.0 at pinned revision e77f175](https://github.com/jrouwe/JoltPhysics/tree/e77f175595e64cb44218cc9d9d56fc365ad0e36a),
MIT licensed. Shell GitHub resolution was unavailable, so the GitHub connector
retrieved the source. All **562 retrieved files** match their upstream Git blob
SHA-1 values; the manifest is retained. No dependency code is vendored or copied
into production. The build enables double world positions, assertions,
deterministic floating-point settings and default Jolt AVX2/SIMD options;
debug rendering, profiling and compute backends are disabled. The custom target
uses the compiler's default ISA. Build settings are retained in `CMakeCache.txt`.

Jolt uses its compressed 16-bit heightfield, reflected/reindexed to preserve the
exported diagonal. Independent terrain fixtures verify diagonal, scale and
origin. This is the same source terrain, with small compression differences.
Primitive convex radii are zero; sweep margin is 1 mm. Shape/character creation,
world construction, broadphase optimization and 2 MiB scratch per possible
worker occur outside hot timing. Measured setup is approximately 82–84 ms
custom and 166–168 ms Jolt in this run.

## Performance

Intel i7-12700, Linux, GCC 16.2.1 release builds. Values below are median / p95
wall milliseconds for **64 commands** including worker dispatch and waiting.
They are not whole-tick frametimes or an interacting 64-player match.

| Work | Custom, 1 worker | Jolt, 1 worker | Custom, 4 workers | Jolt, 4 workers |
|---|---:|---:|---:|---:|
| Rays | 0.437 / 0.568 | 0.075 / 0.093 | 0.185 / 0.301 | 0.039 / 0.088 |
| Cylinder sweeps | 3.792 / 4.610 | 0.179 / 0.209 | 1.172 / 1.503 | 0.096 / 0.149 |
| Sphere sweeps | 0.105 / 0.115 | 0.101 / 0.111 | 0.027 / 0.127 | 0.046 / 0.099 |
| Capsule sweeps | 0.090 / 0.107 | 0.099 / 0.105 | 0.025 / 0.039 | 0.046 / 0.056 |
| Cylinder slide/snap | 1.333 / 1.347 | 0.279 / 0.284 | 0.409 / 0.430 | 0.143 / 0.241 |

On one worker, Jolt is about **4.8× faster for movement** and **21.2× for cylinder
sweeps** in this corpus. It is about 2.8× / 12.3× faster respectively with four
workers. The custom specialized capsule path remains faster; sphere differences
are small at one worker. Do not generalize the cylinder result to all query kinds.

Two-worker Jolt movement is 0.155 / 0.159 ms: four workers improve its median
slightly but worsen p95 in this run. Short jobs are sensitive to scheduling and
worker wakeups. Movement has only 24 timed full-size batches per configuration;
p95/p99 should not be treated as stable production tail estimates. Raw summaries
for all 32/64-command and worker combinations are retained.

For historical engine context, the input Godot 4.7.2 oracle has serial
64-call group medians of 0.546 ms rays, 3.901 ms cylinders, 8.731 ms spheres and
3.414 ms capsules; its 64 measured movement calls sum to **9.585 ms**. Those
Godot timings were retained from the original export, **not rerun in this
comparison**. They include query-parameter setup; the native query path begins
with prepared shapes and hot world data. Engine movement is measured in actual
30-Hz physics callbacks after separate warmup. These differing overheads make
them useful context, not a controlled full-backend speedup measurement.

## Compatibility

The comparator and tolerances are unchanged: 1 cm ray distance, normal vector
difference 0.02 and stable IDs; cast result within Godot's safe/unsafe bracket
plus 1 cm; movement within 3 cm and 0.05 m/s with exact support flags.

| Scenario | Custom failures | Direct Jolt failures |
|---|---:|---:|
| Terrain downward rays | 0/512 | 0/512 |
| Terrain LOS rays | 0/512 | 1/512 |
| Object-directed rays | 13/256 | 13/256 |
| Object cylinder sweeps | 1/256 | 1/256 |
| Ordnance sphere sweeps | 3/256 | 3/256 |
| Terrain cylinder sweeps | 0/256 | 0/256 |
| Terrain capsule sweeps | 0/256 | 0/256 |
| Cylinder slide/snap | 9/64 | **0/64** |
| **Total** | **26/2,368** | **18/2,368** |

Jolt movement position error is at most **5.73 mm**; velocity error is at most
0.0000055 m/s. Its adapter captures Jolt's contact-solver velocity, clears
supported downward velocity and snaps only when unsupported. Jolt's desired
velocity getter by itself retains the incoming downward velocity and does not
satisfy Godot's post-slide velocity contract. These adapter rules use contact
results, never oracle answers. Stair climbing is disabled for the engine corpus;
this does not establish full CS locomotion equivalence.

Both native backends report the same 13 buried-ray terrain exits that Godot
skips, plus the four cast-distance disagreements. The extra Jolt LOS failure
is trace 77: it reports an earlier trunk. Independent analytic evaluation of
that trunk's horizontal distance puts the ray about **0.037 mm outside** its
radius, a grazing tolerance discrepancy that changes which tree is first by
6.93 m along this ray. This remains a failed earliest-hit/ID/normal gate; it is
not waived as harmless. These cases need isolated engine regressions and an
explicit collision policy before integration.

## Next step and limits

Prefer direct Jolt for the next **test-only shadow adapter**, keeping the custom
service as an independent analytic reference. First settle the ray/cast edge
cases, then add multi-tick stair/slope/prone/jetpack/vehicle traces, coupled actor
islands and moving supports. Match server/client prediction, water, road and
runover rules before switching authority. Repeat full off-host combat/network
tests afterward. This benchmark cannot establish sustained 64-player capacity
on the 12-vCPU VPS.

`comparison.json` retains provenance, source/input hashes, all failures, timing
summaries, schedule and limits. Each backend's retained CSV is identical across
its six runs. `jolt-source-manifest.json`, `CMakeCache.txt`, release and sanitizer
logs record the build. World/trace inputs have the exact hashes from the
[earlier custom experiment](../collision-service-20261014/REPORT.md); its
`traces.bin` is reused and the 24 MB world can be regenerated with the exporter.
