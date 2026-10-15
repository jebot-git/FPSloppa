#!/usr/bin/env python3
"""Full admission/presentation smoke on an isolated adaptive CQ server."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

from run_capacity_case import listening, stop


def classify_diagnostics(lines, experimental_capacity):
    expected = [line for line in lines if experimental_capacity and
                line.startswith('WARNING: UNSUPPORTED CQ CAPACITY: more than 32 slots is experimental.')]
    return expected, [line for line in lines if line not in expected]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--port', type=int, default=28009)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((bundle/'release-sha256.json').read_text())
    for name, digest in manifest.items():
        path = (bundle/name).resolve()
        if not path.is_relative_to(bundle) or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise RuntimeError('Bundle checksum mismatch: '+name)
    (out/'release-sha256.json').write_text(json.dumps(manifest, indent=2))
    (out/'server.cfg').write_bytes(args.config.read_bytes())
    base = ['stdbuf', '-oL', '-eL', str(bundle/'cq-server'), '--headless', '--xr-mode', 'off', '--']
    jobs = []
    result = {'passed': False}
    try:
        with (out/'server.log').open('w') as server_log, (out/'desktop.log').open('w') as client_log:
            server = subprocess.Popen(base+['--server', '--config', str(out/'server.cfg'),
                                           '--cq-native-authority', '--cq-adaptive-tick'],
                                      stdout=server_log, stderr=subprocess.STDOUT, start_new_session=True)
            jobs.append(server)
            deadline = time.monotonic()+120
            while not listening(server.pid, args.port):
                if server.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Arena startup/listener failed')
                time.sleep(.1)
            client = subprocess.Popen(base+['--authority-arena-client', '--connect', '127.0.0.1',
                                           '--port', str(args.port), '--authority-client-report', str(out/'desktop.json')],
                                      stdout=client_log, stderr=subprocess.STDOUT, start_new_session=True)
            jobs.append(client)
            if client.wait(timeout=120):
                raise RuntimeError('Full arena client failed')
            result['client'] = json.loads((out/'desktop.json').read_text())
            result['passed'] = not result['client']['failures']
    except Exception as error:
        result['error'] = str(error)
    finally:
        for job in jobs:
            stop(job)
        text = (out/'server.log').read_text()
        ready = [json.loads(line.split(' ', 1)[1]) for line in text.splitlines() if line.startswith('CQ_RESIDENT_READY ')]
        result['ready'] = ready
        result['diagnostics'] = [line for log in ['server.log', 'desktop.log']
                                 for line in (out/log).read_text().splitlines()
                                 if 'ERROR:' in line or 'WARNING:' in line]
        capacity64 = 'set sv_cq_maxclients "64"' in (out/'server.cfg').read_text().splitlines()
        expected, unexpected = classify_diagnostics(result['diagnostics'], capacity64)
        result['expected_capacity_warnings'] = expected
        result['unexpected_diagnostics'] = unexpected
        if unexpected or not ready or ready[0].get('physics_hz') != 60 or not ready[0].get('adaptive_tick'):
            result['passed'] = False
        (out/'summary.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result), flush=True)
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
