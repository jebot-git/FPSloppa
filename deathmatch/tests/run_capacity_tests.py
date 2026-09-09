"""Verify 16 configured dedicated slots, eight host slots, and avatar catalogs."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile, time

root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
binary = root.parent / 'Builds/Server/EntrywayServer.x86_64'
logs = root / 'test-results'
stop = logs / 'capacity-stop'

def wait_for(predicate, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate(): return True
        time.sleep(.1)
    return False

reports = []
for kind, total, guests in [('dedicated', 16, 16), ('host', 8, 7)]:
    stop.unlink(missing_ok=True)
    processes, handles, paths = [], [], []
    def launch(name, command):
        path = logs / f'capacity_{kind}_{name}.log'
        handle = path.open('w'); handles.append(handle); paths.append(path)
        process = subprocess.Popen(command, stdout=handle, stderr=subprocess.STDOUT)
        processes.append(process)
        return path, process
    def client_command(role):
        return [godot, '--headless', '--xr-mode', 'off', '--path', str(root), '--script', 'res://deathmatch/tests/server_capacity.gd', '--', role, str(total)]
    try:
        with tempfile.TemporaryDirectory(prefix='fpsloppa-capacity-') as temporary:
            cfg = Path(temporary) / 'server.cfg'
            cfg.write_text('set net_ip 127.0.0.1\nset net_port 28892\nset sv_maxclients 16\nset timelimit 60\n')
            path, server = launch('server', [str(binary), '--', '--config', str(cfg)] if kind == 'dedicated' else client_command('host'))
            marker = 'SERVER_CONFIG' if kind == 'dedicated' else 'CAPACITY_HOST_READY'
            assert wait_for(lambda: marker in path.read_text()), (kind, 'server startup')
            for i in range(guests):
                path, _ = launch(str(i), client_command(f'Guest{i}'))
                assert wait_for(lambda: 'CAPACITY_JOINED' in path.read_text()), (kind, 'join', i)
            clients = paths[1:] if kind == 'dedicated' else paths[:]
            assert wait_for(lambda: all('CAPACITY_FULL_ROSTER' in p.read_text() for p in clients)), (kind, 'full roster and avatar catalog')
            path, extra = launch('extra', client_command('extra'))
            assert wait_for(lambda: extra.poll() is not None, 15), (kind, 'extra peer rejected')
            assert extra.returncode == 0 and 'CAPACITY_REJECTED' in path.read_text()
            stop.touch()
            for process in processes[1:] if kind == 'dedicated' else processes:
                process.wait(timeout=10)
                assert process.returncode == 0, (kind, 'client exit')
            assert not any('SCRIPT ERROR:' in p.read_text() for p in paths)
            reports.append({'mode': kind, 'players': total, 'avatars': total, 'extra_rejected': True})
            print('CAPACITY_PASS', kind, total, flush=True)
    finally:
        for process in processes:
            if process.poll() is None: process.terminate(); process.wait(timeout=5)
        for handle in handles: handle.close()
        stop.unlink(missing_ok=True)
(logs / 'capacity_summary.json').write_text(json.dumps(reports, indent=2) + '\n')
