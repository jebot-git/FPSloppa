"""Combat and real-map two-process TF/AS experimental weapons regressions."""
from pathlib import Path
import json, os, subprocess, time
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/weapon-variants'
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    env={**os.environ,'XDG_DATA_HOME':str(OUT/'user')}
    base=[os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(ROOT)]
    results=[]
    with (OUT/'combat.log').open('w') as f:
        result=subprocess.run(base+['--script','res://deathmatch/tests/weapon_variants.gd'],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
    log=(OUT/'combat.log').read_text()
    row=next((json.loads(l.split('VARIANTS_RESULT ',1)[1]) for l in log.splitlines() if l.startswith('VARIANTS_RESULT ')),{'passed':False,'failures':['No completed combat report']})
    row.update(role='combat',errors=[l for l in log.splitlines() if 'ERROR:' in l],exit_code=result.returncode)
    row['passed']=row['passed'] and result.returncode==0 and not row['errors'];results.append(row)
    for rule,port in [('quake',27931),('ut99',27932)]:
        jobs=[]
        try:
            for role in ['server','client']:
                log=OUT/f'{rule}-{role}.log';f=log.open('w')
                cmd=base+['--script','res://deathmatch/tests/weapon_variants_network.gd','--',role,rule,str(port)]
                jobs.append((role,subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT),log,f))
                if role=='server':time.sleep(1.5)
            for role,p,log,f in jobs:
                p.wait(timeout=100);f.close();text=log.read_text()
                rows=[json.loads(l.split('VARIANT_NETWORK_RESULT ',1)[1]) for l in text.splitlines() if l.startswith('VARIANT_NETWORK_RESULT ')]
                row=rows[-1] if rows else dict(rule=rule,role=role,passed=False,failures=['No completion report'])
                row['errors']=[l for l in text.splitlines() if 'ERROR:' in l];row['exit_code']=p.returncode
                row['passed']=row['passed'] and p.returncode==0 and not row['errors'];results.append(row)
        finally:
            for role,p,log,f in jobs:
                if p.poll() is None:p.terminate();p.wait(timeout=5)
                f.close()
    report={'passed':all(r['passed'] for r in results),'runs':results}
    (OUT/'network.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
    return 0 if report['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
