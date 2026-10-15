"""Run a prepared Jolt regression deployment without touching the live service."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', default='godot', help='Full Godot 4.7.2 executable, not an export template')
    parser.add_argument('--jobs', type=int, default=4)
    parser.add_argument('--native-only', action='store_true')
    parser.add_argument('--authority-experiments', action='store_true', help='Run gameplay regressions with all experimental authority stages enabled')
    args = parser.parse_args()
    if not 1 <= args.jobs <= 12:
        parser.error('jobs must be 1..12')
    bundle = args.bundle.resolve()
    output = args.output.resolve()
    if output.exists():
        parser.error('output must be a new directory')
    manifest = json.loads((bundle / 'manifest.json').read_text())
    for name, digest in manifest['files'].items():
        path = (bundle / name).resolve()
        if not path.is_relative_to(bundle) or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise RuntimeError('Bundle checksum mismatch: ' + name)
    output.mkdir(parents=True)
    rows = []

    def execute(name, command, timeout=180):
        with (output / (name + '.log')).open('w') as stream:
            result = subprocess.run([str(x) for x in command], cwd=bundle / 'release',
                                    env=env, stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=timeout)
        text = (output / (name + '.log')).read_text()
        errors = [line for line in text.splitlines() if 'SCRIPT ERROR:' in line or 'FAIL ' in line
                  or ('ERROR:' in line and line != 'ERROR: 8 resources still in use at exit (run with --verbose for details).')]
        passed = result.returncode == 0 and not errors
        if name.startswith('runtime-'):
            passed = passed and ('RESULT' in text or (name == 'runtime-terrain' and '"errors":[]' in text))
        row = {'test': name, 'exit_code': result.returncode, 'passed': passed,
               'checks': sum(line.startswith('PASS ') for line in text.splitlines()),
               'known_cleanup_diagnostic': 'ERROR: 8 resources still in use at exit' in text}
        rows.append(row)
        print(json.dumps(row), flush=True)
        if not passed:
            raise RuntimeError('Test failed: ' + name)

    # Isolate preferences, profiles and derived heightmaps from the live server.
    env = dict(os.environ, XDG_DATA_HOME=str(output / 'user-data'),
               XDG_CONFIG_HOME=str(output / 'config'), XDG_CACHE_HOME=str(output / 'cache'))
    try:
        execute('configure', ['cmake', '-S', bundle / 'native', '-B', output / 'build',
                             '-DCMAKE_BUILD_TYPE=Release', '-DCQ_WITH_JOLT=ON',
                             '-DCQ_JOLT_SOURCE_DIR=' + str(bundle / 'jolt')])
        execute('build', ['cmake', '--build', output / 'build', '-j', args.jobs], 1200)
        execute('native', ['ctest', '--test-dir', output / 'build', '--output-on-failure'])
        if not args.native_only:
            godot = shutil.which(args.godot)
            if not godot:
                raise RuntimeError('Full Godot 4.7.2 executable is required')
            version = subprocess.check_output([godot, '--version'], text=True).strip()
            if not version.startswith(manifest['required_godot'] + '.'):
                raise RuntimeError('Godot version mismatch: ' + version)
            command = [godot, '--headless', '--xr-mode', 'off', '--main-pack', bundle / 'release/cq-server.pck']
            for name, script in [
                ('acceptance', 'deathmatch/tests/cq_jolt_runtime.gd'),
                ('snapshot-preparation', 'deathmatch/tests/snapshot_preparation.gd'),
                ('player-simulation', 'deathmatch/tests/player_simulation.gd'),
                ('cs', 'deathmatch/tests/cq_cs_movement.gd'),
                ('jetpack', 'deathmatch/tests/cq_jetpack.gd'),
                ('launcher-reload', 'deathmatch/tests/cq_launcher_reload.gd'),
                ('battery', 'deathmatch/tests/cq_battery_tank.gd'),
                ('hover', 'deathmatch/tests/cq_hover_tanks.gd'),
                ('vehicle-surfaces', 'deathmatch/tests/cq_vehicle_surface.gd'),
                ('ballistics', 'deathmatch/tests/cq_barrage_ballistics.gd'),
                ('cq', 'deathmatch/tests/cq_frontier_integration.gd'),
                ('prediction', 'deathmatch/tests/local_prediction.gd'),
                ('terrain', 'tools/voxel_battle/validate_jungle_physics.gd')]:
                execute('runtime-' + name, command + ['--fixed-fps', '30', '--script', 'res://' + script, '--', '30'] + (['--native-player-state', '--native-input-state', '--native-snapshot-fanout', '--native-snapshot-buffers'] if args.authority_experiments else []))
            execute('runtime-immutable-snapshot', command + ['--script', 'res://deathmatch/tests/snapshot_preparation.gd', '--', '--native-snapshot-buffers'])
            def network_pair(label, script, marker, flags=()):
                jobs = []
                handles = []
                try:
                    for role in ['server', 'client']:
                        log = output / (label + '-' + role + '.log')
                        handle = log.open('w'); handles.append(handle)
                        proc = subprocess.Popen([str(x) for x in command] + ['--script', script, '--', role] + list(flags),
                                                cwd=bundle / 'release', env=env, stdout=handle, stderr=subprocess.STDOUT)
                        jobs.append((role, proc, log))
                        if role == 'server':
                            deadline = time.monotonic() + 30
                            while proc.poll() is None and time.monotonic() < deadline and 'DM_HOST_READY' not in log.read_text():
                                time.sleep(.05)
                            if 'DM_HOST_READY' not in log.read_text():
                                raise RuntimeError('Network test server did not start: ' + label)
                    for role, proc, log in jobs:
                        code = proc.wait(timeout=60)
                        text = log.read_text()
                        passed = code == 0 and marker + ' ' + role + ' []' in text and 'FAIL ' not in text and 'SCRIPT ERROR' not in text
                        errors = [line for line in text.splitlines() if 'ERROR:' in line and line != 'ERROR: 8 resources still in use at exit (run with --verbose for details).']
                        passed = passed and not errors
                        rows.append({'test': label + '-' + role, 'exit_code': code, 'passed': passed})
                        if not passed:
                            raise RuntimeError('Network test failed: ' + role)
                finally:
                    for _, proc, _ in jobs:
                        if proc.poll() is None:
                            proc.terminate()
                            try:
                                proc.wait(timeout=3)
                            except subprocess.TimeoutExpired:
                                proc.kill(); proc.wait()
                    for handle in handles:
                        handle.close()
            network_pair('network', 'res://deathmatch/tests/cq_frontier_network.gd', 'CQ_FRONTIER_NETWORK_RESULT')
            network_pair('snapshot-network', 'res://deathmatch/tests/snapshot_network.gd', 'SNAPSHOT_NETWORK_RESULT')
            network_pair('player-network', 'res://deathmatch/tests/snapshot_network.gd', 'SNAPSHOT_NETWORK_RESULT',
                         ['--native-player-state', '--native-input-state', '--native-snapshot-fanout', '--native-snapshot-buffers'])
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        rows.append({'test': 'runner', 'passed': False, 'error': str(error)})
    result = {'source_commit': manifest['source_commit'], 'source_dirty': manifest['source_dirty'],
              'passed': bool(rows) and all(row['passed'] for row in rows), 'tests': rows,
              'capacity_validation': False}
    (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print('CQ_DEPLOYED_SUITE_RESULT', json.dumps(result))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
