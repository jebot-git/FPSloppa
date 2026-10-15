# Collapse hitch: CPU versus GPU — 2026-10-15

The collapse hitch is dominated by synchronous main-thread mesh/fragment preparation. The animation's ongoing rendering and transform updates are inexpensive in this fixture. These are **Intel N95 development-machine measurements**, not i7-12700 target-machine results.

Godot 4.7.2, Forward+, Intel ADL-N integrated graphics, full streamed map, factory building 10. V-sync and the frame cap are disabled. Two repetitions at each resolution use a complete failed first-storey support set, starting from an intact building without the earlier benchmark's twelve preceding impacts. The old, CPU-bound Voronoi plugin importer was suspended. No desktop game was running during capture; unrelated desktop applications remained open. There are no players, AI or vehicle simulations in this test.

| Measurement | 1280 × 720 | 640 × 360 |
| --- | --- | --- |
| Full collapse: first 20 frames' maximum wall time | 30.70–32.06 ms | 30.38–31.22 ms |
| Full collapse: synchronous trigger + mesh replacement | 28.46–29.04 ms | 27.80–28.11 ms |
| Included main-thread execution time | 26.75–27.30 ms | 25.27–26.95 ms |
| Full collapse: first 20 frames' maximum GPU render time | 3.12–3.21 ms | 1.20–1.32 ms |
| Collapse with animation disabled: maximum initial frame | 13.51–14.37 ms | 10.14–12.42 ms |
| Animation extraction/creation only: synchronous setup | 17.53–18.97 ms | 14.32–15.28 ms |
| Full collapse: subsequent destruction `_process` p95 | 0.120–0.129 ms | 0.103–0.111 ms |

Reducing pixel count by four decreases GPU rendering substantially but barely changes the full-collapse hitch. The Linux main-thread execution counter accounts for roughly 90–97% of synchronous full-collapse setup. Together these distinguish actual CPU execution from an explanation dominated by waiting for the GPU. Some individual mesh calls have wall time above their thread execution time, so scheduling or driver waits can contribute; this probe cannot attribute every wait to a particular driver operation.

The full trigger includes bounded wall-fragment creation as well as building collapse. Building-animation creation alone inside the full trigger costs approximately 13–14 ms of wall time. The remaining trigger work includes roughly 7–8 ms of wall-fragment creation and other support/breach work; disabling animation reduces the entire trigger to about 0.8–0.9 ms. Site-wide near/middle mesh replacement adds about 7–12 ms. The cached 115-body collision disable portion remains below 1 ms. These timings are nested and must not be summed twice.

The full 1.4-second animation and its cleanup are captured: each event window runs at least 1.7 seconds and 180 frames. After the first 20 frames, the maximum whole-frame interval is below 9 ms at 720p in these captures. There is no repeated collapse-sized spike during this animation. The destruction service's ongoing transform work is a small fraction of a millisecond, including its bounded wall fragments. This does not establish the cost of multiple simultaneous collapses or a populated match.

## i7-12700 estimate

The user identified the i7-12700 as the real testing target and requested an estimate rather than remote execution. **No i7 benchmark was performed.** The current preparation code runs on one calling thread; multiplying throughput by the number of cores would overstate its benefit. Intel lists the [i7-12700](https://www.intel.com/content/www/us/en/products/sku/134591/intel-core-i712700-processor-25m-cache-up-to-4-90-ghz/specifications.html) as eight performance and four efficient cores, while the measured [N95](https://www.intel.com/content/www/us/en/products/sku/231800/intel-processor-n95-6m-cache-up-to-3-40-ghz/specifications.html) has four cores. These specifications do not establish a speedup for GDScript mesh processing or graphics-driver work.

Using the measured approximately 29 ms preparation as a sensitivity calculation:

| Assumed improvement for this calling-thread workload | Estimated collapse preparation |
| --- | --- |
| 1.5× | 19.3 ms |
| 2× | 14.5 ms |
| 3× | 9.7 ms |

Use **roughly 10–20 ms of extra preparation** as a provisional planning range, assuming 1.5–3× effective improvement on a performance core. This is an explicit assumption, not a speedup derived from clock ratios or measured on the i7. RAM, power settings, scheduling, the target GPU and its driver remain unspecified. GPU timestamps measured on the N95 must not be transferred to that machine. A 16.67 ms 60 Hz frame budget must also accommodate normal gameplay, so the target CPU alone does not establish hitch-free behavior. VR's tighter frame budget needs a separate target-device capture.

## Next optimization priorities

1. Prebuild compact per-building collapse meshes and reuse the offline ownership masks, replacing the runtime full-site triangle scan, array duplication, bounds classification and vertex recentering in `animate_collapse()`.
2. Pool the already-baked wall fragments and cache their lighting conversion instead of creating/converting them during the impact frame.
3. Build damaged mesh arrays from cached source arrays and index masks, ideally away from the main thread; commit scene/render resource changes on their required thread. Cache or batch repeated site rebuilds.
4. Keep immediate authoritative collision changes. They are inexpensive here; delaying them would introduce visual/gameplay disagreement without resolving the dominant cost.

Reducing pixel count, simplifying the transform animation or changing GPU shaders is unlikely to resolve this particular hitch. Reprofile on the i7 and its actual GPU after reducing synchronous preparation; then test simultaneous impacts and populated gameplay.

## Instrumentation and reproduction

`tools/voxel_battle/profile_collapse.gd` subclasses the production destruction service only to time its entry points. It does not change gameplay behavior. Modes are full collapse, collapse with both kinds of animation disabled, and building animation alone without collision or mesh replacement. The last control temporarily overlays the intact mesh, so its whole-scene GPU cost is not representative of the real collapse; it isolates animation creation cost.

GPU and renderer CPU timings use the [Godot RenderingServer viewport timing API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-set-measure-render-time). Renderer CPU timings exclude scripts; they cannot diagnose this hitch alone. Whole-frame intervals include scheduling and rendering, and are not pure CPU time. GPU query results can lag, so both initial 20-frame windows and the full event trace are retained. Viewport GPU time measures rendering, not every possible upload/driver wait. Calling-thread execution is sampled from Linux `/proc/thread-self/schedstat`, with kernel accounting granularity; sub-millisecond differences should not be treated as precise attribution.

```
DISPLAY=:0 Godot --path . --xr-mode off --audio-driver Dummy --script tools/voxel_battle/profile_collapse.gd
DISPLAY=:0 Godot --path . --xr-mode off --audio-driver Dummy --script tools/voxel_battle/profile_collapse.gd -- --360
```

The Linux probe writes `test-results/collapse-profile-{720,360}.json` with all frame samples and event boundaries. Archived `results.json` contains per-event measurements and summaries; `frames-720.csv` and `frames-360.csv` retain all raw frame samples. Ranges above cover two repetitions, not a statistical confidence interval. No production deployment, gameplay changes or new capacity test were performed.
