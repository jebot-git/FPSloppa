"""Bounded map bakes, physical traversal, CTF checks and rendered inspection."""
from pathlib import Path
import argparse,concurrent.futures,json,os,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('phase',choices=['bake','static','walk','routes','bots','views']);p.add_argument('--only',nargs='*');p.add_argument('--godot',default='/tmp/fpsloppa-godot-official/Godot_v4.7.2-stable_linux.x86_64');args=p.parse_args()
 keys=sorted(x.parent.name for x in (ROOT/'maps/CTFStudies').glob('ctf_*/manifest.json') if not args.only or x.parent.name in args.only)
 def run(key):
  out=ROOT/'test-results/threewave'/key/args.phase
  env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-ctf-study-data/'+key)
  cmd=[args.godot,*([] if args.phase=='views' else ['--headless']),'--xr-mode','off','--path',str(ROOT),'--script','res://tools/threewave_rebuild/'+('bake.gd' if args.phase=='bake' else 'acceptance.gd'),'--',key]
  if args.phase!='bake':cmd += [str(out)]+(['--'+args.phase] if args.phase in ['walk','routes','bots'] else [])
  timeout=340 if args.phase in ['walk','routes'] else 150
  with out.with_suffix('.log').open('w') as log:
   try:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout);code=r.returncode
   except subprocess.TimeoutExpired:code=124
  errors=[line for line in out.with_suffix('.log').read_text().splitlines() if 'ERROR:' in line]
  result={'map':key,'phase':args.phase,'exit_code':code,'errors':errors,'pass':code==0 and not errors}
  print(json.dumps(result),flush=True);return result
 with concurrent.futures.ThreadPoolExecutor(max_workers=1 if args.phase=='views' else 2) as pool:results=list(pool.map(run,keys))
 (ROOT/'test-results/threewave'/('summary-'+args.phase+'.json')).write_text(json.dumps(results,indent=2)+'\n')
 raise SystemExit(0 if all(r['pass'] for r in results) else 1)
if __name__=='__main__':main()
