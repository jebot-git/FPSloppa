# DE round calls

Five original phrases synthesized locally with **Piper 1.8.0**, using the stock
`en_US-joe-medium` voice. These are generated speech, not a recording or voice
imitation of the Counter-Strike announcer. No Counter-Strike audio is included.

The [published Joe model card](https://huggingface.co/rhasspy/piper-voices/blob/main/en/en_US/joe/medium/MODEL_CARD)
identifies its [OHF voice dataset](https://github.com/OHF-Voice/voice-datasets) as
CC0. The model card and immutable model/config download URLs and SHA-256 hashes
are retained under `tools/de_announcer/`. The model was used only as an offline
build input and is not shipped with the game. Piper is GPL-3.0 software; it is
not linked, embedded or required at runtime.

The wording and two-note plant confirmation tone were authored for FPSloppa.
Processing uses mild band limiting, compression and -18 LUFS normalization
with a -2 dB true-peak target; mono 44.1 kHz Ogg Vorbis quality 5. The plant cue
has a short ascending electronic chirp before “The bomb has been planted.”
`de-manifest.json` records all phrases, durations and output hashes. The existing
VoiceBosch recordings retain their separate attribution and CC BY-SA license.

Rebuild from the project root with Python/NumPy, FFmpeg, and Piper in an isolated
Python environment:

```sh
python3 tools/de_announcer/generate.py --python /path/to/piper-venv/bin/python --model /path/to/en_US-joe-medium.onnx
```

Keep the matching `.onnx.json` beside the model. Raw generated WAVs are retained
in `tools/de_announcer/source/` so the delivered audio can also be re-encoded
without rerunning synthesis. TTS inference can vary between runs and library versions;
output hashes identify this particular bake.
