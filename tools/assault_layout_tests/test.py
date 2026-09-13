"""Exercise standard/Tiny Assault objectives, navigation, traversal and sludge exits."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'test-results/assault-defaults'


def run(job):
    label, script, args = job
    log = OUT/(label+'.log')
    command = ['godot','--headless','--xr-mode','off','--path',str(ROOT),
        '--log-file',str(OUT/(label+'-engine.log')),
        '--script','res://deathmatch/tests/'+script+'.gd','--',*args,
        '--client-config',str(OUT/(label+'.cfg'))]
    with log.open('w') as handle:
        result = subprocess.run(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT, timeout=240)
    text = log.read_text()
    row = dict(test=label, exit_code=result.returncode, checks=text.count('PASS '),
        passed=result.returncode == 0 and 'FAIL ' not in text and 'SCRIPT ERROR:' not in text,
        log=str(log.relative_to(ROOT)))
    print(json.dumps(row), flush=True)
    return row


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = []
    for tiny in [False, True]:
        variant = 'tiny' if tiny else 'default'
        args = ['--tiny'] if tiny else []
        jobs += [('hislop-'+variant,'hislop_interior',['res://maps/as_hislop'+('_tiny' if tiny else '')+'.bsp',*args]),
                 ('water-'+variant,'hislop_water',args),('frigate-'+variant,'frigate',args)]
    with ThreadPoolExecutor(max_workers=2) as pool:results = list(pool.map(run,jobs))
    (ROOT/'docs/validation/assault-defaults.json').write_text(json.dumps(results,indent=2)+'\n')
    return 0 if all(r['passed'] for r in results) else 1


if __name__ == '__main__':raise SystemExit(main())
