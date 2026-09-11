"""Exercise the announcer mixer and authoritative policy on real ENet peers."""
from pathlib import Path
import subprocess, shutil, time, json, os

root = Path(__file__).resolve().parents[2]
logs = root / 'test-results'
godot = os.environ.get('GODOT_BIN') or shutil.which('godot') or str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')
processes, handles, results = [], [], []
try:
    for role in ['server', 'client']:
        path = logs / f'announcer-network-{role}.log'
        handle = path.open('w'); handles.append(handle)
        p = subprocess.Popen([godot, '--headless', '--xr-mode', 'off', '--path', str(root), '--script', 'res://deathmatch/tests/announcer_network.gd', '--', role], stdout=handle, stderr=subprocess.STDOUT)
        processes.append((role, p, path))
        if role == 'server':
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline and p.poll() is None:
                if 'DM_HOST_READY' in path.read_text(): break
                time.sleep(.05)
    for role, p, path in processes:
        p.wait(timeout=30)
        text = path.read_text()
        results.append({'test': role, 'passed': p.returncode == 0 and 'ANNOUNCER_NETWORK_RESULT []' in text and 'ERROR:' not in text, 'checks': sum(l.startswith('PASS ') for l in text.splitlines())})
    path = logs / 'announcer-mixer.log'
    with path.open('w') as handle:
        p = subprocess.run([godot, '--headless', '--audio-driver', 'PulseAudio', '--xr-mode', 'off', '--path', str(root), '--script', 'res://deathmatch/tests/announcer.gd'], stdout=handle, stderr=subprocess.STDOUT, timeout=30)
    text = path.read_text()
    results.append({'test': 'mixer', 'passed': p.returncode == 0 and 'ERROR:' not in text and 'ANNOUNCER_RESULT []' in text, 'checks': sum(l.startswith('PASS ') for l in text.splitlines())})
    (logs / 'announcer-results.json').write_text(json.dumps(results, indent=2)+'\n')
    print(json.dumps(results, indent=2))
    raise SystemExit(0 if all(r['passed'] for r in results) else 1)
finally:
    for _, p, _ in processes:
        if p.poll() is None:
            p.terminate(); p.wait(timeout=5)
    for h in handles: h.close()
