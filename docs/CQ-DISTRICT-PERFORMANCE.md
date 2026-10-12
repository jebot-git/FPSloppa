# CQ district performance and filtered upstream integration

Measured 2026-10-12. The original client bottleneck was scripted VRM spring physics, rather than district map rendering. At 32 visible copies of a bundled avatar, switching springs off reduced median frame time by roughly 30–42 ms. The filtered upstream integration reduces spring-enabled frame time by 60–65%, but this desktop still does not sustain a 16.67 ms / 60 FPS budget for 32 nearby avatars. Avatar rendering and animation are now the main remaining costs.

## Source and merge scope

The separate worktree is `Godot-cq-districts`, on `experimental/cq-districts`. The original district source is `4be47be`; incoming source is freshly fetched **origin/main `bb5d0b19939ab807186bbb61ca2f1618c0621fe1`**, reconfirmed after testing. The primary checkout's local main `389b94f` was not used as the upstream source.

This is a filtered, two-parent merge. It imports avatar animation/face optimizations, Godot native spring simulation, distance and mesh LOD, compatible surface compilation, scene caching, native codec/input/packet packing, interpolation, bounded BSPX/palette handling, texture filtering and baked-light compatibility, and Steam Audio runtime shutdown/portability fixes. District translation, server-only geometry paths, asset catalogs, wire layout, admission, ownership, transfers and deployment remain district-specific.

New game modes, music, bots and weapon loadouts are excluded. Neither their scripts nor their manifests/assets were merged. The optional native extension registers only `FPSCodec` and client `FPSPose`; bot/projectile registrations and unused upstream recipient-specific snapshot construction were removed. The existing CQ snapshot record creation and decoding remain in place, with optimized encoding/packing applied to those records.

District adapters enable LOD after a custom avatar enters the scene tree and prepare cached scenes before instantiation. The derived avatar disk cache is disabled in headless mode: its background ResourceSaver writer can wait on renderer work while shutdown waits for the writer. In-memory scene caching remains available. Source workers never instantiate rendered custom avatars.

## Client measurements

Host: Intel N95, Intel integrated ADL-N graphics, Godot 4.7.2, Vulkan Mobile, 1440×900, mono, MSAA off, VSync off. Each case has 90 warmup frames and 240 measured frames. The camera is fixed; 32 copies of each bundled model form an 8×4 grid inside district 40. All avatars remain visible. The full/no-spring pairs run twice in opposite order. Screenshots were inspected.

Values below are **median / p95 wall-clock frame time in milliseconds**, using the first paired repetition. The raw receipts contain both repetitions, GPU and render CPU measurements, maps 00/13/40, frozen rigs and scaling cases.

| Bundled model | Before, springs on | After, springs on | After, springs off | After, moving desktop LOD |
|---|---:|---:|---:|---:|
| D | 51.6 / 58.7 | 20.6 / 22.9 | 17.3 / 19.6 | 18.1 / 22.6 |
| F | 60.6 / 68.9 | 21.9 / 27.6 | 16.1 / 19.9 | 18.9 / 24.3 |
| G | 64.9 / 75.3 | 22.5 / 27.3 | 16.5 / 19.9 | 17.7 / 22.8 |

Upstream production defaults cosmetic springs **off**. The springs-on cases explicitly force them on to compare the old scripted implementation with the native modifier. Moving LOD cases use gameplay mode and run movement, so they are a separate production workload, not a pure subtraction from the stationary preview cases. XR cameras retain full-detail behavior; these are not headset measurements.

District 40 alone measures 9.3 / 11.7 ms before and 10.2 / 10.7 ms after, with approximately 7.2 / 7.1 ms median GPU time. The three map-only baselines are approximately 8–10 ms. There is no evidence that map rendering caused the original 51–65 ms avatar result.

With springs off after integration, nearby 32-avatar cases still take 16.1–17.3 ms median and 19.6–19.9 ms p95. Their median GPU time is approximately 15–16 ms. Frozen poses take approximately 13 ms. CPU/GPU overlap means these numbers are not additive: removing springs does not remove skinning, material shading, body motion, IK or facial updates. Compatible surface compilation reduces imported visible surface counts (D 65→18, F 82→17, G 77→17), while the measured district-plus-avatar draw count remains 169 in this fixture.

The original implementation continued simulating springs beyond the 65 m mesh visibility cutoff: 32 D avatars there took 42 ms median, dropping to 8 ms with springs off. Upstream LOD removes that body cutoff and retains distant avatars, so the far preview case now renders a different workload. The post-merge moving, distant production LOD case measures 10.5 / 12.5 ms, and should be interpreted separately from the original culled-body case.

## District goal and server scope

The campaign still has 81 separate 250 m districts, a 128-player global admission limit and **16 reserved slots per district**. A 32-player district is the next capacity target, not a limit silently enabled by this merge. The client fixture measures 32 remote rigs conservatively, but does not certify 32 distinct VRM uploads, combat, stereo rendering or a VPS.

Headless workers do not run avatar skinning or spring physics. Their budget is movement, collision, combat, ownership and snapshot processing. The live tests exercise four actual campaign BSP workers, 16 protocol actors in one district, ENet, content validation, persistent avatar/identity, and a returning Vulkan desktop. They provide a 16-player regression check, not a 32-player server certification. Current Python gateway code already shares snapshot encoding per district; historical per-recipient encoding results should not be attributed to this backend.

To qualify 32 per district, measure actual split-map workers with 32 admitted actors, representative combat and tracked poses, then check worker p95 against the 16.67 ms simulation budget and client p95 against the chosen display budget. On this desktop, nearby avatar GPU/animation costs require further work for consistent 60 FPS even with springs disabled. Distance LOD should reduce the common dispersed-player workload. Headset and unique-avatar results need their own measurements.

## Validation and limitations

- Cluster Python suite: **43 tests passed**.
- Native codec: **15,248 checks passed**; packet packing: **6,335 checks passed**, with clean process exits. Existing payload/packet behavior is preserved. Native packing improves the test's 16-player heavy-projectile encoding case from roughly 6.3 ms to 2.7 ms median; this is packet packing, not a live simulation timing.
- Replication protocol passes with native acceleration and with both codec/packet fallback switches. Avatar scaling, stances, VR IK, face expressions, capacity rules and external district rules pass.
- Mesh/distance LOD: **547 checks passed**. Animation/native-spring parity: **702 checks passed**.
- Two real workers: BSP boot, movement/double jump, cross-gateway transfer, return transfer with the same actor, logout and ENet passed.
- Configured deployment: four workers, 16 actors, VRM upload/hash download, non-VRM rejection, 81-district content page, persistent identity/team/avatar, returning Vulkan desktop, slot release and ENet passed. The final desktop log has no script errors.
- Editor import and source diff checks passed without script parse/compile errors.
- **Known pre-existing failure:** `tools/cq_gateway/capacity_admission.gd` completes all 14 assertions, then aborts during engine teardown with heap corruption. It reproduces using the original `4be47be` script graph, with native acceleration disabled and with the old Steam Audio library. It is not counted as a passing process test. Experimental teardown changes did not fix it and were discarded.

The gameplay native extension was built locally with GCC 15.2 against the pinned Godot C++ bindings revision `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`. Its ignored local binary and build receipt remain in `addons/fps_native/bin`. This is a development build, not a portable release artifact. Sources and build definitions are committed; a portable build must use the standard container workflow before distribution.

Live worker tests use source-headless Godot via a local wrapper. The available existing server exports failed the console-only runtime audit, so an exported, stripped console package was not certified. The production audit was not weakened.

Raw measurements: [before](validation/cq-district-performance-before-main.json), [after and validation ledger](validation/cq-district-performance-after-main.json). Local logs/screenshots remain under ignored `test-results/district-performance/`.

## Repeating the client measurement

From this worktree, use the local Godot 4.7.2 executable (or equivalent built runtime):

```sh
Godot_v4.7.2-stable_linux.x86_64 --xr-mode off --path . --rendering-method mobile --rendering-driver vulkan --script tools/district_cluster/client_performance.gd
Godot_v4.7.2-stable_linux.x86_64 --xr-mode off --path . --rendering-method mobile --rendering-driver vulkan --script tools/district_cluster/client_performance.gd -- --scaling
python3 -m unittest discover -s tools/district_cluster -t .
```

A real renderer is required for the graphics fixture. The native extension is optional; reproduce the measured setup with the recorded local build or an equivalent build. Disable it explicitly with `--gdscript-codec --gdscript-network-packing --gdscript-poses` when testing the fallbacks. The original baseline used a harness with adapters for the old spring API; its commit and harness digest are recorded in the before receipt.
