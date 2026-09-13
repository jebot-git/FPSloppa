"""Serial, bounded runs against a named isolated project; never overwrite evidence."""
import argparse, hashlib, json, os, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/tmp/fpsloppa-godot-official/Godot_v4.7.2-stable_linux.x86_64'
def main():
 p=argparse.ArgumentParser();p.add_argument('project',type=Path);p.add_argument('label');p.add_argument('jobs',type=Path);a=p.parse_args()
 out=ROOT/'test-results/ai-fixes'/a.label;out.mkdir(parents=True,exist_ok=True)
 for job in json.loads(a.jobs.read_text()):
  name=job.pop('name');script=job.pop('script','match');result=out/(name+'.json');status=out/(name+'-status.json')
  if status.exists():
   prior=json.loads(status.read_text())
   if prior['passed']:print('PRESERVED',name,flush=True);continue
  guarded=[a.project/'project.godot',*sorted((a.project/'deathmatch').rglob('*.gd'))]
  if 'map' in job:guarded += [a.project/'maps'/(job['map']+'.bsp'),a.project/'maps/navigation'/(job['map']+'.res')]
  before={str(f.relative_to(a.project)):hashlib.sha256(f.read_bytes()).hexdigest() for f in guarded if f.is_file()}
  opts=dict(minutes=60,seconds=300,seed=7129,mirror=0,class_mix=[],profile_tick=True,output=str(result));opts.update(job)
  arg=str(result) if script in ['water','navigation'] else json.dumps(opts)
  source=ROOT/'tools'/('ai_balance' if script in ['navigation','supplies'] else 'ai_fixes')/(script+'.gd')
  source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
  print('START',a.label,name,flush=True);start=time.monotonic()
  with (out/(name+'.log')).open('w') as log:
   try:
    proc=subprocess.run([GODOT,'--headless','--xr-mode','off','--fixed-fps','60','--path',str(a.project),'--script',str(source),'--',arg],stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-ai-fixes-data'),timeout=480);code=proc.returncode
   except subprocess.TimeoutExpired:code=124
  errors=list(dict.fromkeys(line for line in (out/(name+'.log')).read_text().splitlines() if 'ERROR:' in line))
  unchanged=all(hashlib.sha256((a.project/f).read_bytes()).hexdigest()==sha for f,sha in before.items()) and hashlib.sha256(source.read_bytes()).hexdigest()==source_sha
  row=dict(passed=code==0 and not errors and result.exists() and unchanged,code=code,errors=errors,seconds=round(time.monotonic()-start,2),inputs=before,script_sha256=source_sha,output_sha256=hashlib.sha256(result.read_bytes()).hexdigest() if result.exists() else None)
  status.write_text(json.dumps(row,indent=2)+'\n');print(name,{k:v for k,v in row.items() if k!='inputs'},flush=True)
  if not row['passed']:raise SystemExit(1)
if __name__=='__main__':main()
