# KOTH validation — 19 September 2026

Godot 4.7.2, ericw-tools 0.18.1, desktop Vulkan/mobile renderer and headless ENet.

310 acceptance checks; 0 failures. All four BSPs received visibility and four-sample-axis lighting with bounce/AO, objective fill lights, fresh scene/BC7/ASTC caches and navigation.

All twelve sites pass floor, player-box clearance, pickup exclusion and navigation checks from every team spawn and both other hills. Server, observer and late joiner agree on the active site/countdown and receive one round-end gong. Graphical tests verify countdown labels and effects-bus playback. Internal base-asset archive and runtime hashes agree.

Eight bots, Doom rules, seed 7129, 180 simulated seconds (two rotation cycles) per map:

| Map | Team score | Shots | Longest stationary sample |
|---|---:|---:|---:|
| koth_solstice | 56 : 39 | 1788 | 2.0 s |
| koth_torture | 61 : 46 | 1629 | 1.0 s |
| koth_alichar | 59 : 38 | 1285 | 1.0 s |
| koth_hyperborea | 30 : 34 | 1850 | 1.0 s |

Bots occupied all three sites and both teams scored in each run. These are functional checks, not a competitive-balance or headset performance certification. Existing 1–2 ObjectDB teardown warnings remain in Godot test processes.

Reproduction and build notes: [rotating KOTH](../../docs/KOTH-ROTATION.md). Full receipts and renders: `test-results/koth-rotation/validation.json` and the adjacent files.
