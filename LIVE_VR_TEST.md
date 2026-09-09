# Local live VR checks

Start WiVRn and connect the headset, then run:

```sh
godot --xr-mode on --path . --script res://deathmatch/tests/live_vr.gd -- --frame-stats
```

This optional test entry point records device poses and control states locally at 10 Hz in `test-results/live-vr.jsonl`, with the latest state in `live-vr-status.json`. Nothing is transmitted outside the normal VR session. The runtime log identifies the headset/runtime and reports application frame timing. Existing logs should be copied before another run.

`test-results/live-vr-command.json` accepts a JSON object with `phase` (a label) and optional `action`: `practice`, `recenter`, `calibrate`, `damage` (local feedback only), `audio_test` (a quiet cue repeated for 15 seconds), or `stop`. Changing the file applies one command. Clear a previous stop command before starting another session. The normal game launcher does not read these files or record this telemetry.

The probe's `practice` action starts a bot-free private host bound to `127.0.0.1:29108` with voice available. Ordinary offline practice disables voice, so it cannot validate microphone capture. The probe records audio level meters and push-to-talk state, without recording microphone audio.

Checks with a wearer:

1. Stand upright, recenter, point at controls with both controllers, and check menu alignment.
2. Start practice, calibrate body while facing forward, and inspect the local avatar. Lean, step sideways without the stick, lift each foot, and distinguish native joints from OSC targets in the log.
3. Hold both controllers in view and rotate the wrists. Check palm orientation, finger bends, wrist placement and weapon grip alignment.
4. Open TURN SETTINGS, change mode/speed/angle and verify turning. Check HUD health, armour, ammo, leading-score frags remaining and time.
5. Trigger local damage feedback, test push-to-talk, and walk stairs.

## Quest Pro / WiVRn session, 2026-09-09

WiVRn 26.6.2 identified Meta Quest Pro and supplied valid grip and aim poses for both controllers. The wearer confirmed menu alignment and recentering. Native body data arrived through SolarXR; the initial feed exposed hips, chest, lower legs and lower arms, with no native foot poses. OSC later supplied intermittent foot targets. These paths must be distinguished when assessing tracking coverage.

The wearer reported twisted hands and deformed fingers. The controller-to-hand basis and finger curl frame were corrected, regression checked on all three bundled avatars, and restarted for live assessment. Native orientation calibration was added without changing measured joint positions. The gaze action now uses the name required by Godot’s eye-gaze extension. After the restart and calibration, the wearer confirmed: “Wrists and fingers look correct.” This validates the hand fix on this Quest Pro/WiVRn setup. The wearer also confirmed that the configurable turn settings work.

Application frame-time windows were generally around 13.9 ms median / 14.3 ms 95th percentile (72 Hz). Loading transitions included slower frames. These are application timings, not compositor/encoding latency measurements.

After the wearer reported very low image quality, PC VR variable-rate shading was disabled; Android retains XR variable-rate shading. The restarted PC session rendered at 2520×2772 per eye with render multiplier and 3D scale both 1.0. The wearer confirmed: “Audio works, microphone works, rendering looks correct.” Audio output was routed to the unmuted WiVRn sink. The diagnostic launcher now assigns the current scene and explicitly enables its audio listeners, and the private host allows microphone testing. The initial audio silence was not isolated to a single cause. Captured level meters reached approximately −8.8 dB on Master and 0.19 microphone amplitude; push-to-talk transmission was active in 51 samples. This confirms local capture/PTT, not remote voice reception by a second player.

The OSC receive buffer and per-frame packet budget were increased after observing dropped packets during loading. A separate burst regression check passed. Controller hand IK, native orientation calibration, eye/controller bindings, and tracking/audio regression checks also passed.

The installed vendor face plugin requests both visual and audio tracking sources. WiVRn rejected the unsupported audio face source, so native face/blink tracking did not initialize. Eye gaze is independent. Standalone Quest/Pico microphone permissions and Android builds were not exercised by this PC-streamed session.
