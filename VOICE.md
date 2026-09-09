# Voice chat

Open **VOICE…** beside MODEL in the menu. The microphone starts **off** on every launch and is switched off when leaving a match. Listen-only works without enabling microphone capture.

Choose **PUSH TO TALK** or **VOICE ACTIVATION**. Desktop push-to-talk uses **V**; VR uses the **off-hand grip** (left grip with the default right-hand gun, right grip after swapping gun hands). Voice activation uses a fixed input threshold with a short release delay. Android asks for microphone permission when enabling capture. The input-device selector, input level, playback volume, global mute and individual player mutes are in the same window. `MIC LIVE` appears on the desktop HUD or VR wrist while transmitting.

Voice transport is match-wide, including dead players; playback is now positional at the speaker, with a 45 metre range and wall occlusion. Dedicated servers only relay audio; they never open a microphone or play it. Hosts can disable voice with `set sv_voice 0`. Voice stops transmitting when the VR session loses focus. No speech is sent before joining a match or in private practice.

The transport is platform-independent Godot code using AudioEffectCapture, AudioStreamMicrophone and AudioStreamGenerator. It works with the same ENet protocol on PC and the experimental Android/OpenXR presets; no native voice plugin or account service is required. Quest/Pico microphone permission, actual headset audio and cross-device interoperability still require device testing. Windows binaries were cross-exported on Linux, not run on Windows here.

Audio is 16 kHz mono, encoded as independent 20 ms IMA ADPCM blocks. Each block is 164 bytes: approximately 65.6 kbit/s payload per active speaker before network overhead. The host relays to other joined players on unreliable-ordered ENet channel 6. Sequence checks, exact length/state validation and a bounded sender rate reject replayed or malformed packets. A short jitter queue, limited silence insertion and a 120 ms playback buffer handle small gaps without retransmitting stale speech. Server bandwidth grows with the number of simultaneous speakers and listeners.

This initial voice implementation has no acoustic echo cancellation, noise suppression, encryption or recording. Headphones avoid speaker-to-microphone feedback; input device selection uses the operating system’s devices. A synthetic signal verified capture through the muted audio bus. Codec fidelity, server relay, decode, mute/unmute, no sender echo, invalid packets, floods and disabled-host policy were tested. Human microphone intelligibility, packet loss over WAN and end-to-end headset latency remain unmeasured.

Sources: [AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html) and [AudioStreamGenerator](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html). Implementation is in `deathmatch/voice/`; tests are `voice_server.gd`, `voice_network.gd` and `run_voice_tests.py`.

VRM mouth expressions follow speech automatically when available. See [AUDIO.md](AUDIO.md) for the approximate vowel estimator and spatial mixer.
