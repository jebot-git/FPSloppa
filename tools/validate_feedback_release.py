"""Exercise rocket movement, feedback assets and bounded VR presentation."""
from pathlib import Path
import json,os,subprocess
root=Path(__file__).resolve().parents[1]
results=[]
for name in ['rocket_jump','feedback_audio','combat','presentation','pickup_models','music']:
    log=root/'test-results'/('feedback-'+name+'.log')
    with log.open('w') as f:
        try:
            run=subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/'+name+'.gd'],stdout=f,stderr=subprocess.STDOUT,timeout=90)
            code=run.returncode
        except subprocess.TimeoutExpired:code=124
    text=log.read_text();passed=code==0 and 'FAIL ' not in text and 'SCRIPT ERROR:' not in text
    results.append({'suite':name,'passed':passed,'exit_code':code,'log':str(log.relative_to(root))})
    print(name,'PASS' if passed else 'FAIL',flush=True)
(root/'test-results/feedback-validation.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
