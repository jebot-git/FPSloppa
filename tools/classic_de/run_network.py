"""Real ENet regression for sliding doors, late joins and wallbang damage."""
import os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/de-restoration';OUT.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,XDG_CONFIG_HOME='/tmp/de-cover-net-config',XDG_DATA_HOME='/tmp/de-cover-net-data')
cmd=['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','deathmatch/tests/de_cover_network.gd','--']
processes=[];logs=[]
try:
    for role in ['server','client']:
        log=open(OUT/f'network-{role}.log','w');logs.append(log)
        processes.append(subprocess.Popen(cmd+[role],stdout=log,stderr=subprocess.STDOUT,env=env))
        if role=='server':time.sleep(1)
    for proc in processes:proc.wait(timeout=70)
    for role,proc in zip(['server','client'],processes):
        text=(OUT/f'network-{role}.log').read_text()
        print(role,proc.returncode,'\n'.join(text.splitlines()[-18:]))
        assert proc.returncode==0 and f'DE_COVER_NETWORK_RESULT {role} []' in text and 'SCRIPT ERROR' not in text
finally:
    for proc in processes:
        if proc.poll() is None:proc.terminate()
    for log in logs:log.close()
