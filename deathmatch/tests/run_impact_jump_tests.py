"""Bounded impact-jump physics, weapon regression and real ENet checks."""
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/impact-jump'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    base = ['godot', '--headless', '--xr-mode', 'off', '--audio-driver', 'Dummy', '--path', str(ROOT)]
    env = {**os.environ, 'XDG_DATA_HOME': str(OUT / 'user')}
    results = []
    for script, roles, marker in [('impact_jump', [''], 'IMPACT_JUMP_RESULT '),
                                   ('weapon_variants', [''], 'VARIANTS_RESULT '),
                                   ('impact_jump_network', ['server', 'client'], 'IMPACT_NETWORK_RESULT ')]:
        jobs = []
        try:
            for role in roles:
                path = OUT / f'{script}-{role or "local"}.log'
                handle = path.open('w')
                cmd = base + ['--script', f'res://deathmatch/tests/{script}.gd'] + (['--', role] if role else [])
                proc = subprocess.Popen(cmd, stdout=handle, stderr=subprocess.STDOUT, env=env, cwd=ROOT)
                jobs.append((proc, handle, path))
                if role == 'server': time.sleep(1)
            for proc, handle, path in jobs:
                proc.wait(timeout=90); handle.close()
                lines = path.read_text(errors='replace').splitlines()
                row = next((json.loads(l[len(marker):]) for l in lines if l.startswith(marker)), {'passed': False, 'failures': ['Missing result']})
                row.update(log=str(path), exit_code=proc.returncode,
                           errors=[l for l in lines if l.startswith(('ERROR:', 'SCRIPT ERROR:')) and 'resources still in use at exit' not in l])
                row['passed'] = row['passed'] and proc.returncode == 0 and not row['errors']
                results.append(row); print(script, path.name, row['passed'], flush=True)
        finally:
            for proc, handle, path in jobs:
                if proc.poll() is None:
                    proc.terminate()
                    try: proc.wait(timeout=5)
                    except subprocess.TimeoutExpired: proc.kill(); proc.wait()
                handle.close()
    report = dict(passed=all(r['passed'] for r in results), runs=results)
    (OUT / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
