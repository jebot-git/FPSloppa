# Spatial audio and mouth animation

## Weapon lifecycle cues (2026-10-01)

The 31-cue `audio/weapon-actions` bank adds chainsaw ready/idle/settle, UT
charge and chamber-loading feedback, rotary/pulse/lightning wind-downs, ST
recovery and support-tool loops, and CS handling/desktop AWP bolt cues.
Existing BFG startup and embedded pump tails stay in their original banks.
CS manual reload gestures retain their event-driven sounds.

Sources were edited through Audacity MCP, then layered and mastered from
recorded machinery, foley, air and liquid. See `deathmatch/audio/weapon-actions/SOURCES.txt`.
Eight nearby positional loop voices supplement the 32 one-shot voices. They
follow the held weapon and Effects settings, cancel on state/life changes,
and clear on map/backend changes, menus and disconnect. Audio feedback
does not change weapon cadence, damage or projectile launch timing.


## Reference revision (2026-09-30)

The first pass sounded too synthetic in the desktop audition. The revision
removes the shared FM/sine sweeps from the mode effects and the pure-tone drones
from ambience. CS now uses separate recorded firearm families; Quake uses
rougher, bandwidth-limited recorded attacks; UT layers metal, pressure and
recorded liquid for bio weapons; Tribes has dedicated shared-arsenal profiles
for blaster/plasma/chaingun/disc/grenade/laser/ELF/mortar/repair/targeting.
Tribes changes affect audio only, retaining Starsiege loadouts and cadence.
The existing Doom/Freedoom bank remains. New sources and hashes are listed in
`deathmatch/audio/modes/SOURCES.md` and `tools/audio-sources/natural-weapons/SOURCES.json`.

Reference study used timestamped frames, decoded waveforms and spectral analysis:

- [UT99 weapons/items](https://www.youtube.com/watch?v=VIS7uEFH4EM): examined
  40–52 s, 63–72 s, 102–115 s and 180–193 s. Keep weapon-specific attack/release
  shapes; avoid one shared pitched motif across shock, bio and launchers.
- [Quake series](https://www.youtube.com/watch?v=HetptHVKbr0): use the Q1 section
  at 24–65 s for the Q1 family, with compact noisy reports and mechanical tails.
  Later Q2–Q4 sections are separate identities.
- [CS 1.6](https://www.youtube.com/watch?v=J5_lCZTexao): examined pistol,
  shotgun and AK sequences at 16–25 s, 58–69 s and 137–148 s. The uploader
  explicitly warns of faulty audio; do not match its absolute level/distortion.
- [Doom II](https://www.youtube.com/watch?v=za6N5mjNmlw): 34–43 s pistol,
  60–70 s shotgun, 88–101 s SSG and 158–168 s plasma establish the contrast
  between short attacks, mechanical actions and sustained energy fire.
- [Tribes weapons](https://www.youtube.com/watch?v=zp46kZ5A_-0) and
  [Starsiege training mission 2](https://www.youtube.com/watch?v=xFxPt05QqaA):
  apply the user's shared-arsenal reference direction to matching weapons only.
  The first title's “2 Weapons” alone does not establish the game as Tribes 2;
  both clips show similar training terrain and weapons. The added clip was
  examined at 55–70 s, 100–115 s, 180–195 s and 270–285 s.
- [Quake TF / TF2 comparison](https://www.youtube.com/watch?v=v5k1nC2PQsw):
  the footage alternates games; keep Quake TF reports with the Q1 family.

Video mixes contain background sound and encoding artifacts; whole-window
spectra are descriptive, not isolated-weapon mastering targets. No reference
audio is sampled or bundled. Measurements do not establish subjective fidelity;
the revised audition still needs listening feedback.

The translocator retains its original flared disc/core meshes, sizes, materials
and receiver. Only the assembly's vertical position moves by 0.10 model units,
leaving its lower surface above the receiver and rails. Three mesh-clearance
assertions cover this, alongside the existing audio tests.

Revision results and before/after auditions are in
`test-results/audio-reference-revision-20260930/`: 158 decoded clips, 357
mode/ambience/geometry assertions, 731 resource assertions and 159 exported
resource checks pass. Custom BGM
continues to suspend ambience, including muted or loading custom playlists.

## Mode identity and map ambience (2026-09-30)

CS weapons now have dedicated reports instead of sharing Doom samples: pistols,
shotguns, SMGs, rifles and heavy weapons are differentiated, knife attacks are
air/metal movement, and USP/M4 suppressors have distinct timbres. Quake gets
coarser mechanical attacks, UT separates bio/shock/flak/plasma and alternate
fire, and Tribes separates discs, energy weapons, heavy launchers and quieter
support emitters. Doom retains the established Freedoom-based reports.

The new bank contains 148 mono clips with bounded variations. It is prewarmed
before play, with no new shot-time file I/O. Peak and firing-cadence energy limits
match the existing weapon budget; changing timbre does not boost the master mix.
HRTF, occlusion, effects volume and the 32-source limit remain in use.

Ten environmental profiles cover tech, Gothic, arena, desert, industrial, coast,
alpine, rain, void and inferno spaces. Known maps select an appropriate profile;
unknown maps inherit their weapon ruleset's character. Two persistent stereo
players crossfade beds, sharing the existing room probes for indoor filtering.
Nearby combat ducks the ambience by 7 dB, leaving tactical cues clear. The beds
follow Effects volume and suspend in menus, loading, the lobby and intermission.

**Matching custom BGM suspends ambience immediately**, including asynchronous
loading, song changes and outgoing custom-track crossfades. Music volume/mute
does not re-enable ambience. An unmatched file in `bgm/` does not suppress the
current map's bed. Matching but unreadable queues retain BGM precedence until a
context change/rescan; ordinary effects and voice are independent.

Sources, licenses and deterministic rebuild instructions:
[mode audio sources](deathmatch/audio/modes/SOURCES.md). The industrial source
was edited/exported through Audacity MCP; the final bank combines licensed
recordings and original procedural layers. Custom music and bundled title/lobby
tracks are unchanged.

Validation covers decoded peak/energy/DC/loop boundaries, all 158 new audio
files, cached variant selection, suppressors, map selection, combat ducking,
menu/lobby suspension, custom-BGM precedence, music loading, HRTF/voice playback
and clean shutdown. An audition reel and per-clip measurements are under
`test-results/audio-refresh-20260930/`. The reel is dry stereo; headset listening
is still required to assess the final timbre and perceived environment balance.

Final checks: 354 mode/ambience assertions, 44 custom-music assertions, 731
effect-resource assertions, and all 158 clips in the decoded-audio review pass.
The Linux client PCK also passes 159 resource/duration checks plus variant
routing from an isolated project, exercising exported import remaps. The
existing HRTF/voice regression passes, including its 960-source lifecycle run.

## Existing gameplay feedback

The last ten seconds of an active round have one short clock tick per second, routed through Effects volume. Lobby, loading and intermission suppress the cue; small timer corrections cannot replay a second's tick. `deathmatch/audio/round_tick.wav` is an original CC0 mechanical tick generated by `tools/generate_clock_tick.py`.

Doom weapons use edited Freedoom effects for a punchier classic Doom-style sound: pistol and chaingun share a report, shotguns have mechanical reload tails, and rockets, plasma, BFG, chainsaw and explosions use short recognizable effects. Railgun, melee and recorded footsteps retain their existing sounds. Pickup arpeggios are replaced with short mechanical clicks, clunks and foley. Sources and licenses: `deathmatch/audio/doom-style/SOURCES.md` and `deathmatch/audio/recorded/SOURCES.md`. Regenerate with `python3 tools/prepare_arena_sfx.py` (ffmpeg required).

Weapon audio uses measured per-stream **boosts and cuts** across all five arsenals,
including alternate takes, flamethrower, reloads and weapon impacts/explosions.
The 170 live clips are enumerated through the real mixer; full resource paths
prevent identically named sounds in different banks from sharing the wrong gain.
The source waveforms and their timbre are unchanged. Normal reports target
−17 dBFS for their loudest 50 ms RMS window, constrained by a −3 dBFS
four-times-oversampled peak ceiling and −17 dBFS energy per firing cycle.
This brings the measured report-body spread from 10.5 dB down to 2.8 dB before
the normal −4 dB shot playback level and positional attenuation. Melee, repair,
targeting, reload and bounce cues have separate quieter role targets.

CS suppressors use −10 dB playback (6 dB below ordinary reports), replacing the
previous −16 dB setting; other CS alternate actions no longer receive that
suppressor reduction. Flamethrower uses the shared −4 dB shot level and its own
cadence calibration. The Effects bus has a zero-makeup, −3 dB hard limiter to
catch overlapping shots before room reverb. Individual reports keep their
dynamics; music and voice do not pass through this effects limiter. Master and
Effects preferences still control the result.

Regenerate `deathmatch/audio/weapon_levels.gd` with
`python3 tools/balance_weapon_audio.py` after changing sounds or cadence;
`--check` verifies the saved gains. `build_mode_audio.py` runs calibration after
authoring, and `review_mode_audio.py` includes runtime gains in its audition.
This is short-effect RMS/peak normalization, not perceptual LUFS mastering;
headset listening remains a device check. Before/after measurements and playback
checks are in `test-results/weapon-levels-20260930/`. The overlap test mixes eight
loud voices and verifies the captured effects bus stays at the −3 dB ceiling.

Combat sounds share a 32-source spatial mixer, using Steam Audio HRTF by default or selectable Godot stereo spatialization. Mono point sources use inverse-distance attenuation, distance filtering, and 10 Hz collision ray tests for wall occlusion. Obstructed sources lose 10 dB and are low-pass filtered. Five room probes twice per second adjust a shared diffuse reverb. HRTF supplies directional headphone cues; room acoustics remain an approximation without diffraction or physically traced reverberation.

Confirmed player hits also produce a short attacker-only click through Effects volume. Surface contacts use distinct dust/chip, energy and heavy-impact cues; flesh and pain retain the recorded variants. The new cues are original deterministic mono PCM generated and cached by `deathmatch/audio/impact_sounds.gd`. Nearby shotgun contacts coalesce, impact audio is rate-limited, and repeated pain grunts have their own cooldown.

Voice playback now comes from each speaker's avatar head, with the same distance/occlusion processing and a 45 metre range. Transport still relays to all joined players. Mute and volume controls continue to apply. Dedicated servers only relay audio.

Local mouth motion uses TwoVoIP’s processed speech, resampled to 16 kHz for analysis. A lightweight spectral/energy estimate produces weights for VRM `aa`, `ih`, `ou`, `ee`, `oh` expressions (and VRM 0 `a/i/u/e/o` aliases). Actual bindings are read from the imported VRM expression animations, allowing custom mesh/morph names. A bounded square-root response makes quiet speech visible on subtle morph targets. The lobby mirror receives the same speech weights independently of hidden first-person meshes, and clears them after speech stops. Remote mouth motion follows the native Opus playback amplitude; attack/release smoothing and silence timeout close the mouth. Muted streams discard pending animation, and dead avatars do not talk visually. No extra face packets, speech service or transcription are involved. This is approximate audio-driven vowel animation, not phoneme recognition or facial tracking. Models without these declared expressions remain usable but have no corresponding mouth motion.

Validation: tests load and animate all five expression bindings on all three default VRMs, check silence and loss recovery, exercise native/OSC body poses, verify audio asset loading and real physics-wall occlusion, and confirm received speech creates a positional source with native Opus playback. Local ENet tests cover voice relay, invalid packets, mute and server policy. Headset listening, acoustic quality and lip-sync latency need human/device evaluation.

## Mixer and custom music

**SETTINGS… → AUDIO** retains independent master, effects, music, announcer and
voice levels. Music uses `ArenaMusic`, including its existing −12 dB trim and
5% volume steps, matching Master, Effects, Announcer and Voice. Muting it does not affect effects or voice.

The title screen always plays internal **Dead Air**; the lobby always plays
internal **Please Hold**. Gameplay normally has map ambience when no custom
track matches; matching ordinary custom BGM suspends it. A conditional climax
cue, **Tower Defense Theme** by DST (CC0), blends in over 2.5 seconds as ambience
fades away, and fades back to ambience when the condition ends. It uses the
original's 1:35–2:50 section, with the buildup on entry and a 40-bar repeat at
130 BPM. Music stays on the Music slider in desktop and VR.

| Climax condition | Who hears it |
| --- | --- |
| ST, CTF, TF: carrying a flag | The carrier |
| DM, IG, CC: exactly one frag below the frag limit | That player |
| TDM: exactly one team frag below the limit | That team |
| IF: one freeze-round point below the limit | That team |
| TF: one capture below the capture limit | That team |
| TB: titan strictly less than 10 metres from its delivery base | Everyone, including spectators |
| AS: first objective completed in the current assault leg | Everyone, including spectators |
| DE: bomb planted during the live round | Everyone, including spectators |

TF and IF use their actual victory counters rather than individual kill totals.
Flag drops/deaths/captures, score reductions, objective/round resets, assault
role changes, intermissions and disconnects release the appropriate cue. A dead
teammate still hears a team cue. Ordinary spectators do not inherit a player's
personal or team cue. TB checks current 3D distance, not historical progress.

Put **Ogg Vorbis `.ogg` files** in `bgm/` beside the desktop game executable.
The folder is provided empty in PC downloads and created on client startup if
missing. Source runs use the project folder; standalone Android uses
`/sdcard/Android/data/<game package>/files/bgm/`. An explicit `--asset-root`
relocates `bgm/` alongside `maps/` and `vrm/`.

| Name inside `bgm/` | Plays during |
| --- | --- |
| `01_song.ogg`, `02_song.ogg` | Any gameplay mode without a more specific playlist |
| `dm_01.ogg`, `dm_02.ogg` | DM only |
| `st_01.ogg`, `tf_01.ogg`, `de_01.ogg` | The named mode only |
| `de_dust2_rebuilt.ogg` | That map only |
| `de_dust2_rebuilt_01.ogg`, `de_dust2_rebuilt_02.ogg` | Multiple tracks for that map |
| `st/` containing OGG files | ST only |
| `de_dust2_rebuilt/` containing OGG files | That map only |
| `tf.m3u` or `de_dust2_rebuilt.m3u` | Local OGG files listed for that mode/map |
| `win_01_song.ogg` | Any climax cue without a more specific win playlist |
| `win_st_01.ogg`, `win_dm_01.ogg` | Climax cues in the named mode |
| `win_ctf_raindance_01.ogg` | Climax cues on that map |
| `win_st/` or `win_ctf_raindance/` | OGG files for that mode/map's climax cues |
| `win_tf.m3u` or `win_ctf_raindance.m3u8` | Local playlist replacing that mode/map's climax cue |

Map playlists take priority over mode playlists, which take priority over the
unprefixed global playlist. Recognized map names are the client's map IDs (the
BSP filename without `.bsp`); these are matched before mode prefixes. Mode IDs
are `dm`, `tdm`, `ctf`, `koth`, `ig`, `if`, `ft`, `cc`, `tf`, `tb`, `as`, `de`, `st`.

During a climax cue, matching **`win_` map → mode → global** playlists take
priority. If none match, the ordinary custom BGM continues without restarting;
only when neither matches does the bundled theme play. Outside a cue, `win_`
files are excluded from ordinary playback. The prefix is case-insensitive;
the remaining name follows the same rules. A `win_` file inside a regular
mode/map folder retains that folder's scope. Win folders apply their scope to
all contained files. M3U entries inherit the playlist's scope, so deliberately
listing a win-named file in an ordinary playlist still plays it there.
Win replacements crossfade with ambience when there is no ordinary custom BGM.

All matching files at the selected priority combine into one repeating queue,
sorted by filename, case-insensitively with numeric order (`2` before `10`).
Files in named mode/map folders, including nested albums, inherit that folder's
scope. Unnamed/general subfolders are not scanned, but playlists can reference
them. Duplicated playlist references play once per queue.

M3U and M3U8 support local relative paths (relative to the playlist) and absolute
paths, comments, UTF-8 BOM, and Windows or Unix line endings/path separators.
Their OGG entries are **sorted by filename**, rather than by the written line
order. Remote URLs, missing files and non-OGG entries are ignored. Unreadable
OGG files are skipped; an entirely unreadable queue is silent.

Folders are rescanned when entering gameplay or changing mode/map, not when a
climax condition changes. Restart the
client or change map after editing the collection. The same selected playlist
continues across map changes; changing playlists starts from its first file.
Audio loads on a worker thread with just one upcoming track prefetched.
Context changes crossfade over 2.5 seconds. Track completion advances to the
next song, and the last song wraps to the first. Client music is never sent to
the server, copied into releases or changed by the installer.

Built-in track sources and license: [music credits](deathmatch/audio/music/SOURCES.md).


## Steam Audio spatialisation (0.3v)

[godot-steam-audio 0.3.1](https://github.com/stechyo/godot-steam-audio/releases/tag/0.3.1), using Valve Steam Audio 4.8.0, is bundled for Linux x86-64, Windows x86-64 and Android arm64/x86-64. Effects use its binaural HRTF and distance attenuation. Incoming voice uses TwoVoIP on native Godot positional players. The listener follows the actual desktop camera or XR headset, including head rotation and room-scale movement. Music and local feedback stay on their normal non-positional buses. Steam/SteamVR accounts are not required; WiVRn and native SteamVR use the same audio path.

**Settings → Audio → Spatial Audio** switches between Steam Audio HRTF (headphones) and standard stereo spatialisation. Volume controls continue to work. Runtime failure to load the extension uses the standard player implementation. Headless servers do not create a listener or audio simulation. CPU HRTF is used, with full acoustic reflection simulation disabled to keep VR frame costs bounded; existing collision ray tests provide muffling through walls and moving doors, with lightweight room reverb.

The bundled extension includes local fixes for concurrent sound-source creation/destruction, native effect cleanup, and Android 16 KiB page alignment. Point sounds use direct binaural convolution. Reference-distance gain is normalized to unity within 5 metres for effects and 3 metres for voice: the SDK's raw `1 / max(distance, minimum)` formula otherwise reduced nearby effects by roughly 14 dB. The source patches and build instructions are included with the addon. Automated checks compare backend loudness, ear direction, streaming voice, and rapid source destruction; the live WiVRn probe also exercised microphone capture and local ENet voice replay.

The adapter keeps one listener/config alive across map changes and matches the plugin's DSP allocation to Godot's 512-frame mixing blocks. Positional one-shots have explicit lifetimes because the upstream stream wrapper does not finish itself. Current voice bypasses that inner-player lifecycle and uses TwoVoIP’s native Opus stream directly. Tests capture stereo output, verify finite samples and left/right reversal when the listener turns, and exercise streamed voice through the native wrapper.

Doppler tracking is enabled on positional effects/voice players and the actual desktop or XR camera. Godot computes the pitch shift from source/listener motion; the Steam Audio stream forwards that playback rate through its HRTF mixer. Standard stereo fallback uses the same tracking. `deathmatch/tests/audio_doppler.gd` captures mixed output with a real audio driver: a stationary 660 Hz tone remains near 660 Hz, approaching at 60 m/s rises to about 799 Hz, and receding falls to about 564 Hz. Moving the listener also shifts pitch. Optical scope cameras do not act as listeners. Live headset listening remains a device check.

Licenses, upstream archive checksum and runtime notices are under `addons/godot-steam-audio/`. The plugin is MIT, Steam Audio Apache-2.0, and its bundled third-party runtime notices are in `THIRDPARTY.md`.

## Combat and item feedback (0.3v)

Recorded pain grunts rotate between three short takes; local feedback is limited to one cue per 300 ms. Player respawns have a stronger teleport cue. Megahealth, mega armour and BFG availability transitions play a positional powerful-item cue once, replicated reliably to clients. Ordinary item respawns stay quiet. Health, armour, ammunition, weapons and mega pickups have distinct short cues with recorded metallic transients. All use the effects bus and its volume control.

The retained title/lobby arrangements use Karoryfer and VSCO instruments, with source credits accompanying the music. Gameplay uses the custom music system described above. Chainsaw contact adds a short spatial grinding cue derived from the existing CC0 Kenney metal impact, with throttled sparks and VR haptics on world contact or a successful blade parry.

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


Grounded takeoffs play a short boot push-off and a distinct 160 ms exertion vocal, using separate recordings from the longer pain grunts; hard landings play a heavier boot impact. Three variants of each use mono positional audio, with 28 m maximum distance, wall occlusion and the selected HRTF/stereo backend. Server-confirmed movement events reach all clients over reliable RPCs, including the jumping player. Held jump, airborne presses, swimming and ordinary stair steps do not repeatedly trigger jump sounds. Map epoch and player spawn serial reject stale events; a server-confirmed newer spawn is accepted even if its state snapshot has not arrived yet. Demo recordings retain these cues. Updated clients and servers must use matching builds.

Validate with `python3 tools/validate_movement_audio.py`: actual character takeoff/landing, movement and pickup regressions, stale event rejection, demo capture, and a dedicated server with two clients hearing one event per takeoff/landing. Headset listening and perceived distance still require an in-device check.

Historical Assault music source material is archived in [docs/audio/assault/](docs/audio/assault/README.md) and is not bundled as runtime BGM.

Objective announcements are authoritative events recorded in demos. Retired voice files and their licenses are archived under `docs/audio/retired-announcer/`, excluded from game exports. Older demos containing those event names remain readable; the retired calls are ignored during playback.

## Round-end gong

`deathmatch/audio/round_gong.wav` is an original 5.5-second procedural bronze gong, generated by `tools/koth/generate_gong.py` and dedicated to CC0. It uses the ArenaEffects bus at −6 dB and plays once when the server ends a match, including a KOTH score or time limit. The gong is independent of announcer speech and follows effects volume. Its authoritative event includes the map epoch so stale-map events are ignored.
