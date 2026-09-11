# Original FPSloppa soundtrack

Metal instrumentation was selected after an A/B audition. Each gameplay mode
now uses its own original electric-guitar, bass and acoustic-drum arrangement.
Title and lobby keep their previously approved compositions and renders.

| Context | Title | BPM | Length | Arrangement |
| --- | --- | ---: | ---: | --- |
| Title / disconnected menu | Dead Air | 68 | 113 s | Slow dark ambient drones and distant metal |
| Between-match lobby | Please Hold | 112 | 103 s | Light elevator jazz with corrected piano/flute harmony |
| Deathmatch | Iron Teeth | 138 | 111 s | Low E thrash riffs and double-kick accents |
| Team deathmatch | Breach Formation | 128 | 120 s | Low D marching metal and staggered kick rhythm |
| Capture the flag | Redline Relay | 146 | 105 s | Galloping guitars and fast power-chord responses |
| King of the hill | Crowned in Rust | 116 | 132 s | Low C sludge riffs with half-time weight |
| Instagib | Razor Current | 166 | 93 s | Fast F-sharp riffing and tightly clipped notes |
| Freeze tag | Cold Anvil | 104 | 148 s | Low C doom riffs and ringing power chords |
| Chainsaw carousel | Chain Drive | 152 | 101 s | Low D groove, chugs and heavy half-time snare |
| Team Fortress | Siege Engine | 124 | 124 s | C-sharp battle rhythm and open chord accents |

Metal tracks use independent left/right guitar recordings, open and palm-muted
articulations, root/fifth/octave power chords, amp saturation, cabinet-like EQ
and acoustic drums with short room tails. They retain 44.1 kHz stereo detail in
compact Vorbis files. Title/lobby use 32 kHz stereo Vorbis and retain editable
eight-channel MODs. No existing game soundtrack recording or melody is used.

The ten active Ogg files total **15,039,851 bytes (14.34 MiB)**. Gameplay is mastered
to −19 LUFS, title −22 and lobby −21, with a −3 dBTP target before Vorbis encoding.
Loop-edge fades prevent sample-boundary clicks. Selection remains asynchronous,
with 2.5-second crossfades, a separate persistent music volume, and no restart
when only the map changes within the same mode. Headless servers load no music.

## Sources, editing and comparison

- `scores.json` records all active assignments, durations, sizes and hashes.
- Each gameplay `*.score.json` stores its recorded-sample arrangement and matching
  render hash. These replace the previous gameplay MOD sources; they are not
  represented as tracker modules.
- `python3 tools/generate_metal_alternates.py --install` regenerates and installs
  all eight gameplay scores. Optional mode keys render a subset, retaining the
  other previously rendered tracks. NumPy and FFmpeg are required.
- `python3 tools/generate_tracker_music.py title lobby` regenerates only the two
  remaining tracker compositions; its default now selects title and lobby.
- `python3 tools/validate_soundtrack.py` audits all ten active renders.

The three auditioned metal tracks are installed without further audio changes.
The five remaining modes use the same recorded-instrument rendering approach
with distinct keys, tempos, riffs and rhythms. Full recordings, additional guitar
sample URLs, hashes, source notes and A/B previews are in
[the metal score folder](../../../docs/audio/metal-alternates/README.md).
The previous industrial Oggs/MODs and metadata are preserved under
`docs/audio/industrial-originals/`. Comparison/source assets under `docs/` are
excluded from game exports; only the selected active audio is shipped.

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
hat.flac and crash.flac. The supplied snippets allow title/lobby tracker regeneration with NumPy and
FFmpeg/libopenmpt. The metal renderer uses the higher-resolution prepared
recordings documented in the metal score folder. Actual note fundamentals are 110 Hz for guitar and 55 Hz for
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
