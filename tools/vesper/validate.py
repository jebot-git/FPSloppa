"""Run VesperAbbey' in-engine objective, sentry, traversal and bot checks."""
from pathlib import Path
import concurrent.futures, hashlib, json, os, subprocess, tempfile, uuid

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/vesper'
FILES=['tools/vesper/acceptance.gd','tools/vesper/bake.gd',
       'deathmatch/arena.gd','deathmatch/bots.gd','deathmatch/fighter.gd',
       'deathmatch/modes/fortress.gd','deathmatch/modes/match.gd','deathmatch/maps/runtime.gd','tools/vesper/lifts.gd']


def fingerprint():
    return hashlib.sha256(b''.join((ROOT/name).read_bytes() for name in FILES)).hexdigest()


def main():
    OUT.mkdir(parents=True,exist_ok=True);bsp=ROOT/'maps/tf_vesper.bsp';sha=hashlib.sha256(bsp.read_bytes()).hexdigest()
    assert (ROOT/'maps/VesperAbbey/navigation-sha256.txt').read_text().strip()==sha,'Navigation cache is stale; rebake'
    before=fingerprint();run_dir=OUT/('run-'+uuid.uuid4().hex[:10]);run_dir.mkdir()
    phases=[('lifts',['--lifts']),('static',['--static']),('6v6',['--no-walks','--players','12']),
            ('6v6-swapped',['--no-walks','--players','12','--swapped']),
            ('4v4',['--no-walks','--players','8']),('8v8',['--no-walks','--players','16'])]
    def phase(item):
        name,flags=item;target=run_dir/name
        with tempfile.TemporaryDirectory(prefix='vesper-') as temp, target.with_suffix('.log').open('w') as log:
            process=subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tools/vesper/lifts.gd' if name=='lifts' else 'res://tools/vesper/acceptance.gd','--',str(bsp),str(target.with_suffix('.json')) if name=='lifts' else str(target),*flags],env=dict(os.environ,XDG_DATA_HOME=temp),stdout=log,stderr=subprocess.STDOUT,timeout=180)
        assert process.returncode==0,f'{name}: Godot exit {process.returncode}; inspect {target}.log'
        result=json.loads(target.with_suffix('.json').read_text());log=target.with_suffix('.log').read_text()
        assert result.get('sha256',result.get('map_sha256'))==sha and not result['failures'] and 'ERROR:' not in log,f'{name}: acceptance failures'
        print('PASS',name,flush=True);return name,result
    # Separate bounded processes keep phase state independent and logs unambiguous.
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results=dict(pool.map(phase,phases[:2]))
        results.update(pool.map(phase,phases[2:]))
    assert fingerprint()==before,'Code changed during validation'
    report=results['static'];report['matches']=[];report['elevators']=results['lifts'];report['checks'].extend(results['lifts']['checks'])
    for name in ['4v4','6v6','6v6-swapped','8v8']:
        row=results[name];report['matches'].extend(row['matches'])
        report['checks'].extend(c for c in row['checks'] if 'bots leave spawn' in c['check'] or 'simulation remains finite' in c['check'])
    assert [r['players'] for r in report['matches']]==[8,12,12,16]
    assert len(report['walks'])==8 and all(r['pass'] for r in report['walks'])
    report['phase_logs']=str(run_dir.relative_to(ROOT))
    report['code_fingerprint']=before
    report['navigation_sha256']=hashlib.sha256((ROOT/'maps/navigation/tf_vesper.res').read_bytes()).hexdigest()
    report['limitations']=['Bot skirmishes do not establish human competitive balance.', 'Godot reports a pre-existing ObjectDB cleanup warning; no engine/script errors permitted.']
    (ROOT/'maps/VesperAbbey/validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'passed':True,'checks':len(report['checks']),'walks':len(report['walks']),'matches':report['matches']},indent=2))


if __name__=='__main__':main()
