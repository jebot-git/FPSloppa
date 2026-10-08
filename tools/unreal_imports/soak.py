from pathlib import Path
import subprocess,json,concurrent.futures
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'test-results/koth-imports';OUT.mkdir(exist_ok=True)
def soak(row):
 name=row['id'];options={'map':name,'mode':'koth','rules':'quake','bots':10,'seconds':90,'seed':7129,'output':str(OUT/(name+'-soak.json'))}
 with (OUT/(name+'-soak.log')).open('w') as f:
  code=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','deathmatch/tests/bot_soak.gd','--',json.dumps(options)],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=240).returncode
 print(name,'soak',code,flush=True);return code
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:codes=list(pool.map(soak,json.loads((HERE/'installed.json').read_text())))
raise SystemExit(bool(any(codes)))
