from pathlib import Path
import subprocess,os,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/avatars-cc0'
rows=json.loads((OUT/'inspection.json').read_text());results=[]
for row in rows:
 if 'destination' not in row:continue
 key=Path(row['destination']).stem;log=OUT/(key+'-armour.log')
 with log.open('w') as out:
  result=subprocess.run(['godot','--xr-mode','off','--path',str(ROOT),'--rendering-method','gl_compatibility','--script','deathmatch/tests/tribes_bodies.gd','--',row['sha256']],env=dict(os.environ,XDG_DATA_HOME='/tmp/tribes-check'),stdout=out,stderr=subprocess.STDOUT,timeout=65)
 content=log.read_text();report=json.loads((OUT/(key+'-armour.json')).read_text())
 report['file']=row['destination'];report['exit_code']=result.returncode;report['script_errors']='SCRIPT ERROR' in content
 results.append(report);print(key,report['checks'],report['failures'],flush=True)
(OUT/'armour-tests.json').write_text(json.dumps(results,indent=2)+'\n')
assert all(r['exit_code']==0 and not r['failures'] and not r['script_errors'] for r in results)
