from pathlib import Path
import subprocess,time,tempfile,os,hashlib,json

def main():
 root=Path(__file__).resolve().parents[2]
 godot='/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'
 logs=root/'test-results';logs.mkdir(exist_ok=True)
 processes=[];handles=[]
 with tempfile.TemporaryDirectory(prefix='arena-map-download-') as temp:
  data=(root/'deathmatch/maps/raw/lqdm2.bsp').read_bytes()+(' test '+temp).encode()
  path=Path(temp)/'host-arena.bsp';path.write_bytes(data)
  sha=hashlib.sha256(data).hexdigest()
  try:
   for role in ['server','client_a','client_b']:
    handle=(logs/f'map_{role}.log').open('w');handles.append(handle)
    env=os.environ.copy();env['XDG_DATA_HOME']=str(Path(temp)/role)
    cmd=[godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/map_download_runner.gd','--',role,str(path),sha]
    process=subprocess.Popen(cmd,env=env,stdout=handle,stderr=subprocess.STDOUT);processes.append((role,process))
    if role=='server':
     deadline=time.monotonic()+15
     while time.monotonic()<deadline:
      if 'DM_HOST_READY' in (logs/'map_server.log').read_text():break
      if process.poll() is not None:break
      time.sleep(.1)
   deadline=time.monotonic()+70
   for role,process in processes:process.wait(timeout=max(1,deadline-time.monotonic()))
   success=True
   for role,process in processes:
    text=(logs/f'map_{role}.log').read_text()
    lines=[line for line in text.splitlines() if any(x in line for x in ['PASS','FAIL','ERROR','RESULT'])]
    print(role,process.returncode,'\n'.join(lines))
    success &= process.returncode==0 and 'MAP_DOWNLOAD_RESULT' in text and 'ERROR:' not in text
   (logs/'map_download_summary.json').write_text(json.dumps({'passed':success,'bytes':len(data),'sha256':sha},indent=2))
   return 0 if success else 1
  finally:
   for _,process in processes:
    if process.poll() is None:process.terminate();process.wait(timeout=3)
   for h in handles:h.close()
