"""Run stance/tracking regressions and reap every local Godot process."""
from pathlib import Path
import json
import subprocess
import time
import argparse

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/stance-locomotion'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only',nargs='+',choices=['stances','vr_crouch_water','quake_movement','physical_rig','local_body','avatar_scaling','local_prediction','vr_alignment'],default=['stances','vr_crouch_water','quake_movement','physical_rig','local_body','avatar_scaling','local_prediction','vr_alignment'])
    args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    results=[]
    for name in args.only:
        path=OUT/(name+'.log')
        with path.open('w') as log:
            result=subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script',f'res://deathmatch/tests/{name}.gd','--','--client-config',str(OUT/(name+'.cfg'))],stdout=log,stderr=subprocess.STDOUT,timeout=90)
        text=path.read_text()
        row=dict(test=name,exit_code=result.returncode,passed=result.returncode==0 and 'FAIL ' not in text and 'ERROR:' not in text)
        results.append(row);print(json.dumps(row),flush=True)
    children=[];handles=[]
    try:
        for role in ['server','client']:
            path=OUT/('network-'+role+'.log');log=path.open('w');handles.append(log)
            child=subprocess.Popen(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/stance_network.gd','--',role,'--client-config',str(OUT/('network-'+role+'.cfg'))],stdout=log,stderr=subprocess.STDOUT)
            children.append((role,child,path))
            if role=='server':
                until=time.monotonic()+10
                while child.poll() is None and time.monotonic()<until and 'DM_HOST_READY' not in path.read_text():time.sleep(.05)
        for role,child,path in children:
            child.wait(timeout=60);text=path.read_text()
            row=dict(test='network-'+role,exit_code=child.returncode,passed=child.returncode==0 and 'STANCE_NETWORK_RESULT' in text and 'FAIL ' not in text and 'ERROR:' not in text)
            results.append(row);print(json.dumps(row),flush=True)
    finally:
        for _,child,_ in children:
            if child.poll() is None:
                child.terminate()
                try:child.wait(timeout=3)
                except subprocess.TimeoutExpired:child.kill();child.wait()
        for log in handles:log.close()
    latest={row['test']:row for row in json.loads((OUT/'results.json').read_text())} if (OUT/'results.json').exists() else {}
    latest.update({row['test']:row for row in results})
    (OUT/'results.json').write_text(json.dumps(list(latest.values()),indent=2)+'\n')
    return 0 if all(row['passed'] for row in results) else 1


if __name__=='__main__':raise SystemExit(main())
