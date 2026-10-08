"""Prepare approved CC0 mode defaults. Requires NumPy and FFmpeg.

Sources are cached outside the game, then pinned in modes.json. Re-running checks
the pinned source hashes. No user bgm files are read or written. Edits remove
digital silence, circularly overlap the ends, and apply constant loudness gain.
"""
from pathlib import Path
import argparse
import concurrent.futures
import hashlib
import json
import subprocess
import tempfile
import urllib.request
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'deathmatch/audio/music/modes'
MANIFEST = OUT.parent / 'modes.json'
RATE = 48000
BASE = 'https://opengameart.org/'
# Mode, title, author, OGA page, download, authored loop.
TRACKS = [
    ('dm', 'Silver Bullet', 'vitalezzz', 'silver-bullet', 'silver_bullet.wav', False),
    ('tdm', 'Brute Force', 'vitalezzz', 'brute-force', 'brute_force_loop.wav', True),
    ('ctf', 'Chase', 'Adiutorium', 'chase-2', 'chase.mp3', False),
    ('koth', 'Open Warfare', 'Ruskerdax', 'open-warfare', 'ruskerdax_-_open_warfare.mp3', False),
    ('ig', 'Final Hour', 'isaiah658', 'final-hour', 'Final-Hour-isaiah658.wav', False),
    ('if', 'Black Diamond', 'Joth', 'black-diamond', 'Black%20Diamond.mp3', True),
    ('cc', 'Megasong', 'Emma_MA', 'megasong', 'megasong_0.mp3', False),
    ('as', 'Fight for Better Future', 'nene', 'fight-for-better-future-rockmetal', 'fight_for_better_future.wav', False),
    ('de', 'Infiltration', 'Adiutorium', 'infiltration', 'infiltration_2.mp3', False),
    ('st', 'Singularity — Action', 'vitalezzz', 'singularity-0', 'singularity_action.wav', True),
    ('ft', 'Energetic Electro Tune', 'TinyWorlds', 'energetic-electro-tune', 'mixdown.ogg', False),
    ('tb', 'The 9th Circle', 'Joth', 'the-9th-circle', 'The%209th%20Circle%20V2.mp3', True),
    ('tf', 'Devoted Guard', 'vitalezzz', 'devoted-guard', 'devoted_guard.wav', False),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def measure(path):
    result = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(path), '-af',
                             'loudnorm=I=-22:TP=-3:LRA=11:print_format=json',
                             '-f', 'null', '-'], capture_output=True, text=True, check=True)
    return json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]


def decode(path):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
                                   '-ar', str(RATE), '-ac', '2', '-f', 'f32le', '-'])
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2).copy()


def prepare(track, cache, previous, output=OUT):
    mode, title, author, page, filename, authored = track
    source = cache / (mode + Path(filename).suffix)
    url = BASE + 'sites/default/files/' + filename
    if not source.exists():
        with urllib.request.urlopen(url, timeout=90) as response:
            source.write_bytes(response.read())
    digest = sha(source)
    if mode in previous and digest != previous[mode]['source_sha256']:
        raise ValueError('Source hash changed for ' + mode)
    samples = decode(source)
    assert np.isfinite(samples).all() and len(samples) > RATE * 20
    # Only trim near-silent edges. Keep the source arrangement/dynamics intact.
    energy = np.sqrt(np.mean(samples[:len(samples)//480*480].reshape(-1,480,2)**2, axis=(1,2)))
    audible = np.flatnonzero(energy > 10**(-48/20))
    start = max(0, int(audible[0])*480 - 480)
    end = min(len(samples), (int(audible[-1])+2)*480)
    samples = samples[start:end]
    # Short repairs for authored loops; a longer musical dissolve for full songs.
    # Circular ordering starts after the overlap and ends at that same point.
    overlap = round((.04 if authored else 2.5) * RATE)
    weight = (.5 - .5*np.cos(np.linspace(0, np.pi, overlap)))[:,None]
    seam = samples[-overlap:]*(1-weight) + samples[:overlap]*weight
    samples = np.concatenate([samples[overlap:-overlap], seam])
    dest = output / (mode + '.ogg')
    target = -25 if mode == 'de' else -22
    with tempfile.TemporaryDirectory(prefix='fps-mode-edit-') as tmp:
        wav = Path(tmp)/'edit.wav'
        subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),
                        '-ac','2','-i','-','-c:a','pcm_f32le',str(wav)],
                       input=samples.astype('<f4').tobytes(), check=True)
        stats = measure(wav)
        gain = min(target-float(stats['input_i']), -4-float(stats['input_tp']))
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-af',f'volume={gain:.6f}dB',
                        '-map_metadata','-1','-c:a','libvorbis','-q:a','5',
                        '-metadata','title='+title,'-metadata','artist='+author,
                        '-metadata','license=CC0-1.0','-metadata','comment='+BASE+'content/'+page,
                        str(dest)], check=True)
    final = measure(dest)
    rendered = decode(dest)
    step = float(np.max(np.abs(rendered[-1]-rendered[0])))
    assert np.isfinite(rendered).all() and float(final['input_tp']) <= -3 and step < .08
    row = dict(key=mode, stem=dest.relative_to(OUT.parent).with_suffix('').as_posix(), title=title, author=author, license='CC0-1.0',
               source_url=BASE+'content/'+page, download_url=url, source_sha256=digest,
               source_start=start/RATE, source_end=end/RATE, authored_loop=authored,
               overlap_seconds=overlap/RATE, loop_offset=0, duration=len(rendered)/RATE,
               target_lufs=target, gain_db=gain, sample_rate=RATE,
               render_measurement=final, loop_step=step, sha256=sha(dest), ogg_bytes=dest.stat().st_size,
               edit='Near-silence trim; raised-cosine circular overlap; constant gain; stereo Vorbis q5')
    print(mode, title, round(row['duration'],2), 'seconds', final['input_i'], 'LUFS', flush=True)
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=Path.home()/'.cache/fpsloppa-oga-mode-music')
    parser.add_argument('--only', nargs='+', help='Rebuild only these modes, preserving the others')
    args = parser.parse_args(); args.cache.mkdir(parents=True, exist_ok=True); OUT.mkdir(parents=True, exist_ok=True)
    previous = {r['key']:r for r in json.loads(MANIFEST.read_text())} if MANIFEST.exists() else {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        rows = list(pool.map(lambda track:prepare(track,args.cache,previous),
                             [t for t in TRACKS if not args.only or t[0] in args.only]))
    previous.update({r['key']:r for r in rows})
    MANIFEST.write_text(json.dumps([previous[t[0]] for t in TRACKS if t[0] in previous], ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    main()
