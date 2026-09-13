"""Test VR radio controls and private communication using independent ENet peers."""
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/team-radio'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    children, handles = [], []
    try:
        for role in ['server', 'sender', 'teammate', 'enemy']:
            path = OUT / (role + '.log')
            handle = path.open('w'); handles.append(handle)
            process = subprocess.Popen(['godot', '--headless', '--xr-mode', 'off', '--path', str(ROOT), '--script', 'res://deathmatch/tests/team_radio_network.gd', '--', role, '--client-config', str(OUT / (role + '.cfg'))], stdout=handle, stderr=subprocess.STDOUT)
            children.append((role, process, path))
            if role == 'server':
                deadline = time.monotonic() + 15
                while time.monotonic() < deadline and process.poll() is None and 'DM_HOST_READY' not in path.read_text():
                    time.sleep(.05)
        for role, process, path in children:
            process.wait(timeout=30)
            log = path.read_text()
            results.append(dict(test=role, exit_code=process.returncode, passed=process.returncode == 0 and 'TEAM_RADIO_RESULT' in log and 'FAIL ' not in log and 'ERROR:' not in log))
    finally:
        for _, process, _ in children:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        for handle in handles: handle.close()
    print(json.dumps(results, indent=2))
    (OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    return 0 if all(row['passed'] for row in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
