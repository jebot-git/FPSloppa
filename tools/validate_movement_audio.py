"""Exercise real takeoff/landing and server-to-client 3D audio events."""
from pathlib import Path
import os,subprocess,time,json,sys
ROOT=Path(__file__).resolve().parents[1];LOG=ROOT/'test-results';GODOT=os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64'));results=[]
LOG.mkdir(exist_ok=True)
def result(name,code,path):
 text=path.read_text();ok=code==0 and not any(s in text for s in ['FAIL ','SCRIPT ERROR','ERROR:'])
 results.append({'test':name,'passed':ok,'exit':code});print(name,ok,flush=True)
if '--network-only' in sys.argv and (LOG/'sfx-validation.json').exists():
 results=[r for r in json.loads((LOG/'sfx-validation.json').read_text()) if not r['test'].startswith('network-')]
for script in ([] if '--network-only' in sys.argv else ['movement_audio','feedback_audio','quake_movement']):
 path=LOG/('sfx-'+script+'.log')
 with path.open('w') as out:r=subprocess.run([GODOT,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/'+script+'.gd'],stdout=out,stderr=subprocess.STDOUT,timeout=60)
 result(script,r.returncode,path)
processes=[];handles=[]
try:
 for role in ['server','jumper','listener']:
  path=LOG/('sfx-network-'+role+'.log');out=path.open('w');handles.append(out)
  p=subprocess.Popen([GODOT,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/movement_audio_network.gd','--',role],stdout=out,stderr=subprocess.STDOUT);processes.append((role,p,path))
  if role=='server':
   end=time.monotonic()+12
   while time.monotonic()<end and 'DM_HOST_READY' not in path.read_text() and p.poll() is None:time.sleep(.05)
 for role,p,path in processes:result('network-'+role,p.wait(timeout=35),path)
finally:
 for _,p,_ in processes:
  if p.poll() is None:p.terminate();p.wait(timeout=5)
 for out in handles:out.close()
(LOG/'sfx-validation.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
