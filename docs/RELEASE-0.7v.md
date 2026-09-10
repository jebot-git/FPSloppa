# FPSloppa 0.7v

This release replaces built-in voice with TwoVoIP/Opus, adds Quake-style movement, and improves VR menus, voting and avatar feedback.

- TwoVoIP 6.5 provides native Opus encoding/playback and noise suppression, retaining push-to-talk as the default, voice activation, per-player mute/volume and the optional external Mumble server policy. Short speech, loss/reordering and idle stream cleanup are covered by regression tests.
- Quake-style ground friction, directional acceleration, air strafing and manual bunny hopping (release and press for each jump) are ported to Godot 4.7.2 from rhulha's MIT-licensed movement project. Existing speeds, TF class modifiers, analog VR control, continuous hold-to-swim, stair smoothing and rocket jumps are retained.
- Lobby voting lives on the wall. Select a mode first, then a map from its server maplist. In-game voting uses the same persistent themed selectors, with visible vote-start/status notifications.
- VR dropdowns support holding the trigger and dragging. TF class selection, host setup, avatar selectors and bindings use the same working UI. Main-menu Quit stays visible; tracking and controller options are in Settings, host setup has its own menu, and demo actions fit in two columns. In-game hosting offers all eight modes and still caps at eight players.
- A compact lobby mirror shows the tracked full avatar, mouth motion and measured blinks. Mouth movement responds more visibly to quiet speech. Linux x86_64 includes a vendor-plugin fix for WiVRn's visual-only face-tracking source; other platforms retain upstream vendor binaries.
- Full-body tracked foot swings can kick for 10 damage, sharing the 0.8-second weapon-whip cooldown and server wall/range checks.
- CC automatic health loss produces screen feedback without repeated pain sounds or impact effects; weapon damage retains normal feedback.
- Normal Quit/window close stops looping music and microphone capture before engine teardown, avoiding retained Ogg playback at shutdown.
- Flag captures play an original fanfare and show a scorer/team banner in the desktop and VR HUD.

## Compatibility and downloads

Use matching **0.7v clients and servers**, protocol `fpsloppa-20-quake-movement`. Android version code is 12; package IDs and signing identity are retained. Linux/Windows clients, the Linux dedicated server, experimental Quest/Pico APKs, source, base assets, optional LibreQuake extra maps and the two original TF arenas are supplied. Standalone headsets can download the matching base assets; desktop/server archives include them.

The Quake-style movement is an adaptation, not a claim of frame-exact Quake III physics. Windows exports and Android APKs are built and inspected; this session's physical hardware test uses Quest Pro through WiVRn on Linux. Voice uses TwoVoIP positional playback, while game effects retain the selectable spatial-audio backend. Existing Steam Audio singleton/thread shutdown warnings remain in some automated tests.

Temporary dummy dropdown entries and microphone recordings belong only to the diagnostic test session. They are excluded from shipped gameplay and release archives. See `docs/validation/release-0.7v.json` for validation results and `LIVE_VR_TEST.md` for hardware findings.

## Archived extras

The original forty-map Arena Collection 1 and the ThreeWave, TeamFortress and Arcane Dimensions conversion tools remain available **only from the [0.5v release](https://github.com/jebot-git/FPSloppa/releases/tag/0.5v)**. They will not be revised, developed further or included in subsequent releases unless a map-loader or format change requires revisiting compatibility. The 0.5v downloads remain unchanged.
