# Simplified 0.20 versus current frame timing

`prepare.py` archives tag `0.20v` into `/tmp/fps-version-020`, builds its native
extension, and prepares `/tmp/fps-version-current` using the working tree. It
refuses existing project folders. The baseline reuses derived import files only
when the original asset bytes and import descriptors match. Both projects run
the same verified patched release template, with the same injected fixture.
Production settings and source history are unchanged.

Run `python3 tools/version_compare/prepare.py`, then
`python3 tools/version_compare/run.py` from a desktop session with GPU access.
The runner writes to `test-results/version-comparison`; archive previous results
before rerunning. Preparation needs the local Godot bindings and imported assets.

Each workload runs 0.20/current/current/0.20 sequentially, with six seconds of
warmup followed by twenty seconds of capture. Both use eight animated avatars,
three bundled VRMs, full-body synthetic tracking, near LOD, native springs/IK,
1440x900 Vulkan Mobile, no MSAA, VSync off and no frame cap. The second workload
adds eight weapons spanning the five loadouts. Each version supplies its own
weapon models and normal animation code. Screenshot capture, startup, VRM
conversion and shader warmup are outside the measured window. Disk caching is
disabled in setup; this is a steady-state comparison, not a loading benchmark.

CPU is main-thread Linux scheduler runtime divided by measured frames. It
excludes worker CPU time and time blocked/sleeping. Viewport render CPU is
reported separately and is part of the main-thread work, not additive. GPU
measurements are delayed viewport timer queries. Frame interval measures the
application loop, including waits. CPU and GPU execute concurrently: do not add
their times. Per-version summaries average the two run means (main CPU) or run
medians (GPU/render CPU/frame interval). Raw frames and per-run p95/p99 are kept.

This small render/animation scene excludes the game map, server simulation,
AI, networking, combat effects, audio, VR hardware and compositor. It cannot
establish full-match or headset FPS. The unarmed/armed comparison is descriptive;
a separate ablation would be needed to attribute changes to individual fixes.
