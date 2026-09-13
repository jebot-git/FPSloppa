"""Bounded Mobile-renderer preview run. Terminates and reaps its own process."""
from pathlib import Path
import argparse
import subprocess

ROOT=Path(__file__).resolve().parents[2]
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--stereo',action='store_true');args=parser.parse_args()
    out=ROOT/'test-results/skyboxes';out.mkdir(parents=True,exist_ok=True)
    label='stereo' if args.stereo else 'render'
    with (out/(label+'.log')).open('w') as log:
        process=subprocess.Popen(['godot','--xr-mode','off','--audio-driver','Dummy','--path',str(ROOT),
                                  '--rendering-method','mobile','--log-file',str(out/(label+'-engine.log')),
                                  '--script','res://tools/skyboxes/'+label+'.gd'],stdout=log,stderr=subprocess.STDOUT)
        try:code=process.wait(timeout=360)
        finally:
            if process.poll() is None:
                process.terminate()
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:process.kill();process.wait()
    print('SKY_RENDER_EXIT',code)
    raise SystemExit(code)
