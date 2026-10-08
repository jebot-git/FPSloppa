"""Run 4v4 combat smoke tests on the capacity-qualified AS conversions."""
from pathlib import Path
import json,subprocess,concurrent.futures,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'test-results/as-imports';OUT.mkdir(exist_ok=True)
def run(row):
 name=row['id'];options={'map':name,'mode':'as','rules':'quake','bots':8,'seconds':90,'seed':7129,'output':str(OUT/(name+'-soak.json'))}
 with (OUT/(name+'-soak.log')).open('w') as f:r=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','deathmatch/tests/bot_soak.gd','--',json.dumps(options)],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=300)
 print(name,r.returncode,flush=True);return r.returncode
rows=json.loads((HERE/'as-installed.json').read_text())
if len(sys.argv)>1:rows=[r for r in rows if r['id'].removeprefix('as_ut_') in sys.argv[1:]]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:codes=list(pool.map(run,rows))
raise SystemExit(any(codes))
