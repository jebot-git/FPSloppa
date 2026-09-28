#!/usr/bin/env python3
"""Reproducible headless ST matches, retaining cutoff and failed runs."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def snapshot(project, destination):
    """Freeze executable test/game scripts, share large unchanged assets."""
    destination.mkdir(parents=True, exist_ok=False)
    def copy_code(source, target):
        if source.is_dir():
            target.mkdir()
            for child in source.iterdir():
                copy_code(child, target / child.name)
        elif source.suffix in ('.gd', '.tscn', '.tres', '.py', '.godot'):
            shutil.copy2(source, target)
        else:
            target.symlink_to(source.resolve())
    for child in project.iterdir():
        if child.name in ('.git', '.worktrees', 'test-results'):
            continue
        target = destination / child.name
        if child.name in ('deathmatch', 'project.godot'):
            copy_code(child, target)
        elif child.name == 'tools':
            target.mkdir()
            for tool in child.iterdir():
                if tool.name == 'tribes':
                    copy_code(tool, target / tool.name)
                else:
                    (target / tool.name).symlink_to(tool.resolve())
        else:
            target.symlink_to(child.resolve())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--snapshot', type=Path, required=True)
    parser.add_argument('--seeds', type=int, default=13, help='Seeds per map (two maps)')
    parser.add_argument('--first-seed', type=int, default=9400)
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--seconds', type=int, default=1200)
    parser.add_argument('--port', type=int, default=29100)
    parser.add_argument('--maps', nargs='+', default=['ctf_stonehenge', 'ctf_raindance'])
    parser.add_argument('--wall-timeout', type=int, default=2400)
    args = parser.parse_args()
    if args.seeds < 1 or args.workers < 1 or args.seconds < 1:
        parser.error('seeds, workers and seconds must be positive')
    project = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    frozen = args.snapshot.resolve()
    snapshot(project, frozen)
    files = list((frozen / 'deathmatch').rglob('*.gd')) + list((frozen / 'tools/tribes').glob('*.gd'))
    receipt = dict(git_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
                   arguments={k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
                   fixed_physics_hz=60, team_size=8, time_scale=1,
                   code={str(p.relative_to(frozen)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
                   maps={name: hashlib.sha256((project / f'maps/{name}.bsp').read_bytes()).hexdigest() for name in args.maps})
    (output / 'provenance.json').write_text(json.dumps(receipt, indent=2))
    (output / 'source.patch').write_bytes(subprocess.check_output(['git', 'diff', '--no-ext-diff'], cwd=project))
    jobs = [(name, seed) for seed in range(args.first_seed, args.first_seed + args.seeds) for name in args.maps]
    def run(index, name, seed):
        folder = output / f'{name}-{seed}'
        folder.mkdir()
        options = dict(output=str(folder), port=args.port + index, team_size=8, speed=1,
                       seconds=args.seconds, seed=seed, map=name, headless=True, navigation_metrics=True)
        (folder / 'options.json').write_text(json.dumps(options, indent=2))
        env = os.environ.copy()
        env['XDG_DATA_HOME'] = f'/tmp/fps-st-batch-{args.port + index}'
        command = ['godot', '--headless', '--xr-mode', 'off', '--disable-render-loop', '--fixed-fps', '60',
                   '--max-fps', '0', '--path', str(frozen), '--script', 'tools/tribes/live_match.gd', '--', json.dumps(options)]
        started = time.monotonic()
        with (folder / 'server.log').open('w') as log:
            process = subprocess.Popen(command, cwd=frozen, env=env, stdout=log, stderr=subprocess.STDOUT)
            (folder / 'process.json').write_text(json.dumps(dict(pid=process.pid, command=command)))
            timed_out = False
            try:
                code = process.wait(timeout=args.wall_timeout)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
                code = process.returncode
                timed_out = True
        result = json.loads((folder / 'result.json').read_text()) if (folder / 'result.json').exists() else {}
        log = (folder / 'server.log').read_text()
        row = dict(map=name, seed=seed, folder=str(folder), exit_code=code, timed_out=timed_out,
                   wall_seconds=time.monotonic()-started, script_errors=log.count('SCRIPT ERROR'))
        row.update({k: result.get(k) for k in ('seconds', 'scores', 'termination_reason', 'first_capture_seconds')})
        row['teams'] = result.get('samples', [{}])[-1].get('teams')
        (folder / 'completion.json').write_text(json.dumps(row, indent=2))
        return row
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(run, i, name, seed) for i, (name, seed) in enumerate(jobs)]
        for future in as_completed(futures):
            row = future.result(); results.append(row)
            (output / 'progress.json').write_text(json.dumps(dict(completed=len(results), requested=len(jobs), runs=results), indent=2))
            print(json.dumps(row), flush=True)
    endings = {'match_finished', 'duration_reached', 'no_capture_600s', 'no_pickup_after_capture_600s'}
    assert all(r['exit_code'] in (0, 2) and not r['timed_out'] and not r['script_errors']
               and r['teams'] == [8, 8] and r['termination_reason'] in endings for r in results), 'Invalid runs retained for inspection'


if __name__ == '__main__':
    main()
