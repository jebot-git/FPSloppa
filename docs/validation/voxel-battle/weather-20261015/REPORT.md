# CQ randomized weather — 15 October 2026

Clear, fog, rain and thunderstorm profiles now run in the unified jungle class arena. A random server seed plus synchronized lighting time defines the same weather and intensity on every client, including late joins. Opportunities are exactly 1,200 seconds apart, with 45-second eased transitions. Rainfall and fog density are independently randomized within profile ranges; repeated weather types may have different intensity. Round epoch refreshes retain the seed, while reconnects clear cached state. Matching client/server protocol `fpsloppa-cq-frontier-23-weather` is required.

Fog follows weather and daylight. Overcast and lightning affect the sky and baked world/avatar lighting. Rain uses a bounded local GPU particle volume and GPU heightfield collision, with a hysteretic particle budget. Original procedural rain audio loops; thunder follows the flash after its acoustic delay, with replay protection. Headless peers allocate no effects. Authoritative damage, movement, spotting and blindness timers are unchanged.

Lightning is a bright directional source in the existing NVG exposure pass. Visible strikes cause localized white glare and a fading 0.65-second afterimage; cover blocks direct glare, looking away removes the source from view, and removing the visor clears the afterimage. Alpha-hashed rain enters the opaque pass so NVG also colors and masks the drops.

## Checks

- **64,757 checks passed** over 5,000 simulated days: full-day minimum spacing, random density ranges and diversity, smooth transitions, repeated weather types, deterministic late joins, thunder bounds, local particle-budget reduction/recovery, and NVG exposure/recovery/cover checks.
- Real isolated ENet server/client test passed seed delivery, epoch resynchronization without rerolling weather, identical derived state, disconnect/reconnect reset, and absence of headless visual/audio allocations.
- Existing CQ NVG regression suite: **25 checks passed**, including muzzle flashes, cover, visor gestures, daylight ranges and glare clearing.
- Full class arena GDScript parse passed.
- Actual streamed map rendered in Forward+ on Intel Graphics (ADL-N), 1280 × 800. All four weather profiles, visible lightning, night fog, NVG lightning glare and NVG recovery were captured and visually reviewed. Rain looping, delayed thunder playback, duplicate-clap suppression, night fog tint and the actual NVG compute pass's white glare/recovery pixels were asserted. Final render log contains no errors or warnings.

The sky uses material parameters to invalidate its cache. Slow sky/cloud blends are quantized to 0.005 increments and unchanged values are not resent; lightning remains frame-accurate. Shader globals continue to drive baked surface lighting.

## Illustrative frame intervals

These consecutive 120-frame visual smoke samples follow two seconds of settling with the same camera. They include normal map streaming/scheduling and display pacing. They do **not** isolate weather cost or establish a stable benchmark, a headset frame budget, server capacity or a 64-player match result.

| Weather | Rain intensity | Fog density | Median interval | p95 |
| --- | --- | --- | --- | --- |
| Rain | 65.1% | 0.001164 | 13.30 ms | 24.53 ms |
| Clear | 0.0% | 0.000211 | 13.31 ms | 27.72 ms |
| Fog | 0.0% | 0.005345 | 13.30 ms | 28.86 ms |
| Thunderstorm | 92.3% | 0.003674 | 13.29 ms | 29.26 ms |

All four samples allocate at most 1,536 particles; intensity controls the active fraction. XR defaults to 1,024 particles but was not tested on a headset. Roof clipping uses rendered geometry and heightfield sampling; this is not an exhaustive indoor collision test. Audio playback and source waveforms were checked programmatically, not by a listening session.

No deployment was activated and the live VPS was not modified. See [configuration and reproduction](../../../CQ-WEATHER.md).
