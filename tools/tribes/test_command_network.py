"""Four-process local ENet checks for remote devices and PDA command state."""
import os, subprocess, time
from pathlib import Path
root = Path(__file__).resolve().parents[2]
out = root / 'test-results/st-command/network'
out.mkdir(parents=True, exist_ok=True)
processes = []
try:
    for role, delay in [('server', 2), ('owner', 1), ('recipient', 1), ('enemy', 0)]:
        with (out / f'{role}.log').open('w') as log:
            process = subprocess.Popen(['godot', '--headless', '--xr-mode', 'off', '--audio-driver', 'Dummy', '--path', str(root), '--script', 'deathmatch/tests/st_command_network.gd', '--', role], stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, XDG_DATA_HOME=f'/tmp/st-command-{role}'))
        processes.append((role, process))
        time.sleep(delay)
    for role, process in processes:
        process.wait(timeout=100)
        report = (out / f'{role}.log').read_text()
        print(role, process.returncode, '\n' + '\n'.join(line for line in report.splitlines() if line.startswith(('PASS', 'FAIL', 'COMMAND_NETWORK'))), flush=True)
        assert process.returncode == 0 and f'COMMAND_NETWORK_RESULT {role} []' in report and 'SCRIPT ERROR' not in report
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
