"""Bounded, reaped current-source clients for the explicitly authorized test server."""
import argparse
import json
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]


def states(path):
    result=[]
    if path.exists():
        for line in path.read_text(errors='replace').splitlines():
            if line.startswith('REMOTE_PROBE '):
                try:result.append(json.loads(line[13:]))
                except json.JSONDecodeError:pass
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host',required=True)
    parser.add_argument('--port',type=int,required=True)
    parser.add_argument('--count',type=int,default=1,choices=range(1,17))
    parser.add_argument('--hold',type=int,default=30)
    parser.add_argument('--label',required=True)
    parser.add_argument('--cold',action='store_true')
    parser.add_argument('--spectator',action='store_true')
    parser.add_argument('--reject',action='store_true')
    args=parser.parse_args()
    assert args.label.replace('-','').isalnum()
    out=ROOT/'test-results/remote-current'/args.label;out.mkdir(parents=True,exist_ok=True)
    # Replace the root script in the scene definition before instantiation;
    # set_script() on a live Arena abandons its already-allocated helper nodes.
    scene=out/'arena.tscn'
    scene.write_text((ROOT/'deathmatch/arena.tscn').read_text().replace('res://deathmatch/arena.gd','res://deathmatch/tests/remote_probe_arena.gd'))
    stop=out/'stop';stop.unlink(missing_ok=True)
    children=[];handles=[];admitted_at=None;peak=0;latest=[]
    begin=time.monotonic();last_print=0;held_seconds=0.0;completed_hold=False
    try:
        for i in range(args.count):
            tag=f'{i+1:02}';log=out/(tag+'.log');handle=log.open('w');handles.append(handle)
            cfg=out/(tag+'.cfg');cfg.write_text('[voice]\nmode=0\n[presentation]\nspatial_audio="stereo"\n')
            assets=out/('assets-'+tag) if args.cold else ROOT
            assets.mkdir(exist_ok=True)
            command=['godot','--headless','--xr-mode','off','--audio-driver','Dummy','--path',str(ROOT),
                '--log-file',str(out/(tag+'-engine.log')),'--script','res://deathmatch/tests/remote_probe.gd','--',
                '--probe',tag,'--host',args.host,'--port',str(args.port),'--stop-file',str(stop),
                '--probe-scene',str(scene),
                '--client-config',str(cfg),'--asset-root',str(assets)]
            if args.spectator:command.append('--spectator')
            if args.reject:command.append('--reject')
            children.append(subprocess.Popen(command,stdout=handle,stderr=subprocess.STDOUT))
            time.sleep(.3)
        while time.monotonic()-begin<args.hold+150:
            snapshots=[states(out/f'{i+1:02}.log') for i in range(args.count)]
            latest=[rows[-1] for rows in snapshots if rows]
            active=[r for r in latest if r['active']]
            peak=max(peak,len(active))
            now=time.monotonic()
            fresh=all((now-begin<12 or time.time()-(out/f'{i+1:02}.log').stat().st_mtime<10) for i in range(args.count))
            if len(active)==args.count and all(r['count']>=args.count for r in active) and fresh and all(p.poll() is None for p in children):
                if admitted_at is None:admitted_at=now;print('ALL_ADMITTED',args.count,flush=True)
                held_seconds=now-admitted_at
                if held_seconds>=args.hold:completed_hold=True;break
            elif admitted_at is not None:
                # A partial admission followed by a disconnect is not a passed hold.
                break
            if now-last_print>10:
                print(json.dumps({'elapsed':round(now-begin),'active':len(active),'rosters':[r['count'] for r in latest],'maps':sorted(set(r['map'] for r in latest)),'phases':sorted(set(r['loading']['phase'] for r in latest))}),flush=True);last_print=now
            if all(p.poll() is not None for p in children):break
            time.sleep(.5)
    finally:
        stop.touch()
        for child in children:
            try:child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.terminate()
                try:child.wait(timeout=5)
                except subprocess.TimeoutExpired:child.kill();child.wait()
        for handle in handles:handle.close()
    exits=[p.returncode for p in children]
    rejected=args.reject and all('REMOTE_REJECTED' in (out/f'{i+1:02}.log').read_text() for i in range(args.count))
    report=dict(host=args.host,port=args.port,count=args.count,cold=args.cold,spectator=args.spectator,peak_admitted=peak,
        held_seconds=round(held_seconds,2),exit_codes=exits,states=latest,
        passed=all(code==0 for code in exits) and (rejected if args.reject else completed_hold))
    (out/'summary.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
