"""Exercise death drops through ENet, including a client joining after the drop."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot'))
    args = parser.parse_args()
    logs = ROOT / 'test-results/dropped-weapons-network'
    logs.mkdir(parents=True, exist_ok=True)
    processes, handles = [], []
    try:
        with tempfile.TemporaryDirectory(prefix='fpsloppa-drops-') as temporary:
            for role in ['server', 'client', 'late']:
                if role == 'late':
                    deadline = time.monotonic() + 25
                    while 'DROP_READY' not in (logs / 'server.log').read_text():
                        if time.monotonic() >= deadline:
                            raise RuntimeError('Server did not create the initial drop')
                        time.sleep(.1)
                handle = (logs / (role + '.log')).open('w')
                handles.append(handle)
                env = dict(os.environ, XDG_DATA_HOME=str(Path(temporary) / role))
                command = [args.godot, '--headless', '--xr-mode', 'off', '--path', str(ROOT),
                           '--script', 'res://deathmatch/tests/dropped_weapons_network.gd', '--', role]
                processes.append((role, subprocess.Popen(command, env=env, stdout=handle, stderr=subprocess.STDOUT)))
                if role == 'server':
                    time.sleep(1)
            for _, process in processes:
                process.wait(timeout=65)
            passed = True
            for role, process in processes:
                contents = (logs / (role + '.log')).read_text()
                good = process.returncode == 0 and 'DROPPED_WEAPONS_NETWORK_RESULT' in contents and 'ERROR:' not in contents
                print(role, 'PASS' if good else 'FAIL', logs / (role + '.log'))
                passed &= good
            return 0 if passed else 1
    finally:
        for _, process in processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        for handle in handles:
            handle.close()


if __name__ == '__main__':
    raise SystemExit(main())
