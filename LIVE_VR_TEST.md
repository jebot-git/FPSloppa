## Owner-reported 0.3v results

Passed: Quest 3 standalone; Linux PCVR with WiVRn; Windows PCVR with SteamVR; Windows PCVR with Virtual Desktop. Pico 4 and other configurations remain untested. These reports apply to 0.3v, not hardware certification of 0.4v.

# Local live VR checks

Start WiVRn and connect the headset, then run:

```sh
godot --xr-mode on --path . --script res://deathmatch/tests/live_vr.gd -- --frame-stats
```

This optional test entry point records device poses and control states locally at 10 Hz in `test-results/live-vr.jsonl`, with the latest state in `live-vr-status.json`. Nothing is transmitted outside the normal VR session. The runtime log identifies the headset/runtime and reports application frame timing. Existing logs should be copied before another run.

`test-results/live-vr-command.json` accepts a JSON object with `phase` (a label) and optional `action`: `practice`, `recenter`, `calibrate`, `damage` (local feedback only), `audio_test` (a quiet cue repeated for 15 seconds), `lobby` (private test wall with three mode maplists), `drag_test` (after `lobby`, adds temporary long mode/map lists for trigger-drag testing; dummy entries cannot be voted into a match), `vote_alert` (temporary diagnostic ballot), `end_lobby`, `kick_target` (stationary combat dummy in private practice), `capture_feedback` (local capture fanfare/banner), `menu`, or `stop`. Changing the file applies one command. Clear a previous stop command before starting another session. The normal game launcher does not read these files or record this telemetry.

The probe's `practice` action starts a bot-free private host bound to `127.0.0.1:29108` with voice available. Ordinary offline practice disables voice, so it cannot validate microphone capture. The probe records audio level meters and push-to-talk state, without recording microphone audio. `mouth_pose` and `mirror_mouth` report speech-expression weights for checking the smaller lobby tracking mirror while holding push-to-talk.

For an explicitly requested microphone recording, run `godot --headless --xr-mode off --path . --script res://deathmatch/tests/live_voice.gd` after the private host is ready. This local spectator captures decoded TwoVoIP/Opus playback into `test-results/live-vr-microphone.wav` (mixer-rate mono), writes a level/packet report, then replays the sample through the ordinary network voice channel. Recording begins on the first PTT packet and stops after 12 seconds; the WAV includes silence during PTT gaps. A local `.opuspackets` companion stores the received speech packets; `-- --replay-only` replays those packets without recording again. These private files stay in the ignored test-results directory and are excluded from commits and release packages.

The live VR probe accepts `-- --standard-audio` or `-- --steam-audio` for a temporary backend choice. Add `--voice-monitor` to keep the named local recording spectator 1.5 metres to the listener's right for audible positional playback. These switches belong to the diagnostic script and do not alter saved audio preferences.

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

## Final 0.3v session

The final WiVRn test exposed a native Steam Audio crash during gameplay. Source lifecycle and simulation/mixer synchronization were repaired, then checked with 960 rapid source creations/deletions and a new live session. Spatial effects were subsequently reported as too quiet. Correcting the SDK's reference-distance gain and using point-source binaural convolution restored their level without changing music. A comparison regression now requires nearby HRTF output to stay within 6 dB of the standard spatializer.

Native lower-leg joints were arriving, but no real foot joints were present. The IK previously used these only as knee bend hints. Estimated ankles now follow calibrated lower-leg translation and rotation; genuine foot poses take priority. The wearer lifted both legs during the final session and confirmed: **“Tracking and audio seem fixed now.”** Final source additionally bounds inferred ankle height above the tracking floor.

The microphone test used the headset's `wivrn.source`, the game's normal PTT capture and ADPCM encoder, and a separate local ENet spectator. It received 424 packets and saved 8.48 seconds of 16 kHz mono speech, peak 0.506 and RMS 0.046, with no clipping. The recording was replayed through the network voice path, including the repaired Steam Audio backend. The private WAV and detailed device logs remain only in ignored `test-results/`; release documentation contains measurements, not recorded speech or raw poses.

The final session produced 1,739 diagnostic samples at a median 72 FPS, rendering 2520×2772 per eye. This validates the connected Quest Pro/WiVRn session. It does not establish standalone Android, physical Vive/Index compatibility, WAN performance, or independent ankle articulation without foot trackers.

## Voice, lobby mirror and face-source compatibility check, 2026-09-10

The Linux TwoVoIP test captured and replayed 82 Opus speech packets through a second local ENet peer. Decoded peak was 0.516 and RMS 0.0337, without clipping. These measurements verify the local network/capture/playback path; wearer confirmation of subjective voice clarity is separate.

The lobby mirror now receives local mouth-expression weights independently of hidden first-person meshes. Quiet speech has a stronger bounded response. The live test measured local mouth weights up to 0.474 and mirror weights up to 0.489, and regression checks verify return to rest.

The wearer also reported missing blinks. The vendor plugin requested an audio face-tracking source that WiVRn does not support, preventing tracker creation. Patched Linux x86_64 binaries request only runtime-advertised sources. The compatible non-preview build logs visual=1/audio=0, and the live mirror received left/right eyelid closure above 0.84. The wearer confirmed: “Seems correct now.” Mirror regression checks cover blink forwarding and tracking-loss rest. This supersedes the unsupported-face-source limitation reported in the earlier session above. Raw tracking and microphone data remain local in ignored test-results.

## Final 0.7v movement and kick check, 2026-09-10

The final Quest Pro/WiVRn test retained 2520×2772 per-eye rendering. After manual jump input and silent CC hunger damage were applied, the wearer reported that all else seemed fine. Holding jump still continuously swims upward; automated collision tests cover both that case and release/press ground jumping.

Tracked kicks were then tested against a stationary combat dummy in the private host. The wearer confirmed: “Kicks register.” This session recorded 2,156 diagnostic samples at a median 72 FPS and observed foot-hit flags and target damage. Kicks deal 10 damage and share the 0.8-second weapon-whip cooldown; regression tests cover both feet, hand/foot cooldown interactions, movement rejection, walls, armour and normal frag accounting. The live client exited with code 0 after testing; OpenXR teardown still logged spatial-extension disconnect and interaction-profile RID warnings. Raw poses and recordings remain excluded from the release.
