"""Verify synthetic Opus proximity/team routing over the authorized remote server."""
from pathlib import Path
import argparse
import json
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--host',required=True);parser.add_argument('--port',required=True,type=int)
parser.add_argument('--label',default='voice');parser.add_argument('--settle',type=float,default=1.0)
args=parser.parse_args()
assert args.label.replace('-','').isalnum()
out=ROOT/'test-results/remote-current'/args.label;out.mkdir(parents=True,exist_ok=True)
children=[];handles=[];results=[]
try:
    for i in range(1,4):
        tag=f'{i:02}';cfg=out/(tag+'.cfg');cfg.write_text('[voice]\nmode=0\n')
        handle=(out/(tag+'.log')).open('w');handles.append(handle)
        children.append(subprocess.Popen(['godot','--headless','--xr-mode','off','--audio-driver','Dummy','--path',str(ROOT),
            '--log-file',str(out/(tag+'-engine.log')),'--script','res://deathmatch/tests/remote_voice.gd','--',
            '--probe',tag,'--host',args.host,'--port',str(args.port),'--settle',str(args.settle),'--client-config',str(cfg),'--asset-root',str(ROOT)],stdout=handle,stderr=subprocess.STDOUT))
        time.sleep(.3)
    for i,child in enumerate(children,1):
        child.wait(timeout=60)
        text=(out/f'{i:02}.log').read_text()
        result=next((json.loads(line[20:]) for line in text.splitlines() if line.startswith('REMOTE_VOICE_RESULT ')),{'passed':False})
        result['exit_code']=child.returncode
        result['passed']=result['passed'] and child.returncode==0 and 'SCRIPT ERROR:' not in text
        results.append(result)
finally:
    for child in children:
        if child.poll() is None:
            child.terminate()
            try:child.wait(timeout=5)
            except subprocess.TimeoutExpired:child.kill();child.wait()
    for handle in handles:handle.close()
(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
raise SystemExit(0 if len(results)==3 and all(r['passed'] for r in results) else 1)
