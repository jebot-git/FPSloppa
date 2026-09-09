# Original tracker soundtrack

Four original industrial arena-shooter compositions:

- **Iron Circuit** — 146 BPM, 105 seconds.
- **Pressure Lock** — 132 BPM, 116 seconds.
- **Foundry Run** — 154 BPM, 100 seconds.
- **Dark Relay** — 126 BPM, 122 seconds.

The first two retain their original compositions. All four now use recorded
electric guitar, electric bass and acoustic drums, with edited power-fifth guitar
samples, restrained distortion and a picked guitar lead. No existing songs or
melodies were sampled. Arrangements are authored in `tools/generate_tracker_music.py`.
Each self-contained ProTracker MOD is 52,880 bytes, including its 8-bit instruments.
The four 32 kHz stereo Vorbis renders total 2,794,392 bytes (2.67 MiB), normalized
to approximately −18 LUFS / −2 dBTP with FFmpeg/libopenmpt. Godot uses these renders
on every platform; no runtime tracker decoder is required. Map changes crossfade
between scores. Settings → Audio → Music saves a separate volume, initially 30%.

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
hat.flac and crash.flac. Then `python3 tools/generate_tracker_music.py` regenerates
all MOD/Ogg files. Actual note fundamentals are 110 Hz for guitar and 55 Hz for
bass; the generator tunes both to the module's C reference. Samples are source
assets and excluded from binary exports.

The original compositions, arrangements, edited instruments and rendered music
are dedicated under **CC0 1.0 Universal**, matching the recordings' license:
https://creativecommons.org/publicdomain/zero/1.0/ . This applies to these music
assets, not the whole game.
