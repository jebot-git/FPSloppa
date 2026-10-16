# Headset grass and vegetation A/B suite

This is an isolated local CQ diagnostic for the cooperative PvE performance work. It does not alter the deployed experiment. AI is disabled, simulation stays at 60 Hz, and the client holds dry weather, daylight and background ambience constant. Keep headset refresh rate, render resolution, foveation and audio backend unchanged between conditions.

Prepare the loopback server and a WiVRn client launcher:

```bash
python3 tools/voxel_battle/prepare_medic_test.py --grass --port 27783 --output /home/blux/.cache/cq-grass-headset-20261015
```

Preparation leaves the local server running and writes `run-client.sh`, `prepared.json` and server logs. Run that shell script when ready to enter the headset. `--xr` explicitly launches the headset client during preparation; `--check` instead runs a short graphical desktop smoke test through every condition and stops its server. Use a fresh output directory for a new preparation. Every client launch gets a separate session directory beneath `takes/`, preserving previous captures.

## Conditions

| Condition | Grass selector | Trees/bush selector | Grass drawing | Grass audio |
| --- | --- | --- | --- | --- |
| A | Live | Live | On | Queries + playback |
| B | Live | Live | On | Off, existing voices stopped |
| C | Frozen | Live | On | Queries + playback |
| D | Frozen | Live | On | Off |
| E | Frozen | Live | Off | Off |
| F | Live | Live | On | Queries only, playback off |
| G | Live | Frozen | On | Off |
| H | Frozen | Frozen | On | Off |

Compare **A/B** for the full grass-audio path, **B/F** for queries/index construction, **F/A** for playback, **A/C** and **B/D** for grass selection, **D/E** for grass drawing, and **B/G** plus **D/H** for trees/bush selection. The switch does not mute ordinary footsteps, gunfire or all game audio.

Frozen selectors retain their submitted instance buffers. They intentionally become stale while moving or looking outside the original tree frustum; avoid large turns and inspect the recorded instance counts. Freezing is a diagnostic condition, not a proposed shipping solution. If counts/coverage differ substantially, use the direct CPU timers and still phase before interpreting a whole-frame improvement as selection cost.

## Headset procedure

1. Launch `run-client.sh`. The client enters the same healthy shocktrooper fixture used for previous testing, with no bots. Allow initial streaming to settle.
2. Open the ordinary VR menu. Use **GRASS TEST: NEXT CONDITION** or **PREVIOUS CONDITION**, then **START TAKE**. Desktop operator shortcuts are **F9** for next condition and **F10** for start/stop.
3. Starting a normal take requests the same fixture spawn again, closes the menu, and allows five seconds for settling. Keep still and face the same direction during this period. Buffers remain live during settling and freeze afterward where required.
4. Follow the headset banner: **20 seconds still with slow, modest head turns; 20 seconds walking; 20 seconds running**. For moving phases, use the same grass-covered path, approximately ten seconds outward and ten back. Avoid firing, menus, vehicles, water and settings changes. Walking may intentionally produce no rustles: the normal grass-audio speed threshold still applies. The running phase must cross grass and produce emissions in condition A for an audio comparison to be useful.
5. A take stops automatically after 60 seconds. Opening the menu, losing XR focus, dying or changing condition terminates the take and marks it incomplete. The next take requires another explicit start.
6. Run A–H, then repeat H–A to reduce warm-cache and order bias. Repeat questionable pairs on the same route. Each pass takes about nine minutes plus menu time.

The suite uses the current corrected selector. It does not recreate the previous release's head-rotation selection bug. Validate on the headset at **90 Hz**; desktop smoke results do not establish VR performance.

## Collection and interpretation

Per-frame CSV data is buffered in memory, then saved at the end of each take. Routine one-second client log flushing and ten-second frame-stat printing are omitted in this fixture. Stage transition messages remain in `client.log`.

Rows include whole-frame intervals, physics tick counts, directly timed grass selection, grass-audio work, tree/bush selection, audio scans/index builds/emissions, vegetation instance counts, movement speed, terrain jobs and viewport CPU/GPU render timings. Metadata includes condition, completion reason, runtime/adapter, source hashes, render scale and refresh rate. Unknown refresh rates are explicitly marked as an assumed 90 Hz. Raw controller/head poses and microphone data are not collected.

```bash
python3 tools/voxel_battle/summarize_grass_test.py /home/blux/.cache/cq-grass-headset-20261015/takes
```

This writes `summary.json` with separate still, walk and run results, whole-frame p50/p95/p99, deadline misses, direct subsystem timings and audio counters. Incomplete takes are retained and labelled. Compare completed, matched repeats; the tool deliberately does not declare a winning condition from unrelated routes.

Whole-frame intervals include waits and runtime pacing. Subsystem timers measure wall duration of those calls, not thread execution time. Viewport GPU query results can lag and do not include the complete XR compositor/encoder pipeline. Do not add independent percentiles or attribute the entire frame interval to the adjacent subsystem sample. Terrain streaming remains active and is counted as a possible confounder.

Stop the local server after the session with `kill <server_pid>` using the PID in `prepared.json`. The remote live server is unaffected.

## Verification receipt

The eight-condition graphical loopback smoke test passes without script errors. Seven focused audio checks verify normal emission, index construction, stopping existing voices, disabled scan bypass, silent queries and playback recovery. The full vegetation fixture passes **4,284 checks**, including freezing dirty/moving grass without altering its render buffers and resuming selection. [Receipts](checks/) include the deliberately short desktop samples; they are not headset performance results. The existing fixture shutdown still reports ObjectDB/resource cleanup warnings.

## First headset capture

[Collection receipt](headset-collection.json): six attempted takes contained zero frames. Closing the VR menu synchronously re-entered the shared toggle and cancelled capture before warmup. The menu now uses an idempotent START action, defers closure and guards duplicate input; [four regression checks](checks/recorder-reentrancy.log) pass. No performance conclusion can be drawn from this run. A client relaunch is required to load the corrected recorder.
