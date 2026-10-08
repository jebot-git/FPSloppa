"""Validate prepared maps through their real runtime collision and bot planner."""
from pathlib import Path
import json,subprocess,time,argparse
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/arena-imports'
p=argparse.ArgumentParser();p.add_argument('--map');p.add_argument('--collection');p.add_argument('--compiled-only',action='store_true');p.add_argument('--resume',action='store_true');args=p.parse_args()
failed=[]
rows=json.loads((ROOT/'tools/arena_imports/conversions.json').read_text())
for row in rows:
 if args.collection and row["collection"]!=args.collection:continue
 if args.compiled_only and row.get('status')!='candidate':continue
 if args.map and row['id']!=args.map:continue
 name=row['id'];prepared=OUT/(name+'.json');receipt=OUT/(name+'-gameplay.json')
 if args.resume and receipt.exists() and not json.loads(receipt.read_text())['failures'] and json.loads(receipt.read_text())['bsp_sha256']==row['sha256']:continue
 end=time.monotonic()+900
 while time.monotonic()<end:
  if prepared.exists() and json.loads(prepared.read_text()).get('bsp_sha256')==row['sha256']:break
  time.sleep(2)
 if not prepared.exists() or json.loads(prepared.read_text()).get('bsp_sha256')!=row['sha256'] or json.loads(prepared.read_text())['failures']:print(name,'not prepared',flush=True);failed.append(name);continue
 with (OUT/(name+'-gameplay.log')).open('w') as f:
  try:code=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','tools/arena_imports/validate.gd','--',name],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
  except subprocess.TimeoutExpired:code=124
 r=json.loads(receipt.read_text()) if receipt.exists() else {}
 if code or not r or r.get('failures') or r.get('bsp_sha256')!=row['sha256']:failed.append(name)
 print(name,code,r.get('failures'),str(r.get('reachable_spawn_pairs'))+'/'+str(r.get('spawn_route_pairs')),'items',r.get('reachable_pickups'),r.get('tested_pickups'),flush=True)

raise SystemExit(bool(failed))
