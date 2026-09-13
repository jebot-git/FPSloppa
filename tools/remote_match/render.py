"""Render the recorded network session in bounded chunks and assemble one MP4."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/remote-all-modes'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('demo', type=Path)
    parser.add_argument('--duration', type=float, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--start-segment', type=int, default=0)
    parser.add_argument('--end-segment', type=int, default=100000)
    parser.add_argument('--no-concat', action='store_true')
    parser.add_argument('--chapters', type=Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    pieces = args.output.parent / (args.output.stem + '-segments')
    pieces.mkdir(exist_ok=True)
    videos = []
    for index, start in enumerate(range(0, int(args.duration + .999), 60)):
        if index < args.start_segment or index >= args.end_segment:continue
        end = min(start+60, args.duration)
        video = pieces / f'{index:03}.mp4'
        videos.append(video.resolve())
        if video.exists():continue
        with tempfile.TemporaryDirectory(prefix='render-', dir=pieces) as temporary:
            avi = Path(temporary).resolve() / 'capture.avi'
            config = dict(demo=str(args.demo.resolve()), start=float(start), end=float(end), screenshot=str((pieces / f'{index:03}.png').resolve()))
            cmd = ['godot', '--path', str(ROOT), '--xr-mode', 'off', '--rendering-method', 'mobile',
                   '--audio-driver', 'Dummy', '--resolution', '1280x720', '--fixed-fps', '30', '--disable-vsync',
                   '--write-movie', str(avi), '--script', 'res://tools/remote_match/movie.gd', '--', json.dumps(config),
                   '--asset-root', str(ROOT)]
            with (pieces / f'{index:03}-render.log').open('w') as log:
                subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=900,
                               env=dict(os.environ, XDG_DATA_HOME=f'/tmp/fpsloppa-remote-movie-{index}'))
            log_text = (pieces / f'{index:03}-render.log').read_text()
            if 'SCRIPT ERROR:' in log_text or 'Invalid or incomplete demo' in log_text:
                raise RuntimeError('Demo render error; inspect segment log')
            with (pieces / f'{index:03}-encode.log').open('w') as log:
                subprocess.run(['ffmpeg','-nostdin','-n','-i',str(avi),'-c:v','libx264','-preset','fast','-crf','20',
                                '-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(video)],
                               stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
        print('SEGMENT_DONE', index, start, end, video.stat().st_size, flush=True)
    if args.no_concat:return
    playlist = pieces / 'concat.txt'
    playlist.write_text(''.join("file '"+str(path).replace("'", "'\\''")+"'\n" for path in videos))
    concat = ['ffmpeg','-nostdin','-n','-f','concat','-safe','0','-i',str(playlist)]
    if args.chapters:concat += ['-i',str(args.chapters),'-map_metadata','1','-map_chapters','1']
    subprocess.run(concat+['-c','copy','-movflags','+faststart',str(args.output)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print('VIDEO_DONE', args.output.resolve(), flush=True)

if __name__ == '__main__':main()
