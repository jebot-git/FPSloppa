"""Bake short DE radio calls using the CC0 Joe Piper voice; no runtime TTS."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
CUES = {
    'de_terrorists': 'You are terrorists.',
    'de_counter_terrorists': 'You are counter terrorists.',
    'de_terrorists_win': 'Terrorists win.',
    'de_counter_terrorists_win': 'Counter terrorists win.',
    'de_bomb_planted': 'The bomb has been planted.',
}
FILTER = 'highpass=f=140,lowpass=f=6500,acompressor=threshold=0.15:ratio=3:attack=5:release=80,loudnorm=I=-18:TP=-2:LRA=5,aresample=44100'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python', required=True, help='Python with piper-tts installed')
    parser.add_argument('--model', type=Path, required=True)
    args = parser.parse_args()
    work = ROOT / 'tools/de_announcer/source'
    out = ROOT / 'deathmatch/audio/announcer'
    work.mkdir(exist_ok=True)
    rows = []
    for cue, text in CUES.items():
        raw = work / (cue + '.wav')
        subprocess.run([args.python, '-m', 'piper', '-m', str(args.model), '-f', str(raw), '--length-scale', '.91', '--noise-scale', '.45', '--noise-w-scale', '.6'], input=text + '\n', text=True, check=True, cwd=work)
        (work / ':memory:.ses').unlink(missing_ok=True)  # ONNX Runtime's local telemetry scratch file.
        source = raw
        if cue == 'de_bomb_planted':
            # Distinct short confirmation chirp leads the global spoken call.
            with wave.open(str(raw)) as w:
                rate = w.getframerate()
                samples = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2')
            chirp = np.zeros(round(rate * .32))
            for offset, freq in [(0, 740), (.105, 1110)]:
                t = np.arange(round(rate * .09)) / rate
                tone = .19 * np.sin(2 * np.pi * freq * t) * np.sin(np.pi * t / .09) ** 2
                i = round(rate * offset)
                chirp[i:i + len(t)] = tone
            mixed = np.concatenate(((chirp * 32767).astype('<i2'), samples))
            source = work / (cue + '-chime.wav')
            with wave.open(str(source), 'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(mixed.tobytes())
        target = out / (cue + '.ogg')
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(source), '-af', FILTER, '-ac', '1', '-c:a', 'libvorbis', '-q:a', '5', '-metadata', 'title=' + text, '-metadata', 'comment=Generated DE cue; Piper en_US-joe-medium (CC0 dataset); see DE-SOURCES.md', str(target)], check=True)
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'quiet', '-show_format', '-show_streams', '-of', 'json', str(target)]))
        rows.append({'cue': cue, 'text': text, 'duration': float(probe['format']['duration']), 'sample_rate': int(probe['streams'][0]['sample_rate']), 'channels': probe['streams'][0]['channels'], 'bytes': target.stat().st_size, 'source_sha256': hashlib.sha256(raw.read_bytes()).hexdigest(), 'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    (out / 'de-manifest.json').write_text(json.dumps({'engine': 'Piper 1.8.0', 'voice': 'en_US-joe-medium', 'length_scale': .91, 'noise_scale': .45, 'noise_w_scale': .6, 'processing': FILTER, 'cues': rows}, indent=2) + '\n')
    print(json.dumps(rows, indent=2))


if __name__ == '__main__':
    main()
