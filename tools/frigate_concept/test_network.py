"""Run Frigate's two-peer objective replication regression; reap both Godot children."""
from pathlib import Path
import json
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/frigate'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    children=[];handles=[];results=[]
    try:
        for role in ['server','client']:
            log=OUT/f'network-{role}.log';handle=log.open('w');handles.append(handle)
            child=subprocess.Popen(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/frigate_network.gd','--',role,'--client-config',str(OUT/f'network-{role}.cfg')],stdout=handle,stderr=subprocess.STDOUT)
            children.append((role,child))
            if role=='server':
                deadline=time.monotonic()+10
                while child.poll() is None and time.monotonic()<deadline and 'DM_HOST_READY' not in log.read_text():time.sleep(.05)
        deadline=time.monotonic()+75
        for role,child in children:
            child.wait(timeout=max(1,deadline-time.monotonic()));text=(OUT/f'network-{role}.log').read_text()
            result=dict(role=role,exit_code=child.returncode,checks=text.count('PASS '),passed=child.returncode==0 and 'FRIGATE_NETWORK_RESULT' in text and 'FAIL ' not in text and 'ERROR:' not in text)
            results.append(result);print(json.dumps(result),flush=True)
        (OUT/'network.json').write_text(json.dumps(results,indent=2)+'\n')
        return 0 if all(r['passed'] for r in results) else 1
    finally:
        for _,child in children:
            if child.poll() is None:
                child.terminate()
                try:child.wait(timeout=3)
                except subprocess.TimeoutExpired:child.kill();child.wait()
        for handle in handles:handle.close()

if __name__=='__main__':raise SystemExit(main())
