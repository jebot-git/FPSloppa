#!/usr/bin/env python3
import json, subprocess, os, argparse, time, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CASES=[('qsrc_dm3','dm','quake'),('qsrc_dm6','tdm','doom'),('ctf_crownreach','ctf','ut99'),('koth_alichar','koth','doom'),('qsrc_dm6','ig','doom'),('qsrc_dm6','if','doom'),('qsrc_dm3','ft','doom'),('cc_basement','cc','doom'),('tf_vesper','tf','quake'),('as_frigate','as','ut99')]
p=argparse.ArgumentParser();p.add_argument('--label',required=True);p.add_argument('--baseline',action='store_true');p.add_argument('--seconds',type=int,default=180);p.add_argument('--modes',default='koth,ctf,dm,if');p.add_argument('--seed',type=int,default=7129);a=p.parse_args()
out=ROOT/'test-results/ai-study'/a.label;out.mkdir(parents=True,exist_ok=True)
summary=[]
for map_id,mode,rules in CASES:
 if mode not in a.modes.split(','):continue
 opts=dict(map=map_id,mode=mode,rules=rules,seconds=a.seconds,seed=a.seed,output=str(out/(mode+'.json')),profile_tick=True)
 opts["source_sha256"]={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ([ROOT/"tools/ai_study/baseline/bots.gd",ROOT/"tools/ai_study/baseline/teamplay.gd",ROOT/"tools/ai_study/baseline/navigation.gd"] if a.baseline else [ROOT/"deathmatch/bots.gd",*sorted((ROOT/"deathmatch/bot_ai").glob("*.gd"))])}
 if a.baseline:opts['ai_script']='res://tools/ai_study/baseline/bots.gd'
 with (out/(mode+'.log')).open('w') as log:
  start=time.monotonic()
  try:result=subprocess.run(['godot','--headless','--xr-mode','off','--fixed-fps','60','--path',str(ROOT),'--script','res://tools/ai_study/soak.gd','--',json.dumps(opts)],stdout=log,stderr=subprocess.STDOUT,env={**os.environ,'XDG_DATA_HOME':'/tmp/fpsloppa-ai-study'},timeout=300);code=result.returncode
  except subprocess.TimeoutExpired:code=124
 errors=[x for x in (out/(mode+'.log')).read_text().splitlines() if x.startswith(('ERROR:','SCRIPT ERROR:'))]
 row=dict(mode=mode,exit_code=code,errors=errors,wall_seconds=round(time.monotonic()-start,2))
 if (out/(mode+'.json')).exists():
  d=json.loads((out/(mode+'.json')).read_text());row.update({k:d[k] for k in ['score','physics_p50_ms','physics_p95_ms','behaviour','counts']});row['shots']=sum(b['shots'] for b in d['bots'].values())
 summary.append(row);(out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps({k:v for k,v in row.items() if k!="behaviour"}),flush=True)
raise SystemExit(int(any(r['exit_code'] or r['errors'] for r in summary)))
