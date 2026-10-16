# Selection-only headset comparison — 15 October 2026

**The populated drawing control passed. Grass-selection computation is a major CPU bottleneck in this scene.** Both completed takes retained **1,539 submitted instances** throughout, with identical seed/end GPU-buffer hashes in A and B. Audio was disabled, tree selection stayed live, and GPU buffer submission was held in both conditions.

Quest Pro / WiVRn, runtime-confirmed 90 Hz, Arc A770, render scale 1.0, 60 Hz local simulation. **10,262 frames / 120.01 seconds** were collected. The test client and isolated local server were stopped afterward; the remote experiment and WiVRn were left unchanged.

| Phase | Selection ON FPS | Selection OFF FPS | ON frame p95 | OFF frame p95 |
| --- | ---: | ---: | ---: | ---: |
| Whole take | 81.24 | 89.77 | 19.44 ms | 13.03 ms |
| Still / head turns | 89.74 | 89.81 | 12.99 ms | 12.93 ms |
| Walking prompt | 83.64 | 89.78 | 18.34 ms | 13.07 ms |
| Running | **70.36** | **89.73** | **24.68 ms** | **13.11 ms** |

Running speeds were closely matched: **7.12 versus 7.17 m/s**. Disabling selection improved running FPS by approximately **27.5%** while the grass geometry remained unchanged. Both first phases were effectively stationary (0.00 / 0.035 m/s); the walking phases differed more (1.49 / 2.25 m/s), so the running comparison is stronger.

Selection rebuilt on **563 frames**, averaging **7.40 ms per rebuild**, p95 **8.56 ms**, maximum **10.20 ms**. Its whole-take mean was only 0.85 ms/frame because many frames did no rebuild; that average hides the deadline-breaking bursts. The running phase's selection p95 across all frames was 8.32 ms. These are direct synchronous call wall timings, not measurements of thread execution time.

Tree/bush selection averaged **2.185 / 2.191 ms** across the two takes. Neither emitted grass audio. Terrain jobs were active on 97 frames in A and none in B; only 40 of A's 1,408 running frames had jobs outstanding. Excluding those frames still leaves a 14.25 ms mean interval and 24.68 ms p95, so the observed sustained drop is not confined to recorded streaming activity. This does not exclude every main-thread streaming commit.

Running GPU-render p95 was 5.33 / 4.04 ms. Although grass buffers were identical, head direction and other visible scenery were not a recorded camera replay. GPU queries also lag and omit the complete runtime pipeline. This is one A/B pair without reversed-order repetition; exact speedup should be treated as scene-specific. Even B's 13.11 ms frame p95 exceeds the strict 11.11 ms target, despite averaging nearly 90 FPS.

The measurement excludes GPU-buffer uploads in both modes. It demonstrates that selection computation alone can cause the running performance loss; it does not measure the additional cost of normal submissions. The immediate optimization target is the synchronous candidate scan, bucket construction, far selection and CPU transform-buffer generation. Bound/incrementally reuse that work and port the hot loop to native C++ before prioritizing grass-audio changes.

[Phase statistics](summary.json) · [Drawing and timing checks](drawing-and-timing-checks.json) · [Raw evidence hashes](evidence.json) · [Complete raw logs/captures](/home/blux/.cache/cq-grass-selection-final-20261015T203041Z.tar.gz)

Compressed per-frame CSVs and original take metadata are beside this report. No client script errors or unsupported hand-source errors were recorded. The runtime journal contains desktop PipeWire capture pause/resume messages; these are not evidence of a headset session/network failure.
