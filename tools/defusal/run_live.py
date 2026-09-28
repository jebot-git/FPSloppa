#!/usr/bin/env python3
"""Launch a visible 6v6 tour of every DE map, two rounds and one side switch each."""
import datetime
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
maps = (ROOT / 'maps/de_maplist.txt').read_text().split()
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--maps', nargs='+', choices=maps, default=maps)
args = parser.parse_args()
output = ROOT / 'test-results' / ('de-live-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
output.mkdir(parents=True)
options = dict(output=str(output), maps=args.maps, port=28996)
env = dict(os.environ, XDG_DATA_HOME=str(output / 'user-data'))
base = ['godot', '--xr-mode', 'off', '--path', str(ROOT), '--script', 'tools/defusal/live_match.gd']
server = subprocess.Popen(base + ['--headless', '--', json.dumps(options)], env=env, cwd=ROOT,
                          stdout=(output / 'server.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
deadline = time.monotonic() + 90
while not (output / 'server-ready.json').exists():
    if server.poll() is not None or time.monotonic() > deadline:
        if server.poll() is None:
            server.terminate()
        raise SystemExit(f'Server startup failed: {output / "server.log"}')
    time.sleep(.25)
options['viewer'] = True
viewer = subprocess.Popen(base + ['--rendering-method', 'mobile', '--rendering-driver', 'vulkan', '--max-fps', '60', '--', json.dumps(options)],
                          env=env, cwd=ROOT, stdout=(output / 'viewer.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
processes = dict(server=server.pid, viewer=viewer.pid, output=str(output), maps=options['maps'], rounds_per_map=2)
(output / 'processes.json').write_text(json.dumps(processes, indent=2) + '\n')
print(json.dumps(processes), flush=True)
