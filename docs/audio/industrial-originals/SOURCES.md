# Original tracker soundtrack

Ten original eight-channel tracker scores, composed for FPSloppa:

| Context | Title | BPM | Length | Arrangement |
| --- | --- | ---: | ---: | --- |
| Title / disconnected menu | Dead Air | 68 | 113 s | Slow, corroded drones and distant metal; no drum beat |
| Between-match lobby | Please Hold | 112 | 103 s | Deliberately incongruous elevator jazz, upright piano and flute |
| Deathmatch | Iron Circuit II | 138 | 111 s | Distorted palm-muted riffs and syncopated machinery |
| Team deathmatch | Pressure Lock II | 128 | 120 s | Low guitar march and staggered heavy kicks |
| Capture the flag | Signal Runner | 146 | 105 s | Broken beats with chromatic guitar stabs |
| King of the hill | High Ground | 116 | 132 s | Half-time percussion and sustained dissonance |
| Instagib | Needlepoint | 166 | 93 s | Fast chopped drum accents and clipped industrial riffs |
| Freeze tag | Cryostasis | 104 | 148 s | Sparse crushing drums, low drones and cold metal |
| Chainsaw carousel | Carousel of Teeth | 152 | 101 s | Rapid mechanical chugs and semitone/tritone tension |
| Team Fortress | Breach Protocol | 124 | 124 s | Heavy syncopated siege rhythm and distorted bass |

Outside the lobby, root pedals, unresolved intervals, overdriven recorded bass,
power-fifth guitar, pitched anvil resonance and crushed acoustic drums replace
the earlier bright piano/flute leads and rising chord progressions. Each mode
has its own rhythm, key and arrangement, with an intro, exposed middle, rebuild
and peak. The title remains slow and ambient. The lobby keeps its light lounge instrumentation, with corrected minor/dominant
sevenths, chord-following flute phrases and compact piano voicings.

No existing game soundtrack recordings or melodies are used. The arrangements
are authored in `tools/generate_tracker_music.py`; `scores.json` records mode
assignments, timing, sizes, checksums and mastering measurements. Source MODs
contain eight channels and their compact 8-bit instruments, each below 400 kB.
Godot plays 32 kHz stereo Ogg Vorbis renders (about 8.5 MiB altogether), so a
runtime tracker decoder is unnecessary. Two arranged cycles are rendered and
the second retained for delay tails; 8 ms fades remove sample-boundary clicks.
Gameplay is mastered to −19 LUFS, title −22 and lobby −21, with a −3 dBTP target
before Vorbis encoding. The music volume remains separately configurable.

Selection follows game mode, lobby or title state, with asynchronous loading
and 2.5-second crossfades. A map change within the same mode does not restart the
track. Headless servers load no music resources.

## Recorded instrument sources — CC0 1.0

Karoryfer Lecolds' **Black and Green Guitars**, **Growlybass**, and **Big Rusty
Drums** are available under CC0: [publisher's free sample catalogue](https://shop.karoryfer.com/pages/free-samples).
The guitar was recorded by Brian Wood. Only seven individual source recordings
are used; links below pin their exact upstream revisions.

- `guitar`: [Samples/black/ord/twang_a3_f_rr1.wav](https://github.com/sfzinstruments/karoryfer.black-and-green-guitars/blob/b3b3249d37dc977a1a297bd2dc053e6d9b6b805c/Samples/black/ord/twang_a3_f_rr1.wav)
- `mute`: [Samples/black/stac/staccato_a3_rr1.wav](https://github.com/sfzinstruments/karoryfer.black-and-green-guitars/blob/b3b3249d37dc977a1a297bd2dc053e6d9b6b805c/Samples/black/stac/staccato_a3_rr1.wav)
- `bass`: [sustain/a2_f_rr1.wav](https://github.com/sfzinstruments/karoryfer.growlybass/blob/4f483268fc66b5a6d5781d421c0d11b8d08d3fc6/sustain/a2_f_rr1.wav)
- `kick`: [Samples/kick_24/kick/kick/k_vl4_rr1.flac](https://github.com/sfzinstruments/karoryfer.big-rusty-drums/blob/f07ce00df34a46b6b08375be56fe116cf15782bc/Samples/kick_24/kick/kick/k_vl4_rr1.flac)
- `snare`: [Samples/snare_14/center/top/sn_center_vl4_rr1.flac](https://github.com/sfzinstruments/karoryfer.big-rusty-drums/blob/f07ce00df34a46b6b08375be56fe116cf15782bc/Samples/snare_14/center/top/sn_center_vl4_rr1.flac)
- `hat`: [Samples/hihat_14/cl/cl/ht_cl_vl4_rr1.flac](https://github.com/sfzinstruments/karoryfer.big-rusty-drums/blob/f07ce00df34a46b6b08375be56fe116cf15782bc/Samples/hihat_14/cl/cl/ht_cl_vl4_rr1.flac)
- `crash`: [Samples/crash_17/cr/cl/cr_vl4_rr1.flac](https://github.com/sfzinstruments/karoryfer.big-rusty-drums/blob/f07ce00df34a46b6b08375be56fe116cf15782bc/Samples/crash_17/cr/cl/cr_vl4_rr1.flac)

`samples/source-hashes.json` records upstream file SHA-256 values. The supplied
mono 22.05 kHz WAV snippets are trimmed conversions, not the full libraries.
`tools/prepare_instrument_samples.py` documents preprocessing; pass a directory
with downloaded files named guitar.wav, mute.wav, bass.wav, kick.flac, snare.flac,
hat.flac and crash.flac. With the supplied snippets, `python3 tools/generate_tracker_music.py` regenerates
all MOD/Ogg files (requires Python NumPy and FFmpeg with libopenmpt/libvorbis).
Optional arguments select mode keys, for example `title dm cc`. Actual note fundamentals are 110 Hz for guitar and 55 Hz for
bass; the generator tunes both to the module's C reference. Samples are source
assets and excluded from binary exports.

## Additional recorded instruments — CC0 1.0

[Versilian Community Sample Library / VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE)
provides upright piano, flute, viola ensemble and anvil recordings. Recordings
are by Sam Gossner and Simon Dalzell, with sample cutting by Elan Hickler.
The library is CC0 1.0. `samples/vsco-sources.json` pins the four source URLs to
commit `440300901dfe9275fd84e0b7763af1f8443ae62e`, with original and prepared
SHA-256 checksums. These are individual snippets, not the full library.

To recreate them, download the listed files as `piano.wav`, `flute.wav`,
`strings.wav`, and `anvil.wav`, then run
`python3 tools/prepare_instrument_samples.py /path/to/downloads --vsco`.
Preparation retains the first six seconds (or the whole shorter file), removes
metadata and converts to mono 22.05 kHz signed 16-bit PCM. Actual reference
fundamentals are approximately 277.18 Hz for this piano sample and 523.25 Hz for
flute and strings. The tracker generator handles tuning, envelopes, reversed
guitar tails, distortion, fifth layering and pitched metal resonances.

Run `python3 tools/validate_soundtrack.py` to check decoded loudness, true peaks,
loop boundaries, durations and prepared VSCO source checksums. Results are
written to `test-results/soundtrack-analysis.json`.

The original compositions, arrangements, edited instruments and rendered music
are dedicated under **CC0 1.0 Universal**, matching the recordings' license:
https://creativecommons.org/publicdomain/zero/1.0/ . This applies to these music
assets, not the whole game.
