"""Run the same workload and gameplay regressions on isolated physics backends."""
import subprocess,os,json,time,statistics
from pathlib import Path
from prepare import ROOT,prepare
OUT=ROOT/'test-results/rapier-comparison';OUT.mkdir(exist_ok=True)
engines=['godot','rapier','jolt']
def run(engine,script,stem,args=(),limit=90,fixed=False):
 project=prepare(engine)
 cmd=['godot','--headless','--xr-mode','off','--path',str(project),'--script','res://'+script]
 if fixed:cmd+=['--fixed-fps','60']
 cmd+=['--',*map(str,args),'--asset-root',str(ROOT),'--client-config','/tmp/fps-physics-tests.cfg','--no-avatar-disk-cache']
 with (OUT/(stem+'.log')).open('w') as log:
  try:
   p=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=limit,env={**os.environ,'XDG_DATA_HOME':'/tmp/fps-physics-config'})
   code=p.returncode
  except subprocess.TimeoutExpired:code='timeout'
 print(stem,code,flush=True);return code
results=[]
for repeat,order in enumerate([engines,list(reversed(engines)),engines]):
 for engine in order:
  stem=f'{engine}-bench-{repeat}'
  code=run(engine,'tools/physics_compare/benchmark.gd',stem,[OUT/(stem+'.json')],fixed=True)
  results.append({'engine':engine,'test':'benchmark','repeat':repeat,'exit':code})
for name in ['stairs','quake_movement','tribes_physics','jetpack_physics','st_ski_safety','cs16_penetration']:
 for engine in engines:
  code=run(engine,f'deathmatch/tests/{name}.gd',engine+'-'+name,limit=90,fixed=True)
  results.append({'engine':engine,'test':name,'exit':code})
(OUT/'runs.json').write_text(json.dumps(results,indent=2)+'\n')
