"""Focused mode, map, UI and ENet checks; writes a machine-readable validation report."""
from pathlib import Path
import json,os,shutil,subprocess,time
root=Path(__file__).resolve().parents[1]
logs=root/'test-results';logs.mkdir(exist_ok=True)
godot=os.environ.get('GODOT_BIN') or shutil.which('godot')
results=[]
def run(name,script):
 path=logs/f'team-{name}.log'
 with path.open('w') as out:
  p=subprocess.run([godot,'--headless','--xr-mode','off','--path',str(root),'--script',f'res://{script}'],stdout=out,stderr=subprocess.STDOUT,timeout=90)
 text=path.read_text();ok=p.returncode==0 and not any(x in text for x in ['FAIL ','ERROR:'])
 results.append({'test':name,'passed':ok,'exit':p.returncode});print(name,ok,flush=True)
for name in ['team_modes','server_logging','votes','steam_audio','maps','team_objectives','presentation','vr_ui']:
 run(name,'deathmatch/tests/'+name+'.gd')
processes=[];handles=[]
try:
 for role in ['server','red','blue','observer']:
  path=logs/f'team-network-{role}.log';out=path.open('w');handles.append(out)
  p=subprocess.Popen([godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/team_network.gd','--',role],stdout=out,stderr=subprocess.STDOUT);processes.append((role,p,path))
  if role=='server':
   deadline=time.monotonic()+10
   while time.monotonic()<deadline and 'DM_HOST_READY' not in path.read_text():
    if p.poll() is not None:break
    time.sleep(.05)
 for role,p,path in processes:
  p.wait(timeout=60);text=path.read_text();ok=p.returncode==0 and 'TEAM_NETWORK_RESULT' in text and not any(x in text for x in ['FAIL ','ERROR:'])
  results.append({'test':'network-'+role,'passed':ok,'exit':p.returncode});print('network-'+role,ok,flush=True)
finally:
 for _,p,_ in processes:
  if p.poll() is None:p.terminate();p.wait(timeout=5)
 for out in handles:out.close()
(logs/'team-validation.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(x['passed'] for x in results) else 1)
