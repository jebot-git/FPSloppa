"""Continue after KOTH, serially, retaining the recommended priority order."""
from pathlib import Path
import json,os,subprocess,sys
from run import ROOT,GODOT
PROJECT=Path('/tmp/fpsloppa-ai-balance-20260912')
OUT=ROOT/'test-results/ai-balance/priority-20260912'
for map_id,mode,rules,prefix in [('koth_alichar','koth','doom','02'),('ctf_crownreach','ctf','ut99','03')]:
 opts=dict(map=map_id,mode=mode,rules=rules,output=str(OUT/(prefix+'-supplies.json')))
 logpath=OUT/(prefix+'-supplies.log')
 with logpath.open('w') as log:
  result=subprocess.run([GODOT,'--headless','--xr-mode','off','--fixed-fps','60','--path',str(PROJECT),'--script',str(ROOT/'tools/ai_balance/supplies.gd'),'--',json.dumps(opts)],env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-ai-balance-data'),stdout=log,stderr=subprocess.STDOUT,timeout=90)
 errors=[l for l in logpath.read_text().splitlines() if 'ERROR:' in l]
 print('SUPPLIES',map_id,result.returncode,errors,flush=True)
 if result.returncode or errors:raise SystemExit(1)
for phase in ['ctf','as','tf','cc_if']:
 print('PRIORITY_PHASE',phase,flush=True)
 subprocess.run([sys.executable,str(ROOT/'tools/ai_balance/run.py'),'--project',str(PROJECT),'--label','priority-20260912','--phase',phase,'--resume'],check=True)
 subprocess.run([sys.executable,str(ROOT/'tools/ai_balance/summarize.py')],check=True)
