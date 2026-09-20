"""Supervise a local CQ campaign. Remote workers use the individual service CLI."""
import argparse
import asyncio
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

from . import campaign, config
from .transport import rpc

ROOT = Path(__file__).resolve().parents[2]


def private(path, value):
    if path.exists():
        if json.loads(path.read_text()) != value:
            raise ValueError(f'Existing generated configuration differs: {path}')
    else:
        config.write_private(path, value)


async def ready(settings, districts, processes, timeout=120, markers=()):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        failed = [name for name, process in processes if process.poll() is not None]
        if failed:
            raise RuntimeError(f"Service exited: {', '.join(failed)}; inspect the state directory logs")
        # A persisted online lease can outlive the previous process. Require
        # this launch's bound coordinator/gateways before trusting online rows.
        started = True
        for path, offset, marker in markers:
            with path.open() as log:
                log.seek(offset)
                if marker not in log.read():
                    started = False
                    break
        if not started:
            await asyncio.sleep(.25)
            continue
        try:
            state = await rpc(settings['coordinators'][0], dict(op='status', token=settings['admin_token']))
            if not campaign.enabled(state) or state['player_limit'] != 128:
                raise RuntimeError('Existing coordinator database is not a CQ campaign; use a separate state directory')
            if all(state['districts'][d]['online'] for d in districts):
                return
        except (OSError, TimeoutError):
            pass
        await asyncio.sleep(.25)
    raise TimeoutError('CQ startup timed out; inspect the state directory logs')


def run(args):
    root = args.state_dir.resolve()
    root.mkdir(parents=True, exist_ok=True)
    path = root / 'cluster.json'
    if not path.exists():
        config.write_private(path, config.campaign(args.base_port))
    settings = config.read(path)
    if not campaign.enabled(settings):
        raise ValueError('Default CQ requires the 81-district campaign configuration')
    districts = sorted(set(args.districts or settings['districts']))
    if not set(districts) <= settings['districts'].keys():
        raise ValueError('Unknown campaign district')
    binary = args.binary.resolve()
    if not binary.is_file():
        raise ValueError('Build the campaign worker package first; see docs/CAMPAIGN-81.md')
    engine = shutil.which(os.environ.get('GODOT_BIN', 'godot'))
    if engine is None:
        raise ValueError('Godot is required for the ENet client gateways')
    gateways = sorted({settings['districts'][d]['gateway'] for d in districts})
    routes = {f"{g['address'][0]}:{g['address'][1]}": [g['address'][0], g['address'][1]+100]
              for g in settings['gateways'].values()}
    client_district = 'd40' if 'd40' in districts else districts[0]
    address = settings['gateways'][settings['districts'][client_district]['gateway']]['address']
    private(root / 'client.json', dict(address=[address[0], address[1]+100],
            district=client_district, token=settings['client_token'], team=0, name='CQ Explorer'))
    commands = [('coordinator', [sys.executable, '-m', 'tools.district_cluster', 'coordinator',
        '--config', str(path), '--database', str(root / 'control.sqlite')])]
    for gateway in gateways:
        commands.append((gateway, [sys.executable, '-m', 'tools.district_cluster', 'gateway',
            '--config', str(path), '--name', gateway, '--wait-lease']))
        address = settings['gateways'][gateway]['address']
        edge = root / (gateway + '-edge.json')
        private(edge, dict(backend=address, listen=[address[0], address[1]+100], routes=routes))
        commands.append((gateway+'-edge', [engine, '--headless', '--xr-mode', 'off', '--path', str(ROOT),
            '--script', 'tools/district_cluster/edge_main.gd', '--', str(edge)]))
    for district in districts:
        row = settings['districts'][district]
        worker = root / (district + '.json')
        private(worker, dict(district=district, map_slot=row['map_slot'], asset_id=row['asset_id'],
            address=settings['gateways'][row['gateway']]['address'], token=settings['worker_tokens'][district],
            state_dir=str(root / 'workers' / district)))
        commands.append((district, [str(binary), '--', '--asset-root', str(binary.parent), '--experimental-cq',
            '--cq-district-maps', '--cq-worker', str(row['map_slot']), '--cluster-worker', str(worker)]))
    processes, logs, markers = [], [], []
    def stop(_signum, _frame):
        raise KeyboardInterrupt
    previous = signal.signal(signal.SIGTERM, stop)
    try:
        for name, command in commands:
            log = (root / (name + '.log')).open('a')
            logs.append(log)
            marker = ('CLUSTER_READY coordinator' if name=='coordinator' else
                      'CLUSTER_ENET_READY' if name.endswith('-edge') else
                      'CLUSTER_READY gateway' if name in gateways else 'CLUSTER_WORKER_READY')
            markers.append((root / (name + '.log'), log.tell(), marker))
            processes.append((name, subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                env=dict(os.environ, XDG_DATA_HOME=str(root / 'profile')))))
            if name == 'coordinator':
                asyncio.run(ready(settings, [], processes, 15, markers))
        asyncio.run(ready(settings, districts, processes, markers=markers))
        print(f'CQ_READY districts={len(districts)}/81 players=128 district_capacity=16', flush=True)
        print(f'Client: ./launch-conquest.sh {root / "client.json"}', flush=True)
        while True:
            for name, process in processes:
                if process.poll() is not None:
                    raise RuntimeError(f'{name} exited; inspect {root / (name + ".log")}')
            time.sleep(.5)
    finally:
        signal.signal(signal.SIGTERM, previous)
        for _, process in reversed(processes):
            if process.poll() is None:
                process.terminate()
        deadline = time.monotonic() + 8
        for _, process in reversed(processes):
            try:
                process.wait(timeout=max(.01, deadline-time.monotonic()))
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for log in logs:
            log.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state-dir', type=Path, default=ROOT/'test-results/cq-campaign')
    parser.add_argument('--binary', type=Path, default=ROOT/'Builds/Campaign81/FPSloppaServer.x86_64')
    parser.add_argument('--base-port', type=int, default=41000)
    parser.add_argument('--districts', nargs='+', help='Run only these workers; atlas and campaign remain 81 districts')
    args = parser.parse_args()
    try:
        run(args)
    except KeyboardInterrupt:
        pass
    except (OSError, ValueError, RuntimeError, TimeoutError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
