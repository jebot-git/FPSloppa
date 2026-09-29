# ST cinematic recording

`capture_match.gd` records an actual local 8v8 ST server to FPSDEMO1 and collects
flag, movement, and disc-jump telemetry. It reuses the existing ten-minute capture
and pickup cutoff. One bot per team is assigned vehicle pilot inputs when the
map has vehicle terminals; normal purchases, seats, physics and damage still
apply. Remaining bots retain normal objective AI. No speed or health buffs.

Example (choose an unused local port and a new output directory):

```sh
godot --headless --xr-mode off --path . --script tools/tribes/trailer/capture_match.gd -- \
  '{"map":"ctf_raindance","port":28996,"seed":9294,"seconds":540,"output":"res://video-output/st-trailer/raindance"}'
```

`inspect_demo.gd DEMO OUTPUT_JSON` extracts movement and effect events from the
demo for selecting real action. It disables object decoding and bounds frame
sizes, and can inspect the complete frames in an in-progress recording.

`render.gd PLAN_JSON` uses offline demo playback with a camera-only shot plan.
Each shot names its bot, start, duration, camera kind and optional framing values.
Plans and camera receipts for this trailer are in `video-output/st-trailer/`.
Rendering hides the HUD and world labels, stops in-game music and announcements,
and records gameplay sounds. Camera raycasts prevent terrain/wall clipping.
The production replay path interpolates both vehicles and fighters on demo time.
The director runs before avatar animation and hides labels after all scene updates.
Vehicle-follow cameras exclude their own hull from obstacle checks.

```sh
godot --path . --xr-mode off --rendering-method mobile --rendering-driver vulkan \
  --audio-driver Dummy --fixed-fps 30 --disable-vsync \
  --write-movie /absolute/output.avi --script tools/tribes/trailer/render.gd -- /absolute/plan.json
```

The project's `.movie` viewport overrides select 1920x1080 for MovieMaker only.
Each shot has two seconds of replay warmup; the receipt identifies the exact
frames to retain. Do not keep the warmup or loading frames in the edit.

`assemble.py` reproduces the inspected 110-second cut, encodes H.264 video,
preserves synchronized effects, mixes the requested CC0 DST track, and writes
an edit manifest with provenance. MovieMaker's resolution and audio behavior
follow the [Godot movie documentation](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html).

The final video, source recordings, QA contact sheets and music credit are under
`video-output/st-trailer/`. Large media remains outside the source repository.

The revised action cut uses `video-output/st-trailer/revision/*-plan.json`,
`order.json`, and `assemble.py --revision`. It is 180 seconds and retains the
disc jumps and Raindance flag-snatch sequence, with more moving combat and
carrier escapes. The original 110-second cut remains available separately.
