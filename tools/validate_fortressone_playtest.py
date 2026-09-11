"""Rendered TF map acceptance run; requires a working graphical display."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--match',default='');p.add_argument('--resume',action='store_true');p.add_argument('--preview-only',action='store_true');args=p.parse_args()
out=ROOT/('test-results/fortressone-previews' if args.preview_only else 'test-results/fortressone-playtest');out.mkdir(parents=True,exist_ok=True)
results=[]
fingerprint=hashlib.sha256(b''.join((ROOT/name).read_bytes() for name in ['deathmatch/tests/fortressone_playtest.gd','deathmatch/arena.gd','deathmatch/bots.gd','deathmatch/fighter.gd','deathmatch/modes/match.gd','deathmatch/modes/fortress.gd','deathmatch/maps/runtime.gd','deathmatch/maps/loader.gd','addons/bsp_importer/bsp_reader.gd'])).hexdigest()
paths=sorted(args.directory.resolve().glob('*.bsp'))
if not any(args.match in p.stem for p in paths):raise SystemExit('No matching BSP maps found')
for path in paths:
 if args.match not in path.stem:continue
 target=out/path.stem
 if args.resume and target.with_suffix('.json').exists():
  previous=json.loads(target.with_suffix('.json').read_text())
  if previous.get('audit_fingerprint')==fingerprint and previous.get('sha256')==hashlib.sha256(path.read_bytes()).hexdigest():results.append(previous);continue
 print('PLAYTEST',path.stem,flush=True)
 with target.with_suffix('.log').open('w') as log:
  try:r=subprocess.run([os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')),'--path',str(ROOT),'--xr-mode','off','--rendering-method','gl_compatibility','--script','res://deathmatch/tests/fortressone_preview.gd' if args.preview_only else 'res://deathmatch/tests/fortressone_playtest.gd','--',str(path),str(target)],stdout=log,stderr=subprocess.STDOUT,timeout=360);code=r.returncode
  except subprocess.TimeoutExpired:code=124
 if args.preview_only:
  results.append({'failures':[],'exit_code':code,'engine_errors':[line for line in target.with_suffix('.log').read_text().splitlines() if 'ERROR:' in line]});continue
 result=json.loads(target.with_suffix('.json').read_text()) if target.with_suffix('.json').exists() else {'map':path.stem,'failures':['No completed playtest']}
 result['audit_fingerprint']=fingerprint;result['exit_code']=code;result['engine_errors']=[line for line in target.with_suffix('.log').read_text().splitlines() if 'ERROR:' in line];target.with_suffix('.json').write_text(json.dumps(result,indent=2)+'\n');results.append(result)
 print('RESULT',path.stem,result['failures'],flush=True)
raise SystemExit(1 if any(r['failures'] or r['exit_code'] or r['engine_errors'] for r in results) else 0)
