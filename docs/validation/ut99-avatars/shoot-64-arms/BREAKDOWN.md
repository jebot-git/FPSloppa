# Recorded 64-avatar shooting frame costs

The largest directly timed CPU block is the authoritative gameplay callback: **9.554 ms median per physics tick**. The run processed **6,618 ticks for 1,130 rendered samples** (5.86 ticks/render on average). Combined stereo GPU time was **4.273 ms median** and arm updates **0.517 ms per rendered frame**. This supports CPU simulation saturation as the main issue; it does not isolate the engine collision solver or weapon impacts individually.

This is an analysis of the existing 120-second receipt, **not a new benchmark**. It uses Vulkan Mobile, all seven World Leaders skins, original vertex animation and the early arm approximation. It predates the accepted constrained head/neck/arm IK solver, Forward+ policy and final dense undergrowth. Do not use these numbers as performance claims for the current branch.

| Counter | Median (ms) | p95 (ms) | Measurement unit |
|---|---:|---:|---|
| Reported process delta | 121.234 | 140.979 | Per rendered callback; engine delta |
| Authoritative gameplay CPU | 9.554 | 19.949 | Per physics tick |
| Synthetic headset/controller pose generation and validation | 0.748 | 0.875 | Per physics tick, outside gameplay timer |
| Arm deformation update CPU | 0.517 | 0.577 | Summed across 64 avatars per rendered frame |
| Combined eye render CPU | 1.292 | 1.491 | RenderingServer viewport counter, both eyes |
| Combined eye GPU | 4.273 | 6.427 | RenderingServer viewport counter, both eyes |

The measured wall duration is 120.022 seconds: **9.41 rendered samples/s**, or **106.214 ms average wall interval**. A wall median/p95 cannot be recovered because the CSV has engine deltas rather than individual wall timestamps. Simulation advances 110.3 seconds. The CSV shows seven ticks between renders at the median, eight at p95, and one additional tick after the final recorded render. Several physics ticks therefore accumulate before one render; comparing a per-tick median directly with a per-frame delta understates simulation cost. Multiplying the median tick cost by the mean tick count is not an actual measured frame budget, and independent percentiles cannot be added.

The gameplay timer wraps `game._physics_process`: movement/`move_and_slide` calls, authoritative combat, traces, hit handling, gameplay and effects dispatch are included. Engine physics phases outside that callback, separate fighter/node callbacks, avatar animation and other scene processing lack exclusive counters. No reliable percentage or separate total can be assigned to collision, weapon impacts or head IK from this receipt. AI work and navigation polygons are both zero. GPU/CPU overlap also prevents subtracting the GPU time from process delta to derive CPU time.

Environment update shows a constant 2.47 ms because the stationary renderer retains its last refresh measurement when it skips updates. That number is excluded from per-frame attribution. Terrain is settled in all 1,130 samples. The median recorded draw count is 1,087 and primitives 400,118 across the frame; these are workload counts, not separate timing categories.

The run fires 31,144 shots with no deaths and 1,072 reloads. The 64-slot effects pool remains valid but reaches capacity and evicts 1,336 effects. These counters establish activity and saturation, not the duration of impact processing.

[Original receipt](result.json), [raw CSV](frames.csv.gz), [audited breakdown](breakdown.json). The analysis checks sample counts, settled terrain and all CSV timing/workload percentiles against the receipt, and verifies 60 Hz simulation tick accounting.

```sh
python3 tools/ut99_avatar/frame_breakdown.py docs/validation/ut99-avatars/shoot-64-arms --output docs/validation/ut99-avatars/shoot-64-arms/breakdown.json
```
