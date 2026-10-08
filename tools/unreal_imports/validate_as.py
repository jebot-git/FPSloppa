from pathlib import Path
import subprocess,concurrent.futures,json,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
def validate(p):
 with (p/'runtime-validation.log').open('w') as f:r=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','tools/unreal_imports/validate_as.gd','--','res://'+str((p/(p.name+'.bsp')).relative_to(ROOT)),'--rebuild-navigation'],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=240)
 d=json.loads((p/'runtime-validation.json').read_text());print(p.name,r.returncode,d['routes'],d['total_routes'],d['failures'],flush=True);return d
folders=sorted((HERE/'local/candidates').glob('as_ut_*'))
if len(sys.argv)>1:folders=[p for p in folders if p.name.removeprefix('as_ut_') in sys.argv[1:]]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:rows=list(e.map(validate,folders))
if len(rows)==4:(HERE/'as-validation.json').write_text(json.dumps({'maps':rows,'failures':[r['id'] for r in rows if r['failures']]},indent=2)+'\n')
raise SystemExit(any(r['failures'] for r in rows))
