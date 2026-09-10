"""Exercise persistent map upload/download and separate external libraries."""
from pathlib import Path
import subprocess,tempfile,time,json,shutil,os,hashlib
root=Path(__file__).resolve().parents[1];logs=root/'test-results';logs.mkdir(exist_ok=True)
godot=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
files=json.loads((root/'deathmatch/assets/base_manifest.json').read_text())['files'];results=[]
with tempfile.TemporaryDirectory(prefix='fpsloppa-upload-') as temp:
 temp=Path(temp);raw=(root/'maps/lqdm2.bsp').read_bytes()+str(temp).encode();fixture=temp/'upload.bsp';fixture.write_bytes(raw);sha=hashlib.sha256(raw).hexdigest()
 processes=[];handles=[]
 try:
  for role in ['server','uploader','receiver']:
   assets=temp/role
   for row in files:
    dest=assets/row['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/row['path'],dest)
   path=logs/f'asset-upload-{role}.log';out=path.open('w');handles.append(out)
   p=subprocess.Popen([godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/map_upload_runner.gd','--',role,str(fixture),sha,'--asset-root',str(assets)],env=dict(os.environ,XDG_DATA_HOME=str(temp/(role+'-profile'))),stdout=out,stderr=subprocess.STDOUT);processes.append((role,p,path))
   if role=='server':
    deadline=time.monotonic()+15
    while time.monotonic()<deadline and 'DM_HOST_READY' not in path.read_text():
     if p.poll() is not None:break
     time.sleep(.05)
  for role,p,path in processes:
   p.wait(timeout=100);text=path.read_text();ok=p.returncode==0 and 'MAP_UPLOAD_RESULT' in text and not any(x in text for x in ['FAIL ','ERROR:']);results.append({'role':role,'passed':ok});print(role,ok,flush=True)
 finally:
  for _,p,_ in processes:
   if p.poll() is None:p.terminate();p.wait(timeout=5)
  for handle in handles:handle.close()
(logs/'asset-transfer-validation.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(row['passed'] for row in results) else 1)
