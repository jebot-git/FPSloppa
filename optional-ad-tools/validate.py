"""Screen AD maps in separate bounded Godot processes, retaining per-map failures."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,time

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);p.add_argument('--only');p.add_argument('--resume',action='store_true');a=p.parse_args()
 root=Path(__file__).resolve().parents[1];logs=a.output/'validation';logs.mkdir(exist_ok=True)
 godot=os.environ.get('GODOT_BIN') or shutil.which('godot') or '/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'
 summary=a.output/'validation.json';results={r['id']:r for r in json.loads(summary.read_text())} if summary.exists() else {}
 for path in sorted((a.output/'candidates').glob('*.bsp')):
  if a.only and a.only not in path.stem:continue
  checksum=hashlib.sha256(path.read_bytes()).hexdigest();previous=results.get(path.stem,{})
  if a.resume and previous.get('passed') and previous.get('candidate_sha256')==checksum:continue
  report=path.with_name(path.stem+'-layout.json');log=logs/(path.stem+'.log');started=time.monotonic();reason=''
  # A crash must not resurrect a successful result from a previous run.
  if report.exists():report.unlink()
  with log.open('w') as out:
   process=subprocess.Popen([godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://optional-ad-tools/layout.gd','--',str(path.resolve())],stdout=out,stderr=subprocess.STDOUT)
   while process.poll() is None:
    if time.monotonic()-started>180 or log.stat().st_size>32_000_000:
     reason='Process exceeded 180 seconds or 32 MB diagnostic limit';process.kill();break
    time.sleep(.1)
   code=process.wait()
  row=json.loads(report.read_text()) if report.exists() else {'id':path.stem,'passed':False,'errors':['No completed layout']}
  text=log.read_text(errors='replace')
  if code!=0 or 'SCRIPT ERROR' in text or 'ERROR:' in text:
   row['passed']=False;row['errors'].append(reason or 'Godot errors or nonzero exit '+str(code)+'; see log')
  if hashlib.sha256(path.read_bytes()).hexdigest()!=checksum:row['passed']=False;row['errors'].append('Candidate changed during validation; rerun sequentially')
  row['candidate_sha256']=checksum;row['seconds']=round(time.monotonic()-started,2);results[path.stem]=row
  print(path.stem,row['passed'],row['seconds'],row['errors'][:3],flush=True)
  temporary=summary.with_suffix('.json.tmp');temporary.write_text(json.dumps(list(results.values()),indent=2));temporary.replace(summary)
if __name__=='__main__':main()
