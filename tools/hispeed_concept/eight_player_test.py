"""Dedicated AS server plus eight independent ENet clients on the actual HiSpeed BSP."""
from pathlib import Path
import argparse,json,os,subprocess,tempfile,time
ROOT=Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('bsp',type=Path);parser.add_argument('--demo',type=Path);parser.add_argument('--output',type=Path,default=ROOT/'test-results/as-eight');args=parser.parse_args()
    if args.demo:
        args.demo.parent.mkdir(parents=True,exist_ok=True)
        if args.demo.exists():raise SystemExit("Refusing to overwrite "+str(args.demo))
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);processes=[];handles=[];results=[]
    with tempfile.TemporaryDirectory(prefix='fpsloppa-as-eight-') as temp:
        try:
            for role in ['server']+[f'player{i}' for i in range(8)]:
                log=out/(role+'.log');handle=log.open('w');handles.append(handle)
                cmd=[os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')),'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/assault_eight.gd','--',role,str(args.bsp.resolve()),*([str(args.demo.resolve())] if args.demo else [])]
                proc=subprocess.Popen(cmd,env=dict(os.environ,XDG_DATA_HOME=str(Path(temp)/role)),stdout=handle,stderr=subprocess.STDOUT);processes.append((role,proc))
                if role=='server':
                    deadline=time.monotonic()+30
                    while time.monotonic()<deadline and proc.poll() is None and 'DM_HOST_READY' not in log.read_text():time.sleep(.1)
                    if 'DM_HOST_READY' not in log.read_text():raise RuntimeError('AS host did not start: '+str(log))
            deadline=time.monotonic()+210
            for role,proc in processes:
                proc.wait(timeout=max(1,deadline-time.monotonic()));text=(out/(role+'.log')).read_text()
                rows=[json.loads(line.removeprefix('EIGHT_RESULT ')) for line in text.splitlines() if line.startswith('EIGHT_RESULT ')]
                results.append({'role':role,'exit':proc.returncode,'passed':proc.returncode==0 and len(rows)==1 and not rows[0]['failures'] and 'ERROR:' not in text,'result':rows[0] if rows else {}})
            (out/'RESULT.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2),flush=True)
            return 0 if all(row['passed'] for row in results) else 1
        finally:
            for _,proc in processes:
                if proc.poll() is None:proc.terminate()
            for _,proc in processes:
                if proc.poll() is None:
                    try:proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:proc.kill();proc.wait()
            for handle in handles:handle.close()
if __name__=='__main__':raise SystemExit(main())
