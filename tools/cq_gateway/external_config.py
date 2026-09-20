"""Create private per-match master/worker provisioning files; no credentials on stdout."""
import argparse, json, secrets
from pathlib import Path


def create(directory, zones, port, worker_ports=None):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not zones or len(set(zones)) != len(zones) or any(z not in range(16) for z in zones):
        raise ValueError('Choose distinct districts from 0 to 15')
    if not 1024 <= port <= 65535:
        raise ValueError('Use a private port from 1024 to 65535')
    session = secrets.token_hex(32)
    workers = [dict(zone=z, token=secrets.token_hex(32), instance=secrets.token_hex(32)) for z in zones]
    files = {'master.json': dict(port=port, session=session, workers=workers)}
    files.update({f'worker-{w["zone"]}.json': dict(w, session=session, port=(worker_ports or {}).get(w['zone'], port)) for w in workers})
    if any((directory / name).exists() for name in files):
        raise FileExistsError('Use a fresh provisioning directory for each master lifetime')
    for name, value in files.items():
        path = directory / name
        # Open exclusively with private permissions from the first byte.
        import os
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as f:
            json.dump(value, f, indent=2)
            f.write('\n')
    return directory / 'master.json'


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--zones', type=int, nargs='+', default=list(range(16)))
    p.add_argument('--port', type=int, default=39000)
    args = p.parse_args()
    print('Created', create(args.output, args.zones, args.port))
