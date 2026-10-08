# Built-in music

**Shadows Awaken Within** (main menu), **Singularity — Calm** (lobby), and the
conditional **Tower Defense Theme — Climax Loop** are bundled.
Gameplay also supports client-owned Ogg music from the external `bgm` folder;
see [AUDIO.md](../../../AUDIO.md) for cue conditions and playlist rules.

## Default mode soundtrack — CC0 1.0

The approved OpenGameArt recordings are bundled under `modes/` as edited stereo
Vorbis loops. Each linked submission lists CC0. All source and output SHA-256
hashes, exact trim/overlap points, durations and loudness measurements are in
[`modes.json`](modes.json).

| Mode | Recording | Creator |
| --- | --- | --- |
| DM | [Silver Bullet](https://opengameart.org/content/silver-bullet) | vitalezzz |
| TDM | [Brute Force, loop version](https://opengameart.org/content/brute-force) | vitalezzz |
| CTF | [Chase](https://opengameart.org/content/chase-2) | Adiutorium |
| KOTH | [Open Warfare, original](https://opengameart.org/content/open-warfare) | Ruskerdax |
| IG | [Final Hour](https://opengameart.org/content/final-hour) | isaiah658 |
| IF | [Black Diamond](https://opengameart.org/content/black-diamond) | Joth |
| FT | [Energetic Electro Tune](https://opengameart.org/content/energetic-electro-tune) | TinyWorlds |
| CC | [Megasong](https://opengameart.org/content/megasong) | Emma_MA |
| TF | [Devoted Guard](https://opengameart.org/content/devoted-guard) | vitalezzz |
| TB | [The 9th Circle](https://opengameart.org/content/the-9th-circle) | Joth |
| AS | [Fight for Better Future](https://opengameart.org/content/fight-for-better-future-rockmetal) | nene |
| DE | [Infiltration](https://opengameart.org/content/infiltration) | Adiutorium |
| ST | [Singularity, Action version](https://opengameart.org/content/singularity-0) | vitalezzz |

Rebuild with `python3 tools/prepare_mode_music.py` (FFmpeg and NumPy). Original
downloads are cached in `~/.cache/fpsloppa-oga-mode-music`, outside exports. Once
recorded, source hashes are checked before processing; changed upstream files
are rejected. `--only dm tdm` rebuilds selected modes. Edits remove near-silent
edges, circularly overlap full songs by 2.5 seconds (40 ms for authored loops),
and apply constant gain toward −22 LUFS / −25 for DE, with −4 dBTP headroom before
Vorbis encoding. No generated instrumentation is added. These edits remain CC0.

`python3 tools/validate_soundtrack.py` checks decoded duration, finite PCM,
loop-boundary steps, loudness, true peaks and hashes. Native playback/overrides
and ambience transitions are checked by `deathmatch/tests/default_mode_music.gd`,
`music.gd`, and `climax_music.gd`.

## Tower Defense Theme — CC0 1.0

Original by **DST (Deceased Superior Technician)**, published December 10, 2012:
[OpenGameArt source and CC0 license](https://opengameart.org/content/tower-defense-theme),
[original MP3](https://opengameart.org/sites/default/files/DST-TowerDefenseTheme_1.mp3).

The FPSloppa edit uses exactly **95–170 seconds** of that recording. A
1.153854-second raised-cosine overlap blends the tail into the opening, keeping
the 130 BPM beat phase. First playback includes the original buildup; the
runtime then repeats from 1.153854 seconds, for a 40-bar / 73.846146-second loop.
Linear loudness adjustment preserves the source's dynamics; the encoded render
measures −19.06 LUFS and −7.18 dBTP. No generated instruments were added.

`climax.json` records source/render SHA-256 hashes, exact edit points, loop
offset, measurements and attribution. Regenerate with
`python3 tools/prepare_climax_music.py /path/to/DST-TowerDefenseTheme_1.mp3`.
The tool requires FFmpeg and NumPy and checks the original download's hash.
`python3 tools/validate_soundtrack.py` also validates this cue's decoded loop
boundary, duration, loudness, peak and hash. This CC0 edit retains the original
license. The full downloaded MP3 is not bundled.

## Main-menu and lobby themes — CC0 1.0

Both replacements are by **vitalezzz**, approved after OpenGameArt previews:

| Context | Recording | Source audio |
| --- | --- | --- |
| Main menu | [Shadows Awaken Within](https://opengameart.org/content/shadows-awaken-within) | [WAV](https://opengameart.org/sites/default/files/shadows_awaken_within.wav) |
| Lobby | [Singularity — Calm](https://opengameart.org/content/singularity-0) | [WAV](https://opengameart.org/sites/default/files/singularity_calm.wav) |

The OGA pages list CC0. [`contexts.json`](contexts.json) records source/output
hashes, exact trim and loop edits, loudness measurements and durations. Rebuild
with `python3 tools/prepare_context_music.py`; `--only title` or `--only lobby`
limits regeneration. The shared mode pipeline applies constant gain toward
−22 LUFS, trims near-silent edges, and circularly overlaps the title by 2.5 seconds
and the authored lobby loop by 40 ms. These edits remain CC0. Playback uses the
existing Music slider, mute, and context crossfade; custom gameplay playlists
retain their established precedence.

Legacy **Dead Air** and **Please Hold** recordings, MOD sources and `scores.json`
remain in the source tree for historical reproducibility; export presets exclude
them. `tools/generate_tracker_music.py` only regenerates those legacy recordings,
not the active themes. The instrument provenance below applies to those earlier
tracker compositions. Historical material under `docs/audio/` is also excluded.

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
