"""Run real ENet suicide/respawn/score replication checks. Local sockets required."""
from pathlib import Path
import json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'test-results/suicide-network';out.mkdir(parents=True,exist_ok=True)
processes=[];handles=[]
try:
    for role in ['server','shooter','target']:
        log=out/(role+'.log');handle=log.open('w');handles.append(handle)
        process=subprocess.Popen([os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')),'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/suicide_network.gd','--',role],stdout=handle,stderr=subprocess.STDOUT)
        processes.append((role,process))
        if role=='server':
            until=time.monotonic()+10
            while time.monotonic()<until and process.poll() is None and 'DM_HOST_READY' not in log.read_text():time.sleep(.1)
            if 'DM_HOST_READY' not in log.read_text():raise RuntimeError('Host failed to start')
    results=[]
    for role,process in processes:
        process.wait(timeout=50);text=(out/(role+'.log')).read_text()
        results.append({'role':role,'exit':process.returncode,'pass':process.returncode==0 and 'NETWORK_RESULT' in text and 'ERROR:' not in text})
    (out/'RESULT.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
    raise SystemExit(0 if all(r['pass'] for r in results) else 1)
finally:
    for _,p in processes:
        if p.poll() is None:p.terminate();p.wait(timeout=5)
    for h in handles:h.close()
