# Headset grass A/B results — 15 October 2026

Eight completed 60-second takes, **40,695 frames / 480.04 seconds**, Quest Pro on WiVRn at runtime-confirmed **90 Hz**, Arc A770, render scale 1.0, 60 Hz local simulation. The client and isolated local server were stopped after collection; WiVRn and the remote experiment were left unchanged. No client script errors or unsupported hand-source errors occurred in this capture. The collected runtime journal has no matched recenter/network-error lines.

[Raw logs and captures](/home/blux/.cache/cq-grass-final-20261015T201913Z.tar.gz), [hash manifest](evidence.json), [phase statistics](summary.json), [direct rebuild timings](direct-timings.json). Compressed CSVs beside this report retain every frame row; they contain no raw tracking poses or microphone data.

| Condition | Whole-take FPS | Whole-frame p95 | Last 20 seconds FPS |
| --- | ---: | ---: | ---: |
| A: normal grass + audio | 77.6 | 21.07 ms | 68.1 |
| B: normal grass, audio off | 79.1 | 19.72 ms | 68.6 |
| C: frozen grass selection + audio | 89.8 | 13.09 ms | 89.8 |
| D: frozen grass selection, audio off | 89.8 | 13.21 ms | 89.8 |
| E: grass hidden, audio off | 89.7 | 13.24 ms | 89.7 |
| F: normal grass, silent audio queries | 79.6 | 20.33 ms | 69.1 |
| G: trees/bush selection frozen, audio off | 82.7 | 19.96 ms | 73.4 |
| H: all selection frozen, audio off | 89.8 | 13.29 ms | 89.8 |

## Findings

**Grass rebuilding is the strongest measured suspect.** With live selection, rebuild calls average **5.50–5.90 ms when they run**, with per-take rebuild p95 values **7.79–9.14 ms** and maximum **10.39 ms**. These synchronous calls consume a large fraction of the 11.11 ms headset interval before other work. In A, selection rebuilt on 1,095 of 4,659 frames; its mean across all frames was 1.39 ms, which hides the burst cost. In the last 20 seconds, live-selection takes A/B/F ran at 68.1/68.6/69.1 FPS with similar average movement speeds of 7.38/7.13/7.39 m/s.

**Grass audio is a smaller contributor in this run.** Disabling it did not recover running performance. A emitted 72 rustles and C emitted 58, confirming that enabled playback was exercised. A's maximum measured grass-audio callback was **0.575 ms**, including cold index construction; F's maximum was **0.117 ms** with no new index builds. F still ran at 69.1 FPS in the running phase. These wall timers do not separately measure audio-thread mixing, but the A/B/F comparison does not support grass audio as the principal cause of the sustained drop.

**Tree/bush selection is secondary work worth reducing.** It averaged approximately **1.94–2.02 ms per sampled frame** in live-tree conditions. G held 459 tree/bush instances and skipped that selector, reaching 82.7 FPS overall and 73.4 in the running phase, while live grass remained expensive. The route and visibility differences prevent treating that change as a precise isolated speedup.

Live-selection running GPU-render p95 values were approximately **5.14–5.35 ms**. This supports investigating main-thread selection first, but viewport GPU queries can lag and omit compositor/encoder and resource-upload costs.

## Limits that affect interpretation

- **All frozen-grass takes C/D/H retained zero grass instances.** Those captures removed grass drawing as well as its CPU selection. Their near-90 FPS result cannot distinguish selection CPU from drawing cost, and D/E cannot qualify grass rendering cost. The summary now flags this explicitly. A later frozen-buffer comparison must verify nonzero retained instances before capture.
- The first 20-second prompt was labelled still/head-turn, but measured mean speeds were **2.11–4.63 m/s**. These are movement samples, not a stationary head-turn control.
- This is one forward pass, without reversed-order repeats or identical recorded routes. Cold audio indexing occurred in A and not F. Terrain worker jobs were active on some frames, although all takes ended with zero outstanding jobs. These factors limit exact causal estimates.
- Whole-frame p95 remains approximately 13.1–13.3 ms even near 90 FPS. The target is not demonstrated as a strict 11.11 ms tail bound. Frame intervals include runtime pacing; direct subsystem timers measure call wall duration, not thread execution. Do not sum independent percentiles.

## Recommended next work

Prioritize bounded, incremental grass candidate selection and buffer updates; the 2,048 rendered-instance cap does not bound the preceding candidate scan, bucket construction and sorting. The hot loop is a reasonable native C++ target, alongside reducing allocations and reusing spatial selection results. Follow with tree/bush selection. Keep grass-audio optimization lower priority unless a different capture shows significant audio-thread cost.

Retest after optimization on the same headset and route, including a nonempty frozen-grass control, repeated A/B pairs and reversed order. This test contains no AI and does not qualify cooperative enemy simulation or multiplayer capacity.
