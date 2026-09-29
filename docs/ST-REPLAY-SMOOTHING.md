# Vehicle replay smoothing and revised ST trailer

Replay rendering now uses recorded frame timestamps and a shared 50 ms display
buffer for vehicles and fighters. Playback advances before fighter animation on
each display frame; the previous implementation advanced on the physics tick,
stamped vehicles with the running game clock and interpolated them against wall
time. These clocks disagree during offline movie capture, pause, speed changes
and seeking. Rewind now clears both vehicle and fighter pose histories.

Replay actors, cameras and first-person weapons bypass engine physics
interpolation because their transforms have already been interpolated. Mounted
camera positions and passenger graphics use the same hull frame. Passengers no
longer animate a running gait from the aircraft's world velocity. Carried flags
follow their carrier's displayed position instead of the latest snapshot.

The cinematic director consumes the normal replay path rather than injecting a
separate vehicle timeline. Its obstacle ray excludes the followed vehicle, which
prevents sudden closeups when a banking hull intersects the camera ray. UI and
world labels are hidden after avatar/vehicle updates. Combat shots can frame an
opponent, with bounded, smoothed aiming to avoid camera jumps on enemy respawn.

Validation:

- `deathmatch/tests/vehicle_replay.gd`: records and replays an occupied LPC through
  the production recorder/parser. Checks uniform movement and shared seat poses
  at 30/90/144 Hz and 0.5x/1x/2x playback, pause, rewind, mounted camera/graphics,
  a real VRM passenger after animation, unmounted actors, process order and
  restoration of normal interpolation. 39 checks pass under Vulkan; the translating-hull fixture has less than 1 mm position/step error.
- `deathmatch/tests/tribes_demo.gd`: 17 existing replay checks pass.
- `deathmatch/tests/st_transport_vr.gd -- --vr-test`: 56 existing vehicle control
  and smoothing checks pass under Vulkan with simulated VR.

The three-minute revision is rendered from the original three 8v8 recordings,
with 30 six-second shots. Both disc sequences and the Raindance flag snatch and
escape are retained. Additional sequences emphasize moving firefights, pursuit
and carrier breakaways. The recordings contain flag pickups and escapes, not
completed captures. Music remains the requested CC0 Tower Defense Theme by DST,
mixed with recorded game sound effects; it is not added to the game soundtrack.

Shot plans, edit provenance, visual checks and the final video are in
`video-output/st-trailer/revision/`. Rebuild with:

```sh
python3 tools/tribes/trailer/assemble.py --revision
```

Final media validation: 180.000 seconds, 1920×1080 at 30 fps, stereo AAC at
48 kHz. Mixed audio measures −17.5 LUFS and −1.1 dBFS true peak. No blank
intervals of 0.3 seconds or frozen intervals of one second were detected. Both
reframed transport shots have zero camera-obstruction frames. All 30 final
shots were visually reviewed. See the dated validation receipt for hashes.
