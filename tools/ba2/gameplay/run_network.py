#!/usr/bin/env python3
"""Check concurrent cockpit claims over real localhost ENet connections."""
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'test-results/ba2/gameplay'
OUT.mkdir(parents=True, exist_ok=True)
processes, handles, rows = [], [], []
try:
    for role in ('server', 'client_a', 'client_b'):
        path = OUT / f'network-{role}.log'
        handle = path.open('w'); handles.append(handle)
        process = subprocess.Popen(['godot', '--headless', '--xr-mode', 'off',
            '--audio-driver', 'Dummy', '--path', str(ROOT), '--script',
            'res://tools/ba2/gameplay/network.gd', '--', role,
            '--client-config', str(OUT / f'network-{role}.cfg')],
            env=dict(os.environ, XDG_DATA_HOME='/tmp/fpsloppa-ba2-data'),
            stdout=handle, stderr=subprocess.STDOUT)
        processes.append((role, process))
        if role == 'server':
            deadline = time.monotonic() + 15
            while process.poll() is None and time.monotonic() < deadline:
                if 'DM_HOST_READY' in path.read_text(): break
                time.sleep(.1)
    deadline = time.monotonic() + 65
    for role, process in processes:
        process.wait(timeout=max(1, deadline-time.monotonic()))
        output = (OUT / f'network-{role}.log').read_text()
        rows.append(dict(role=role, passed=process.returncode == 0 and
            'BA2_NETWORK_RESULT' in output and 'SCRIPT ERROR:' not in output,
            checks=output.count('PASS ')))
        print(output)
    (OUT / 'network.json').write_text(json.dumps(rows, indent=2)+'\n')
finally:
    for _, process in processes:
        if process.poll() is None:
            process.terminate()
            try: process.wait(timeout=3)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
    for handle in handles: handle.close()
raise SystemExit(0 if len(rows)==3 and all(row['passed'] for row in rows) else 1)
