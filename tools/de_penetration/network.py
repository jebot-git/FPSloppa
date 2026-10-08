"""Two-process local ENet wallbang validation on the converted Inferno BSP."""
import subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];out=ROOT/'test-results/de-penetration';out.mkdir(exist_ok=True)
jobs=[]
try:
 for role in ['server','client']:
  log=(out/('network-'+role+'.log')).open('w');cmd=[str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','tools/de_penetration/network.gd','--',role,'--no-bots'];jobs.append((role,subprocess.Popen(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT),log))
  if role=='server':time.sleep(2)
 for role,p,log in jobs:
  p.wait(timeout=80);log.flush();s=(out/('network-'+role+'.log')).read_text();print(role,p.returncode,s[-1800:]);assert p.returncode==0 and 'CONVERTED_COVER_NETWORK' in s and 'SCRIPT ERROR:' not in s
finally:
 for _,p,log in jobs:
  if p.poll() is None:p.kill();p.wait()
  log.close()
