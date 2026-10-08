from pathlib import Path
import subprocess,json,concurrent.futures
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def validate(folder):
 name=folder.name;log=folder/'runtime-validation.log'
 with log.open('w') as f:
  try:code=subprocess.run([str(ROOT/'run.sh'),'--headless','--xr-mode','off','--audio-driver','Dummy','--script','tools/unreal_imports/validate_runtime.gd','--','res://'+str((folder/(name+'.bsp')).relative_to(ROOT))],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=180).returncode
  except subprocess.TimeoutExpired:code=124
 report=json.loads((folder/'runtime-validation.json').read_text()) if (folder/'runtime-validation.json').exists() else {}
 print(name,code,report.get('routes'),report.get('total_routes'),report.get('failures'),flush=True);return code
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(validate,sorted((HERE/'local/candidates').glob('koth_ut_*'))))
raise SystemExit(bool(any(results)))
