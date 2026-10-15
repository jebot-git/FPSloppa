#!/usr/bin/env python3
"""Exercise the resident core and its separate Godot/Jolt/ENet host.

This is not the production CQ capacity suite. Never controls a live service.
"""
import argparse
import math
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from build_gameplay_native import require_build


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_manifest():
    files = [p for p in (ROOT / 'addons/fps_native/src').glob('authority*.*')
             if p.suffix in ('.cpp', '.h')]
    files += list((ROOT / 'deathmatch/native').glob('*.gd'))
    files += [p for p in (ROOT / 'tools/authority_core').iterdir()
              if p.suffix in ('.cpp', '.gd', '.py') or p.name == 'CMakeLists.txt']
    for folder in ['tools/voxel_battle', 'tools/streamed_heightfield',
                   'deathmatch/conquest/classes', 'deathmatch/conquest/frontier',
                   'deathmatch/server', 'deathmatch/modes', 'deathmatch/avatars']:
        files += list((ROOT / folder).rglob('*.gd'))
    files += [ROOT / 'deathmatch/arena.gd', ROOT / 'project.godot']
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(set(files))}


def terminate_on_signal(signum, _frame):
    # Raise through the process-group cleanup in finally, including on SIGTERM.
    raise SystemExit(128 + signum)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--seconds', type=float, default=120)
    parser.add_argument('--players', type=int, nargs='+', default=[32, 64])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--skip-core', action='store_true')
    parser.add_argument('--clients-per-process', type=int, default=4)
    parser.add_argument('--cq-core', action='store_true')
    parser.add_argument('--tracked', action='store_true')
    parser.add_argument('--jungle-map', action='store_true')
    parser.add_argument('--stress-test', action='store_true')
    args = parser.parse_args()
    if not 1 <= args.seconds <= 3600 or any(n < 1 or n > 128 for n in args.players) or not 1 <= args.clients_per_process <= 128:
        parser.error('Use 1–3600 seconds and 1–128 player storage slots')
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error('Output directory must be new or empty')
    library = require_build('linux', server=True)
    source = source_manifest()
    library_hash = digest(library)
    output.mkdir(parents=True, exist_ok=True)
    signal.signal(signal.SIGTERM, terminate_on_signal)
    base = [args.godot, '--headless', '--xr-mode', 'off', '--path', str(ROOT)]
    if not args.skip_core:
        build = output / 'core-build'
        subprocess.run(['cmake', '-S', str(ROOT / 'tools/authority_core'), '-B', str(build),
                        '-DCMAKE_BUILD_TYPE=Release'], check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['cmake', '--build', str(build), '-j', '8'],
                       check=True, stdout=subprocess.DEVNULL)
        golden = output / 'golden'
        exported = subprocess.run(base + ['--script', 'res://tools/authority_core/reference_export.gd', '--', '--output', str(golden)], cwd=ROOT, capture_output=True, text=True, timeout=60)
        (output / 'reference-export.log').write_text(exported.stdout + exported.stderr)
        if exported.returncode or 'ERROR:' in exported.stdout + exported.stderr:
            raise RuntimeError('Reference generation failed')
        result = subprocess.run([str(build / 'authority-tests'), str(golden)], check=True,
                                capture_output=True, text=True)
        (output / 'core-tests.json').write_text(result.stdout)
    for name in ['functional','vr_functional','terrain_functional','entity_functional','transport_functional']:
        functional = subprocess.run(base + ['--script', f'res://tools/authority_core/{name}.gd'],
                                    cwd=ROOT, capture_output=True, text=True, timeout=120)
        (output / f'{name}.log').write_text(functional.stdout + functional.stderr)
        if functional.returncode or any(t in functional.stdout + functional.stderr
                                        for t in ['ERROR:', 'WARNING:']):
            raise RuntimeError(f'{name} suite failed; inspect {name}.log')
    reports = []
    for index, count in enumerate(args.players):
        report = output / f'{count}-server.json'
        processes = []
        try:
            with (output / f'{count}-server.log').open('w') as server_log, \
                    (output / f'{count}-clients.log').open('w') as client_log:
                common = ['--players', str(count), '--seconds', str(args.seconds),
                          '--port', str(27929 + index)]
                common += [flag for flag, enabled in [('--cq-core', args.cq_core), ('--tracked', args.tracked), ('--jungle-map', args.jungle_map), ('--stress-test', args.stress_test)] if enabled]
                driver = base + ['--script', 'res://tools/authority_core/driver.gd', '--']
                server = subprocess.Popen(driver + common + ['--role', 'server', '--report', str(report)],
                                          cwd=ROOT, stdout=server_log, stderr=subprocess.STDOUT,
                                          start_new_session=True)
                processes.append(server)
                time.sleep(1)
                if server.poll() is not None:
                    raise RuntimeError('Server failed at startup; inspect ' + server_log.name)
                groups = []
                for first in range(0, count, args.clients_per_process):
                    log = (output / f'{count}-clients-{first}.log').open('w')
                    clients = subprocess.Popen(driver + common + ['--role', 'clients', '--client-count', str(min(args.clients_per_process,count-first))], cwd=ROOT,
                                               stdout=log, stderr=subprocess.STDOUT,start_new_session=True)
                    processes.append(clients);groups.append((clients,log))
                try:
                    for process in [*(p for p,_ in groups), server]:
                        if process.wait(timeout=args.seconds + 65):
                            raise RuntimeError('Godot fixture failed; inspect logs')
                finally:
                    for _,log in groups:log.close()
                combined=''.join((output / f'{count}-clients-{first}.log').read_text() for first in range(0,count,args.clients_per_process))
                (output / f'{count}-clients.log').write_text(combined)
            for log in [output / f'{count}-server.log', output / f'{count}-clients.log']:
                content = log.read_text()
                if any(t in content for t in ['ERROR:', 'WARNING:']):
                    raise RuntimeError('Unexpected diagnostic: ' + str(log))
            clients = [json.loads(line.split(' ',1)[1]) for line in (output / f'{count}-clients.log').read_text().splitlines() if line.startswith('AUTHORITY_CLIENTS ')]
            if len(clients) != math.ceil(count/args.clients_per_process):
                raise RuntimeError('Missing client process summary')
            client = {key:sum(c[key] for c in clients) for key in ['admitted','players','frames','bad_frames','disconnected','total_inputs_sent']}
            client['transport']=[c['transport'] for c in clients]
            client['minimum_frames']=min(c['minimum_frames'] for c in clients)
            client['minimum_inputs_sent']=min(c['minimum_inputs_sent'] for c in clients)
            row = json.loads(report.read_text())
            row['clients'] = client
            native = row['native']
            if row['hz'] < 29.5 or native['overflow'] or native['projectile_full']:
                raise RuntimeError('Fixture capacity/queue failure')
            if (native['deaths'] and not args.cq_core) or row['disconnected']:
                raise RuntimeError('Steady-population fixture lost an active player')
            if client['minimum_frames'] < args.seconds * 15:
                raise RuntimeError('Insufficient frame delivery')
            if client['minimum_inputs_sent'] < args.seconds * 29:
                raise RuntimeError('Client workload was below target input rate')
            offered = count * client['minimum_inputs_sent']
            row['accepted_fraction_of_minimum_offered'] = native['accepted'] / offered
            if args.seconds >= 30 and row['accepted_fraction_of_minimum_offered'] < .90:
                raise RuntimeError('Input delivery below 90%; capacity result is not representative')
            reports.append(row)
            print(json.dumps(row), flush=True)
        finally:
            for process in processes:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
    if source_manifest() != source or digest(library) != library_hash:
        raise RuntimeError('Source/library changed during tests; discard timing results')
    (output / 'summary.json').write_text(json.dumps({
        'scope': 'resident CQ jungle fixture' if args.jungle_map else 'resident CQ fixture' if args.cq_core else 'native infantry fixture', 'source_sha256': source,
        'native_library_sha256': library_hash, 'cases': reports,
    }, indent=2))


if __name__ == '__main__':
    main()
