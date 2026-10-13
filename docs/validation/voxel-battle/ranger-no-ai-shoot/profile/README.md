# No-AI physics cost diagnostic

Separate 60.011-second diagnostic repeat of the same 32 ranger VRM crowd with alternating locomotion and random CS fire, simulated stereo, prepass on and springs off. 2,480 rendered samples and 3,598 authoritative physics ticks; 8,592 shots and 300 reloads. AI calls, AI timing samples and navmesh polygons remain zero. All 32 avatars fired more than their first magazine. The original two-minute receipt remains the baseline.

Movement/collision is the largest measured contributor to authoritative physics CPU, totaling 8.157 seconds / 39.60% of 20.597 seconds. Weapon input totals 7.039 seconds / 34.17%. Movement is 2.267 ms per physics tick averaged across the entire formation. Weapon input averages 1.956 ms per tick, but is bursty because guns synchronize firing/reloading. Its p95 per rendered frame exceeds movement's p95.

| Scope | Share of authoritative physics CPU | Median per render frame | p95 per render frame |
| --- | ---: | ---: | ---: |
| Avatar movement and collision | 39.60% | 2.430 ms | 6.653 ms |
| CS weapon input, including firing and reload handling | 34.17% | 0.357 ms | 11.648 ms |
| Impact effects, nested inside firing | 19.60% | 0 ms | 7.739 ms |
| Hit tracing, nested inside firing | 5.67% | 0 ms | 1.848 ms |
| Snapshot | 3.34% | 0 ms | 0.679 ms |
| History | 1.96% | 0.130 ms | 0.336 ms |

Impact effects account for 63.76% of measured firing CPU. The impact handler includes weapon visual effects, an additional surface ray and spatial impact audio; those three pieces were not individually timed, so the measurement does not attribute the entire handler cost to a single piece. The movement scope covers `Fighter.simulate`, including floor/support queries, water/step logic and `move_and_slide`; it does not separately isolate those engine calls. Despite in-place visual animations and zero movement commands, all collision bodies still run the normal character simulation.

Timers are inclusive. Do not sum weapon input with its nested fire/impact/trace scopes. Percentages use total authoritative physics callback CPU, not total wall frame time or Godot engine-wide physics CPU. Per-frame buckets aggregate physics ticks between render callbacks; per-tick and per-render-frame timings are different. Frame buckets begin when each label first appears and exclude the final uncommitted bucket. Diagnostic overhead is included. Native engine physics server work outside the callback, render animation updates and GPU work are not part of that CPU denominator. The baseline remains the uninstrumented 120-second test.

The diagnostic server loop is a copy of the original with timers inserted around character simulation; its content was verified identical after removing those timer lines. Other scopes forward to the original methods. Code and hashes are included. Results were saved before shutdown, which emitted ten ObjectDB instance and three resource-in-use cleanup warnings/errors; process exit code was zero.

[Scope results](profile.json) · [Run](result.json) · [Checks](checks.json)

```bash
godot --xr-mode off --rendering-method mobile --rendering-driver vulkan --path . --script tools/vrm_to_mdl/profile_no_ai.gd -- --representation vrm --simulate --seconds 60 --output res://test-results/ranger-no-ai-profile
```
