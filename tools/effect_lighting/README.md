# Effect-lighting feasibility probe

This diagnostic compares 0, 2, 4 and 8 sustained, unshadowed omni lights in a
controlled room with the game's baked-map shader and eight actual VRM instances
(three shipped models). It also repeats the comparison with four background
lights. It does not install a gameplay effect-light manager or change saved
materials/settings.

```sh
python3 tools/effect_lighting/run.py
python3 tools/effect_lighting/report.py
```

The first command opens a desktop Vulkan Mobile window and needs display/GPU
access. It uses the installed `godot`, disables XR and audio, and bounds the child
process to 240 seconds. It writes `test-results/effect-lighting/`; preserve that
directory before a new run if historical evidence is needed. The second command
checks the records and writes `docs/validation/effect-lighting-study.json`.

The test uses 1280×800, 4× MSAA, VSync off, static avatar poses, and no particles,
combat or shadows. Every variant warms for 90 frames and measures 180 frames.
Three blocks alternate ascending/descending light counts, with baseline samples
at each end: 5,400 measured frames in total. GPU timings come from Godot viewport
render-time measurements, not FPS reciprocals. Raw samples remain in the result.

The eight-effect/four-background-light case intentionally exceeds Mobile's eight
omni lights per mesh. It illustrates a budget hazard, not a supported quality tier
or a valid measurement of twelve simultaneously contributing lights.

See [the study](../../docs/EFFECT-LIGHTING-STUDY.md) for integration points,
alternatives, candidate budgets and the remaining on-device acceptance work.
