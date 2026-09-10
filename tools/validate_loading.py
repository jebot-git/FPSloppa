"""Real map + two VRM downloads into an empty client model cache before admission."""
from pathlib import Path
import argparse,json,os,subprocess,tempfile,time,shutil
parser=argparse.ArgumentParser();parser.add_argument("--render-client",action="store_true");args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1]
godot=os.environ.get('GODOT_BIN','godot')
logs=ROOT/('test-results/loading-rendered' if args.render_client else 'test-results/loading');logs.mkdir(parents=True,exist_ok=True)
results=[]
with tempfile.TemporaryDirectory(prefix='fpsloppa-loading-') as temp:
    folder=Path(temp)
    custom=folder/'arena.bsp';custom.write_bytes((ROOT/'maps/lqdm2.bsp').read_bytes()+b' loading-gate '+folder.name.encode())
    models=[ROOT/'vrm/sample_f.vrm',ROOT/'vrm/sample_c.vrm']
    if not models[1].exists():models[1]=next(p for p in (ROOT/'vrm').glob('sample_*.vrm') if p!=models[0])
    processes=[];handles=[]
    try:
        for role in ['server','client']:
            assets=folder/role; (assets/'maps').mkdir(parents=True);(assets/'vrm').mkdir()
            for p in (ROOT/'maps').glob('lqdm*'):
                if p.is_file():shutil.copy2(p,assets/'maps'/p.name)
            path=logs/(role+'.log');out=path.open('w');handles.append(out)
            command=[godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/loading_join.gd','--',role,str(custom),*map(str,models),'--asset-root',str(assets)]
            if role=='client' and args.render_client:
                command.remove('--headless');command[1:1]=['--audio-driver','Dummy']
            proc=subprocess.Popen(command,env=dict(os.environ,XDG_DATA_HOME=str(folder/('profile-'+role))),stdout=out,stderr=subprocess.STDOUT);processes.append((role,proc,path))
            if role=='server':
                until=time.monotonic()+15
                while time.monotonic()<until and 'DM_HOST_READY' not in path.read_text() and proc.poll() is None:time.sleep(.05)
        for role,proc,path in processes:
            proc.wait(timeout=100);text=path.read_text()
            passed=proc.returncode==0 and 'LOADING_JOIN_RESULT' in text and not any(t in text for t in ['ERROR:','FAIL '])
            results.append({'role':role,'passed':passed});print(role,passed,text[-2500:],flush=True)
    finally:
        for _,proc,_ in processes:
            if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
        for handle in handles:handle.close()
(logs/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(row['passed'] for row in results) else 1)
