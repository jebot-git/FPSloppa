"""Audit locally retained converted maps without copying them into the repository.
Usage: python3 tools/validate_converted_traversal.py [--match substring] [--resume]
"""
from pathlib import Path
import argparse, collections, hashlib, json, os, re, struct, subprocess, time
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/converted-traversal'
OUT.mkdir(parents=True,exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--match',default='');p.add_argument('--resume',action='store_true');p.add_argument('--directory',type=Path);p.add_argument('--results',type=Path);args=p.parse_args()
if args.results:OUT=args.results.resolve();OUT.mkdir(parents=True,exist_ok=True)
paths=sorted((ROOT/'maps').glob('ad_arena_*.bsp'))+sorted((ROOT.parent/'Builds/TF-Local-Validated/maps').glob('*.bsp'))+sorted((ROOT.parent/'Builds/ThreeWave-Local/maps').glob('*.bsp'))
if args.directory:paths=sorted(args.directory.resolve().glob("*.bsp"))
results=[]
if not paths:raise SystemExit("No BSP maps found")
fingerprint=hashlib.sha256(b''.join((ROOT/name).read_bytes() for name in ['deathmatch/tests/converted_traversal.gd','deathmatch/maps/runtime.gd','deathmatch/maps/loader.gd','addons/bsp_importer/bsp_reader.gd','deathmatch/fighter.gd'])).hexdigest()
for path in paths:
 if args.match not in path.stem:continue
 data=path.read_bytes();version=struct.unpack_from('<I',data)[0];lumps=[struct.unpack_from('<II',data,4+i*8) for i in range(15)]
 o,n=lumps[0];entities=[dict(re.findall(r'"([^"\n]*)"\s*"([^"\n]*)"',e)) for e in data[o:o+n].decode('latin1').split('}') if '"classname"' in e]
 counts=collections.Counter(e['classname'] for e in entities);water=[];liquids=collections.Counter()
 o,n=lumps[10];stride=28 if version==29 else 44 if version==0x32505342 else 32
 for at in range(o,o+n,stride):
  content=struct.unpack_from('<i',data,at)[0]
  if content not in [-3,-4,-5,-9,-10,-11,-12,-13,-14]:continue
  liquids[content]+=1
  lo=struct.unpack_from('<3f' if version==0x32505342 else '<3h',data,at+8)
  hi=struct.unpack_from('<3f' if version==0x32505342 else '<3h',data,at+(20 if version==0x32505342 else 14))
  if content==-3:water.append({'lo':lo,'hi':hi})
 if len(water)>160:water=[water[int(i*(len(water)-1)/159)] for i in range(160)]
 targets={e.get('targetname') for e in entities if e.get('targetname')}
 unsupported=[e for e in entities if e['classname'] in ['func_train','func_button','trigger_multiple','trigger_once','trigger_changelevel','trigger_secret']]
 request={'path':str(path),'name':path.stem,'sha256':hashlib.sha256(data).hexdigest(),'entities':entities,'counts':counts,'liquid_leaves':liquids,'water_bounds':water,'unsupported_logic':unsupported,'unresolved_targets':[e for e in entities if e.get('target') and e['target'] not in targets]}
 req=OUT/(path.stem+'-input.json');req.write_text(json.dumps(request))
 report=OUT/(path.stem+'.json');log=OUT/(path.stem+'.log')
 if args.resume and report.exists():
  previous=json.loads(report.read_text())
  if previous.get('audit_fingerprint')==fingerprint and previous.get('sha256')==request['sha256'] and previous.get('exit_code')==0 and not previous.get('failures') and not previous.get('engine_errors'):
   results.append(previous);continue
 print('CHECK',path.stem,flush=True);start=time.monotonic()
 with log.open('w') as f:
  try:r=subprocess.run([os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')),'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/converted_traversal.gd','--',str(req),str(report)],stdout=f,stderr=subprocess.STDOUT,timeout=240);code=r.returncode
  except subprocess.TimeoutExpired:code=124
 result=json.loads(report.read_text()) if report.exists() else {'name':path.stem,'failures':['No completed report'],'path':str(path)}
 result.update(audit_fingerprint=fingerprint,exit_code=code,seconds=round(time.monotonic()-start,2),engine_errors=[line for line in log.read_text().splitlines() if 'ERROR:' in line]);report.write_text(json.dumps(result,indent=2));results.append(result)
 print('RESULT',path.stem,'failures',len(result.get('failures',[])),'engine_errors',len(result['engine_errors']),flush=True)
 (OUT/'summary.json').write_text(json.dumps(results,indent=2))
(OUT/'summary.json').write_text(json.dumps(results,indent=2))

raise SystemExit(1 if any(r.get("failures") or r.get("engine_errors") or r.get("exit_code") for r in results) else 0)
