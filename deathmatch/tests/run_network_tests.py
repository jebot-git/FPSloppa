"""Run a real ENet server and two independent clients on loopback."""
from pathlib import Path
import subprocess, time, sys, json

if '--maps' in sys.argv:
    from run_map_download_tests import main
    sys.exit(main())

if '--avatars' in sys.argv:
    from run_avatar_network_tests import main
    sys.exit(main())

root = Path(__file__).resolve().parents[2]
godot = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else '/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'
logs = root / 'test-results'
logs.mkdir(exist_ok=True)
processes = []
handles = []
try:
    for role in ['server', 'shooter', 'target']:
        handle = (logs / (role + '.log')).open('w')
        handles.append(handle)
        cmd = [godot, '--headless','--xr-mode','off', '--path', str(root), '--script', 'res://deathmatch/tests/bsp_network_runner.gd' if '--bsp' in sys.argv else 'res://deathmatch/tests/network_runner.gd', '--', role]
        processes.append((role, subprocess.Popen(cmd, stdout=handle, stderr=subprocess.STDOUT)))
        if role == 'server':
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if 'DM_HOST_READY' in (logs / 'server.log').read_text():
                    break
                time.sleep(.05)
    deadline = time.monotonic() + 35
    for role, process in processes:
        process.wait(timeout=max(1, deadline-time.monotonic()))
    success = True
    for role, process in processes:
        contents = (logs / (role + '.log')).read_text()
        print(f'--- {role} (exit {process.returncode}) ---\n{contents}')
        success &= process.returncode == 0 and 'NETWORK_RESULT' in contents and 'ERROR:' not in contents
    (logs/'summary.json').write_text(json.dumps({'passed': success, 'roles': {role: p.returncode for role,p in processes}}, indent=2))
    sys.exit(0 if success else 1)
finally:
    for _, process in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=3)
    for handle in handles:
        handle.close()
