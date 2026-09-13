"""Focused production regressions, run serially and with bounded processes."""
from pathlib import Path
import json,os,subprocess,hashlib,sys
from run import ROOT,GODOT
project=ROOT/'test-results/ai-fixes/project-nav'
out=ROOT/'test-results/ai-fixes'
receipt=ROOT/'docs/validation/ai-balance-regressions.json'
results=json.loads(receipt.read_text()) if '--resume' in sys.argv and receipt.exists() else []
(project/'test-results/bot-soak').mkdir(parents=True,exist_ok=True)
for label,path in [('baseline',Path('/tmp/fpsloppa-ai-fixes-base')),('final',project)]:
 if any(r['test']=='traversal-'+label and r['passed'] for r in results):continue
 script=ROOT/'tools/ai_fixes/traversal.gd';result=out/('traversal-'+label+'.json')
 with (out/('traversal-'+label+'.log')).open('w') as log:
  proc=subprocess.run([GODOT,'--headless','--xr-mode','off','--fixed-fps','60','--path',str(path),'--script',str(script),'--',str(result)],stdout=log,stderr=subprocess.STDOUT,timeout=180,env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-ai-fixes-data'))
 errors=[s for s in (out/('traversal-'+label+'.log')).read_text().splitlines() if 'ERROR:' in s]
 row=dict(test='traversal-'+label,passed=proc.returncode==0 and not errors,errors=errors,sha256=hashlib.sha256(result.read_bytes()).hexdigest());results.append(row);print(row,flush=True)
 if not row['passed']:raise SystemExit(1)
for name in ['bot_balance','bot_navigation','bot_objective_roles','bot_tactics','bot_weapons','bot_movement','player_platform','instafreeze','frigate']:
 if any(r['test']==name and r['passed'] for r in results):continue
 results=[r for r in results if r['test']!=name]
 logpath=out/('regression-'+name+'.log')
 with logpath.open('w') as log:
  proc=subprocess.run([GODOT,'--headless','--xr-mode','off','--fixed-fps','60','--path',str(project),'--script','res://deathmatch/tests/'+name+'.gd'],stdout=log,stderr=subprocess.STDOUT,timeout=180,env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-ai-fixes-data'))
 errors=list(dict.fromkeys(s for s in logpath.read_text().splitlines() if 'ERROR:' in s or s.startswith('FAIL ')))
 row=dict(test=name,passed=proc.returncode==0 and not errors,code=proc.returncode,errors=errors);results.append(row);print(row,flush=True)
 (ROOT/'docs/validation/ai-balance-regressions.json').write_text(json.dumps(results,indent=2)+'\n')
 if not row['passed']:raise SystemExit(1)
