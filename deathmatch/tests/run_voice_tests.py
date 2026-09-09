"""Voice relay integration; optionally use the exported dedicated server."""
from pathlib import Path
import subprocess,time,sys,json
root=Path(__file__).resolve().parents[2]
logs=root/'test-results'; logs.mkdir(exist_ok=True)
godot='/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'
processes=[]; handles=[]
external=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
try:
 for role in ['server','sender','receiver']:
  handle=(logs/('voice_'+role+'.log')).open('w'); handles.append(handle)
  if role=='server' and external:
   cmd=[str(external),'--headless','--xr-mode','off','--','+exec',str(external.parent/'server.cfg'),'--port','28888']
  else:
   cmd=[godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/voice_network.gd','--',role]
  proc=subprocess.Popen(cmd,stdout=handle,stderr=subprocess.STDOUT);processes.append((role,proc))
  if role=='server':
   deadline=time.monotonic()+20
   while time.monotonic()<deadline:
    if 'DM_HOST_READY' in (logs/'voice_server.log').read_text():break
    if proc.poll() is not None:break
    time.sleep(.1)
 success=True
 for role,proc in processes:
  if role=='server' and external:continue
  proc.wait(timeout=25)
  content=(logs/('voice_'+role+'.log')).read_text()
  success &= proc.returncode==0 and 'VOICE_NETWORK_RESULT' in content and 'FAIL ' not in content and 'ERROR:' not in content
 if external:
  content=(logs/'voice_server.log').read_text()
  success &= processes[0][1].poll() is None and 'SERVER_CONFIG' in content and 'ERROR:' not in content
 for role,_ in processes:print(role,(logs/('voice_'+role+'.log')).read_text())
 (logs/('voice_binary_summary.json' if external else 'voice_summary.json')).write_text(json.dumps({'passed':success,'exported_server':str(external) if external else None},indent=2))
 sys.exit(0 if success else 1)
finally:
 for _,proc in processes:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
 for handle in handles:handle.close()
