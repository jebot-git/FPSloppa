#!/usr/bin/env python3
"""Start local ST 6v6; automatically stop if no capture in 600 game seconds."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=28984)
parser.add_argument('--output', default='test-results/st-tribes/live')
parser.add_argument('--speed', type=int, choices=[1, 2, 4], default=1)
parser.add_argument('--seconds', type=float, default=0)
parser.add_argument('--seed', type=int, default=9281)
parser.add_argument('--headless', action='store_true')
parser.add_argument('--renderer', choices=['mobile', 'forward_plus'], default='mobile')
args = parser.parse_args()
project = Path(__file__).resolve().parents[2]
output = (project / args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
options = dict(output=str(output), port=args.port, speed=args.speed, seconds=args.seconds, seed=args.seed)
base = ['godot', '--xr-mode', 'off', '--path', str(project), '--script', 'tools/tribes/live_match.gd']
env = os.environ.copy()
env['XDG_DATA_HOME'] = f'/tmp/fps-st-live-{args.port}'
server = subprocess.Popen(base[:1] + ['--headless'] + base[1:] + ['--', json.dumps(options)], cwd=project, env=env, stdout=(output / 'server.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
processes = {'server': server.pid, 'port': args.port, 'output': str(output)}
(output / 'processes.json').write_text(json.dumps(processes, indent=2))
deadline = time.monotonic() + 60
while time.monotonic() < deadline:
    if server.poll() is not None:
        raise SystemExit(f'Server exited {server.returncode}; see {output / "server.log"}')
    if (output / 'server.json').exists() and json.loads((output / 'server.json').read_text()).get('pid') == server.pid:
        break
    time.sleep(.2)
else:
    server.terminate()
    raise SystemExit('Server startup timed out')
if not args.headless:
    options['viewer'] = True
    viewer = subprocess.Popen(base[:1] + ['--rendering-method', args.renderer, '--rendering-driver', 'vulkan'] + base[1:] + ['--', json.dumps(options)], cwd=project, env=env, stdout=(output / 'viewer.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
    processes['viewer'] = viewer.pid
(output / 'processes.json').write_text(json.dumps(processes, indent=2))
print(json.dumps(processes))
