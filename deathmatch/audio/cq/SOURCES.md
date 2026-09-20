# Conquest: Vesper audio

Original FPSloppa arrangements and environmental synthesis, dedicated to CC0-1.0.
No reference-film audio, melodies, recordings or artist performances are included.

* **Iron Vespers** — 144 BPM, 64 bars, 1:46.667. Brass-led orchestral action:
  antiphonal spiccato strings, a modal horn theme, trumpet responses, low brass,
  timpani, concert bass drum, marching snare and cymbals. The requested reference
  was Basil Poledouris's broad orchestral action vocabulary.
* **Standards at Dusk** — 72 BPM, 24 bars, 1:20. A restrained military orchestral
  variation: soft horn, sustained strings, subdued snare and concert bass drum.
* Eleven **64-second environmental loops** cover cathedral, bastion, arcology,
  data, docks, foundry, garden, market, observatory, reactor and transit districts.
  These use original filtered wind/air noise, ventilation, electrical hum, distant
  mechanical traffic and sparse metal resonance. No music or intelligible speech.

The score uses real individual instrument recordings from **VSCO 2 Community
Edition**, recorded by Sam Gossner and Simon Dalzell, with sample cutting by Elan
Hickler / Soundemote. The publisher licenses these recordings under CC0:
https://versilian-studios.com/vsco-community/
https://github.com/sgossner/VSCO-2-CE

Exact sample paths, SHA-256 hashes and pinned upstream commit are in
`tools/cq_audio/samples.json`; the original license is `VSCO-LICENSE.txt` beside
this file and under `tools/cq_audio/`. Source recordings are build inputs fetched
by `tools/cq_audio/fetch_samples.py`, not runtime assets. No paid service is needed.

Rebuild with Python, NumPy and FFmpeg:

```
python3 tools/cq_audio/fetch_samples.py
python3 tools/cq_audio/render.py
```

The generated score JSON records every pitched event, tempo and bar count.
`manifest.json` records all encoded asset hashes, measured loudness, peaks, loop
boundaries and the complete 81-district theme mapping. Vorbis loops are stereo,
44.1 kHz. Tails/reverb wrap across bar boundaries. Combat is approximately -19
LUFS, menu -27 LUFS, and ambience -35 LUFS, before player volume controls.

Playback is local to the CQ desktop client; no master/worker audio or additional
network messages are required. The main menu provides saved music/ambience
volume sliders. JSON `music_volume` and `ambience_volume` can override them.
