# CQ weather

The unified jungle class arena starts weather automatically on both native and
script authorities. Clear, fog, rain and thunderstorm profiles use a single
random server seed and the existing synchronized lighting clock. Clients request
the seed through an authenticated, rate-limited reliable RPC after admission;
late joins derive the current blend immediately. Round/map epoch refreshes keep
the session seed, and reconnects clear cached state. Protocol
`fpsloppa-cq-frontier-23-weather` requires matching client and server packages.

One random phase in the first day establishes a fixed weather opportunity every
1,200 seconds, the full lighting cycle. Opportunities are therefore at least one
full day apart, including across day boundaries. Each chooses clear (40%), fog
(20%), rain (25%) or thunderstorm (15%); the same weather type may recur with
a different intensity.
Transitions ease over 45 seconds, and the initial condition is randomized too.
Fog density and rainfall are independent seeded targets within the selected
profile. Clear has light haze (0.00006–0.00028), fog 0.0025–0.01, rain
0.0007–0.003 and storms 0.0014–0.005. Rainfall varies from 25–85% in rain and
65–100% in storms, with no precipitation in clear/fog profiles. Both targets
blend at the same daily opportunity; they never reroll per frame or per client.

The stateless schedule has no simulation-tick dependency and survives late joins
and 60/30 Hz authority changes without accelerating weather.

Analytic environment fog follows the profile and day/night tint. Overcast dims
the sky and baked direct/ambient lighting. Thunderstorms add synchronized distant
sky bolts, short double flashes and a procedural clap delayed by sound travel
time. Clients do not replay past claps when joining or seeking the clock.
Lightning also feeds the existing NVG angular exposure pass: a visible strike
causes localized white glare and a 0.65-second fading afterimage. Cover blocks
direct glare, looking away removes the source from view, and removing the visor
clears the afterimage. This does not change authoritative spotting or blindness
timers.

Rain uses at most 1,536 local GPU particles (1,024 in XR), covering 40 × 40 metres
around the active camera. Alpha-hashed drops enter the opaque pass, so the NVG
compositor also colors/masks rain correctly. A 256-resolution GPU heightfield
clips drops at rendered roofs and terrain; its snapped local bounds only update when moved and are hidden
in dry weather. One upward CPU ray every half-second muffles audio under cover.
The particle budget falls to 40% after sustained frame pressure and recovers only
after sustained headroom. Fog density remains identical across client quality
levels. No particles, colliders or audio players are allocated on headless peers.
Weather does not change authoritative damage, movement or spotting rules.

Run the policy/network test with:

```sh
godot --headless --xr-mode off --path . --script tools/voxel_battle/test_weather.gd
```

Render all profiles on the real map, check looping rain and delayed thunder,
and capture illustrative frame intervals with:

```sh
godot --xr-mode off --path . --script tools/voxel_battle/preview_weather.gd
```

Captures and measurements go to `test-results/weather`. These short, sequential
render cases are visual smoke checks, not a GPU benchmark or multiplayer load
test. They do not validate an XR device or guarantee frame budgets.
