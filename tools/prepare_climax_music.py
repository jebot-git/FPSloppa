"""Remix DST's CC0 Tower Defense Theme, 1:35–2:50. Requires numpy and FFmpeg.

Usage: python3 tools/prepare_climax_music.py /path/to/DST-TowerDefenseTheme_1.mp3
The source hash pins the exact OGA download; the runtime uses the authored loop
start in climax.json. The first pass retains the buildup; subsequent passes
repeat 40 bars at 130 BPM, with a phase-aligned overlap instead of a hard cut.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'deathmatch/audio/music'
SOURCE_SHA = '07cc9cd797c8ea6738b1bd740526f2610fd2ec0115774294ebda3a5ed8e62a30'
RATE = 48000


def measure(path):
    run = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(path), '-af',
                          'loudnorm=I=-19:TP=-3:LRA=10:print_format=json',
                          '-f', 'null', '-'], capture_output=True, text=True, check=True)
    return json.JSONDecoder().raw_decode(run.stderr[run.stderr.rfind('{'):])[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    if hashlib.sha256(args.source.read_bytes()).hexdigest() != SOURCE_SHA:
        raise SystemExit('Source hash does not match the credited OGA original')
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(args.source),
                                   '-ss', '95', '-t', '75', '-ar', str(RATE), '-ac', '2',
                                   '-f', 'f32le', '-'])
    samples = np.frombuffer(raw, dtype='<f4').reshape(-1, 2).copy()
    assert len(samples) == 75 * RATE and np.isfinite(samples).all()
    period = round(40 * 4 * 60 / 130 * RATE)
    overlap = len(samples) - period
    weight = (.5 - .5 * np.cos(np.linspace(0, np.pi, overlap)))[:, None]
    samples[-overlap:] = samples[-overlap:] * (1 - weight) + samples[:overlap] * weight
    dest = OUT / 'tower_defense_climax.ogg'
    with tempfile.TemporaryDirectory(prefix='fpsloppa-climax-') as tmp:
        work = Path(tmp) / 'edit.wav'
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-f', 'f32le', '-ar', str(RATE),
                        '-ac', '2', '-i', '-', '-c:a', 'pcm_f32le', str(work)],
                       input=samples.astype('<f4').tobytes(), check=True)
        stats = measure(work)
        gain = min(-19 - float(stats['input_i']), -3.5 - float(stats['input_tp']))
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(work), '-af',
                        f'volume={gain:.6f}dB', '-map_metadata', '-1', '-c:a', 'libvorbis',
                        '-q:a', '5', '-metadata', 'title=Tower Defense Theme — Climax Loop',
                        '-metadata', 'artist=DST (Deceased Superior Technician)',
                        '-metadata', 'comment=CC0; FPSloppa edit of 95–170s; loop offset 1.1538541667s',
                        str(dest)], check=True)
    final = measure(dest)
    row = dict(key='win', stem=dest.stem, title='Tower Defense Theme — Climax Loop',
               author='DST (Deceased Superior Technician)', license='CC0-1.0',
               source_url='https://opengameart.org/content/tower-defense-theme',
               download_url='https://opengameart.org/sites/default/files/DST-TowerDefenseTheme_1.mp3',
               source_sha256=SOURCE_SHA, source_start=95, source_end=170,
               bpm=130, bars=40, sample_rate=RATE, duration=len(samples)/RATE,
               loop_offset=overlap/RATE, loop_seconds=period/RATE,
               edit='Raised-cosine overlap, beat-aligned 40-bar repeat; original buildup on first entry',
               target_lufs=-19, gain_db=gain, render_measurement=final,
               ogg_bytes=dest.stat().st_size, sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
    (OUT / 'climax.json').write_text(json.dumps(row, indent=2) + '\n')
    print(json.dumps(row, indent=2))


if __name__ == '__main__':
    main()
