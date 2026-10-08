#!/usr/bin/env python3
"""Start a local ST match; research capture cutoffs are enabled by default."""
import argparse
import hashlib
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
parser.add_argument('--team-size', type=int, choices=range(1, 17), default=6)
parser.add_argument('--navigation-metrics', action='store_true')
parser.add_argument('--map', choices=(Path(__file__).resolve().parents[2] / 'maps/st_maplist.txt').read_text().split(), default='ctf_stonehenge')
parser.add_argument('--continuous', action='store_true', help='Disable research capture cutoffs for a live viewing session')
parser.add_argument('--local-view', action='store_true', help='Render the authority camera without consuming a player slot')
parser.add_argument('--headless', action='store_true')
parser.add_argument('--record', action='store_true', help='Record the visible spectator viewport and game-clock anchors')
parser.add_argument('--renderer', choices=['mobile', 'forward_plus'], default='mobile')
args = parser.parse_args()
if args.local_view and args.headless:
    parser.error('--local-view and --headless are mutually exclusive')
# A full 32-bot match leaves no protocol slot for an ENet observer.
if args.team_size == 16 and not args.headless:
    args.local_view = True
if args.local_view and args.record:
    parser.error('--record currently requires the separate ENet spectator')
project = Path(__file__).resolve().parents[2]
output = (project / args.output).resolve()
if args.record and args.headless:
    parser.error('--record requires a visible spectator')
if output.exists() and any(output.iterdir()):
    parser.error('Use an empty output directory to preserve earlier match evidence')
output.mkdir(parents=True, exist_ok=True)
options = dict(output=str(output), port=args.port, speed=args.speed, seconds=args.seconds, seed=args.seed,
               map=args.map, record=args.record, headless=args.headless, renderer=args.renderer,
               local_view=args.local_view, continuous=args.continuous, team_size=args.team_size, navigation_metrics=args.navigation_metrics)
(output / 'options.json').write_text(json.dumps(options, indent=2))
diff = subprocess.check_output(['git', 'diff', '--no-ext-diff'], cwd=project)
(output / 'source.patch').write_bytes(diff)
code = {}
for folder in ['deathmatch/bot_ai', 'deathmatch/tribes', 'deathmatch/movement', 'tools/tribes']:
    for path in sorted((project / folder).glob('*')):
        if path.suffix in ('.gd', '.py'):
            code[str(path.relative_to(project))] = hashlib.sha256(path.read_bytes()).hexdigest()
(output / 'provenance.json').write_text(json.dumps(dict(
    git_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
    diff_sha256=hashlib.sha256(diff).hexdigest(), code=code,
    bsp_sha256=hashlib.sha256((project / 'maps' / (args.map + '.bsp')).read_bytes()).hexdigest(),
    navigation_sha256=hashlib.sha256((project / 'maps/navigation' / (args.map + '.res')).read_bytes()).hexdigest(),
), indent=2))
base = ['godot', '--xr-mode', 'off', '--path', str(project), '--script', 'tools/tribes/live_match.gd']
env = os.environ.copy()
env['XDG_DATA_HOME'] = f'/tmp/fps-st-live-{args.port}'
server = subprocess.Popen(base[:1] + (['--rendering-method', args.renderer, '--rendering-driver', 'vulkan'] if args.local_view else ['--headless']) + base[1:] + ['--', json.dumps(options)], cwd=project, env=env, stdout=(output / 'server.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
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
if not args.headless and not args.local_view:
    options['viewer'] = True
    viewer = subprocess.Popen(base[:1] + ['--rendering-method', args.renderer, '--rendering-driver', 'vulkan'] + base[1:] + ['--', json.dumps(options)], cwd=project, env=env, stdout=(output / 'viewer.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
    processes['viewer'] = viewer.pid
(output / 'processes.json').write_text(json.dumps(processes, indent=2))
print(json.dumps(processes))
