"""Exercise Scout RPCs, held inputs and snapshots over real local ENet."""
import os,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'test-results/st-vehicles/network';out.mkdir(parents=True,exist_ok=True)
processes=[]
try:
 for role,delay in [('server',2),('pilot',1),('viewer',0)]:
  with (out/f'{role}.log').open('w') as log:
   p=subprocess.Popen(['godot','--headless','--xr-mode','off','--path',str(root),'--script','deathmatch/tests/st_scout_network.gd','--',role],stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME=f'/tmp/scout-network-{role}',XDG_CONFIG_HOME=f'/tmp/scout-network-{role}'))
  processes.append((role,p));time.sleep(delay)
 for role,p in processes:
  p.wait(timeout=60)
  text=(out/f'{role}.log').read_text();print(role,p.returncode,'\n'+'\n'.join(x for x in text.splitlines() if x.startswith(('PASS','FAIL','SCOUT_NETWORK'))))
  assert p.returncode==0 and f'SCOUT_NETWORK_RESULT {role} []' in text and 'SCRIPT ERROR' not in text
finally:
 for _,p in processes:
  if p.poll() is None:p.terminate()
