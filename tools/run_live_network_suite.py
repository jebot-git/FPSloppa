"""Real ENet clients against an explicitly selected test endpoint, with a visible observer.

Read the RCON credential from the staged config; never place it on the command line.
This runner does not deploy, stop servers, or touch production configuration.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import time

from rcon import command

ROOT = Path(__file__).resolve().parents[1]
CASES = [('dm', 'qsrc_dm3', 'doom'), ('tdm', 'qsrc_dm6', 'quake'),
         ('ctf', 'ctf_crownreach', 'ut99'), ('koth', 'koth_alichar', 'doom'),
         ('ig', 'qsrc_dm6', 'doom'), ('if', 'qsrc_dm6', 'doom'),
         ('ft', 'qsrc_dm3', 'doom'), ('cc', 'cc_basement', 'doom'),
         ('tf', 'tf_vesper', 'quake'), ('as', 'as_frigate', 'ut99'),
         ('tb', 'tb_ashfall', 'quake')]


def password_from(path):
    for line in path.read_text().splitlines():
        words = shlex.split(line, comments=True)
        if len(words) == 3 and words[1] == 'rcon_password':
            return words[2]
    raise ValueError('Staged config has no RCON credential')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True)
    parser.add_argument('--port', required=True, type=int)
    parser.add_argument('--rcon-port', required=True, type=int)
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--players', default=12, type=int, choices=range(1, 16))
    parser.add_argument('--hold', default=20, type=float)
    parser.add_argument('--tb-hold', default=100, type=float)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--server-only', action='store_true', help='Package/map smoke; no client coverage')
    parser.add_argument('--local-server', type=Path, help='Start and reap this staged binary for a localhost preflight')
    parser.add_argument('--modes', nargs='+', choices=[c[0] for c in CASES])
    args = parser.parse_args()
    if args.local_server and args.host != '127.0.0.1':
        parser.error('--local-server requires --host 127.0.0.1')
    if min(args.hold, args.tb_hold) <= 0:
        parser.error('Hold durations must be positive')
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    password = password_from(args.config)
    last_rcon = 0.0
    def rcon(text):
        nonlocal last_rcon
        # The server caps authentication attempts per IP; use its normal policy.
        time.sleep(max(0.0, 5.2 - (time.monotonic() - last_rcon)))
        last_rcon = time.monotonic()
        result = command('127.0.0.1', args.rcon_port, password, text)
        if result.get('error') or result.get('ok') is False:
            raise RuntimeError(str(result))
        return result
    cases = [c for c in CASES if not args.modes or c[0] in args.modes]
    scene = out / 'client.tscn'
    scene.write_text((ROOT / 'deathmatch/arena.tscn').read_text().replace(
        'res://deathmatch/arena.gd', 'res://tools/network_study/remote_arena.gd'))
    stop, status = out / 'stop', out / 'status.json'
    processes, handles, results = [], [], []
    server = None
    error = None
    def observed():
        try:
            if time.time() - status.stat().st_mtime > 10:
                return {}
            return json.loads(status.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
    def peer_state(index):
        path = out / f'client-{index:02}.log'
        if time.time() - path.stat().st_mtime > 12:
            return {}
        for line in reversed(path.read_text(errors='replace').splitlines()):
            if line.startswith('NETBOT '):
                return json.loads(line[7:])
        return {}
    try:
        if args.local_server:
            binary = args.local_server.resolve()
            handle = (out / 'server.log').open('w'); handles.append(handle)
            server = subprocess.Popen([str(binary), '--log-file', str(out / 'server-engine.log'), '--',
                '--config', str(args.config.resolve()), '--asset-root', str(binary.parent),
                '--quit-after-seconds', '1800'], cwd=binary.parent, stdout=handle, stderr=subprocess.STDOUT,
                env={**os.environ, 'XDG_DATA_HOME': str(out / 'server-data')})
            deadline = time.monotonic() + 60
            while True:
                if server.poll() is not None:
                    raise RuntimeError('Staged server exited during startup')
                try:
                    rcon('status'); break
                except (OSError, ValueError):
                    if time.monotonic() >= deadline:
                        raise RuntimeError('Staged server startup timed out')
                    time.sleep(.5)
        (out / 'initial-server.json').write_text(json.dumps(rcon('status'), indent=2))
        for number, (mode, map_id, rules) in enumerate(cases):
            rcon(f'match {mode} {map_id} {rules}')
            if args.server_only:
                deadline = time.monotonic() + 60
                while True:
                    response = rcon('status')
                    if response.get('mode') == mode and response.get('map') == map_id and response.get('weapon_rules') == rules:
                        break
                    if time.monotonic() >= deadline:
                        raise RuntimeError('Server map failed to settle: ' + mode)
                    time.sleep(.5)
                results.append(dict(mode=mode, map=map_id, response=response))
                print('SERVER_MAP_OK', mode, map_id, flush=True)
                continue
            if number == 0:
                for index in range(args.players + 1):
                    observer = index == args.players
                    options = dict(scene=str(scene), index=index, observer=observer,
                                   host=args.host, port=args.port, stop=str(stop),
                                   status=str(status), demo=str(out / 'live.fpsdemo'))
                    cfg = out / f'client-{index:02}.cfg'
                    cfg.write_text('[voice]\nmode=0\n[audio]\nmusic=0\n[presentation]\nspatial_audio="stereo"\n')
                    log = (out / f'client-{index:02}.log').open('w')
                    handles.append(log)
                    display = ['--headless', '--audio-driver', 'Dummy'] if args.headless or not observer else [
                        '--rendering-method', 'mobile', '--rendering-driver', 'vulkan',
                        '--resolution', '1280x720', '--audio-driver', 'Dummy']
                    processes.append(subprocess.Popen([
                        'godot', *display, '--xr-mode', 'off', '--max-fps', '60', '--path', str(ROOT),
                        '--log-file', str(out / f'engine-{index:02}.log'),
                        '--script', 'res://tools/remote_match/client.gd', '--', json.dumps(options),
                        '--asset-root', str(ROOT), '--client-config', str(cfg)],
                        stdout=log, stderr=subprocess.STDOUT,
                        env={**os.environ, 'XDG_DATA_HOME': str(out / f'data-{index:02}')}))
                    time.sleep(.25)
            deadline = time.monotonic() + 150
            while time.monotonic() < deadline:
                row = observed()
                peers = [peer_state(i) for i in range(len(processes))]
                if any(p.poll() is not None for p in processes):
                    raise RuntimeError('Client exited during admission')
                if (row.get('active') and row.get('mode') == mode and row.get('map') == map_id
                    and row.get('weapon_rules') == rules and len(row.get('players', [])) == len(processes)
                    and all(p.get('active') and p.get('mode') == mode and p.get('map') == map_id
                            and p.get('players') == len(processes) for p in peers)):
                    break
                time.sleep(.5)
            else:
                raise RuntimeError('Admission/rotation timeout: ' + mode)
            start, samples = time.monotonic(), []
            while time.monotonic() - start < (args.tb_hold if mode == 'tb' else args.hold):
                row = observed()
                peers = [peer_state(i) for i in range(len(processes))]
                if (not row.get('active') or row.get('mode') != mode or row.get('map') != map_id
                    or len(row.get('players', [])) != len(processes)
                    or any(not p.get('active') or p.get('mode') != mode or p.get('map') != map_id
                           or p.get('players') != len(processes) for p in peers)
                    or any(p.poll() is not None for p in processes)):
                    raise RuntimeError('Roster, map, or process lost: ' + mode)
                samples.append(dict(observer=row, peers=peers))
                time.sleep(1)
            results.append(dict(mode=mode, map=map_id, rules=rules, samples=samples,
                                held_seconds=time.monotonic() - start, server=rcon('status')))
            (out / 'rounds.json').write_text(json.dumps(results, indent=2))
            print('LIVE_NETWORK_MODE_OK', mode, len(processes), flush=True)
    except Exception as exc:
        error = str(exc)
    finally:
        stop.touch()
        for p in processes:
            try:
                p.wait(timeout=10)
            except subprocess.TimeoutExpired:
                p.terminate()
                try:
                    p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    p.kill(); p.wait()
        if server is not None and server.poll() is None:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill(); server.wait()
        for handle in handles:
            handle.close()
        script_errors = {p.name: [line for line in p.read_text(errors='replace').splitlines()
                                  if line.startswith('SCRIPT ERROR:')]
                         for p in [*out.glob('client-*.log'), *out.glob('server.log')]}
        engine_errors = {p.name: [line for line in p.read_text(errors='replace').splitlines()
                                  if line.startswith('ERROR:')]
                         for p in [*out.glob('client-*.log'), *out.glob('server.log')]}
        # Keep known engine shutdown leaks in the receipt, separately from runtime errors.
        runtime_errors = {name: [line for line in lines if 'resources still in use at exit' not in line]
                          for name, lines in engine_errors.items()}
        passed = (error is None and len(results) == len(cases)
                  and all(p.returncode == 0 for p in processes) and not any(script_errors.values())
                  and not any(runtime_errors.values()))
        report = dict(passed=passed, error=error, host=args.host, port=args.port,
                      server_only=args.server_only, graphical=not args.headless and not args.server_only,
                      completed=[r['mode'] for r in results], exits=[p.returncode for p in processes],
                      script_errors=script_errors, engine_errors=engine_errors, results=results)
        (out / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
        print('LIVE_NETWORK_RESULT', passed, error, flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
