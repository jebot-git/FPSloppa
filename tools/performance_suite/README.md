# Weapon-lab performance suite

Three opt-in stages follow the September 30 headset test. All output is local.
The desktop fixture is a repeatable rendering workload, not a headset benchmark
or a weapon balance test. Live runs use the normal client and saved tracking and
haptics settings. Nothing here changes vibration intensity or tracking behavior.

## 1. Individual frame timing and event correlation

```sh
python3 tools/performance_suite/run.py timing --seconds 60 --warmup 10 --repeats 2
# With a headset streaming, join an already-running test server:
python3 tools/performance_suite/run.py timing --live --connect SERVER --port 27777 --seconds 120 --refresh-hz 72
```

This records raw application frame intervals, process/physics monitors, viewport
render CPU/GPU queries, draw calls, weapon/ruleset, menu/focus flags and timestamped
shot/hit presentation events. It computes the median across individual frames,
p95/p99, and application intervals exceeding the selected refresh budget.
`shot_fx` and `hit_fx` are client presentation events, **not authoritative server
fire/damage records**. Retain the server event log separately for damage analysis.

`frames.jsonl`, `events.jsonl`, `poses.jsonl`, `metadata.json`, `clock.json`, engine
logs and `report.json` live under a new timestamped `test-results/performance-suite/`
directory. `--output PATH` selects a new directory; existing captures are refused.
Source fingerprints, engine/GPU, settings, avatar identities and actual XR refresh
rate are recorded. Pass the actual headset rate with `--refresh-hz`; a mismatched
reported rate invalidates the intended budget test. Warmup and final report writes
are excluded. Pose-buffer flushes during measurement remain included.

Godot viewport GPU measurements are delayed, latest-available queries. They do
not establish exact GPU-to-shot frame correspondence. Process/physics monitors
are engine monitor readings, not exclusive scopes. CPU/GPU work overlaps: never
add these numbers together. Unsupported render timing is reported as unavailable.

### WiVRn compositor/encoder capture

A Godot application cannot supply compositor missed-frame, reprojection or encoder
latency measurements. WiVRn must be built with `WIVRN_USE_PERFETTO=ON`; the installed
binary name alone does not prove support. See the installed WiVRn documentation
at `/usr/share/doc/wivrn/docs/profiling.md` (or that file in WiVRn sources).

Start the tracing-capable runtime with `WIVRN_TRACING=system` before connecting the
headset, then provide its capture wrapper:

```sh
python3 tools/performance_suite/run.py doctor --wivrn-capture /path/to/WiVRn/tools/perfetto/wivrn_capture.py
python3 tools/performance_suite/run.py timing --live --connect SERVER --seconds 120 --wivrn-capture /path/to/WiVRn/tools/perfetto/wivrn_capture.py
```

The runner starts capture when the client reports readiness, saves
`compositor.pftrace` alongside each run, and rejects missing/failed captures. The
WiVRn wrapper may download tracebox on first use. It uses WiVRn-only tracing,
without sudo/ftrace. Runtime launch/restart is deliberately manual so an existing
headset session is not interrupted by preparing this suite.

Inspect the trace with WiVRn's `pftrace_summary.py` or Perfetto. For Monado's own
compositor spans use a WiVRn build with `WIVRN_TRACE_MONADO=ON` and its documented
`--full` capture workflow; WiVRn-only slices do not establish Monado GPU cost.
The suite does not infer compositor frame misses from application intervals.
`compositor_measured: false` in the JSON analysis means **not analyzed by this
analyzer**, even when a raw trace was captured. `clock.json` brackets host
monotonic/UTC samples; Godot records ticks/UTC anchors. Cross-process correlation
through UTC is approximate and subject to clock adjustments, not an exact
GPU timestamp calibration. Use runtime frame IDs within the compositor trace.

## 2. Capture overhead: off / immediate / buffered

```sh
python3 tools/performance_suite/run.py overhead --seconds 60 --warmup 10 --repeats 4
# Same matrix using the real headset and normal local tracking:
python3 tools/performance_suite/run.py overhead --live --connect SERVER --seconds 120 --repeats 4
```

Each alternating-order block runs:

| Mode | Additional pose capture |
|---|---|
| none | No pose capture; common frame/event telemetry stays active |
| immediate | Up to 30 Hz; enumerate tracker descriptions and presentation metadata each sample, serialize, flush, rewrite status |
| buffered | Same dynamic pose sampler; cache inventory for one second, omit repeated static metadata, flush batches once per second |

Order reverses each second block: A/B/C, C/B/A. This is a controlled reproduction
of the previous logger's expensive operations, not a byte-identical replay of its
222 MB payload. Reports retain per-run p95 and over-budget rates to expose run
variation; the median of run medians is labeled separately. Capture time includes
sampling, serialization, writing and measured flush work. Common frame telemetry
has overhead in every run. No mode is an entirely uninstrumented game.

Keep headset rate, resolution/foveation, map, avatars, weapon sequence, Bluetooth
state and thermal conditions fixed. Follow the same 5-second-per-weapon routine
in live tests, beginning after warmup. Avoid menus during measured windows. Inspect
menu/inactive/unfocused counts and weapon sample exposure before interpreting
results. Live human movement is not deterministic. Select at least four blocks
for an actual comparison; short smoke tests only validate the machinery.

## 3. Targeted effects, avatar/IK and rendering profiles

```sh
python3 tools/performance_suite/run.py profile --seconds 60 --warmup 10 --repeats 4
# Real-headset scopes, without changing the wearer's avatar or tracking:
python3 tools/performance_suite/run.py profile --live --connect SERVER --seconds 120
```

Desktop variants run in forward/reverse order:

| Variant | Question |
|---|---|
| full | Combined effects, VRM animation/IK and rendering cost |
| no-effects | Difference when scripted weapon/impact effects are omitted |
| frozen | Difference when avatar processing/modifiers stop but geometry remains |
| hidden | Difference when avatar geometry and processing are both absent |

Eight avatars use the three bundled VRoid models, seven visible, above the current
map. Synthetic full-body poses animate continuously; weapons cycle every five
seconds and emit presentation effects at the weapon's cycle interval (capped at
10 Hz). Default CS covers all 12 slots in 60 seconds. `--rules doom|quake|ut99`
selects other arsenals. This fixture exercises presentation, not firing accuracy,
projectile trajectories or damage balance. Desktop physics/gameplay and voice are
inactive; audio presentation still follows current settings.

Disposable copies instrument shot presentation, combat/weapon effect processing
and tracking sampling. Existing opt-in avatar metrics provide rig, pose/IK, eye
and mouth scopes. Scopes are inclusive microseconds/counts; nested scopes must not
be added. Frozen/hidden differences suggest animation versus geometry costs but
**do not isolate engine skinning GPU kernels**. Use a GPU profiler after these
comparisons identify a GPU-bound case. Live profile runs only enable scopes; they
never freeze or hide the local avatar. Native spring simulation is not measured
as a standalone script scope.

Shot scopes also cover impact/streak/pooled-shape activation and audio selection
and playback. Scope totals are accumulated per affected frame; nested calls must
not be added. To compare effect allocation independently of human firing, use
the rendered A/B/B/A fixture with a saved reference script:

```sh
godot --path . --xr-mode off --script res://tools/performance_suite/effects.gd -- test-results/effects.json res://test-results/reference_visuals.gd
```

The suite uses an editor-capable Godot executable for `--script`. The production
client template rejects project-path overrides and does not run script drivers;
normal `run-vr.sh` play uses the project's verified patched release runtime.
For diagnostics of that runtime, use an adjacent disposable project with the
diagnostic driver as its main scene. Record which engine was used when comparing
results. See `PERFORMANCE.md` for the September 30 fixes and validation.

Do not change LOD/IK cadence or the local body representation based on a desktop
result alone. First establish repeatable p95/p99 improvements in the relevant
headset scene, then check physical motion/weapon alignment and perceived haptics.

## Validation and controls

```sh
python3 -m unittest discover -s tools/performance_suite -v
python3 tools/performance_suite/run.py timing --prepare-only
python3 tools/performance_suite/run.py analyze --output test-results/performance-suite/RUN
```

The runner bounds execution and stops only its child processes on failure. It
rejects script/engine errors, incomplete/truncated traces, nonmonotonic frame
samples, and comparisons with incompatible source/hardware/settings. Results are
not a certification of native headset FPS. Native Bluetooth fixes need a physical
connect → stop → quit → relaunch → reconnect check; software tests use a mock
link or an unavailable D-Bus address and never actuate the vest.

## Engine threading comparison

```sh
python3 tools/performance_suite/thread_compare.py --variants baseline render --seconds 30 --warmup 10 --repeats 2
python3 tools/performance_suite/thread_compare.py --live --connect SERVER --variants baseline render --seconds 30 --warmup 10 --repeats 2
```

This uses the verified patched Linux release runtime for every case. Disposable
projects select baseline, separate rendering, separate 3D physics, or both; the
normal project settings are untouched. Omitting `--variants` tests all four.
Run order reverses each block. The desktop fixture retains eight avatars, seven
visible, and the existing deterministic weapon/pose sequence. Live captures use
the passive CS weapon lab, normal tracking and human input, with the vest disabled
at runtime. They do not save preferences. The connected test server must support
the `/lab` commands. Supply the same weapon sequence in each live run.

Each run records actual startup settings, source/runtime hashes, frame scopes,
focus, and 10 Hz Linux per-thread scheduler accounting. CPU figures cover the
entire measurement window; focused frame percentiles exclude menus, inactivity
and unfocused frames. One core-equivalent means one logical CPU fully occupied.
Core migration is not simultaneous execution. Render/GPU monitor queries are
delayed, and these captures do not measure compositor reprojection or latency.

`comparison.json` keeps per-run percentiles, CPU use and acceptance status.
`thread-report.json` contains detailed thread use and metadata. A completed
capture with engine errors remains available for diagnosis but is explicitly
rejected. Crashed/timed-out variants are skipped in later blocks. No result
automatically enables threading in the game.

On the September 30 build, separate physics and the combined mode crashed after
an inaccessible physics-space query. Separate rendering completed but produced
texture-update errors and wrong-thread renderer cleanup errors. Its timing
results are exploratory, not acceptance results; see `PERFORMANCE.md`.
