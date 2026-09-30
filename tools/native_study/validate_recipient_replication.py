"""Validate cosmetic projectiles, native special traces and the retained recipient experiment."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--network', action='store_true')
    parser.add_argument('--bench', action='store_true')
    parser.add_argument('--out', type=Path, default=ROOT/'test-results/recipient-replication')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    results = []

    def start(name, script, extra=()):
        log = args.out/f'{name}.log'
        stream = log.open('w')
        command = [args.godot, '--headless', '--xr-mode', 'off', '--path', str(ROOT),
                   '--log-file', str(args.out/f'{name}-engine.log'), '--script', script]
        if extra:
            command += ['--', *extra]
        process = subprocess.Popen(command, cwd=ROOT, env={**os.environ,
            'XDG_DATA_HOME': str(args.out/f'{name}-user')}, stdout=stream, stderr=subprocess.STDOUT)
        return process, stream, log

    def finish(job, timeout=90):
        process, stream, log = job
        try:
            code = process.wait(timeout=timeout)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            stream.close()
        lines = log.read_text(errors='replace').splitlines()
        errors = [line for line in lines if line.startswith(('SCRIPT ERROR:', 'ERROR:', 'FAIL '))]
        markers = [line for line in lines if '_RESULT' in line]
        row = {'name': log.stem, 'exit': code, 'errors': errors, 'results': markers}
        results.append(row)
        print(json.dumps(row), flush=True)
        if code or errors or not markers:
            raise RuntimeError(f'Validation failed: {log}')

    try:
        for name in ['recipient_replication', 'predicted_projectiles', 'replication_protocol',
                     'native_responsiveness', 'native_network_packing', 'native_special_trace', 'native_rewind', 'fortress', 'flame_coverage', 'weapon_variants', 'cs16', 'movement_replay']:
            finish(start(name, f'res://deathmatch/tests/{name}.gd'))
        if args.network:
            for script, rules in [('projectile_prediction_network', ''), ('rocket_trigger_network', 'quake'), ('rocket_trigger_network', 'doom')]:
                jobs = []
                try:
                    for role in ['server', 'client']:
                        name = f'{script}-{rules}-{role}'
                        extra = [role] + ([rules] if rules else [])
                        extra += ['--map', 'tf_abbeyline', '--client-config', str(args.out/f'{name}.cfg')]
                        jobs.append(start(name, f'res://deathmatch/tests/{script}.gd', extra))
                        if role == 'server':
                            time.sleep(1)
                    for job in jobs:
                        finish(job)
                finally:
                    for process, stream, _ in jobs:
                        if process.poll() is None:
                            process.kill()
                            process.wait()
                        stream.close()
        if args.bench:
            for name in ['recipient_replication', 'special_trace', 'cosmetic_projectiles']:
                finish(start(f'perf-{name}', f'res://tools/native_study/{name}.gd'))
    finally:
        (args.out/'summary.json').write_text(json.dumps(results, indent=2)+'\n')

if __name__ == '__main__':
    main()
