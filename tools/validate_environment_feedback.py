"""Import and test environment sound transitions and forgiving T-pose calibration."""
from pathlib import Path
import json
import subprocess
import argparse

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/environment-feedback'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    supported=['import','environment_feedback','auto_calibration','vr_gestures','pad_telefrag','assault','frigate']
    parser.add_argument('tests',nargs='*',help='Optional suites: '+', '.join(supported))
    args=parser.parse_args()
    if any(name not in supported for name in args.tests):parser.error('Unsupported suite')
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[]
    names=args.tests or ['import','environment_feedback','auto_calibration','vr_gestures','pad_telefrag']
    commands=[(name,['--editor','--import'] if name=='import' else ['--script',f'res://deathmatch/tests/{name}.gd']) for name in names]
    for name,args in commands:
        if name=='assault':args+=['--',str(ROOT/'maps/as_hislop.bsp')]
        with (OUT/f'{name}.log').open('w') as output:
            try:
                result=subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),*args],stdout=output,stderr=subprocess.STDOUT,timeout=240 if name=='frigate' else 120)
                code=result.returncode
            except subprocess.TimeoutExpired:
                code=124
        log=(OUT/f'{name}.log').read_text()
        row=dict(test=name,exit_code=code,checks=log.count('PASS '),passed=code==0 and 'SCRIPT ERROR:' not in log and 'FAIL ' not in log)
        rows.append(row);print(json.dumps(row),flush=True)
        (OUT/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
    return 0 if all(r['passed'] for r in rows) else 1

if __name__=='__main__':raise SystemExit(main())
