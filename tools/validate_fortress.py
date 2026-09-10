"""TF rules, BSP navigation, and three-process class/custom-VRM replication checks."""
from pathlib import Path
import subprocess,os,json,tempfile,shutil,time,struct,hashlib
root=Path(__file__).resolve().parents[1];logs=root/'test-results';logs.mkdir(exist_ok=True)
godot=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
report=[]
def check(name,p,path,marker):
 text=path.read_text();passed=p.returncode==0 and marker in text and not any(s in text for s in ['SCRIPT ERROR:','ERROR:','FAIL '])
 report.append({'test':name,'passed':passed});print(name,passed,flush=True)
def assets(dest):
 for row in json.loads((root/'deathmatch/assets/base_manifest.json').read_text())['files']:
  out=dest/row['path'];out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/row['path'],out)
with tempfile.TemporaryDirectory(prefix='fpsloppa-tf-test-') as temp:
 tmp=Path(temp);base=tmp/'assets';assets(base)
 for script,marker in [('fortress','FORTRESS_RESULT []'),('fortress_maps','TF_MAPS_RESULT []')]:
  path=logs/f'tf-{script}.log'
  with path.open('w') as out:p=subprocess.run([godot,'--headless','--xr-mode','off','--path',str(root),'--script',f'res://deathmatch/tests/{script}.gd','--','--asset-root',str(base)],env=dict(os.environ,XDG_DATA_HOME=str(tmp/'rules-profile')),stdout=out,stderr=subprocess.STDOUT,timeout=120)
  check(script,p,path,marker)
 # Make a genuinely new VRM asset. Only the scout receives it initially.
 raw=(root/'vrm/sample_f.vrm').read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length]);doc['extensions']['VRM']['meta']['title']='TF custom disguise '+tmp.name
 chunk=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode();chunk+=b' '*(-len(chunk)%4);binary=raw[20+length:]
 data=struct.pack('<IIIII',0x46546c67,2,20+len(chunk)+len(binary),len(chunk),0x4e4f534a)+chunk+binary
 fixture=tmp/'custom.vrm';fixture.write_bytes(data);digest=hashlib.sha256(data).hexdigest()
 processes=[];handles=[]
 try:
  for role in ['server','scout','spy']:
   asset_root=tmp/('assets-'+role);assets(asset_root);path=logs/f'tf-network-{role}.log';out=path.open('w');handles.append(out)
   cmd=[godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/fortress_network.gd','--',role,str(fixture),digest,'--asset-root',str(asset_root)]
   p=subprocess.Popen(cmd,env=dict(os.environ,XDG_DATA_HOME=str(tmp/('profile-'+role))),stdout=out,stderr=subprocess.STDOUT);processes.append((role,p,path))
   if role=='server':
    deadline=time.monotonic()+10
    while time.monotonic()<deadline and 'DM_HOST_READY' not in path.read_text():
     if p.poll() is not None:break
     time.sleep(.05)
  for role,p,path in processes:p.wait(timeout=110);check('network-'+role,p,path,'TF_NETWORK_RESULT')
 finally:
  for _,p,_ in processes:
   if p.poll() is None:p.terminate();p.wait(timeout=5)
  for out in handles:out.close()
(logs/'fortress-validation.json').write_text(json.dumps(report,indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in report) else 1)
