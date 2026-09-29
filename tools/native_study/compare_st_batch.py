"""Sequential native/reference comparisons on a local client or staged server."""
from pathlib import Path
import argparse,hashlib,json,os,resource,subprocess,time

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kind',choices=['server','avatars','projectiles'],required=True)
    parser.add_argument('--runtime',default='godot')
    parser.add_argument('--packaged',action='store_true',help='Run benchmark entry scene from adjacent dedicated PCK')
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--counts',nargs='+',type=int,default=[16,32])
    parser.add_argument('--maps',nargs='+',default=['ctf_stonehenge','ctf_raindance'])
    parser.add_argument('--ticks',type=int,default=1200)
    parser.add_argument('--warmup',type=int,default=300)
    parser.add_argument('--order',nargs='+',default=['reference-a','native-a','native-b','reference-b'])
    args=parser.parse_args();args.project=args.project.resolve();args.output=args.output.resolve();args.output.mkdir(parents=True,exist_ok=True)
    reports={}
    for count in args.counts:
        for map_id in (args.maps if args.kind=='server' else ['']):
            for label in args.order:
                name='-'.join(str(x) for x in [args.kind,map_id,count,label] if x)
                flags=[]
                if label.startswith('reference'):
                    flags=['--gdscript-st-steering','--reference-nav-queries','--reference-mine-scan'] if args.kind=='server' else ['--gdscript-avatar-channels'] if args.kind=='avatars' else ['--reference-mine-scan']
                values=[map_id,str(count),str(args.ticks),str(args.warmup)] if args.kind=='server' else [str(count)]
                command=[args.runtime,*([] if args.kind=='avatars' else ['--headless']),'--xr-mode','off',* ([] if args.packaged else ['--path',str(args.project),'--script','res://tools/native_study/st_batch_'+args.kind+'.gd']),'--',*values,*flags,*(['--projectile-benchmark'] if args.packaged and args.kind=='projectiles' else []),'--client-config','/tmp/fps-st-batch.cfg']
                before=resource.getrusage(resource.RUSAGE_CHILDREN);started=time.monotonic();peak=0
                cpu_before=[int(x) for x in Path('/proc/stat').read_text().splitlines()[0].split()[1:]]
                log=args.output/(name+'.log')
                with log.open('w') as stream:
                    proc=subprocess.Popen(command,cwd=args.project,env=dict(os.environ,XDG_DATA_HOME='/tmp/fps-st-batch-data'),stdout=stream,stderr=subprocess.STDOUT)
                    try:
                        while proc.poll() is None:
                            try:
                                status=Path('/proc')/str(proc.pid)/'status'
                                for line in status.read_text().splitlines():
                                    if line.startswith('VmHWM:'):peak=max(peak,int(line.split()[1]))
                            except FileNotFoundError:pass
                            if 'SCRIPT ERROR' in log.read_text() or time.monotonic()-started>480:
                                proc.terminate();proc.wait(timeout=15);raise RuntimeError(name+' failed or timed out; '+str(log))
                            time.sleep(.25)
                    finally:
                        if proc.poll() is None:proc.kill();proc.wait()
                output=log.read_text()
                if proc.returncode or 'SCRIPT ERROR' in output or 'FAIL ' in output:raise RuntimeError(name+' failed; '+str(log))
                result=None
                for line in output.splitlines():
                    if line.startswith('ST_BATCH_RESULT '):result=json.loads(line.split(' ',1)[1])
                if result is None:raise RuntimeError(name+' missing benchmark result')
                after=resource.getrusage(resource.RUSAGE_CHILDREN);cpu_after=[int(x) for x in Path('/proc/stat').read_text().splitlines()[0].split()[1:]]
                cpu_delta=[a-b for a,b in zip(cpu_after,cpu_before)]
                reports[name]={'result':result,'elapsed_seconds':time.monotonic()-started,'process_cpu_seconds':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,'peak_rss_kib':peak,'host_steal_fraction':cpu_delta[7]/max(1,sum(cpu_delta[:8])),'command':command,'log_sha256':hashlib.sha256(output.encode()).hexdigest()}
                (args.output/(name+'.json')).write_text(json.dumps(reports[name],indent=2)+'\n')
                (args.output/(args.kind+'-comparison.json')).write_text(json.dumps(reports,indent=2)+'\n')
                print(name,'PASS',flush=True)
if __name__=='__main__':main()
