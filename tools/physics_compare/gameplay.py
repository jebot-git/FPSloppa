"""Full-map, 16-bot compatibility and tick-cost checks on isolated backends."""
from pathlib import Path
import json,os,subprocess
from prepare import ROOT,prepare
OUT=ROOT/'test-results/jolt-default';OUT.mkdir(exist_ok=True)
rows=[]
for map_name,mode,rules in [('qsrc_dm6','tdm','quake'),('ctf_katabatic','st','tribes'),('de_dust2_rebuilt','de','cs16')]:
 for engine in ['godot','jolt']:
  project=prepare(engine);name=engine+'-'+map_name;output=OUT/(name+'.json')
  options=dict(map=map_name,mode=mode,rules=rules,bots=16,seconds=90,profile_tick=True,seed=20261001,output=str(output))
  cmd=['godot','--headless','--xr-mode','off','--path',str(project),'--fixed-fps','60','--script','res://deathmatch/tests/bot_soak.gd','--',json.dumps(options),'--asset-root',str(ROOT),'--client-config','/tmp/fps-jolt-soak.cfg','--no-avatar-disk-cache']
  print('START',name,flush=True)
  with (OUT/(name+'.log')).open('w') as log:
   try:code=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env={**os.environ,'XDG_DATA_HOME':'/tmp/fps-jolt-soak'},timeout=180).returncode
   except subprocess.TimeoutExpired:code='timeout'
  text=(OUT/(name+'.log')).read_text();errors=[s for s in text.splitlines() if 'ERROR:' in s or 'WARNING:' in s or 'leaked' in s]
  row=dict(engine=engine,map=map_name,exit=code,errors=errors)
  if code==0 and output.exists():
   data=json.loads(output.read_text());bots=data['bots'];row.update(backend=data['physics_backend'],bots=len(bots),seconds=data['simulated_seconds'],distance=sum(b['distance'] for b in bots.values()),shots=sum(b['shots'] for b in bots.values()),damage=data['damage'],tick_p50_ms=data['physics_p50_ms'],tick_p95_ms=data['physics_p95_ms'])
   if len(bots)!=16 or row['seconds']<90 or row['distance']<100 or row['shots']==0:errors.append('Insufficient active gameplay')
  else:errors.append('Capture did not complete')
  rows.append(row);(OUT/'gameplay.json').write_text(json.dumps(rows,indent=2));print('DONE',json.dumps(row),flush=True)
