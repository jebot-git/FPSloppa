# VR performance and verification

The target is native 72 FPS or better: 13.89 ms per frame at 72 Hz, 11.11 ms at 90 Hz. This build is optimized toward that target, but has **not** demonstrated it on Quest, Pico or PC VR hardware. No headset was connected for this release. A successful APK export is not a frame-rate or thermal test.

## September 30 weapon-lab follow-up

The [three-stage performance suite](tools/performance_suite/README.md) records individual frames and weapon events, compares immediate versus cached/buffered telemetry, and profiles effects, avatar/IK and rendering variants. It supports optional WiVRn Perfetto capture. The earlier weapon-lab run collected window summaries rather than per-frame CPU/GPU/compositor timing, so it cannot attribute its frame-time outliers to these subsystems. The wearer found local tracking representation and vibration intensity adequate; neither is retuned by this follow-up.

## September 2026 CPU and stair update

Runtime avatar springs now use Godot native simulation and can be disabled in Graphics. Stair camera offsets interpolate with the capsule. See the [investigation, CPU comparison, server findings, and validation](docs/VR-PERFORMANCE-2026-09-26.md). These local CPU measurements do not establish Vive Pro 2 / SteamVR performance.

## Changes

- Vulkan Mobile renderer on PC and Android, following Godot's current XR recommendation. OpenXR handles stereo/multiview and headset frame pacing; desktop VSync is disabled in XR. PC retains the runtime's refresh selection. Standalone requests the lowest advertised refresh rate at or above 72 Hz when the session starts.
- OpenGL/GLES fallback is disabled. Preview tools use Mobile, and Compatibility-specific avatar/decal workarounds have been removed; see [renderer support](docs/RENDERER-SUPPORT.md).
- Graphics shows Fovea Size (Off/Small/Medium/Large) with gaze support, replacing Static Foveation (Off/Low/Medium/High). The choices are saved independently and applied immediately. PC defaults to Off; Android to Medium. Compatible runtimes use their native profile, otherwise Godot supplies stereo VRS. Gaze is used when available, with fixed foveation otherwise. Manual strength is independent of workload-adaptive foveation. Quad views are unsupported by the current engine; see [foveation analysis](docs/XR-FOVEATION.md). Runtime capability and requested settings are logged as `XR_FOVEATION`; these do not certify GPU savings or active eye tracking.
- 4× MSAA on PC, 2× on Android; no SSAO, glow or dynamic sun shadows. No second full-scene spectator render is added.
- BSP occlusion culling and bounded nearby unshadowed lights: eight on PC, four on Android, selected at 5 Hz. Ambient illumination remains available throughout the maps.
- VRM outline passes and shadow casting disabled. Meshes retain their authored materials, transparency and expressions. Geometry is hidden beyond 65 metres.
- Cached bone lookup and foot contact queries at 12.5 Hz. Body IK runs at display cadence within six metres, approximately 30 Hz beyond six metres and 15 Hz beyond eighteen metres, retaining the last solved pose between updates. Eye, head/weapon presentation and locomotion continue through the existing render/snapshot paths; authoritative combat is unchanged.
- Hidden/disabled avatars skip signal-driven spring-bone simulation. Silent mouth expressions stop doing blend-shape work once they reach rest.
- Bot decision/line-of-sight work runs at 5 Hz per bot and path queries at most every 0.6 seconds. The five supplied navigation meshes are baked ahead of time. Audio and combat effects retain their existing bounded pools.

Custom VRM size limits are not GPU-complexity guarantees. Eight unusually expensive custom models, imported map compilation, initial VRM decoding, or a large effects-heavy fight can still miss the frame budget. Runtime VRM/BSP imports remain synchronous at their existing import points; do them before a match where possible. No reprojection or generated frame count is represented as native FPS.

## Repeatable desktop measurement

`deathmatch/tests/benchmark.gd` loads Solstice and eight player models (local model hidden, seven remote models visible), places them above the map geometry for a consistent view, warms up, and records 360 frames while gently rotating the camera. It saves a screenshot and JSON percentiles in `test-results/`. This is a rendering stress comparison, not a playable-map route or a headset test. Both compared runs use the same final gameplay/IK code; the reference restores the earlier expensive rendering settings.

Hardware: Intel Graphics ADL-N, Linux, 1440 × 900 single viewport, VSync off, Godot 4.7.2 editor binary running the game script.

| Configuration | Median frame | 95th percentile | Median FPS equivalent | Draw calls (median) |
|---|---:|---:|---:|---:|
| Forward+ reference; SSAO/glow, sun shadows, outlines, all map lights, no occlusion | 49.315 ms | 52.572 ms | 20.3 | 1446 |
| Final Mobile renderer and bounded effects | 16.390 ms | 20.411 ms | 61.0 | 36 |

Median frame time decreased by approximately 67%. The measured result still misses 72 FPS on this integrated GPU. Different renderer batching and shadow passes affect draw-call accounting. Source JSON and screenshots: `benchmark_render_reference.*`, `benchmark_optimized.*`. The older `benchmark_baseline.*` used a different camera placement and should not be used for this controlled comparison.

Reproduce optimized run:

```sh
godot --path . --xr-mode off --script res://deathmatch/tests/benchmark.gd -- optimized
```

Reproduce rendering reference (explicitly select Forward+):

```sh
godot --path . --xr-mode off --rendering-method forward_plus --script res://deathmatch/tests/benchmark.gd -- render_reference
```

## Real-headset acceptance test still required

Launch with `-- --frame-stats` to print ten-second frame percentile summaries after a five-second warmup. Use `-- --practice --map lqdm1 --frame-stats` for an offline session. These application timings supplement, rather than replace, compositor CPU/GPU timing.

Test each headset and supported PC GPU at native resolution and its selected refresh rate, with eight crossplay participants, voice enabled, several different VRMs, tracking active, weapon effects and each BSP arena. Run at least 20 minutes to catch thermal throttling. Use Meta OVR Metrics/Performance Analyzer, SteamVR frame timing and PICO Graphics Probe as appropriate; inspect CPU and GPU costs separately, missed frames and reprojection. Verify tracking latency and image readability in addition to FPS. Repeat with heavy permitted custom content and during joins/downloads. Keep 72 FPS unverified until these measurements pass.

Sources informing these choices:

- [Godot: Setting up XR](https://docs.godotengine.org/en/stable/tutorials/xr/setting_up_xr.html) — Mobile renderer recommendation.
- [Godot: OpenXR settings](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_settings.html) — VRS and foveation support.
- [Meta: Testing and performance analysis](https://developers.meta.com/horizon/documentation/unity/unity-perf/) — device profiling and required performance assessment.
- [Valve: Advanced VR Rendering, Alex Vlachos](https://media.steampowered.com/apps/valve/2015/Alex_Vlachos_Advanced_VR_Rendering_GDC2015.pdf) — frame budgets, stereo efficiency and MSAA.
- [PICO: Graphics Probe](https://developer.picoxr.com/blog/graphics-probe-tool/) — device graphics profiling.

## VR stall and threading investigation — 2026-09-30

Quest Pro / WiVRn v26.9 at 72 Hz, i7-12700 (12 physical cores, 20 logical CPUs),
Arc A770, full tracking, vest disabled. Two diagnostic sessions used a private
local copy of the passive weapon-lab server. The first supplied 2,031 focused
frames; the second supplied 3,080 focused frames over 45 seconds. Different
human-driven weapon workloads mean these are not an optimization A/B comparison.

The recurring shot-related stall is `experimental/visuals.gd`:
`impacts → streak → shape`. Accumulated `shape` time per affected frame was
9.610 ms median, 10.447 ms p95 and 11.458 ms maximum. These nested scope times
must not be added. The scope creates a mesh instance and material and attaches
the node; which individual engine setter/driver operation dominates is not yet
isolated. Pool/prewarm these bounded resources before changing tracking quality
or increasing worker counts. Audio selection also had an 8.991 ms maximum,
suggesting cold resource preparation deserves a separate preload check.

OpenXR interception recorded wall time and calling-thread CPU time, with no
dropped records. In the detailed session, main-thread CPU between consecutive
`xrWaitFrame` entries was 6.011 ms median, rising to 17.574 ms on cycles longer
than 20 ms. The normal OpenXR wait was 7.369 ms median and did not explain the
recurring slow cycles. Frame-sampler median/p95/p99 were 14.038/22.562/25.488 ms;
its boundaries differ from the OpenXR cycles. This does not measure compositor
reprojection, encoder or network latency.

10 Hz per-thread scheduler accounting measured 0.659–0.724 core-equivalents for
the game, of which the main thread used 0.405–0.458 and 20 worker threads together
used about 0.22. This is light aggregate CPU use with a serial critical path.
Rendering uses the default Safe thread model; physics is not on a separate
thread. Asset I/O, music loading and mesh LOD generation have background work.
Native Bluetooth has its own worker but was disabled for these captures.
All intercepted OpenXR calls ran on the main thread. Core migration is not
parallel execution; sampling saw the main thread on both P- and E-cores.

Both exits reproduced engine cleanup defects: `xrEndSession` returned -29
(`SESSION_NOT_STOPPING`) without a preceding exit request; session/instance
destruction then succeeded. Godot 4.7.2's spatial marker cleanup unconditionally
disconnects a signal that is only conditionally connected. Its action-map loader
also uses `interaction_profile_array` with an inverted membership test instead
of adding created RIDs to `interaction_profiles`, explaining the four leaked
profile RIDs. Two additional ObjectDB leak identities remain unresolved.
These engine defects were diagnosed, not patched in the installed executable.
Correct the session lifecycle and cleanup bookkeeping, then validate repeated
quit/relaunch. Separate rendering is explicitly experimental in this engine;
evaluate it only after the measured effect-allocation cost is addressed.

Full report and raw traces: `test-results/performance-suite/stalls-20260930/`.
Diagnostic clients, monitor processes and local servers were stopped. No
production threading, tracking, rendering or vibration settings were changed.

## Stall and shutdown fixes — 2026-09-30

Weapon visuals now allocate a fixed pool of 64 mesh instances, materials and
tracer meshes before play, reuse shared ring/sphere geometry, and recycle the
pool on expiry and map changes. Geometry, fading and oldest-first capacity
eviction are preserved. Built-in combat sound resources and generated impact
sounds are cached during setup without advancing the gameplay RNG. Optional
sounds retain their existing lazy-load fallback.

A deterministic rendered A/B/B/A effects fixture measured the former allocation
path against the pool: median creation cost was 227.5/234.5 microseconds for the
reference and 117.5/115 microseconds for the pool; p95 was 372/376 versus 219/230
microseconds. This measures effects creation, not complete frame time.

A subsequent 45-second headset capture recorded 3,230 focused frames with full
tracking and the vest disabled:

| Metric | Earlier diagnostic | After fixes |
|---|---:|---:|
| Impact presentation, median per affected frame | 9.718 ms | 0.106 ms |
| Audio selection, maximum per affected frame | 8.991 ms | 0.052 ms |
| Application frame median | 14.038 ms | 13.897 ms |
| Application frame p95 / p99 | 22.562 / 25.488 ms | 15.626 / 16.748 ms |
| Application frame maximum | 28.930 ms | 25.673 ms |
| Whole-game / main-thread CPU, core-equivalents | 0.724 / 0.458 | 0.683 / 0.420 |

Human firing workloads differed, and the new run used the project's release
runtime instead of the system editor executable. The frame comparison is an
observed improvement, not a controlled estimate of the pooling change alone.
The controlled effects fixture supports the allocation improvement. Remaining
frame spikes still exceed the 13.889 ms budget at 72 Hz. Tracking median was
0.266 ms and avatar pose scope median was 0.191 ms; neither system was degraded
to obtain the improvement. No worker-count or rendering-thread setting changed.

The rebuilt Godot 4.7.2 Linux runtime applies `tools/patches/openxr-shutdown.patch`:
only end an OpenXR session in STOPPING state, guard the optional marker signal
disconnect, and register interaction-profile RIDs for cleanup. Engine build
receipts now include patch hashes and reject stale templates. `./run.sh` and
`./run-vr.sh` use the verified local runtime when available; explicit `GODOT_BIN`
and editor/script/headless operations retain the development executable.
`python3 tools/build_client_templates.py linuxbsd --container --jobs 8`
reproduces the runtime. Windows/Android templates must be rebuilt before export.

The two remaining native leaks were the Steam Audio server singleton and its
reflection thread. The extension now destroys the singleton, wakes and joins
the worker before SDK teardown, and balances scene ownership. Linux debug and
release extensions were rebuilt; other platforms require rebuilding the added
patch documented in `addons/godot-steam-audio/SOURCES.md`.

Validation includes 731 resource/geometry/cache checks, 394 shared-hit-feedback
checks, and the audio HRTF/voice test with 960 rapidly retired sources. The audio
test now allows the same mixer retirement interval used by normal game shutdown.
Idle and active-audio shutdowns no longer report the native ObjectDB leaks.
Two subsequent VR launches (private lab and normal `run-vr.sh`) exited with code
0 and no OpenXR cleanup errors or ObjectDB leaks. Existing asset import warnings
and verbose native binding StringName diagnostics remain; these runs are not
claimed to have completely empty warning logs. Six Python suite checks and
preparation of all eight profile captures also passed.

Artifacts: `test-results/performance-fixes-20260930/`. The new runtime statically
links its OpenXR loader, so the earlier LD_PRELOAD interceptor produces no API
records for it. New measurements use script scopes and scheduler accounting;
they do not claim new compositor or per-OpenXR-call timing measurements.

## Additional threading experiment — 2026-09-30

Decision: retain Safe rendering and the default physics thread settings. Separate
rendering shows potential desktop headroom, but introduces engine errors and did
not improve the headset result. Separate physics is currently incompatible with
the game. No production settings were changed by this experiment.

All variants used the same patched Linux release runtime. A four-way desktop
compatibility pass tested baseline, separate rendering, separate 3D physics and
both. Rendering completed with errors; physics and the combined variant both
exited on SIGSEGV after reporting that direct physics-space state was inaccessible
outside the physics update. No valid physics-thread timing result was obtained.
Physics was consequently excluded from headset testing.

The remaining variants ran in baseline/render/render/baseline order, with ten
seconds of warmup and thirty seconds measured per run. The fixed desktop fixture
used eight avatars (seven visible), synthetic poses, weapon effects and normal
rendering at 1440 × 900 with VSync disabled:

| Variant | Run medians | Run p95 | Run p99 | Mean CPU, core-equivalents |
|---|---:|---:|---:|---:|
| Baseline | 5.134 / 5.385 ms | 7.064 / 7.202 ms | 8.302 / 8.004 ms | 1.318 |
| Separate rendering, rejected | 4.084 / 4.112 ms | 6.383 / 6.552 ms | 7.486 / 8.088 ms | 1.805 |

The median of the two run medians decreased by 22.1%; the corresponding run-p95
and run-p99 summaries decreased by 9.3% and 4.5%. These are exploratory gains:
texture-update errors mean equivalent rendering correctness is not established.
The main thread fell from approximately 0.938 to 0.658 core-equivalents while
WorkerThread 0 performed rendering work. Higher total CPU use bought additional
uncapped application throughput; it is not a CPU-efficiency improvement.

The Quest Pro / WiVRn 72 Hz comparison used full tracking, saved presentation
settings, the passive local CS weapon lab and no vest. All 8,605 measured frames
were focused, active and outside menus. The headset reported 2520 × 2772 render
targets. Engine, GPU, resolution, MSAA, presentation, haptics and avatar identities
matched across runs:

| Run | Median | p95 | p99 | Intervals over 20 ms |
|---|---:|---:|---:|---:|
| Baseline 1 | 13.886 ms | 15.612 ms | 16.309 ms | 0.00% |
| Rendering 1, rejected | 13.898 ms | 15.893 ms | 17.056 ms | 0.51% |
| Rendering 2, rejected | 13.819 ms | 16.437 ms | 27.072 ms | 3.34% |
| Baseline 2 | 13.921 ms | 15.624 ms | 16.335 ms | 0.05% |

The last baseline included a single 111.488 ms interval; neither mode eliminates
all stalls. Human firing differed substantially: the baseline runs recorded
130/106 shot effects, versus 1/58 with separate rendering. These are not matched
weapon-workload comparisons. The wearer reported no noticeable difference.
Main-thread use decreased from approximately 0.416 to 0.303 core-equivalents;
whole-game use remained approximately 0.692 versus 0.679. Moving work to another
thread did not raise throughput in this refresh-paced VR workload. These are
application timings, not compositor miss counts or motion-to-photon latency.

Every rendering-thread run reported null/empty texture updates and wrong-thread
`RenderingDevice::finalize` cleanup. Headset runs additionally reported
wrong-thread `free_rid` calls and three leaked rendering-device texture RIDs;
two ObjectDB instances also leaked. Baseline runs exited without these errors.
The [Godot threading documentation](https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html)
also identifies separate rendering as having known bugs and restricts active
scene-tree access from worker threads.

Before retesting, audit texture upload ownership and renderer/OpenXR resource
cleanup on the render thread. Physics threading needs direct-space queries moved
to the permitted physics phase, with cached results for presentation and guarded
native access. The physics toggle moves the server step, not gameplay scripts or
avatar IK wholesale; its potential gain cannot be inferred from the entire
physics-process monitor. Adding more workers to the existing 20-thread pool does
not address these dependencies. Keep tracking and haptic behavior unchanged.

Reproduce with `tools/performance_suite/thread_compare.py`; its README documents
the isolated projects and acceptance rules. Eight Python suite checks passed.
Raw data: `test-results/threading-smoke-run-20260930/`,
`test-results/threading-vr-20260930/`, `test-results/threading-desktop-20260930/`.
Combined results and metadata comparison: `test-results/threading-summary-20260930/report.json`.
All diagnostic clients and the private test server were stopped.


## VRM import batching and native springs — 2026-10-01

Runtime spring integration and collisions already use the engine's C++
`SpringBoneSimulator3D`; the VRM GDScript adapter converts definitions and manages
activation. The retained scripted solver is only used by editor/reference paths.
The benchmark now explicitly enables springs and verifies actual native modifier
steps, preventing a disabled-simulation result from being labeled native.

Three reversed-order runs with eight avatars and 197 imported chains measured
median headless CPU frames of 4.382 ms scripted, 1.733 ms native, and 0.840 ms with
springs disabled. These are whole synthetic scene timings at a fixed 90 Hz
simulation delta, not isolated solver timers or headset/compositor measurements.
The native path is already in gameplay; the 60% difference is not a new gain.
The two solvers use matching imported definitions but are not numerically identical.

Enabled an import-only surface compiler in `deathmatch/avatars/visual_loader.gd`.
It combines compatible same-material surfaces within each mesh, preserving nodes,
skins, vertices and triangles. Facial morph meshes, material-animation targets,
overrides, unknown/transparent shaders, custom vertex streams, prebuilt LODs and
shadow meshes are retained. Work is bounded to 100k vertices / 600k indices per
mesh; larger inputs remain accepted without this pass. Four VRMs went from
65/82/77/102 remote surfaces to 18/17/17/18. Original VRM uploads, license metadata,
VRM 0.x/1.0 acceptance, tracking and first-person mesh identity remain intact.
Use `--unmerged-avatar-surfaces` for an original-import A/B comparison.

An eight-avatar static Vulkan Mobile ABBA test on Intel Arc A770 at 1280×800
measured CPU render time 0.2795 → 0.1735 ms (38% reduction), with wall time
0.977 → 0.609 ms. GPU time was nearly unchanged (0.216 → 0.2075 ms), and the
engine draw-call counter remained 48. Fewer material surfaces primarily reduce
CPU processing/submission here; these numbers are not whole-game FPS gains.
Rendered images differed at 17 pixels, by one 8-bit colour level. Geometry counts,
4/8-influence skinning, morph identity, scaling, native springs and facial-channel
regressions pass, including actual VRM 0.x and 1.0 inputs.

A derived PackedScene cache was also prototyped, but persistence is not enabled
in the live loader. Fresh VRM conversion took roughly 0.4–0.7 s; converted scenes
loaded/configured in 160–190 ms, versus about 0.6–0.8 ms for existing in-memory
reuse. Saving the converted scene adds 320–400 ms once and creates 18–25 MB files.
A production cache should use content + engine/importer/compiler version keys,
atomic bounded writes, and asynchronous ResourceLoader requests checked for
completion before instantiation. It should also avoid evicting active avatars
from the current four-entry decoded-scene cache. GPU upload stalls need a separate
headset capture. Simply removing VRM metadata is not the main optimization target.

Measurements and validation: `test-results/vrm-optimization/summary.json`.
Reproduction tools: `tools/avatar_lod/prepare_scripted_reference.py`,
`benchmark_native_springs.gd`, `profile_import.gd`,
`benchmark_surface_compile.gd`, and `benchmark_runtime_cache.gd`.
Native reference: https://github.com/godotengine/godot/blob/master/scene/3d/spring_bone_simulator_3d.cpp
Background loading: https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html

## Persistent avatar cache and physics-backend comparison — 2026-10-01

Enabled a local derived PackedScene cache in `deathmatch/avatars/runtime_cache.gd`.
Uploads and network transfers still accept validated VRM 0.x / 1.0 files.
The cache key includes the VRM content hash, engine build/precision, importer and
shader source hashes, surface compiler/rest-bounds/loader/filtering revisions,
compiler mode and headless/rendered mode. The cache is under
`user://avatar-runtime-cache/`, capped at 512 MB with a 128 MB entry limit.
A single background writer publishes atomic files; at most two frozen scenes
wait behind it. Writes beyond that bounded queue are opportunistically skipped.
Shutdown discards queued work and joins the write already running. Failed,
truncated or unusable entries fall back to the source VRM. Original VRM files
and license metadata remain unchanged. `--no-avatar-disk-cache` disables disk use.

Cached resources load through `ResourceLoader.load_threaded_request`; join
preparation, avatar switching, previews and the lobby mirror poll for completion
before instantiation. Active avatar instances and join-pinned models are retained
in memory; only unused scenes are reduced to four entries by last use. Mipmap
preparation is stored with the converted model. Mutable resources are isolated
for saving while immutable textures/shaders stay shared, avoiding a full GPU
texture copy. MToon's common shader is initialized on the main thread: a reduced
probe reproduced a RefCounted leak when its include was first loaded on a worker,
and eliminated that leak with main-thread initialization.

Four-avatar desktop Vulkan Mobile tests on the Arc A770 measured:

| Operation | Cold VRM | Persistent cache |
|---|---:|---:|
| Typical preparation wall time (models 2–4) | 572–826 ms | 297–338 ms, background |
| Longest preparation call on main thread (models 2–4) | 572–826 ms | 0.10–0.11 ms |
| Instantiate/configure cached rig (models 2–4) | — | 3.2–3.3 ms |
| Existing in-memory reuse | — | 2.3–2.6 ms |

The first cached avatar took 533 ms in the background and 53 ms to instantiate /
configure, including cold shader/weapon setup. First-time VRM conversion still
blocks; cache construction adds a roughly 34–41 ms snapshot and a one-time
0.84–1.03 s background write in this capture. These are loading measurements,
not headset frame-time or compositor results. Current geometry, morph counts,
bones and scale matched after reload. The 1280×800 front-view comparison changed
13 pixels (maximum channel difference 171, image-wide mean 0.00087); the visible
models and materials match. Vulkan build/load/visual runs exited without errors
or leaked-object warnings. Tests also cover real VRM 1.0 persistence, corrupt and
unusable entry recovery, resource isolation, cancelled previews and queue limits.
Reports, renders and validation logs: `test-results/avatar-cache/`.
Reproduce with `tools/avatar_lod/benchmark_persistent_cache.gd` and
`compare_persistent_cache.gd`; use separate cache directories for cold builds.

The production physics backend resolves `DEFAULT` to **GodotPhysics3D** in this
project. It has not been changed. Compared it against built-in Jolt and the
Rapier release archive tagged v0.36.0 (its loaded binary identifies itself as
Rapier3D v0.35.4). Rapier was installed only in disposable `/tmp` projects.
`tools/physics_compare/run.py` runs reversed-order comparisons and gameplay
regressions; `prepare.py` shares project resources while isolating settings and
extension lists. Release URL and archive SHA-256 are recorded in the report.

The fixed-60-Hz headless fixture uses 16 actual fighter controllers, 128 rays and
16 capsule casts per tick, 64 rigid debris bodies, 193 static boxes and 3,200
terrain triangles. Each of three runs per backend measures 600 ticks after 120
warmup ticks. Values below are medians across the three run medians:

| Time, ms | Godot Physics (current) | Rapier | Jolt |
|---|---:|---:|---:|
| Fighter movement | 0.860 | 1.831 | 0.328 |
| Ray/shape queries | 0.848 | 0.435 | 0.288 |
| Whole headless frame interval | 2.116 | 2.798 | 1.067 |

Rapier improves queries by about 49% but movement takes 2.13× as long; the overall
fixture is 32% slower. Jolt cuts the frame interval by about 50%. This includes
headless loop overhead and is not a whole-game FPS forecast. Godot's coarsely
updated physics monitor is retained in raw reports but excluded from this table.
All three passed the same **207 gameplay checks** covering stairs, Quake movement,
Tribes physics, jetpacks, ski safety and CS penetration. These checks establish
compatibility for these cases, not a demonstrated fidelity improvement.

Rapier documents parallel SIMD, deterministic simulation, physics-state
serialization and extra joint/fluid features. Its documented limits include
missing 3D soft bodies and asymmetric collision semantics. Those capabilities
would need specific integration; switching backends does not make the entire
networked game deterministic. Avatar IK and native `SpringBoneSimulator3D`
remain separate from the rigid-body backend, so they do not acquire a Rapier
speedup. For this game, Jolt is the stronger candidate for a subsequent full-map
and VR comparison; the measured Rapier result does not justify migration.
Primary references: https://github.com/appsinacup/godot-rapier-physics and
https://godot.rapier.rs/docs/progress/ . Local results:
`test-results/rapier-comparison/summary.json`.

## Simplified 0.20/current frametime comparison (2026-10-01)

Compared tag `0.20v` (`ad9ff949`) with the current working tree (HEAD
`80220c9` plus local changes). Both used the verified patched Godot 4.7.2
release runtime, Vulkan Mobile, Intel Arc A770 / i7-12700, 1440×900,
render scale 1, no MSAA, VSync off, uncapped. Two 20-second captures per
version/workload in A/B/B/A order, each after six seconds of warmup.
The baseline native extension was rebuilt from its tagged source; reused
import artifacts had identical original bytes and import descriptors.

The fixture contains eight animated near-LOD avatars from three identical
bundled VRMs, with synthetic full-body tracking. The armed workload adds
eight weapons spanning Doom, Quake, UT99, Tribes and CS. Each version uses
its own models and normal processing. All avatars remained awake and near
LOD; runtime/settings/source fingerprints were verified. Eight final runs
completed without logged engine errors or shutdown warnings.

| Workload / measurement (ms) | 0.20 | Current | Change |
|---|---:|---:|---:|
| Avatars only: main CPU/frame | 2.357 | 1.566 | -33.5% |
| Avatars only: GPU | 0.467 | 0.342 | -26.8% |
| Avatars only: render CPU | 0.477 | 0.202 | -57.7% |
| Avatars only: frame interval | 2.423 | 1.643 | -32.2% |
| Avatars only: p95 frame interval | 3.093 | 2.101 | -32.1% |
| Armed avatars: main CPU/frame | 2.508 | 1.731 | -31.0% |
| Armed avatars: GPU | 0.462 | 0.380 | -17.7% |
| Armed avatars: render CPU | 0.516 | 0.244 | -52.7% |
| Armed avatars: frame interval | 2.572 | 1.805 | -29.8% |
| Armed avatars: p95 frame interval | 3.282 | 2.335 | -28.9% |

CPU/frame is Linux main-thread scheduler runtime divided by frame count,
then averaged over the two runs; it excludes worker CPU and blocked time.
GPU, render CPU and frame interval are averages of the two run medians;
p95 is the average of the two run p95s. Viewport GPU queries are delayed.
Render CPU is part of main-thread work, and CPU/GPU times overlap.

Current is consistently faster in this small, CPU-bound presentation fixture.
The armed scene renders 235,429 versus 197,383 primitives (+19.3%) and
124 versus 58 draw calls; improved frame times therefore coexist with a
higher weapon rendering workload. Avatar-only draw calls are 25 for both;
reported primitives differ (169,201 versus 157,053) despite identical VRM
inputs, so this is a version comparison rather than an identical-draw-stream
isolation of one optimization. Individual fixes need separate ablations.

No game map, AI, server, networking, combat effects, audio, headset or
compositor are measured. This does not establish full-match or VR gains.
Import/loading/shader warmup are excluded and disk caching is disabled,
so the result must not be attributed to persistent-cache loading savings.

The initial avatar-only attempt used a negative weapon ID that created a
fallback model. Those four runs were discarded and replaced with captures
that remove the weapon instances. Armed captures were unaffected. Both
fixture hashes/manifests and discarded captures are retained for audit.

Tools: `tools/version_compare/{prepare.py,fixture.gd,run.py}`. Raw frames,
screenshots, logs, manifests, source fingerprints and final per-run results:
`test-results/version-comparison/summary.json`.

## Jolt default and full-map validation (2026-10-01)

Selected built-in `Jolt Physics` in `project.godot`. The stripped console
runtime now compiles Jolt as well as Godot Physics; its generated project
copies the source project's selected backend. Packaging and verification
actually start a tiny Jolt world and reject the former Godot-only template.
The server startup log now reports the actual direct-space backend class.
Linux, Windows and Android client template binaries contain the Jolt module;
Linux was also exercised through the verified release client. Separate physics
threading stays at its existing disabled default.

The server packaging audit exposed an earlier avatar-cache dependency issue:
`Library` eagerly preloaded client-only GLTF/shader code. It now warms the loader
on construction only when GLTF exists and this is not a dedicated build.
Runtime-cache loading remains lazy. The client cache regression still passes
all 27 checks, and the real stripped server loads without client plugins.

Accepted validation: 21 regression suites, 59,763 checks (most are native
acceleration/parity checks), covering movement/stairs/skiing, prediction,
hitscan, penetration, projectiles, grenades, triggers, vehicles, teleports,
VR interaction geometry and avatar caching. Two ENet tests were repeated
with local socket access after sandbox denials. The cache test was repeated
with caching enabled after the general test runner disabled it. Only the
successful corrected runs are included in `summary.json`.

The actual headless release server passed 41 checks across DM6, Katabatic,
Dust2, Vesper and HiSlop, including collision, spawns, triggers, mode reset
and lobby transition, with zero engine errors or shutdown warnings.
`Builds/JoltValidationServer` is a host-toolchain local validation artifact;
normal portable builds continue to use the documented Ubuntu toolchain.

Six 90-simulation-second full-map runs (16 bots, one run per backend/map)
completed with finite physics state, movement, firing and damage. Median
scoped game-tick CPU time, measured after 30 seconds of warmup:

| Map | Godot Physics | Jolt | Change |
|---|---:|---:|---:|
| qsrc_dm6 | 5.246 ms | 3.745 ms | -28.6% |
| ctf_katabatic | 8.133 ms | 6.032 ms | -25.8% |
| de_dust2_rebuilt | 3.173 ms | 2.267 ms | -28.6% |

These are single-run observations from actual AI/gameplay, not deterministic
replays or whole-frame/VR measurements. Small validation/package processes
ran during parts of the matrix. Bot trajectories and combat diverge between
backends, so these timings support suitability but do not isolate backend
speed alone. The earlier three-run synthetic physics comparison remains
the controlled backend measurement.

Jolt's documented joint-property, ray-face-index and kinematic-contact
differences do not match current gameplay dependencies found in the source
audit. Default collision margins and internal-edge settings were retained;
real movement/query regressions passed without retuning. Reference:
https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html

Artifacts: `test-results/jolt-default/summary.json`, `gameplay.json`,
`console-probe.log`, client template audit, and individual regression logs.
Existing exports and the remote server were not rebuilt/deployed in place.

Live follow-up: the verified Linux release client joined the actual stripped
Jolt server on loopback for an 8v8 Katabatic match (plus one observer). Both
reported `JoltPhysicsDirectSpaceState3D`; teams were verified as 8+8 and bot
movement continued. At 1440×900 and a 60 FPS cap, a 60-second capture after
20 seconds of warmup recorded 3,599 frames: median interval **16.688 ms**,
p95 **18.979 ms**, p99 **19.588 ms**; average client main CPU **7.109 ms/frame**;
median render CPU **0.650 ms** and GPU **0.795 ms** (GPU p95 **1.520 ms**).
This is a live network spectator, not a wearer-controlled VR benchmark or
a matched live Godot/Jolt comparison. Screenshots were suspended during the
measurement window. No engine errors appeared in either active process.
The server emits its existing >16-slot warning because sixteen combatants
plus the observer require seventeen slots. The visible match was stopped at the user’s request on 2026-10-01 at
06:46:27 UTC; both client and server were confirmed stopped.
Logs, frame samples, screenshot, status and process IDs are in
`test-results/jolt-default/live/`.

## Current versus 0.20 after Jolt default (2026-10-01)

The preceding live client and server were stopped before this comparison.
Twenty fresh captures completed: two runs per version for each of five
workloads, ordered **0.20 → current → current → 0.20**. No builds, other game
instances or validation suites ran concurrently. All twenty captures completed
without engine errors, warnings or shutdown leak reports. Source, native binary
and BSP fingerprints were checked again after the matrix.

Baseline is the exact `0.20v` source tag, commit
`ad9ff949b2796ca9da6eae0c2c9c9c2be4d1eb89`, with its native extension rebuilt
from that tag. Current includes the working tree, with its own freshly rebuilt
extension. Both use the same verified Godot 4.7.2 release runtime on the
i7-12700 / Intel Arc A770. Actual backend classes confirm Godot Physics for
0.20 and Jolt for current. These are comparisons of complete source/asset
versions on one runtime, not an isolated measurement of the Jolt change.

Rendering uses eight animated VRM avatars, a fixed camera, 1440×900 Vulkan
Mobile, no VSync or FPS cap, six seconds of warmup and twenty seconds of capture.
Each build uses its own weapon assets. Avatar disk caches are disabled during
setup; loading is outside the capture. CPU is **mean main-thread execution
time per frame**, excluding worker CPU; GPU and frame intervals are medians.
The table averages the two per-run statistics, rather than pooling frames.

| Rendering measurement | 0.20 | Current | Change |
|---|---:|---:|---:|
| Unarmed main CPU | 2.400 ms | 1.574 ms | -34.4% |
| Armed main CPU | 2.504 ms | 1.755 ms | -29.9% |
| Unarmed GPU | 0.460 ms | 0.351 ms | -23.7% |
| Armed GPU | 0.502 ms | 0.397 ms | -20.8% |
| Unarmed frame interval | 2.457 ms | 1.654 ms | -32.7% |
| Armed frame interval | 2.570 ms | 1.827 ms | -28.9% |
| Unarmed frame interval p95 | 3.189 ms | 2.108 ms | -33.9% |
| Armed frame interval p95 | 3.266 ms | 2.389 ms | -26.9% |

The armed fixture's visible draw calls increased from 58 to 124 and primitives
from 197,383 to 235,429 (+19.3%). Overall rendering remains faster in this
workload despite the added weapon detail. This does not establish performance
on a headset, on a lower-end GPU, or in a fully rendered map.

Gameplay uses the same common driver with each version's gameplay code,
sixteen bots, fixed 60 Hz simulation, seed 20261001, thirty simulated seconds
of warmup and sixty measured seconds. The reported CPU interval encloses
`game._physics_process(1.0/60)`, including synchronous movement/query work;
it excludes the engine physics step outside that callback. It is neither
whole-frame time nor total CPU across worker threads. Rendering, networking,
audio output and XR are excluded. All runs retained sixteen bots, finite
positions/velocities, movement, firing and damage.

| 16-bot workload | Median 0.20 → current | Change | p95 0.20 → current |
|---|---:|---:|---:|
| DM6 / TDM / Quake | 4.668 → 3.457 ms | -26.0% | 7.786 → 6.095 ms |
| Katabatic / ST | 6.395 → 5.599 ms | -12.4% | 22.700 → 22.035 ms |
| Dust2 / DE / CS | 2.944 → 2.109 ms | -28.4% | 6.982 → 5.569 ms |

Katabatic remains the principal outlier: p95 improves just 2.9% and still
exceeds a 16.67 ms tick budget inside the gameplay callback alone. Its p99
improves from 38.192 to 28.071 ms. The next performance investigation should
profile expensive ST gameplay ticks; these aggregate captures do not identify
the responsible functions. Two runs per build give a consistency check, not
a confidence interval or coverage of every match state.

The baseline BSP files were verified against the tagged manifest. DM6 and
Dust2 BSP/navigation inputs match current byte-for-byte; Katabatic uses each
version's own map and navigation. AI/combat diverge between versions, especially
on Katabatic, so the gameplay deltas include changed workload and behaviour.
No VR compositor or wearer-controlled session was measured here.

Artifacts: `test-results/version-comparison-jolt-20261001/summary.json`,
`manifest.json`, `current-sources.json`, per-run frame/tick samples, screenshots
and logs. There are 75,215 rendered frames and 43,212 measured gameplay ticks.
Run with `python3 tools/version_compare/benchmark.py --output <fresh-directory>`
after preparing the isolated projects using `tools/version_compare/prepare.py`.
The runner requires the locally retained, hash-verified 0.20 server map assets.

## Katabatic CPU attribution and bot isolation (2026-10-01)

The recurring CPU spikes primarily come from **synchronous bot planning**.
Katabatic's large navigation structures amplify that workload: 59,128 walking
mesh polygons and 8,632 terrain-graph points. Passive map processing, character
movement and Tribes systems are substantially cheaper and comparatively steady.
This addresses the preceding headless gameplay-tick limit; it does not measure
Katabatic's graphics or a VR compositor.

Fourteen accepted runs used the current Jolt release runtime, fixed 60 Hz
simulation, seed 20261001, thirty simulated seconds of warmup and sixty seconds
of measurement. There were two repeats of each condition. The ten-run coarse
matrix used reversed condition order; the four-run detailed/planning-disabled
matrix used ABBA order. All completed without engine errors, warnings or leaks.
Production scripts, BSP and native binary hashes remained unchanged. All
instrumentation and behaviour changes were confined to temporary project copies.

Times below enclose the same game physics callback as the version comparison.
Statistics are the averages of the two per-run statistics, not pooled samples.

| Condition | Median | Mean | p95 | p99 |
|---|---:|---:|---:|---:|
| Empty map, spectator present | 0.133 ms | 0.167 ms | 0.254 ms | 0.384 ms |
| 16 actors, AI/inputs disabled after warmup | 2.842 ms | 2.941 ms | 3.349 ms | 3.990 ms |
| 8 active bots | 2.763 ms | 3.973 ms | 13.956 ms | 19.373 ms |
| 16 active bots, uninstrumented | 5.709 ms | 8.247 ms | 22.275 ms | 28.310 ms |
| 16 bots, planning disabled after warmup | 5.610 ms | 5.665 ms | 6.627 ms | 7.190 ms |

The planning-disabled diagnostic retained perception, steering, combat,
character physics and map systems. It recorded about 9,809 m of aggregate
movement and 342 shots over the full 90 seconds, versus 10,226 m and 360 shots
in the normal run. Its p95 fell **70.3%**. This is a causal diagnostic, not a
viable gameplay configuration: goals stop being refreshed and trajectories
subsequently diverge. Idle-run movement totals include the active warmup.

Coarse instrumentation increased mean callback time by approximately 2.0%;
the detailed timers increased it by approximately 2.3%. In the detailed runs,
the slowest 5% of callbacks averaged 26.610 ms, including:

| Inclusive scope | Mean across all measured ticks | Mean on slowest 5% of ticks |
|---|---:|---:|
| All bot AI | 5.387 ms | 23.308 ms |
| Bot planning | 2.639 ms | 20.087 ms |
| Native walking-path search | 0.837 ms | 8.109 ms |
| Native closest-polygon lookup | 0.244 ms | 1.988 ms |
| Terrain A* search | 0.321 ms | 1.844 ms |
| Route-length/link-cost calculation | 0.324 ms | 2.198 ms |
| Character movement | 0.931 ms | 1.015 ms |
| Tribes systems | 1.088 ms | 1.125 ms |
| Fixed defences, included in Tribes systems | 0.060 ms | 0.061 ms |

These scopes nest; their rows must not be added. Bot AI accounts for about
88% of slow-callback time, and planning alone about 75%. Map runtime callbacks,
which execute outside the measured game callback, averaged 0.445 ms in the
coarse profiles. The complete headless loop is also recorded; it includes
engine work, harness overhead and scheduling, and is not GPU/VR frame time.

`deathmatch/bots.gd::tick()` revisits plans on a roughly 0.8-second cadence.
`plan()` normally evaluates up to six candidate routes, extending to eighteen
when initial candidates fail. The detailed runs recorded 1,108 planning calls
per measured minute and thousands of route evaluations. A single plan reached
32.7 ms. Individual traced native walking searches reached 3.565 ms; batching
multiple queries and terrain/cost evaluations creates the much larger spikes.

The observed stuck-bot issue is real, but unsuccessful navigation searches are
not the sole cause of the CPU spikes. Of 3,311 traced walking-path queries
lasting at least 0.5 ms, 186 failed to reach their requested goal, accounting
for 5.9% of traced query time. A returned navigation path is not proof that a
character can physically execute it. Of 806 plans over 10 ms, 625 occurred with
reported actor speed above 0.5 m/s; expensive planning also affects moving bots.

Reproduced incidents include bot -5 accumulating 20.3 stationary seconds with
a 6.1-second maximum continuous stall, and bot -3 stalling for 8.1 seconds on an
inventory route near `(-429.08, 73.54, -359.70)`. The latter oscillated around
waypoint 9 of 12. In the detailed capture, bot -6 planned for 22.7 ms while
moving at only 0.125 m/s near `(453.38, 94.28, 142.25)`, targeting inventory 4.
These are recorded locations for follow-up capsule/path replay, not a visual
confirmation of every reported bunker/scaffolding/wall failure.

Follow-up priorities are to repair physical route execution around bunker
portals and overlapping floors, then reduce planning bursts: preserve viable
routes, reuse candidate results with appropriate invalidation, and spread
lower-priority candidate evaluation across ticks. Walking-mesh simplification
or partitioning should preserve narrow doors, floor separation and clearance.
The measurements do not support prioritising turret physics for these spikes.
No proposed optimisation or routing fix was applied as part of this diagnosis.

Harness: `tools/katabatic/performance.py`; use `--output <fresh-directory>` for
the coarse matrix and `--detail-only --output <fresh-directory>` for the focused
trace/ablation. Results: `test-results/katabatic-attribution-20261001/analysis.json`
and `test-results/katabatic-attribution-detail-20261001/`. Both retain raw tick
data, bot stall records, validation, source hashes, and exact instrumentation
snapshots. The initial short smoke capture is excluded from these results.


## Standalone bot worker implementation and CPU comparison (2026-10-01)

The optional bot service now runs perception, team tactics, navigation, aiming
and steering in a separate console-only process. The dedicated server retains
all authoritative simulation. Setup and operational limits are in
[SERVER.md](SERVER.md#external-bot-service). Neither the old scripted transport
probe nor the earlier AI-off ablation is used as evidence of this implementation.

A sequential 16-bot Katabatic comparison used the console release runtime, Jolt,
30 seconds of warmup and a fixed 30-second measurement window. The fixed window
excludes startup, worker disconnect and bot removal. Local AI uses the existing
60 Hz callback; external AI runs at up to 30 Hz with up to 20 Hz world snapshots.
Matches use normal random decisions, not a deterministic replay. These are
callback wall times, not total CPU utilization, GPU time or VR compositor time.

| Dedicated-server gameplay callback | Local AI | External worker | Reduction |
|---|---:|---:|---:|
| Median | 5.460 ms | 3.352 ms | 38.6% |
| Mean | 8.021 ms | 3.409 ms | 57.5% |
| p95 | 24.138 ms | 4.080 ms | 83.1% |
| p99 | 44.553 ms | 4.889 ms | 89.0% |

The bot transport/serialization callback runs outside that gameplay callback.
Its mean cost, apportioned across physics steps, was **0.724 ms** with the worker
and 0.005 ms without it. Gameplay plus service averaged **8.026 → 4.133 ms**
(48.5% lower); engine physics and other callbacks are still outside that sum.
The separate worker averaged 12.84 ms per AI pass over its entire run, including
startup, and its cold maximum was 706 ms. This moves expensive work to another
process/core; it does not make total machine CPU or memory lower. Short random
runs vary, so treat these as measured examples rather than a fixed speedup.

Every sampled worker status held all 16 leases, with no unexpected reconnect.
The final pre-disconnect sample had 28,870 accepted bot inputs, 44 validated
mode-action requests and 30 rejected stale inputs. The connection is independent
of gameplay clients. It uses signed, bounded frames, receipt acknowledgements
separate from AI completion, and expiring input leases. A stress iteration caught
and fixed a backpressure deadlock after slow planning; earlier failed iterations
are retained but excluded from the comparison.

Validation also covered normal-client admission to a full bot match, bot eviction
and refill, worker suspension, map rotation/restart, dedicated-server restart with
a surviving worker, graceful worker exit and population-policy restoration.
Separate-process smoke runs passed DM, ST, TF, TB, DE/Dust2 and AS/Frigate. The
Hislop AS run and the existing local AS regression both report the same four
navigation edge-merge errors; this map issue is not a transport regression.
Existing defusal behavior (27 checks), teamplay and Assault regressions passed.
New contract tests cover assignment, human-ID rejection, sequence/map/life/age
checks, finite inputs, swimming/hammer-jump intent, signatures, replay, tampering
and oversized frames. The worker does not repair the previously observed blocked
Katabatic routes, and no WAN/remote-host or VR visual-equivalence test was run.

Results: `test-results/bot-service-benchmark/summary.json`, with raw runs in
`bot-service-benchmark-local/` and `bot-service-benchmark-worker/`. The comparison
folder retains the instrumented PCK, instrumentation sources and build receipt.
Reproduce with `tools/bot_service/profile_build.py`, two sequential
`tools/bot_service/integration.py` runs (`--local` for the baseline, `--seconds 66`,
`--mode st --map ctf_katabatic --bots 16`) and `tools/bot_service/analyze.py`.
