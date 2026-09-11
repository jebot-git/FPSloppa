"""Join both bundled Assault maps using exported binaries and staged assets."""
from pathlib import Path
import hashlib
import argparse
import json
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
BUILDS = ROOT.parent / 'Builds'
OUT = ROOT / 'test-results' / 'release-assault'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--map', choices=['as_hislop', 'as_frigate'])
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    reports = []
    manifest = json.loads((ROOT / 'deathmatch/assets/base_manifest.json').read_text())
    for folder in ['Linux', 'Windows', 'Server']:
        for row in manifest['files']:
            path = BUILDS / folder / row['path']
            assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256'], path
    for index, map_id in enumerate(['as_hislop', 'as_frigate']):
        if args.map and args.map != map_id:
            continue
        port = 28891 + index
        with tempfile.TemporaryDirectory(prefix='fpsloppa-release-as-') as temp:
            cfg = Path(temp) / 'server.cfg'
            # Mode lists take precedence over the common fallback map command.
            rotation = '' if index == 0 else 'as_frigate as_hislop'
            cfg.write_text(f'set sv_gametype "as"\nset sv_gametypes "as"\nmap "{map_id}"\nset as_maplist "{rotation}"\nset net_ip "127.0.0.1"\nset net_port "{port}"\nset timelimit "7"\n')
            server_path = OUT / f'{map_id}-server.log'
            client_path = OUT / f'{map_id}-client.log'
            with server_path.open('w') as server_log, client_path.open('w') as client_log:
                server = subprocess.Popen([str(BUILDS / 'Server/FPSloppaServer.x86_64'), '--', '--config', str(cfg)], stdout=server_log, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 30
                    while server.poll() is None and time.monotonic() < deadline and 'DM_HOST_READY' not in server_path.read_text():
                        time.sleep(.1)
                    client = subprocess.run([str(BUILDS / 'Linux/FPSloppa.x86_64'), '--verbose', '--xr-mode', 'off', '--audio-driver', 'Dummy', '--max-fps', '60', '--', '--client-config', str(Path(temp) / 'client.cfg'), '--quit-after-seconds', '12', '--connect', '127.0.0.1', '--port', str(port)], stdout=client_log, stderr=subprocess.STDOUT, timeout=90)
                    st, ct = server_path.read_text(), client_path.read_text()
                    checks = {
                        'client_exit': client.returncode == 0,
                        'server_alive': server.poll() is None,
                        'joined': 'joined the arena' in st,
                        'assault_config': 'gametype=as' in st,
                        'rotation_includes_both_maps': 'as_hislop' in st and 'as_frigate' in st,
                        'client_map': 'MAP_READY ' + map_id in ct,
                        'no_runtime_errors': 'ERROR:' not in st + ct,
                    }
                    reports.append({'map': map_id, 'passed': all(checks.values()), 'checks': checks})
                    print(json.dumps(reports[-1]), flush=True)
                finally:
                    if server.poll() is None:
                        server.terminate()
                        try:
                            server.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            server.kill(); server.wait()
            (OUT / 'results.json').write_text(json.dumps({'staged_assets_verified': True, 'maps': reports, 'passed': all(row['passed'] for row in reports)}, indent=2) + '\n')
    return 0 if all(row['passed'] for row in reports) else 1


if __name__ == '__main__':
    raise SystemExit(main())
