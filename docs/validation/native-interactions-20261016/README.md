# Native VR interaction and weather continuation — 2026-10-16

This batch extends the native client; it does **not** finish the complete migration. The standalone CQ server remains a separate C++ application without Godot. The client still uses Godot and substantial script scene/interaction orchestration.

## Implemented

- `FPSVRInteraction` owns two-hand aim engagement/release hysteresis and smoothing, shoulder-stock calibration and alignment, tracking-space swim-stroke accumulation and decay, physical throw gain/speed limiting and guided direction, and real engine sphere-swept grenade preview trajectories. Each local interaction has its own native state; no scene/controller object is retained by this service.
- Script adapters supply controller transforms and authored grip geometry. Existing state properties remain accessible. `--gdscript-vr-interactions` selects the independent reference state machines for editor fixtures.
- `FPSWorld.weather_sample` and `weather_lightning` own deterministic weather opportunities, seeded variable fog/rain targets, 45-second transitions, and strike timing/distance/direction. The original at-most-one-opportunity-per-1,200-second-cycle rule is unchanged. Native sampling preserves late-join determinism; `--gdscript-weather` selects the reference.
- Exported standalone CQ admission checks required native capabilities and rejects `--gdscript-*` reference selectors. Editor binaries retain diagnostic paths. This check does not remove retained script adapters or prove packaged target support.
- The standalone build now builds the registered authority test dependency and runs both CTest suites. Previously a regular server build left the excluded authority test executable absent, so a subsequent CTest invocation could not run that suite.

## Verification

[Ten selected regression suites](regressions.json) pass **85,103 checks**, including:

- [16,949 VR differential checks](vr-parity.log): stateful weapon changes, both handedness settings, grip/tracking loss, smoothing, shoulder hysteresis, swimming resets/discontinuities, throw speed limits and collision sweeps against real engine shapes.
- [26,101 weather differential checks](weather-parity.log): seeds, negative/late-join times, transition boundaries and lightning results.
- [23 stock/foveation integration checks](stock-foveation.log).
- Native client protocol, projection, session, field/reconciliation, interpolation, avatar/container/transfer and network packing regressions.

The [existing weather integration suite](weather-integration.log) additionally passes **64,757 checks**, including real ENet late joins/epoch synchronization, density bounds, change spacing and local rain budget recovery. Total selected Godot checks: **149,860**. [Both standalone C++ suites pass](server-tests.log).

Fresh [desktop](desktop.json) and [simulated tracked](tracked.json) clients pass against an isolated standalone server: combat, grenades, squads, team changes, jetpack, destruction and death/gibbing/respawn, plus desktop NVG and simulated tracked poses. Desktop reports zero steady-state movement corrections; tracked reports one correction (maximum recorded error 0.201m). Both have zero prediction resets and pass the fixture thresholds. These fixtures synthesize input and do not replace controller/headset or rendered device QA.

The first live attempt rejected a stale cooked-map identity after the weather source changed. The world was actually [recooked](world-cook.log), including 9,088 collision bodies, 1,215,193 navigation polygons and 25 avatar bundles, then both clients passed against matching data. No live service was deployed or restarted.

The older [crouch/water suite](legacy-water-unavailable.log) cannot complete in this workspace: no compatible legacy arena is installed, then its setup accesses an absent bots instance. It is not counted as passing. New native swim-state differential coverage passes. The previously documented native/reference Quake obstacle tolerance failure remains outside this slice.

## Remaining work

Physical reload/magazine/grab, wheel/vehicle/controller and scope interaction ownership; avatar/presentation lifecycle and compatibility dictionaries; scene factories and cosmetic dispatch; environment/streaming/collapse, audio/voice orchestration; launcher updater/storage/process services; retirement of legacy scripted hosts; and clean packaged Windows/Android/headset QA. UI layout/signals and offline authoring/reference tools remain intentionally scripted.

No whole-client FPS improvement or i7-12700 performance estimate is inferred from these correctness fixtures. Native binaries and cooked worlds are build artifacts and remain ignored; rebuild them from the committed sources before packaging.
