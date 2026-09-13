"""Run real ENet AI clients plus a visible observer against the staged test server."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/remote-all-modes'
spec = importlib.util.spec_from_file_location('rcon', ROOT / 'tools/rcon.py')
rcon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rcon)

def command(text):
    deadline = time.monotonic() + 75
    while True:
        try:return rcon.command('127.0.0.1', 28778, (OUT / 'rcon.secret').read_text(), text)
        except (OSError, json.JSONDecodeError):
            if time.monotonic() >= deadline:raise
            time.sleep(5)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--preflight', action='store_true')
    args = parser.parse_args()
    stop = OUT / 'stop'
    stop.unlink(missing_ok=True)
    handles, children, results = [], [], []
    cases = json.loads((OUT / 'schedule.json').read_text())['cases']
    count = 2 if args.preflight else 8
    demo = OUT / (f'preflight-{int(time.time())}.fpsdemo' if args.preflight else 'all-modes.fpsdemo')
    status_path = OUT / 'observer-status.json'
    status_path.unlink(missing_ok=True)
    def observed():
        return json.loads(status_path.read_text()) if status_path.exists() else dict(players=[],pending=1,map='',mode='')
    if demo.exists():
        raise RuntimeError('Recording already exists; preserve it before another run')
    try:
        first = cases[0]
        assert command(f"match {first['mode']} {first['map']} {first['rules']}").get('ok')
        for index in range(count + 1):
            observer = index == count
            tag = 'observer' if observer else f'bot-{index+1:02}'
            handle = (OUT / (tag + '.log')).open('w'); handles.append(handle)
            config = OUT / (tag + '.cfg')
            config.write_text('[voice]\nmode=0\n[presentation]\nspatial_audio="stereo"\ntexture_filter=2\n')
            options = dict(scene=str(OUT / 'client.tscn'), index=index, observer=observer,
                           host='45.147.228.101', port=7777, stop=str(stop), demo=str(demo), status=str(status_path))
            cmd = ['godot', '--path', str(ROOT), '--xr-mode', 'off', '--max-fps', '60',
                   '--audio-driver', 'Dummy' if not observer else 'PulseAudio',
                   '--log-file', str(OUT / (tag + '-engine.log'))]
            if not observer: cmd += ['--headless']
            else: cmd += ['--resolution', '1280x720', '--position', '60,60', '--rendering-method', 'mobile']
            cmd += ['--script', 'res://tools/remote_match/client.gd', '--', json.dumps(options),
                    '--client-config', str(config), '--asset-root', str(ROOT)]
            env = dict(os.environ, XDG_DATA_HOME='/tmp/fpsloppa-all-modes-' + tag)
            children.append(subprocess.Popen(cmd, stdout=handle, stderr=subprocess.STDOUT, env=env))
            time.sleep(.3)
        for case_index, case in enumerate(cases[:1] if args.preflight else cases):
            if case_index:
                assert command(f"match {case['mode']} {case['map']} {case['rules']}").get('ok')
            deadline = time.monotonic() + 150
            while time.monotonic() < deadline:
                status = observed()
                if len(status['players']) == count + 1 and status['pending'] == 0 and status['map'] == case['map'] and status['mode'] == case['mode']:break
                assert all(p.poll() is None for p in children), 'A client exited during admission'
                time.sleep(1)
            else: raise RuntimeError('Client admission timed out: ' + str(status))
            assert sum(p['spectator'] for p in status['players']) == 1, status
            assert status['weapon_rules'] == case['rules'] and not status['lobby'], status
            # Start the measured round with the complete roster, avoiding join-time bias.
            assert command('restart').get('ok')
            started = time.monotonic(); samples = []; last_print = 0
            print('ROUND_START', json.dumps(case), flush=True)
            while time.monotonic() - started < 240:
                status = observed(); samples.append(status)
                assert not status['lobby'], 'Unexpected lobby transition'
                assert len(status['players']) == count + 1, status
                assert all(p.poll() is None for p in children), 'A client exited during round'
                for tag in [f'bot-{i+1:02}' for i in range(count)] + ['observer']:
                    log = (OUT / (tag + '.log')).read_text(errors='replace')
                    if 'SCRIPT ERROR:' in log:raise RuntimeError('Script error in ' + tag + ': ' + log[-4000:])
                elapsed = time.monotonic() - started
                if elapsed - last_print >= 10:
                    print('ROUND_PROGRESS', case['mode'], round(elapsed), 'remaining', round(status['time_remaining']), 'players', len(status['players']), flush=True);last_print=elapsed
                if (args.preflight and elapsed > 20) or (elapsed > 3 and status['intermission'] > 0 and (case['mode'] != 'as' or status['assault_finished'])):break
                time.sleep(.5)
            else: raise RuntimeError('Round did not end within the time bound')
            result = dict(case=case, elapsed=time.monotonic()-started, final=status, samples=samples)
            results.append(result)
            (OUT / ('preflight.json' if args.preflight else 'results.json')).write_text(json.dumps(results, indent=2)+'\n')
            print('ROUND_END', case['mode'], status['result'], flush=True)
            time.sleep(2)
    finally:
        stop.touch()
        for process in children:
            try:process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:process.kill();process.wait()
        for handle in handles:handle.close()
        print('CLIENTS_REAPED', [p.returncode for p in children], flush=True)
        if not args.preflight:
            subprocess.run(['ssh','-S','/tmp/fpsloppa-remote-test.sock','blux@45.147.228.101',
                            'screen -S fpsloppa-all-modes -X quit'], check=False)
            print('TEST_SERVER_STOP_REQUESTED', flush=True)

if __name__ == '__main__':main()
