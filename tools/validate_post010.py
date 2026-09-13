from pathlib import Path
import subprocess,concurrent.futures,json
root=Path(__file__).resolve().parents[1]
def run(name):
 path=root/'test-results'/f'post010-{name}.log'
 with path.open('w') as log:
  result=subprocess.run(['godot','--headless','--xr-mode','off','--audio-driver','Dummy','--log-file',f'/tmp/fpsloppa-{name}-engine.log','--path',str(root),'--script',f'res://deathmatch/tests/{name}.gd','--','--client-config',f'/tmp/fpsloppa-{name}.cfg'],stdout=log,stderr=subprocess.STDOUT,timeout=120)
 text=path.read_text();return {'test':name,'exit':result.returncode,'errors':[line for line in text.splitlines() if 'ERROR:' in line or line.startswith('FAIL ')],'passed':result.returncode==0 and 'ERROR:' not in text and '\nFAIL ' not in text}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,['post010','scoreboard_suicide','vr_ui']))
(root/'test-results/post010-validation.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2));raise SystemExit(0 if all(r['passed'] for r in results) else 1)
