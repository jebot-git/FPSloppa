"""Real ENet utility purchases, throws, effects, late join and demo capture."""
import os
from pathlib import Path
import subprocess
import time
import sys
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results/classic-de'
prefix = 'utility-vr-network' if '--tracked' in sys.argv else 'utility-network'
(OUT / (prefix+'.fpsdemo')).unlink(missing_ok=True)
processes, logs = [], []
try:
    for role, delay in [('server', 1), ('attacker', 1), ('defender', 8), ('viewer', 0)]:
        log = open(OUT / f'{prefix}-{role}.log', 'w'); logs.append(log)
        env = dict(os.environ, XDG_CONFIG_HOME=f'/tmp/fps-utility-{role}', XDG_DATA_HOME=f'/tmp/fps-utility-{role}')
        proc = subprocess.Popen(['godot', '--headless', '--xr-mode', 'off', '--path', str(ROOT), '--script', 'deathmatch/tests/defusal_grenade_network.gd', '--', role, *(['--tracked'] if '--tracked' in sys.argv else [])], stdout=log, stderr=subprocess.STDOUT, env=env)
        processes.append((role, proc)); time.sleep(delay)
    for role, proc in processes:
        proc.wait(timeout=55)
        content = (OUT / f'{prefix}-{role}.log').read_text()
        print(role, proc.returncode, '\n'.join(content.splitlines()[-25:]))
        assert proc.returncode == 0 and f'UTILITY_NETWORK_RESULT {role} []' in content and 'SCRIPT ERROR' not in content
finally:
    for _, proc in processes:
        if proc.poll() is None: proc.terminate()
    for log in logs: log.close()
