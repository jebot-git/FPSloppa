# Voice chat

Open **VOICE…** beside MODEL in the menu. Voice chat starts enabled in **PUSH TO TALK** on each launch. Your mode selection survives leaving/rejoining matches during that launch. Choose **LISTEN ONLY** to stop microphone capture while continuing to hear other players.

Choose **PUSH TO TALK** or **VOICE ACTIVATION**. Desktop push-to-talk uses **V**; VR uses the **off-hand grip** (left grip with the default right-hand gun, right grip after swapping gun hands). Voice activation uses a fixed input threshold with a short release delay. Android requests microphone access on startup. Denial keeps listening available and preserves the selected mode; use **RETRY ACCESS** or the headset app permissions to grant access later. The voice panel uses the same canvas as the VR menu, with large controller-selectable mode buttons, a microphone device button that cycles available inputs, input level, playback volume, global mute and individual player mutes. It fits the VR viewport without native popups. `MIC LIVE` appears on the desktop HUD or VR wrist while transmitting.

Voice transport is match-wide, including dead players; playback is now positional at the speaker, with a 45 metre range and wall occlusion. Dedicated servers only relay audio; they never open a microphone or play it. Hosts can disable voice with `set sv_voice 0`. Voice stops transmitting when the VR session loses focus; push-to-talk also stops if the off-hand grip loses tracking. No speech is sent before joining a match or in private practice.

The transport is platform-independent Godot code using AudioEffectCapture, AudioStreamMicrophone and AudioStreamGenerator. It works with the same ENet protocol on PC and the experimental Android/OpenXR presets; no native voice plugin or account service is required. Quest/Pico microphone permission, actual headset audio and cross-device interoperability still require device testing. Windows binaries were cross-exported on Linux, not run on Windows here.

Audio is 16 kHz mono, encoded as independent 20 ms IMA ADPCM blocks. Each block is 164 bytes: approximately 65.6 kbit/s payload per active speaker before network overhead. The host relays to other joined players on unreliable-ordered ENet channel 6. Sequence checks, exact length/state validation and a bounded sender rate reject replayed or malformed packets. A short jitter queue, limited silence insertion and a 120 ms playback buffer handle small gaps without retransmitting stale speech. Server bandwidth grows with the number of simultaneous speakers and listeners.

This initial voice implementation has no acoustic echo cancellation, noise suppression, encryption or recording. Headphones avoid speaker-to-microphone feedback; input device selection uses the operating system’s devices. A synthetic signal verified capture through the muted audio bus. Codec fidelity, server relay, decode, mute/unmute, no sender echo, invalid packets, floods and disabled-host policy were tested. Human microphone intelligibility, packet loss over WAN and end-to-end headset latency remain unmeasured.

Sources: [AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html) and [AudioStreamGenerator](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html). Implementation is in `deathmatch/voice/`; tests include `voice_server.gd`, `permissions.gd`, `vr_ui.gd`, `local_body.gd`, `voice_network.gd` and `run_voice_tests.py`.

VRM mouth expressions follow speech automatically when available. See [AUDIO.md](AUDIO.md) for the approximate vowel estimator and spatial mixer.


## Optional dedicated-server Mumble handoff

```cfg
set sv_voice "1"
set sv_voice_backend "mumble"
set sv_mumble_url "mumble://voice.example.org:64738/Entryway"
```

This advertises an **Open external Mumble client** button in the voice menu and disables the built-in microphone/relay for that server. Clicking it hands the endpoint to an installed client via `mumble://`; it never automatically joins or opens a microphone. Configure the Mumble service independently and install a compatible client on each participating device. Mumble has its own audio, mute and push-to-talk settings; the game's VR grip PTT and avatar mouth animation do not control external Mumble. Standalone headsets need a compatible Android client/URI handler and may have foreground/background restrictions.

No maintained Godot 4 Mumble/XMPP voice-client plugin was identified during this integration. This option is a deliberate external-client handoff, not an embedded Mumble implementation, positional Link plugin, or protocol bridge. The [official Mumble project](https://github.com/mumble-voip/mumble) provides client/server software and [downloads](https://www.mumble.info/downloads/). In-game hosts always use the existing simple voice system; dedicated servers use it by default (`sv_voice_backend "builtin"`). Built-in received voice now uses Steam Audio HRTF when selected in Audio settings.
