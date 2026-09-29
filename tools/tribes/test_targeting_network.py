"""Four-process ENet check of real laser input and beacon deployment/cleanup."""
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[2]
flags = sys.argv[1:]
out = root / 'test-results/st-main-sync' / ('targeting-network-reference' if flags else 'targeting-network')
out.mkdir(parents=True, exist_ok=True)
processes = []
try:
    for role, delay in [('server', 2), ('owner', 1), ('recipient', 1), ('enemy', 0)]:
        with (out / f'{role}.log').open('w') as log:
            process = subprocess.Popen(['godot', '--headless', '--xr-mode', 'off', '--audio-driver', 'Dummy', '--path', str(root), '--script', 'deathmatch/tests/st_targeting_network.gd', '--', role, *flags], stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, XDG_DATA_HOME=f'/tmp/st-targeting-{role}'))
        processes.append((role, process))
        time.sleep(delay)
    failed = []
    for role, process in processes:
        process.wait(timeout=80)
        report = (out / f'{role}.log').read_text()
        print(role, process.returncode, '\n' + '\n'.join(line for line in report.splitlines() if line.startswith(('PASS', 'FAIL', 'TARGETING_NETWORK'))), flush=True)
        if process.returncode != 0 or f'TARGETING_NETWORK_RESULT {role} []' not in report or 'SCRIPT ERROR' in report:
            failed.append(role)
    if failed:
        raise SystemExit('Failed: ' + ', '.join(failed))
finally:
    for _, process in processes:
        if process.poll() is None:
            process.terminate()
    for _, process in processes:
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
