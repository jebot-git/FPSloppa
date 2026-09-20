"""Build an isolated console benchmark pack and sweep master/worker capacity.

Run build_console_server.py with --cq-assets first to produce the baseline package.
No live listeners, admission-limit changes, or remote service operations.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary', type=Path, default=ROOT/'Builds/CQExternal/FPSloppaServer.x86_64')
p.add_argument('--name', default='capacity')
p.add_argument('--cpus', default='8,9', help='Affinity; choose one performance core and its SMT sibling on this machine')
p.add_argument('--suite', choices=['master', 'worker', 'all'], default='all')
p.add_argument('--seconds', type=float, default=12)
p.add_argument('--repeat', type=int, default=1)
p.add_argument('--players', type=int, nargs='+', default=[4,8,16,24,32,48,64,96,128])
p.add_argument('--districts', type=int, nargs='+', help='Explicit master matrix, combined with --players')
p.add_argument('--iterations', type=int, default=40)
p.add_argument('--shared', action='store_true', help='Measure proposed shared district encoding, not current production replication')
p.add_argument('--xr', action='store_true', help='Include ordinary tracked head/hand/weapon pose payloads')
p.add_argument('--ordnance', type=int, default=0, help='Synthetic rocket records per district in master snapshots')
args = p.parse_args()
if not 1 <= args.seconds <= 60 or not 1 <= args.repeat <= 5 or not 1 <= args.iterations <= 200:
    p.error('Use 1–60 seconds, 1–5 repeats and 1–200 snapshot iterations')
if any(n < 1 or n > 128 for n in args.players) or args.ordnance not in range(257):
    p.error('Use 1–128 synthetic players and 0–256 projectile records')
if args.districts and any(d < 1 or d > 128 or d*max(args.players)>256 for d in args.districts):
    p.error('Limit the explicit matrix to 1–128 districts and 256 total synthetic actors')
out = ROOT/'test-results/cq-scale'/args.name
out.mkdir(parents=True, exist_ok=True)


def prepare():
    baseline = json.loads((args.binary.parent/'server-build.json').read_text())
    (out/'scalability.tscn').write_text('[gd_scene format=3]\n[ext_resource type="Script" path="res://tools/cq_gateway/scalability.gd" id="1"]\n[node name="Scale" type="Node"]\nscript=ExtResource("1")\n')
    manifest=dict(base_pack=str(args.binary.with_suffix('.pck').resolve()),resources=baseline['resources'],project=str(out/'project.godot'),output=str(out/'ScaleServer.pck'),extra=[dict(path='res://tools/cq_gateway/scalability.gd',source=str(ROOT/'tools/cq_gateway/scalability.gd')),dict(path='res://tools/cq_gateway/scalability.tscn',source=str(out/'scalability.tscn'))])
    (out/'pack.json').write_text(json.dumps(manifest,indent=2)+'\n')
    with (out/'package.log').open('w') as log:
        subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','tools/cq_gateway/scalability_pack.gd','--',str(out/'pack.json')],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    shutil.copy2(args.binary,out/'ScaleServer.x86_64')


def case(label, extra):
    command = ['taskset','-c',args.cpus,str(out/'ScaleServer.x86_64'),'--','--asset-root',str(args.binary.resolve().parent),'--experimental-cq','--ordnance',str(args.ordnance),*extra,*(['--shared'] if args.shared else []),*(['--xr'] if args.xr else [])]
    peak_rss=0; started=time.monotonic()
    with (out/(label+'.log')).open('w') as log:
        proc=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env=dict(os.environ,XDG_DATA_HOME=str(out/'profile')))
        try:
            while proc.poll() is None:
                try:
                    fields=Path(f'/proc/{proc.pid}/status').read_text().splitlines()
                    peak_rss=max(peak_rss,next(int(row.split()[1]) for row in fields if row.startswith('VmRSS:')))
                except (OSError,StopIteration):pass
                if time.monotonic()-started>180:raise TimeoutError(label)
                time.sleep(.1)
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid,signal.SIGKILL);proc.wait()
    text=(out/(label+'.log')).read_text()
    if proc.returncode or 'SCRIPT ERROR' in text:
        raise RuntimeError(f'{label} failed: '+text[-3000:])
    result=json.loads(next(row.removeprefix('CQ_SCALE ') for row in text.splitlines() if row.startswith('CQ_SCALE ')))
    result.update(label=label,peak_rss_mib=peak_rss/1024,wall_seconds=time.monotonic()-started)
    print(label,json.dumps(result),flush=True)
    return result


prepare()
report=dict(scope='Isolated console-runtime CPU/serialization benchmark with synthetic actors, not connected clients or multi-host certification.',cpu=next(row.split(':',1)[1].strip() for row in Path('/proc/cpuinfo').read_text().splitlines() if row.startswith('model name')),affinity=args.cpus,baseline_binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),baseline_pack_sha256=hashlib.sha256(args.binary.with_suffix('.pck').read_bytes()).hexdigest(),benchmark_sha256=hashlib.sha256((ROOT/'tools/cq_gateway/scalability.gd').read_bytes()).hexdigest(),runs=[])
report['options']={key:str(value) if isinstance(value,Path) else value for key,value in vars(args).items()}
try:
    for repeat in range(args.repeat):
        if args.suite in ('master','all'):
            cases=[(d,4) for d in [1,4,8,16,24,32,48,64]]+[(1,n) for n in args.players if n!=4]+[(16,8),(16,16)]
            if args.districts:cases=[(d,n) for d in args.districts for n in args.players]
            for districts,players in cases:
                report['runs'].append(case(f'master-d{districts}-p{players}-r{repeat}',['--kind','master','--districts',str(districts),'--players',str(players),'--iterations',str(args.iterations)]))
        if args.suite in ('worker','all'):
            for scenario in ['movement','combat']:
                for players in args.players:
                    report['runs'].append(case(f'worker-{scenario}-p{players}-r{repeat}',['--kind','worker','--players',str(players),'--scenario',scenario,'--seconds',str(args.seconds)]))
        (out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
finally:
    (out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
