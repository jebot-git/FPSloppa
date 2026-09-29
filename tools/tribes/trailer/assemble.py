"""Assemble the inspected 2026-09-29 ST replay shots, with synchronized SFX."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'video-output/st-trailer'
OUT = SOURCE
ORDER = [
    ('stonehenge', 0), ('raindance', 0), ('katabatic', 6),
    ('stonehenge', 2), ('disc', 0), ('stonehenge', 1),
    ('raindance', 2), ('katabatic', 2), ('raindance', 3),
    ('stonehenge', 3), ('katabatic', 1), ('raindance', 4),
    ('stonehenge', 5), ('katabatic', 3), ('raindance-fix', 0),
    ('katabatic', 0), ('katabatic-fix', 0), ('stonehenge', 4),
    ('katabatic', 5),
]


def run(args):
    subprocess.run(['ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error', '-y', *args], check=True)


def main():
    global OUT, ORDER
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision', action='store_true', help='Build the three-minute action cut')
    args = parser.parse_args()
    if args.revision:
        OUT = SOURCE / 'revision'
        ORDER = json.loads((OUT / 'order.json').read_text())
    clips = OUT / 'edit'
    clips.mkdir(exist_ok=True)
    shots = []
    cursor = 0.0
    for index, (source, row_index) in enumerate(ORDER):
        rows = json.loads((OUT / (source + '-render.json')).read_text())
        row = rows[row_index]
        duration = row['frames'] / 30
        shots.append(dict(row, source=source, index=index, timeline_start=cursor,
                          duration=duration, clip=str(clips / f'{index:02d}.mkv')))
        cursor += duration
    assert cursor <= (180 if args.revision else 120)

    def cut(row):
        filters = []
        if row['index'] == 0:
            filters.append('fade=t=in:st=0:d=0.6')
        if row['index'] == len(shots) - 1:
            filters.append(f"fade=t=out:st={row['duration'] - 1.5}:d=1.5")
        args = ['-ss', str(row['first_frame'] / 30), '-i', str(OUT / (row['source'] + '.avi')),
                '-t', str(row['duration']), '-map', '0:v:0', '-map', '0:a:0']
        if filters:
            args += ['-vf', ','.join(filters)]
        args += ['-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-threads', '4',
                 '-pix_fmt', 'yuv420p', '-r', '30', '-c:a', 'flac', '-ar', '48000', row['clip']]
        run(args)
        print('Encoded', row['index'], row['name'], flush=True)

    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(cut, shots))
    concat = clips / 'shots.ffconcat'
    concat.write_text('ffconcat version 1.0\n' + ''.join(f"file '{Path(s['clip']).name}'\n" for s in shots))
    # Retain transient headroom for discs and gunfire. Music ducks under effects,
    # with one final loudness/true-peak pass and a shared end fade.
    mix = (
        '[0:a]volume=2.5,asplit=2[fx][key];'
        '[1:a]volume=0.24,afade=t=in:st=0:d=1[music];'
        '[music][key]sidechaincompress=threshold=0.025:ratio=3:attack=8:release=250[duck];'
        f'[fx][duck]amix=inputs=2:duration=first:normalize=0,atrim=duration={cursor},'
        f'afade=t=out:st={cursor-2.5}:d=2.5,loudnorm=I=-17:TP=-1.5:LRA=11[a]'
    )
    final = OUT / ('ST-cinematic-trailer-3min.mp4' if args.revision else 'ST-cinematic-trailer.mp4')
    run(['-f', 'concat', '-safe', '0', '-i', str(concat),
         '-i', str(SOURCE / 'source/DST-TowerDefenseTheme.mp3'), '-filter_complex', mix,
         '-map', '0:v:0', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '256k',
         '-ar', '48000', '-t', str(cursor), '-movflags', '+faststart',
         '-metadata', 'title=FPSloppa — ST cinematic',
         '-metadata', 'comment=8v8 replay footage. Music: Tower Defense Theme by DST (CC0), OpenGameArt.org. See CREDITS.md.',
         str(final)])
    (OUT / 'edit-manifest.json').write_text(json.dumps({'duration': cursor, 'fps': 30, 'shots': shots,
                                                     'sha256': hashlib.sha256(final.read_bytes()).hexdigest()}, indent=2))
    print(final, cursor, 'seconds', flush=True)


if __name__ == '__main__':
    main()
