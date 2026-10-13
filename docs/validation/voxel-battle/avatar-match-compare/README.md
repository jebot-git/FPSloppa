# Two-minute 16v16 VRM / MDL match comparison

Two sequential 120-second wall-clock measurements completed on Godot 4.7.2 Vulkan Mobile, Intel Arc A770. Both use 16v16 TDM bots, CS weapons (four AWP specialists per team), jetpacks, the same terrain/map/navigation and seed 1977. The six accepted avatar sources are sample_d_darkness, sample_e/f/g, hairsample_female/male. Each bot ID keeps the same model, source hash and team in both runs; `checks.json` verifies equality.

Both runs use the same uncapped desktop simulated stereo path: two 2160×2376 shared-world viewports, 64 mm eye separation, fixed overview eye cameras based at (0, 260, 170) looking at (0, 15, 0), 90° FOV. The overview makes avatars distant; this is a whole-match workload under production culling/LOD rather than a close crowd benchmark. Native OpenXR pacing and foveation are absent in both. Renderer CPU and GPU timing sum the two eye viewport measurements. Wall-frame time includes gameplay, physics, avatar updates, scenery and desktop presentation.

VRM has surface/index preparation enabled, all 32 spring systems inactive, and normal distance animation and mesh LOD. MDL uses the corresponding low-poly opaque unshaded skins and GPU vertex animation through a fighter-compatible experimental adapter. Locomotion, attack, pain and death clips respond to fighter state; crouch height is approximated. Both have CS weapon meshes and ordinary jetpack visuals. Avatar representation does not alter collision or combat rules. Differences include geometry, materials and animation fidelity, not just file format.

Avatar preparation, navigation bake, terrain streaming and pending avatar mesh LOD generation are outside the measured interval. Score limit is raised to avoid early termination. Measurements stop at the wall-clock deadline; when overloaded, less than 120 seconds of game time advances. No screenshot readback occurs during measurement.

## Results

Values are median / p95:

| Measurement | VRM | MDL (corrected locked observer) |
| --- | ---: | ---: |
| Frame | 113.14 / 139.82 ms | 34.60 / 129.39 ms |
| Stereo GPU | 2.77 / 4.15 ms | 1.00 / 3.24 ms |
| Renderer CPU | 1.80 / 2.21 ms | 0.64 / 0.91 ms |
| Authoritative physics per tick | 11.56 / 34.77 ms | 11.14 / 34.04 ms |
| Bot AI per tick | 6.70 / 29.83 ms | 6.18 / 29.46 ms |

| Whole run | VRM | MDL |
| --- | ---: | ---: |
| Wall duration | 120.004 s | 120.027 s |
| Simulated match duration | 106.88 s | 113.28 s |
| Rendered frame samples | 1,018 | 2,381 |
| Average rendered frames/s over measurement | 8.48 | 19.84 |
| Final Red / Blue score | 47 / 47 | 45 / 49 |
| Median draw calls | 643 | 515 |
| Median primitives | 685,822 | 287,594 |

MDL lowered median frame time by 69.4%, stereo GPU time by 63.9%, and renderer CPU time by 64.2%. The frame p95 remains high. MDL's simulation advanced 6.0% more game time. Expensive simulation ticks and physics catchup remain a practical constraint. Per-tick timing cannot be subtracted directly from per-render-frame timing: several physics ticks can run in one rendered frame.

This is one accepted live match per representation. Combat paths and outcomes diverged, despite matching seed and source avatars. It supports lower rendering cost for these MDL assets in this scenario, not a precise format-only causal speedup or a claim of playable VR frame rates. Repeated trials or an identical trajectory replay would strengthen the comparison.

## Validation and correction

All measurement logs were free of engine errors. The VRM run had a cleanup argument-type error after its report and captures had already been saved; the process was stopped. The cleanup call was corrected for MDL without changing the measured workload.

An initial MDL trial recorded 77.63 ms median frame time and 137.60 ms p95. Its stereo eye cameras stayed fixed, but keyboard input moved the observer camera about 4.9 m, potentially changing LOD/streaming. That trial is retained in `mdl-first-observer-moved/` and excluded from the primary comparison. The MDL match was rerun for a full 120 seconds with observer input disabled and transform preserved; the table above uses that corrected run. The difference between live MDL trials also illustrates match-to-match variability, and must not be attributed solely to the camera correction. The corrected observer camera and FOV match the VRM receipt exactly.

Each run's exact harness copy and source fingerprints are included. CSV sample counts and medians were independently recomputed; both eye captures are nonempty and distinct.

[VRM report](vrm/result.json) · [MDL report](mdl/result.json) · [Checks](checks.json)

[VRM samples](vrm/frames.csv) · [MDL samples](mdl/frames.csv)

[VRM stereo capture](vrm/preview.png) · [MDL stereo capture](mdl/preview.png)

Reproduction commands are in `tools/vrm_to_mdl/README.md`. Run sequentially, with no other benchmark scene running. The current harness locks observer controls for either representation.
