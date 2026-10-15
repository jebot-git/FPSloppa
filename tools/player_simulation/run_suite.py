"""Run ordered, isolated authority experiments. Never modifies a system service."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CAPACITY = ROOT / 'tools/frontier_vps' if (ROOT / 'tools/frontier_vps').is_dir() else ROOT / 'capacity'
CONFIG = ROOT / 'tools/voxel_battle/cq_classes.cfg' if (ROOT / 'tools/voxel_battle/cq_classes.cfg').is_file() else CAPACITY / 'server.cfg'
STAGES = {
    'reference': [],
    'player-state': ['--native-player-state'],
    'input-state': ['--native-player-state', '--native-input-state'],
    'fanout': ['--native-player-state', '--native-input-state', '--native-snapshot-fanout'],
    'buffers': ['--native-player-state', '--native-input-state', '--native-snapshot-fanout', '--native-snapshot-buffers'],
}
KNOWN_CLEANUP = 'ERROR: 8 resources still in use at exit (run with --verbose for details).'


def errors(text):
    return [line for line in text.splitlines() if 'SCRIPT ERROR:' in line or 'FAIL ' in line
            or ('ERROR:' in line and line != KNOWN_CLEANUP)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True, help='Prepared cq-server beside its pck/addons')
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seconds', type=int, default=120)
    parser.add_argument('--fleet-tail', type=int, default=35, help='Post-profile client lifetime allowance; >=5, default 35')
    parser.add_argument('--players', type=int, nargs='+', choices=[32, 64], default=[32, 64])
    parser.add_argument('--stages', nargs='+', choices=list(STAGES), default=list(STAGES))
    parser.add_argument('--port', type=int, default=27879)
    parser.add_argument('--skip-regressions', action='store_true')
    args = parser.parse_args()
    if args.fleet_tail < 5:
        parser.error('fleet-tail must be at least 5 seconds')
    if args.seconds < 10:
        parser.error('Use at least 10 seconds; 120 seconds is the comparison default')
    if args.output.exists():
        parser.error('Output must be a new directory')
    binary = args.binary.resolve()
    if not binary.is_file() or not binary.with_suffix('.pck').is_file():
        parser.error('Prepared cq-server and cq-server.pck are required')
    args.output.mkdir(parents=True)
    env = dict(os.environ, XDG_DATA_HOME=str(args.output.resolve() / 'user-data'),
               XDG_CONFIG_HOME=str(args.output.resolve() / 'config'), XDG_CACHE_HOME=str(args.output.resolve() / 'cache'))
    receipt = {'seconds': args.seconds, 'fleet_tail': args.fleet_tail, 'players': args.players, 'stages': args.stages,
               'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
               'pck_sha256': hashlib.sha256(binary.with_suffix('.pck').read_bytes()).hexdigest(),
               'results': []}
    try:
        if not args.skip_regressions:
            scripts = [('player-state', 'player_simulation', []),
                       ('snapshot', 'snapshot_preparation', []),
                       ('immutable-snapshot', 'snapshot_preparation', ['--native-snapshot-buffers']),
                       ('native-backend', 'native_backend', []),
                       ('input-delivery', 'network_delivery', []),
                       ('fire-delivery', 'fire_delivery', [])]
            for name, script, flags in scripts:
                command = [args.godot, '--headless', '--xr-mode', 'off', '--main-pack', str(binary.with_suffix('.pck')),
                           '--script', 'res://deathmatch/tests/' + script + '.gd', '--'] + flags
                result = subprocess.run(command, cwd=binary.parent, env=env, text=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, timeout=180)
                (args.output / (name + '.log')).write_text(result.stdout)
                if result.returncode or errors(result.stdout):
                    raise RuntimeError('Regression failed: ' + name)
        for stage in args.stages:
            folder = args.output / stage
            command = ['python3', str(CAPACITY / 'native_compare.py'), '--binary', str(binary),
                       '--fleet', str(CAPACITY / 'client_fleet.py'),
                       '--config', str(CONFIG), '--output', str(folder),
                       '--seconds', str(args.seconds), '--fleet-tail', str(args.fleet_tail), '--port', str(args.port), '--players'] + list(map(str, args.players))
            command += ['--server-arg=--attribute-movement', '--server-arg=--trace-tune-buffer']
            command += ['--server-arg=' + flag for flag in STAGES[stage]]
            with (args.output / (stage + '.log')).open('w') as log:
                subprocess.run(command, cwd=binary.parent, env=env, stdout=log, stderr=subprocess.STDOUT,
                               timeout=(args.seconds + 230) * len(args.players), check=True)
            for population in args.players:
                case = folder / str(population)
                report = json.loads((case / 'report.json').read_text())
                fleet = json.loads((case / 'fleet/fleet.json').read_text())
                clients = fleet['clients']
                healthy = (fleet['successful_clients'] == population and len(clients) == population
                           and all(c.get('admitted') == 1 and c.get('rejected') == 0
                                   and c.get('snapshot_packets_received', 0) > 0 for c in clients)
                           and report['attribution']['scope_errors'] == 0
                           and report['players']['p50'] == population
                           and report.get('native_backend') is True
                           and not errors((case / 'server.log').read_text())
                           and all(not errors(log.read_text()) and 'LOAD_CLIENT_TRANSPORT_LOST' not in log.read_text()
                                   for log in (case / 'fleet').glob('client-*.log')))
                if stage == 'buffers':
                    healthy = healthy and report.get('snapshot_buffers', {}).get('submitted', 0) > 0
                if not healthy:
                    raise RuntimeError(f'Incomplete/failed capacity case: {stage}/{population}')
                attribution = report['attribution']
                means = {k: round(v['self_total_ms'] / max(1, attribution['ticks']), 6)
                         for k, v in attribution['categories'].items()}
                row = {'stage': stage, 'players': population, 'achieved_hz': report['achieved_tick_hz'],
                       'physics_callback_ms': report['physics_callback_ms'],
                       'snapshot_send_ms': report['snapshot_send_ms'], 'self_mean_ms_per_tick': means,
                       'replication': report['replication'], 'snapshot_buffers': report.get('snapshot_buffers', {}), 'healthy': healthy}
                receipt['results'].append(row)
                print(json.dumps({'stage': stage, 'players': population, 'hz': row['achieved_hz'], 'healthy': healthy}), flush=True)
        receipt['passed'] = True
    finally:
        (args.output / 'results.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    main()
