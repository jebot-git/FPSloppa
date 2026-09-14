"""Exercise restored Q1 switches and moving brushes on two real ENet clients."""
from pathlib import Path
import json, os, subprocess, time
root=Path(__file__).resolve().parents[2];out=root/'test-results/quake-mover-network';out.mkdir(exist_ok=True)
processes=[];handles=[]
try:
 for role in ['server','client1','client2']:
  h=(out/(role+'.log')).open('w');handles.append(h)
  cmd=[os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(root),'--log-file',str(out/(role+'-engine.log')),'--script','res://deathmatch/tests/quake_mover_network.gd','--',role]
  proc=subprocess.Popen(cmd,stdout=h,stderr=subprocess.STDOUT);processes.append((role,proc))
  if role=='server':
   deadline=time.monotonic()+30
   while time.monotonic()<deadline and proc.poll() is None and 'DM_HOST_READY' not in (out/'server.log').read_text():time.sleep(.1)
   assert 'DM_HOST_READY' in (out/'server.log').read_text(),'Server did not start'
 results=[]
 for role,proc in processes:
  proc.wait(timeout=60);log=(out/(role+'.log')).read_text()
  results.append({'role':role,'exit':proc.returncode,'pass':proc.returncode==0 and 'NETWORK_RESULT' in log and 'ERROR:' not in log})
 (out/'results.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results))
 assert all(row['pass'] for row in results)
finally:
 for _,proc in processes:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
 for h in handles:h.close()
