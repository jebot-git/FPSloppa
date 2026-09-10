"""Run new-mode/VR regression checks and three independent ENet processes."""
from pathlib import Path
import subprocess,os,time,json,tempfile,shutil
root=Path(__file__).resolve().parents[1];logs=root/'test-results';logs.mkdir(exist_ok=True)
godot=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64');results=[]
def verify(name,p,path,marker=''):
 text=path.read_text();ok=p.returncode==0 and marker in text and not any(x in text for x in ['FAIL ','SCRIPT ERROR:','ERROR:'])
 results.append({'test':name,'passed':ok,'exit':p.returncode});print(name,ok,flush=True)
with tempfile.TemporaryDirectory(prefix='fpsloppa-special-') as profile:
 asset_root=Path(profile)/"assets"
 for row in json.loads((root/"deathmatch/assets/base_manifest.json").read_text())["files"]:
  dest=asset_root/row["path"];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/row["path"],dest)
 env=dict(os.environ,XDG_DATA_HOME=profile)
 for script in ['special_modes','controls_seated','controller_tracking','vr','combat','melee','dual_pistols','team_modes','votes','vr_ui','map_import','optional_maps']:
  path=logs/f'special-{script}.log'
  with path.open('w') as out:p=subprocess.run([godot,'--headless','--xr-mode','off','--path',str(root),'--script',f'res://deathmatch/tests/{script}.gd','--','--asset-root',str(asset_root)],env=env,stdout=out,stderr=subprocess.STDOUT,timeout=120)
  verify(script,p,path)
 processes=[];handles=[]
 try:
  for role in ['server','red','blue']:
   path=logs/f'special-network-{role}.log';out=path.open('w');handles.append(out)
   p=subprocess.Popen([godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/special_network.gd','--',role,'--asset-root',str(asset_root)],env=env,stdout=out,stderr=subprocess.STDOUT);processes.append((role,p,path))
   if role=='server':
    deadline=time.monotonic()+10
    while time.monotonic()<deadline and 'DM_HOST_READY' not in path.read_text():
     if p.poll() is not None:break
     time.sleep(.05)
  for role,p,path in processes:p.wait(timeout=45);verify('network-'+role,p,path,'SPECIAL_NETWORK_RESULT')
 finally:
  for _,p,_ in processes:
   if p.poll() is None:p.terminate();p.wait(timeout=5)
  for out in handles:out.close()
(logs/'special-validation.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
