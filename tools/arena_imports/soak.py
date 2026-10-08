"""Short live-bot movement/combat checks on representative converted arenas."""
from pathlib import Path
import subprocess,json,time
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/arena-imports'
for name in ['dm_q30_abattoir','dm_q30_magenta','dm_rcmd_spirit1dm1']:
 deadline=time.monotonic()+1200
 while not (OUT/(name+'.json')).exists() and time.monotonic()<deadline:time.sleep(3)
 options={'map':name,'mode':'dm','rules':'quake','bots':4,'seconds':30,'seed':7129,'output':str(OUT/(name+'-soak.json'))}
 with (OUT/(name+'-soak.log')).open('w') as f:
  try:code=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','deathmatch/tests/bot_soak.gd','--',json.dumps(options)],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=150).returncode
  except subprocess.TimeoutExpired:code=124
 print(name,code,flush=True)
