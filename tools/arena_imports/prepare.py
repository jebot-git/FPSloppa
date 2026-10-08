"""Prepare lighting/mips/navigation and retain per-map failures for review."""
from pathlib import Path
import subprocess,json,argparse,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/arena-imports'
p=argparse.ArgumentParser();p.add_argument('--resume',action='store_true');p.add_argument('--map');p.add_argument('--collection');p.add_argument('--compiled-only',action='store_true');a=p.parse_args();OUT.mkdir(parents=True,exist_ok=True)
def fresh(row,receipt):
 try:
  report=json.loads(receipt.read_text())
  if report['bsp_sha256']!=row['sha256'] or report['failures']:return False
  if hashlib.sha256((ROOT/'maps'/(row['id']+'.bsp')).read_bytes()).hexdigest()!=row['sha256']:return False
  if {c['format'] for c in report['codecs']}!={'bc7','astc4'}:return False
  for c in report['codecs']:
   if hashlib.sha256((ROOT/c['path'].removeprefix('res://')).read_bytes()).hexdigest()!=c['sha256']:return False
  return all((ROOT/'maps/cache'/(row['id']+suffix)).exists() for suffix in ['.scn','-lightmap1.scn']) and (ROOT/'maps/navigation'/(row['id']+'.res')).exists()
 except (OSError,ValueError,KeyError):return False
rows=json.loads((ROOT/'tools/arena_imports/conversions.json').read_text());reports=[]
for row in rows:
 if a.collection and row["collection"]!=a.collection:continue
 if a.compiled_only and row.get('status')!='candidate':continue
 if a.map and row['id']!=a.map:continue
 receipt=OUT/(row['id']+'.json');log=OUT/(row['id']+'.log')
 if a.resume and fresh(row,receipt):print(row['id'],'cached',flush=True);continue
 with log.open('w') as f:
  try:code=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','tools/arena_imports/prepare.gd','--',row['id']],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=600).returncode
  except subprocess.TimeoutExpired:code=124
 text=log.read_text();reports.append({'id':row['id'],'exit':code,'errors':[l for l in text.splitlines() if 'ERROR:' in l]});print(row['id'],code,reports[-1]['errors'][:3],flush=True)
 (ROOT/'tools/arena_imports/preparation.json').write_text(json.dumps(reports,indent=2)+'\n')

raise SystemExit(1 if any(r["exit"] or r["errors"] for r in reports) else 0)
