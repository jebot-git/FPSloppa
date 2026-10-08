#!/usr/bin/env python3
"""Prepare and audit every base DE/ST map in isolated engine processes."""
import argparse,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/expansion-assets'
def main():
 p=argparse.ArgumentParser();p.add_argument('--resume',action='store_true');p.add_argument('--map');a=p.parse_args();OUT.mkdir(parents=True,exist_ok=True)
 rows=[r for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()) if r.get('distribution','base')=='base' and any(m in ['st','de'] for m in r.get('modes',[]))]
 rows.sort(key=lambda r:not (ROOT/r["path"].removeprefix("res://")).exists())
 for row in rows:
  if a.map and row['id']!=a.map:continue
  receipt=OUT/(row['id']+'.json')
  if a.resume and receipt.exists():
   report=json.loads(receipt.read_text())
   if not report['failures'] and report['bsp_sha256']==row['sha256'] and all(hashlib.sha256((ROOT/c['path'].removeprefix('res://')).read_bytes()).hexdigest()==c['sha256'] for c in report['codecs']):continue
  with (OUT/(row['id']+'.log')).open('w') as log:
   code=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','tools/expansions/prepare.gd','--',row['id']],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=900).returncode
  print(row['id'],code,flush=True)
  assert code==0 and receipt.exists() and not json.loads(receipt.read_text())['failures'],(row['id'],(OUT/(row['id']+'.log')).read_text()[-2000:])
 results=[json.loads((OUT/(r['id']+'.json')).read_text()) for r in rows if (OUT/(r['id']+'.json')).exists()]
 for r in results:
  paths=['maps/'+r['id']+'.bsp','maps/cache/'+r['id']+'.scn','maps/cache/'+r['id']+'-lightmap1.scn','maps/navigation/'+r['id']+'.res']+[c['path'].removeprefix('res://') for c in r['codecs']]
  r['assets']=[{'path':p,'sha256':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()} for p in paths]
 (ROOT/'tools/expansions/validation.json').write_text(json.dumps({'maps':results,'expected_maps':len(rows),'complete':len(results)==len(rows)},indent=2)+'\n')
 print('Prepared',len(results),'of',len(rows),flush=True)
if __name__=='__main__':main()
