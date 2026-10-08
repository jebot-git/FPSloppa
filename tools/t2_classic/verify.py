#!/usr/bin/env python3
"""Validate every installed Classic map in isolated Godot processes."""
import argparse,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--map');p.add_argument('--skip-prepare',action='store_true');p.add_argument('--routes',action='store_true');a=p.parse_args()
 rows=[r for r in json.loads((ROOT/'tools/t2_classic/sources.json').read_text())['maps'] if not r['existing'] and (not a.map or a.map in [r['id'],r['title']])]
 if not rows:raise ValueError('No matching map')
 failures=[]
 for row in rows:
  key=row['id'];folder=ROOT/'test-results/t2-classic'/key;folder.mkdir(parents=True,exist_ok=True)
  for script in ['inspect']+([] if a.skip_prepare else ['prepare'])+['acceptance']+(['routes'] if a.routes else []):
   with (folder/(script+'-final.log')).open('w') as log:
    try:code=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--script',f'tools/t2_classic/{script}.gd','--',key],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=480).returncode
    except subprocess.TimeoutExpired:code=124
   errors='SCRIPT ERROR' in (folder/(script+'-final.log')).read_text()
   print(key,script,code,flush=True)
   if code or errors:failures.append([key,script,code]);break
 print(json.dumps({'maps':len(rows),'failures':failures}))
 raise SystemExit(bool(failures))
if __name__=='__main__':main()
