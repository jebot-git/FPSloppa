# Spatial audio and mouth animation

Weapons now use edited Freedoom effects for a punchier classic Doom-style sound: pistol and chaingun share a report, shotguns have mechanical reload tails, and rockets, plasma, BFG, chainsaw and explosions use short recognizable effects. Railgun, melee and recorded footsteps retain their existing sounds. Pickup arpeggios are replaced with short mechanical clicks, clunks and foley. Sources and licenses: `deathmatch/audio/doom-style/SOURCES.md` and `deathmatch/audio/recorded/SOURCES.md`. Regenerate with `python3 tools/prepare_arena_sfx.py` (ffmpeg required).

Weapon reports use measured, attenuation-only per-clip trims. Peaks are capped at -6 dBFS and sustained energy (including overlapping tails at the weapon’s firing cadence) at -20 dBFS, before the existing -4 dB shot playback level and distance attenuation. Voice levels are independent of weapon trims. This is energy/peak balancing, not perceptual LUFS mastering; headset listening remains a device check. Regenerate `deathmatch/audio/weapon_levels.gd` with `python3 tools/balance_weapon_audio.py` after changing sounds or cadence.

Combat sounds share a 32-source spatial mixer, using Steam Audio HRTF by default or selectable Godot stereo spatialization. Mono point sources use inverse-distance attenuation, distance filtering, and 10 Hz collision ray tests for wall occlusion. Obstructed sources lose 10 dB and are low-pass filtered. Five room probes twice per second adjust a shared diffuse reverb. HRTF supplies directional headphone cues; room acoustics remain an approximation without diffraction or physically traced reverberation.

Voice playback now comes from each speaker's avatar head, with the same distance/occlusion processing and a 45 metre range. Transport still relays to all joined players. Mute and volume controls continue to apply. Dedicated servers only relay audio.

Local mouth motion uses TwoVoIP’s processed speech, resampled to 16 kHz for analysis. A lightweight spectral/energy estimate produces weights for VRM `aa`, `ih`, `ou`, `ee`, `oh` expressions (and VRM 0 `a/i/u/e/o` aliases). Actual bindings are read from the imported VRM expression animations, allowing custom mesh/morph names. A bounded square-root response makes quiet speech visible on subtle morph targets. The lobby mirror receives the same speech weights independently of hidden first-person meshes, and clears them after speech stops. Remote mouth motion follows the native Opus playback amplitude; attack/release smoothing and silence timeout close the mouth. Muted streams discard pending animation, and dead avatars do not talk visually. No extra face packets, speech service or transcription are involved. This is approximate audio-driven vowel animation, not phoneme recognition or facial tracking. Models without these declared expressions remain usable but have no corresponding mouth motion.

Validation: tests load and animate all five expression bindings on all three default VRMs, check silence and loss recovery, exercise native/OSC body poses, verify audio asset loading and real physics-wall occlusion, and confirm received speech creates a positional source with native Opus playback. Local ENet tests cover voice relay, invalid packets, mute and server policy. Headset listening, acoustic quality and lip-sync latency need human/device evaluation.

## Mixer and soundtrack

**SETTINGS… → AUDIO** provides persistent master, sound-effects, music and voice levels plus output-device selection. Sound effects use `ArenaEffects`, music uses `ArenaMusic`, and voice retains its independent playback gain; voice plays independently of the effects bus. Muting music does not affect incoming voice or microphone capture. Ten original scores plus the public-domain Assault theme cover the game modes, lobby and title screen. The eight original gameplay scores use distinct metal arrangements with double-tracked recorded guitars, bass and acoustic drums. The title remains slow and ambient; the lobby keeps its corrected elevator-jazz harmony. Selection loads asynchronously and crossfades over 2.5 seconds without restarting on same-mode map changes. The active Ogg files total about 16.45 MiB; [source arrangements and provenance](deathmatch/audio/music/SOURCES.md) are included in the source project. The [industrial-versus-metal audition](docs/audio/metal-alternates/README.md) remains available outside game exports.


## Steam Audio spatialisation (0.3v)

[godot-steam-audio 0.3.1](https://github.com/stechyo/godot-steam-audio/releases/tag/0.3.1), using Valve Steam Audio 4.8.0, is bundled for Linux x86-64, Windows x86-64 and Android arm64/x86-64. Effects use its binaural HRTF and distance attenuation. Incoming voice uses TwoVoIP on native Godot positional players. The listener follows the actual desktop camera or XR headset, including head rotation and room-scale movement. Music and local feedback stay on their normal non-positional buses. Steam/SteamVR accounts are not required; WiVRn and native SteamVR use the same audio path.

**Settings → Audio → Spatial Audio** switches between Steam Audio HRTF (headphones) and standard stereo spatialisation. Volume controls continue to work. Runtime failure to load the extension uses the standard player implementation. Headless servers do not create a listener or audio simulation. CPU HRTF is used, with full acoustic reflection simulation disabled to keep VR frame costs bounded; existing collision ray tests provide muffling through walls and moving doors, with lightweight room reverb.

The bundled extension includes local fixes for concurrent sound-source creation/destruction, native effect cleanup, and Android 16 KiB page alignment. Point sounds use direct binaural convolution. Reference-distance gain is normalized to unity within 5 metres for effects and 3 metres for voice: the SDK's raw `1 / max(distance, minimum)` formula otherwise reduced nearby effects by roughly 14 dB. The source patches and build instructions are included with the addon. Automated checks compare backend loudness, ear direction, streaming voice, and rapid source destruction; the live WiVRn probe also exercised microphone capture and local ENet voice replay.

The adapter keeps one listener/config alive across map changes and matches the plugin's DSP allocation to Godot's 512-frame mixing blocks. Positional one-shots have explicit lifetimes because the upstream stream wrapper does not finish itself. Current voice bypasses that inner-player lifecycle and uses TwoVoIP’s native Opus stream directly. Tests capture stereo output, verify finite samples and left/right reversal when the listener turns, and exercise streamed voice through the native wrapper.

Licenses, upstream archive checksum and runtime notices are under `addons/godot-steam-audio/`. The plugin is MIT, Steam Audio Apache-2.0, and its bundled third-party runtime notices are in `THIRDPARTY.md`.

## Combat and item feedback (0.3v)

Recorded pain grunts rotate between three short takes; local feedback is limited to one cue per 300 ms. Player respawns have a stronger teleport cue. Megahealth, mega armour and BFG availability transitions play a positional powerful-item cue once, replicated reliably to clients. Ordinary item respawns stay quiet. Health, armour, ammunition, weapons and mega pickups have distinct short cues with recorded metallic transients. All use the effects bus and its volume control.

Gameplay music uses CC0 Karoryfer guitar, bass and acoustic drums at 44.1 kHz. The title/lobby tracker arrangements also use VSCO piano, flute, strings and anvil. Full source links, editable arrangements and regeneration instructions accompany the music. Chainsaw contact adds a short spatial grinding cue derived from the existing CC0 Kenney metal impact, with throttled sparks and VR haptics on world contact or a successful blade parry.

## Announcer

WARLORD by VoiceBosch supplies TF flag-capture and AS objective confirmation ("Objective completed"), first blood, double/triple kills within three seconds, and streaks of 5/10/15 enemy kills without dying. Match start, mode introductions, last-man-standing, game-over and winner voices are disabled; ordinary CTF has no objective voice. First blood is global; combo/streak calls are personal. Suicides and team kills do not earn awards. The existing capture fanfare remains alongside the visual notice.

Dedicated servers control calls with `set sv_announcer "1"` (default) or `"0"` in `server.cfg`; policy is sent after each player finishes joining, including map rotations. Client-hosted games enable calls. Settings → Audio → Announcer controls a persistent local volume (default 80%, 0 mutes), independently of effects, music and voice. Calls use a non-positional stereo bus directly to Master, so world occlusion and Steam Audio distance attenuation cannot suppress them. Playback is sequential, with at most four queued calls, six-second expiry and objective priority. No announcer audio is loaded or played on headless servers.

The selected Ogg recordings total about 211 KiB. Credits and CC BY-SA 4.0 terms are in [the source notice](deathmatch/audio/announcer/SOURCES.md). Announcer and chainsaw-contact RPCs use protocol `fpsloppa-26-fortress-effects`; clients and servers must use matching builds.

## Body calibration confirmation

Successful manual or automatic T-pose body calibration plays a local 480 ms
three-note bell cue through `ArenaEffects`, with a short haptic pulse. Holding a
T-pose cannot repeatedly trigger playback. `calibration_complete.wav` and its
standard-library generator `tools/generate_calibration_sound.py` are original
project assets under CC0 1.0. The cue is peak-normalized to −9 dBFS and played at
−10 dB before the user's effects/master volume controls; it is not spatialized
or sent over the network.


Grounded takeoffs play a short boot push-off and exertion grunt; hard landings play a heavier boot impact. Three variants of each use mono positional audio, with 28 m maximum distance, wall occlusion and the selected HRTF/stereo backend. Server-confirmed movement events reach all clients over reliable RPCs, including the jumping player. Held jump, airborne presses, swimming and ordinary stair steps do not repeatedly trigger jump sounds. Map epoch and player spawn serial reject stale events; a server-confirmed newer spawn is accepted even if its state snapshot has not arrived yet. Demo recordings retain these cues. Updated clients and servers must use matching builds.

Validate with `python3 tools/validate_movement_audio.py`: actual character takeoff/landing, movement and pickup regressions, stale event rejection, demo capture, and a dedicated server with two clients hearing one event per takeoff/landing. Headset listening and perceived distance still require an in-device check.

Assault uses Zilly Mike’s public-domain **Mega Destruction**, retaining the XM arrangement and instruments in a 44.1 kHz stereo Ogg conversion mastered to the existing −19 LUFS target. It loops through the same music bus, volume setting and crossfade system. [Original module, attribution and conversion instructions](docs/audio/assault/README.md).

Objective announcements are authoritative events recorded in demos. Retired voice files and their licenses are archived under `docs/audio/retired-announcer/`, excluded from game exports. Older demos containing those event names remain readable; the retired calls are ignored during playback.
