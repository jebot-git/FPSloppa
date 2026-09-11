"""Run a real AS authority and two ENet clients; requires local UDP sockets."""
from pathlib import Path
import argparse,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('bsp',type=Path);a=p.parse_args()
out=ROOT/'test-results/hispeed-network';out.mkdir(parents=True,exist_ok=True)
processes=[];handles=[]
try:
    for role in ['server','attacker','defender']:
        log=out/(role+'.log');handle=log.open('w');handles.append(handle)
        proc=subprocess.Popen([os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')),'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/assault_network.gd','--',role,str(a.bsp.resolve())],stdout=handle,stderr=subprocess.STDOUT)
        processes.append((role,proc))
        if role=='server':
            end=time.monotonic()+20
            while time.monotonic()<end and proc.poll() is None and 'DM_HOST_READY' not in log.read_text():time.sleep(.1)
            if 'DM_HOST_READY' not in log.read_text():raise RuntimeError('AS host did not start; inspect '+str(log))
    results=[]
    for role,proc in processes:
        proc.wait(timeout=100);text=(out/(role+'.log')).read_text()
        results.append({'role':role,'exit':proc.returncode,'pass':proc.returncode==0 and 'NETWORK_RESULT' in text and 'ERROR:' not in text})
    (out/'RESULT.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
    raise SystemExit(0 if all(row['pass'] for row in results) else 1)
finally:
    for _,proc in processes:
        if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
    for handle in handles:handle.close()
