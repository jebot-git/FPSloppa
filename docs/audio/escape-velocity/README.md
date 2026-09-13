# Escape Velocity

Original instrumental audition for FPSloppa: **136 BPM, 4/4, 1:56**, centred on E minor. Chopped breakbeats, distorted recorded guitar, syncopated electric bass, viola swells, a quiet electronic arpeggio and short guitar-scrub effects. The right/left guitar parts use separate recorded takes.

- [Listen — MP3](Escape-Velocity.mp3)
- [Compact Ogg Vorbis](Escape-Velocity.ogg)
- [44.1 kHz stereo WAV master](Escape-Velocity.wav)
- [Editable event score and audio validation](score.json)

The finite audition is retained here. A revised looping arrangement is now selected for **TB / Titanball** in the game.

## Reference and comparison

Requested broad reference: Apollo 440's **Lost In Space (Theme)**. The search located [the official Apollo 440 Topic upload, provided by Epic](https://www.youtube.com/watch?v=wQJlyQykD38). The upload credits two drummers, bass and scratches. No reference audio, melody transcription, film dialogue or extracted reference stems were used in the composition. The new riff, melody, chord progression and arrangement were written in the generator.

A temporary copy of that upload was used for **signal-level comparison**, not a claimed human listening evaluation. The comparison measures spectral energy distribution, onset-based tempo candidates, RMS dynamics and stereo correlation. The reference's tempo candidates were ambiguous, so the original composition keeps its deliberately chosen 136 BPM rather than treating the strongest autocorrelation peak as a verified tempo.

The first draft had too much sub/bass energy and too little presence/treble relative to the reference. The revised mix reduces kick and bass weight, brings forward the snare/hat/crash, raises guitar/string presence and adds original scrubbed-guitar accents. See [first-draft measurements](first-draft-comparison.json) and [revised measurements](reference-comparison.json). No reference audio is included in this folder or the game distribution.

## Arrangement

| Time | Section |
| --- | --- |
| 0:00 | Ignition: restrained drums, filtered texture and guitar accents |
| 0:14 | Main drive: breakbeat, low-string riff and original lead hook |
| 0:42 | Orbital breakdown: strings, bass and sparse percussion |
| 0:56 | Rebuild: rhythmic layers return |
| 1:11 | Full thrust: complete arrangement with octave string accents |
| 1:39 | Exit burn, ending on E and a decaying tail |

## Reproduce and validate

```sh
python3 tools/compose_escape_velocity.py
# Optional: compare with a locally available reference recording.
python3 tools/compare_escape_velocity.py /path/to/reference-audio
```

Requires Python, NumPy and FFmpeg. The generator records the note/event score, measured guitar tuning, file hashes, duration, integrated loudness, true peak and stereo correlation. It validates finite decoded PCM, no clipping, and approximately −18 LUFS across WAV/MP3/Ogg. The master targets −2 dBTP, with post-encoding peak verification.

The arrangement is rendered from the project's existing CC0 samples: Karoryfer Black and Green Guitars, Growlybass and Big Rusty Drums, plus VSCO 2 CE viola ensemble. Exact source URLs and hashes are retained in [the metal sample manifest](../metal-alternates/sources.json) and [the VSCO sample manifest](../../../deathmatch/audio/music/samples/vsco-sources.json); all used prepared samples matched those checksums. See [full source credits](../../../deathmatch/audio/music/SOURCES.md). Original composition and arrangement follow the project's CC0 music dedication. The reference recording has its own copyright and is not part of that dedication.

## Titanball looping version

[Listen to the game loop](Escape-Velocity-Loop.ogg) · [Audition its exact end/start transition](loop-boundary.ogg)

The game version runs for 64 bars / 112.941 seconds and keeps the full groove at
the beginning and end. Its final B chord leads into E on repeat, with instrument
and effect tails wrapped into the start. Sub-beat edge ramps suppress codec
clicks; there is no outro fade or inserted silence. It is mastered to −19 LUFS
to match the other gameplay tracks. Both TF's existing track and the original
1:56 finite audition are retained.

Regenerate and install with `python3 tools/generate_tb_music.py --install`.
[Loop score and measurements](loop.score.json) include the exported asset hash.
Runtime assets are `deathmatch/audio/music/escape_velocity.ogg` and its score;
the player selects this stem only for TB.
