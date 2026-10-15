"""Run the prepared comparison with an optional same-user CQ service suspension.

Execute on the VPS. A detached guardian resumes the original process if the
supervisor exits unexpectedly. No service installation/configuration is changed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def identity(pid):
    try:
        stat = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
        return stat[19], stat[0]
    except (FileNotFoundError, ProcessLookupError):
        return None


def resume(pid, original):
    current = identity(pid)
    if current and current[0] == original[0]:
        os.kill(pid, signal.SIGCONT)
        return True
    return False


def terminate_group(process):
    if process:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--suspend-service', help='Explicitly authorize suspension of this same-user service')
    parser.add_argument('--verify-only', action='store_true')
    parser.add_argument('--timeout', type=int, default=3600)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    manifest = json.loads((bundle / 'manifest.json').read_text())
    for name, digest in manifest['files'].items():
        path = (bundle / name).resolve()
        if not path.is_relative_to(bundle) or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise RuntimeError('Bundle checksum mismatch: ' + name)
    pid = 0
    original = None
    if args.suspend_service:
        info = subprocess.check_output(['systemctl', 'show', args.suspend_service,
                                        '-p', 'MainPID', '-p', 'WatchdogUSec', '-p', 'NRestarts'], text=True)
        fields = dict(line.split('=', 1) for line in info.splitlines())
        pid = int(fields['MainPID'])
        if pid:
            if fields['WatchdogUSec'] != '0':
                raise RuntimeError('Cannot suspend a watchdog-managed service')
            if Path(f'/proc/{pid}').stat().st_uid != os.getuid():
                raise RuntimeError('Service must run as the current user')
            if b'--server' not in Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0'):
                raise RuntimeError('Service process is not a CQ server')
            original = identity(pid)
            if original is None:
                raise RuntimeError('Service process disappeared before suspension')
    print(json.dumps({'verified_files': len(manifest['files']), 'service': args.suspend_service,
                      'pid': pid, 'original_identity': original}), flush=True)
    if args.verify_only:
        return
    if args.output.exists():
        parser.error('Output must be a new directory')
    args.output.mkdir(parents=True)
    output = args.output.resolve()
    supervisor = os.getpid()
    supervisor_identity = identity(supervisor)
    should_resume = bool(pid and original[1] not in ['T', 't'])
    if should_resume:
        guardian = os.fork()
        if guardian == 0:
            os.setsid()
            deadline = time.monotonic() + args.timeout + 60
            while time.monotonic() < deadline:
                current = identity(supervisor)
                if not current or current[0] != supervisor_identity[0] or current[1] == 'Z':
                    break
                time.sleep(2)
            restored = resume(pid, original)
            (output / 'guardian.json').write_text(json.dumps({'resumed_original_process': restored, 'utc_epoch': time.time()}))
            os._exit(0)
    def interrupted(signum, _frame):
        raise RuntimeError('Supervisor interrupted: ' + str(signum))
    for signum in [signal.SIGTERM, signal.SIGINT, signal.SIGHUP, signal.SIGALRM]:
        signal.signal(signum, interrupted)
    signal.alarm(args.timeout)
    sampler = None
    tests = None
    status = {'service': args.suspend_service, 'original_pid': pid, 'original_identity': original,
              'started_utc_epoch': time.time(), 'suspended': False, 'completed': False}
    try:
        if should_resume:
            os.kill(pid, signal.SIGSTOP)
            status['suspended'] = True
        (output / 'status.json').write_text(json.dumps(status, indent=2))
        binary = bundle / 'release/cq-server'
        with (output / 'sampler.log').open('w') as sample_log, (output / 'comparison.log').open('w') as test_log:
            sampler = subprocess.Popen([sys.executable, str(bundle / 'capacity/process_sampler.py'),
                                        '--binary', str(binary), '--output', str(output / 'processes.jsonl'),
                                        '--seconds', str(args.timeout)], stdout=sample_log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            tests = subprocess.Popen([sys.executable, str(bundle / 'tools/player_simulation/run_suite.py'),
                                      '--binary', str(binary), '--output', str(output / 'comparison'),
                                      '--seconds', '120', '--players', '32', '64', '--skip-regressions'],
                                     cwd=bundle, stdout=test_log, stderr=subprocess.STDOUT, start_new_session=True)
            status['comparison_exit_code'] = tests.wait(timeout=args.timeout - 20)
            result = json.loads((output / 'comparison/results.json').read_text())
            status['completed'] = status['comparison_exit_code'] == 0 and result.get('passed') is True and len(result['results']) == 10
            if not status['completed']:
                raise RuntimeError('Comparison did not pass all ten cases')
    finally:
        terminate_group(tests)
        terminate_group(sampler)
        status['resumed_original_process'] = resume(pid, original) if should_resume else False
        status['finished_utc_epoch'] = time.time()
        (output / 'status.json').write_text(json.dumps(status, indent=2))
        signal.alarm(0)
        print(json.dumps(status), flush=True)


if __name__ == '__main__':
    main()
