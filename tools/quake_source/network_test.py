"""Actual host download/handshake test with two isolated clients."""
from pathlib import Path
import argparse,subprocess,time,shutil,os,json,tempfile
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('map',type=Path);a=p.parse_args();path=a.map.resolve();out=ROOT/'test-results/quake-source-network-final';out.mkdir(parents=True,exist_ok=True);processes=[];handles=[]
try:
 for role in ['server','client1','client2']:
  asset=Path(tempfile.mkdtemp(prefix=role+'-',dir=out));maps=asset/'maps';maps.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'maps/lqdm1.bsp',maps/'lqdm1.bsp')
  log=out/(role+'.log');h=log.open('w');handles.append(h)
  cmd=[os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')),'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/quake_source_network.gd','--',role,str(path),'--asset-root',str(asset)]
  proc=subprocess.Popen(cmd,stdout=h,stderr=subprocess.STDOUT);processes.append((role,proc))
  if role=='server':
   deadline=time.monotonic()+30
   while time.monotonic()<deadline and proc.poll() is None and 'DM_HOST_READY' not in log.read_text():time.sleep(.1)
   if 'DM_HOST_READY' not in log.read_text():raise RuntimeError('Host did not start; inspect server.log')
 results=[]
 for role,proc in processes:
  proc.wait(timeout=100);text=(out/(role+'.log')).read_text();results.append({'role':role,'exit':proc.returncode,'pass':proc.returncode==0 and 'NETWORK_RESULT' in text and 'ERROR:' not in text});print(role,results[-1],flush=True)
 (out/'RESULT.json').write_text(json.dumps(results,indent=2));raise SystemExit(0 if all(r['pass'] for r in results) else 1)
finally:
 for _,proc in processes:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
 for h in handles:h.close()
