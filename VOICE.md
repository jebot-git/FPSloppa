# Voice chat

Open **VOICE…** in the main menu or **Settings → Audio → Voice Chat & Microphone**. On a fresh config, voice starts enabled in **PUSH TO TALK**. Hold **V** on desktop or the **off-hand grip** in VR. Listen-only stops microphone capture; voice activation uses a level threshold and a short release delay. The menu offers input-device selection, playback volume, global mute and individual player mutes. Android requests microphone permission, with a retry button after denial. No voice is sent before admission, during offline practice, or while the VR session is unfocused.

Voice mode, preferred microphone, mute-all and activation threshold are saved in the `[voice]` section of `deathmatch.cfg` (or the file selected with `--client-config`). Playback volume remains in `[presentation] voice`. Reconnecting, server voice policy and quitting do not overwrite these preferences. If the preferred microphone is unavailable, capture falls back to the system default while retaining the preference. Per-player mutes are session-specific because peer IDs change when players reconnect. See [client.example.cfg](client.example.cfg).

Voice now uses [TwoVoIP v6.5](https://github.com/goatchurchprime/two-voip-godot-4/releases/tag/v6.5): native resampling, RNNoise noise reduction, Opus encoding and native buffered decoding. The previous ADPCM codec, capture bus and generator playback have been removed. Pinned Linux, Windows and Android binaries and license notices are included in `addons/twovoip`; integration details and local helper fixes are in [FPSLOPPA-NOTES.md](addons/twovoip/FPSLOPPA-NOTES.md).

Audio is mono 48 kHz, in 20 ms Opus frames at a 24 kbit/s target. Unordered unreliable ENet channel 6 carries separately sequenced packets from each speaker. Server admission, packet shape/size validation, replay-window checks and rate limits remain enforced. Dedicated servers only validate and relay packets; they never capture or decode speech. The plugin reorders short gaps and uses Opus loss concealment. Very short utterances and final buffered frames are drained; stalled speakers are cleaned up. The playback buffer targets 80 ms, excluding network and device latency. Clients and servers must use the same protocol (`fpsloppa-20-quake-movement`).

Voice is audible at the speaker's avatar, including dead players and spectators, with distance attenuation up to 60 metres. It uses `AudioStreamPlayer3D` directly so native Opus playback works independently of the Steam Audio effect-player wrapper. Game effects still use the selected audio backend. The built-in relay requires no account or separate service. Dedicated servers can disable it with `set sv_voice 0`.

Automated tests cover real Opus decode levels, two simultaneous speakers, packet reordering/loss/duplicates, one-frame PTT utterances, idle resource cleanup, server rate limits, cross-process relay, mute/unmute, and VR pointer interaction. The local Quest Pro/WiVRn test captured transmitted speech at a second client and replayed the decoded audio. Windows and standalone Android native execution have not been tested in this session. Noise suppression is included; acoustic echo cancellation and encrypted voice transport are not.

VRM mouth expressions follow the local processed speech spectrum; remote mouths use the decoded amplitude. Test-only microphone recordings remain in the ignored `test-results` directory. Normal gameplay does not record voice.

## Optional dedicated-server Mumble handoff

```cfg
set sv_voice "1"
set sv_voice_backend "mumble"
set sv_mumble_url "mumble://voice.example.org:64738/Entryway"
```

This advertises an **Open external Mumble client** button in the voice menu and disables the built-in microphone/relay for that server. Clicking it hands the endpoint to an installed client via `mumble://`; it never automatically joins or opens a microphone. Configure the Mumble service independently and install a compatible client on each participating device. Mumble has its own audio, mute and push-to-talk settings; the game's VR grip PTT and avatar mouth animation do not control external Mumble. Standalone headsets need a compatible Android client/URI handler and may have foreground/background restrictions.

No maintained Godot 4 Mumble/XMPP voice-client plugin was identified during this integration. This option is a deliberate external-client handoff, not an embedded Mumble implementation, positional Link plugin, or protocol bridge. The [official Mumble project](https://github.com/mumble-voip/mumble) provides client/server software and [downloads](https://www.mumble.info/downloads/). In-game hosts always use TwoVoIP; dedicated servers use it by default (`sv_voice_backend "builtin"`). Built-in received voice uses native Opus playback on positional Godot sources.
