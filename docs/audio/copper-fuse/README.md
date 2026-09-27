# Copper Fuse — orchestral DE revision

Original 102.4-second, 64-bar orchestral action cue at **150 BPM**, in D minor.
The arrangement uses short cello/violin ostinati, sustained string triads, horns,
trumpet accents, flute, orchestral snare, low drum, cymbals and tuned timpani.
A coordinated Dm–B♭–Gm–Dm–A progression replaces the previous mixed electronic,
sax and steel-pan arrangement. Melodies, rhythm programming and arrangement are
original; no soundtrack recording or transcribed theme is included.

**Open `Copper-Fuse-Orchestral.xm` directly in MilkyTracker.** This is a real
24-channel XM module with 16 patterns and 10 embedded instruments, verified by
loading and playing it in the local MilkyTracker installation. The module is the
editable score. Its instrument tuning, note releases and pan settings are part
of the module; the game render adds a short circular hall ambience and loudness
normalization. Editing the XM does not automatically replace the game OGG.

- Runtime: `deathmatch/audio/music/copper_fuse.ogg`, 44.1 kHz stereo Vorbis.
- Editable module: `docs/audio/copper-fuse/Copper-Fuse-Orchestral.xm`.
- Event manifest: `deathmatch/audio/music/copper_fuse.score.json`.
- Recompose and render: `python3 tools/generate_de_music.py --install`.
- Dependencies: NumPy and FFmpeg with `libopenmpt` and Vorbis support.
- Generator: `tools/compose_de_orchestral.py`; rerunning it overwrites the XM.
- Measured: −20.0 LUFS, −7.48 dBTP, decoded seam step 0.0006104.
- Loop audition: `test-results/defusal/copper-fuse-boundary.wav`.

CC0 cello, violin, horn, trumpet, orchestral snare and timpani recordings come
from [VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE), credited to
Sam Gossner and Simon Dalzell, with sample cutting by Elan Hickler. Existing
project strings, flute, kick and crash retain their
[documented sources](../../../deathmatch/audio/music/SOURCES.md).
Older VCSL sax/bongo and other prepared samples remain in the source archive for
the earlier revision, but are not used in this orchestral module.

`samples/sources.json` pins upstream commits, URLs and original/prepared hashes;
`samples/*-LICENSE.txt` preserves the CC0 licenses. The original composition,
arrangement and render use the soundtrack's CC0 1.0 dedication. Normal in-game
music volume and the existing 2.5-second mode crossfade apply.
