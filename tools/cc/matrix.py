"""Base/optional mode compatibility smoke matrix; no production server is contacted."""
from pathlib import Path
import subprocess,json,os,concurrent.futures
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/cc/compatibility';OUT.mkdir(exist_ok=True)
def run(case):
 id,mode,optional=case;key=id+'-'+mode;out=OUT/(key+'.json');options={'map':id,'mode':mode,'rules':'doom','seconds':45,'seed':912,'output':str(out)}
 if optional:
  bsp=ROOT/'optional-librequake/maps'/(id+'.bsp');scene=ROOT/'optional-librequake/maps/cache'/(id+'.scn')
  import hashlib
  options['map_entry']={'id':id,'title':id,'path':str(bsp),'scene':str(scene),'sha256':hashlib.sha256(bsp.read_bytes()).hexdigest(),'custom':True}
 log=OUT/(key+'.log')
 with log.open('w') as f:
  try:r=subprocess.run(['godot','--headless','--xr-mode','off','--fixed-fps','60','--path',str(ROOT),'--script','res://deathmatch/tests/bot_soak.gd','--',json.dumps(options)],env={**os.environ,'XDG_DATA_HOME':'/tmp/fpsloppa-matrix-'+key},stdout=f,stderr=subprocess.STDOUT,timeout=180);code=r.returncode
  except subprocess.TimeoutExpired:code=124
 errors=[l for l in log.read_text().splitlines() if l.startswith(('ERROR:','SCRIPT ERROR:'))];d=json.loads(out.read_text()) if out.exists() else {};result={'id':id,'mode':mode,'optional':optional,'exit_code':code,'errors':errors,'seconds':d.get('simulated_seconds',0),'damage':d.get('damage',{}),'score':d.get('score',[])};print(key,code,len(errors),flush=True);return result
cases=[('qsrc_dm'+str(i),m,False) for i in range(1,8) for m in ['dm','ig','ft','tdm']]+[('lqdm'+str(i),m,True) for i in range(1,9) for m in ['dm','ig','ft','tdm']]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,cases))
(OUT/'summary.json').write_text(json.dumps(results,indent=2)+'\n');raise SystemExit(int(any(r['exit_code'] or r['errors'] or r['seconds']<45 for r in results)))
