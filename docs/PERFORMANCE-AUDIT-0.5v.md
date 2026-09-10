# Performance and lifecycle audit — 0.5v

Tested on 2026-09-10 after a clean fast-forward pull from `668da3f` (0.3v) to
`cec9edd` (0.5v). Production code was not changed. Reproducible diagnostic scripts
and this report are local, uncommitted additions.

**Findings:** a substantial server CPU regression under sustained projectile
load; a confirmed, pre-existing Steam Audio shutdown leak; no accumulating
orphan nodes, GPU allocations or surviving test processes in the exercised
lifecycles. Twenty unrelated zombie processes were present before and after the
work. The desktop rendering comparison did not show a material regression.

Machine: Intel Core i7-12700, Intel Arc A770, Linux, Godot 4.7.2 Fedora
`ed1daf0bf`. Source projects were run directly. The 0.3v reference was unpacked
from its Git commit into `/tmp/fpsloppa-baseline-03`; no old exported binary was
mistaken for the newly pulled code.

## 1. Server projectile processing exceeds the 60 Hz budget

The same synthetic fixture ran in both versions: 8 or 16 stationary players
continuously firing plasma outward, producing long-lived projectiles. There
were 120 warmup ticks and 600 measured ticks. The 32-player case was run only on
0.5v, where that capacity is explicitly experimental. This deliberately stressful
fixture measures update cost; it is not a forecast of an ordinary match.

| Players | 0.3v median / p95 tick, ms | 0.5v median / p95 tick, ms | Peak live projectiles |
|---|---:|---:|---:|
| 8 | 3.439 / 3.715 | 4.930 / 5.419 | 281 |
| 16 | 11.000 / 11.541 | 16.246 / 17.094 | 523 |
| 32 | Not tested | 64.299 / 66.797 | 1,085 |

At 16 players the p95 cost increased about 48%, exceeding the 16.67 ms budget
for 60 physics ticks per second before accounting for other work. The 32-player
stress case is far outside that budget. Snapshot p95 cost remained comparatively
small: 0.622 ms at 16 and 1.341 ms at 32 in 0.5v.

The main measured cost is `arena.gd::_update_projectiles`, which calls `_trace`
for each projectile. `_trace` calls `_rewound_positions(0)`, which constructs a
nested `_history_positions()` dictionary for every player. `LagCompensation.positions`
then immediately returns an empty dictionary because the rewind is zero. This
repeats for every projectile and contributes avoidable allocation and iteration.

A clean paired run with a test-only subclass measured:

| 16-player diagnostic | Median tick | p95 tick | Mean projectile-update time per tick, including warmup |
|---|---:|---:|---:|
| Stock behavior | 16.545 ms | 17.434 ms | 13.181 ms |
| Return early when rewind is zero | 12.219 ms | 12.898 ms | 9.608 ms |

That single diagnostic change reduced p95 tick time by about 26%. It is **not
applied to production code**. The first candidate fix is an early return in
`_rewound_positions` before constructing history when `rewind <= 0`. Keep the
positive-rewind interpolation and hit-registration checks intact. Further
profiling should examine repeated sphere/query creation in `HitDetection.world_fraction`
and the per-projectile scan of every player; these are additional candidates,
not separately proven causes by this audit.

## 2. Steam Audio has a real shutdown leak, unchanged since 0.3v

Two minimal projects ran the same empty SceneTree script:

- Plain Godot: no ObjectDB leak warning.
- Godot with only the bundled Steam Audio extension: one unnamed leaked instance.

A rendered game or the native audio test also reports a retained `Thread` after
initializing Steam Audio. The available matching native source creates a
`SteamAudioServer` singleton in `register_types.cpp`; its destruction is commented
out in `uninit_ext`. This explains why simply loading the extension reproduces
an unnamed shutdown instance even without an arena, avatars or OpenXR session.
The addon files are unchanged between 0.3v and 0.5v.

This is a teardown defect, not evidence of memory continuously increasing during
play. In the tested loops it did not spawn surviving OS processes or accumulate
additional orphan nodes per session. Fixing it requires correct worker shutdown,
joining and native effect release before deleting the singleton; blindly enabling
the commented deletion is unsuitable given the upstream shutdown-crash note.
No native allocation-stack sanitizer was run, so this audit does not quantify all
retained native allocations or certify absence of every leak.

## 3. Repeated lifecycle results

Every session used nine actor instances as a diagnostic workload. Rows below
show settled samples from cycle 8 onward, after initial asset/shader warmup.
Static-memory measurements include the test's small growing sample log. RSS can
retain allocator/driver high-water allocations and is not by itself proof of a leak.

| Test | Cycles | Result |
|---|---:|---|
| Headless host/disconnect | 24 | 2,414 objects, 345 nodes, 387 resources after every disconnect; zero orphan nodes |
| Full rendered arena create/destroy | 16 | Returns to 3 autoload nodes, 1,876 objects, 141 resources; zero orphan nodes; GPU allocation settles at 99.75 MiB |
| Three map loads per session | 16 / 48 loads | Constant 5,164 objects and 1,206 nodes after disconnect; GPU allocation about 523.55 MiB; no orphan nodes |
| Record, open, seek and stop demos | 16 | 1,920 recorded snapshots and 192 seeks; stable 5,138 objects / 1,206 nodes; no orphan nodes or accumulating file descriptors |
| Sound/projectile creation and teardown | 16 | 1,280 native sound requests and projectile lifecycles; sound pool empties on every disconnect; no orphan nodes |

The rendered arena process reached roughly 1.23 GiB RSS during warmup. Later
settled samples were around 1.18 GiB rather than growing each cycle. Its retained
GPU allocation was constant. Retaining loaded assets while the menu stays open
is distinct from retaining another copy on every load.

The native audio regression also created/destroyed 960 sources while mixing,
including immediate/deferred deletion and generated voice playback, without a
crash. Small transient object differences during audio cleanup settled rather
than increasing once per iteration. These short repeated-cycle tests are not a
multi-hour soak or standalone thermal test.

## 4. Process cleanup and existing zombies

The audit took host `/proc` inventories before and after testing and supervised
all launched suites in separate process groups. A child-subreaper monitor sampled
RSS, CPU ticks, thread and file-descriptor counts and recorded any children left
behind. Every completed suite left **zero surviving child processes** and required
no forced cleanup by the outer audit monitor.

There were **20 pre-existing zombie processes**, all still present at the end:
SlimeVR, WiVRn dashboard and VRCX children of PID 3726, whose process name is
`oadesktopentry-`. Their reported RSS was zero. They predate this pull/test run,
are not Godot processes, and were not caused or modified by the audit. Their
parent needs to reap them; sending a kill signal directly to a zombie does not
reap it. No desktop launcher, VR service or pre-existing user process was stopped.

The initial avatar-lighting test was mistakenly included in the headless batch;
it waits for a rendered frame and reached its 90-second timeout. The subprocess
runner killed and reaped it, with no orphan left behind. The graphical rerun
passed all lighting checks. Two early profiling probes also exposed a diagnostic
script-replacement cleanup issue; that fixture was corrected, and the final paired
runs retained only the pre-existing native extension warning.

## 5. Rendering and functional checks

Four sequential single-view desktop benchmark runs used the unchanged existing
benchmark, 8 avatars, 1440 × 900, Mobile renderer and VSync disabled:

| Version | Median frame, two runs | p95 frame, two runs | Median draw calls |
|---|---:|---:|---:|
| 0.3v | 6.037 / 5.877 ms | 7.373 / 6.642 ms | 43 |
| 0.5v | 5.992 / 6.215 ms | 7.082 / 7.392 ms | 43 |

The ranges largely overlap; this small sample does not establish a material
rendering regression. It is not a headset/compositor or Android performance claim.

All 20 final functional checks passed, covering session features, TF/special modes,
lag compensation, hit detection, projectile ordering, map/avatar transfer guards,
baked/avatar lighting, feedback, rocket jumps, combat, menus, tracking, OSC bursts,
server logging and native audio. Separate real ENet suites passed for voice,
lobby late-join/voting, TF/custom-avatar transfer and persistent map uploads.
The 100 ms RTT / ±15 ms jitter / 2% loss proxy run registered 29/29 accepted shots
and all participants exited cleanly. Accepted-shot counts can vary because impaired
links may discard a fire command before the server accepts it.

## Evidence and reproduction

[Machine-readable report](validation/performance-audit-0.5v.json). Detailed logs,
per-cycle counts, process samples and comparison JSON are in
`test-results/performance-audit/` (intentionally excluded from Git).

From the project root, with Godot 4.7.2 available:

```sh
python3 tools/audit_processes.py before
python3 tools/audit_processes.py --timeout 240 sessions -- godot --headless --xr-mode off --path . --script res://deathmatch/tests/lifecycle_soak.gd -- --audit-kind sessions --audit-cycles 24
python3 tools/audit_processes.py --timeout 240 arenas -- godot --xr-mode off --path . --script res://deathmatch/tests/lifecycle_soak.gd -- --audit-kind arenas --audit-cycles 16
# Repeat with --audit-kind maps, demos or combat for those rendered lifecycles.
python3 tools/audit_processes.py --timeout 90 cpu16 -- godot --headless --xr-mode off --path . --script res://deathmatch/tests/server_load_audit.gd -- 16
python3 tools/audit_processes.py --timeout 90 profile16 -- godot --headless --xr-mode off --path . --script res://deathmatch/tests/server_load_audit.gd -- 16 --profile
python3 tools/audit_processes.py --timeout 90 control16 -- godot --headless --xr-mode off --path . --script res://deathmatch/tests/server_load_audit.gd -- 16 --profile --skip-zero-rewind
python3 tools/audit_processes.py after
```

Use an isolated `XDG_DATA_HOME` when reproducing to avoid changing personal
settings. Run graphical comparisons sequentially. Base maps and VRMs must be
installed as in this source checkout. Audit JSON reports measurements; the CPU
stress script does not mark an over-budget tick as a functional assertion failure.
