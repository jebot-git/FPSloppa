"""Dedicated server plus two ENet clients across map rotation and wraparound."""
from pathlib import Path
import os,shutil,subprocess,time
root=Path(__file__).resolve().parents[2]
logs=root/'test-results';logs.mkdir(exist_ok=True)
godot=os.environ.get('GODOT_BIN') or shutil.which('godot')
processes=[];handles=[]
try:
 for role in ['server','first','second']:
  log=logs/f'rotation_{role}.log';handle=log.open('w');handles.append(handle)
  command=[godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/map_rotation.gd','--',role]
  process=subprocess.Popen(command,stdout=handle,stderr=subprocess.STDOUT);processes.append((role,process))
  if role=='server':
   end=time.monotonic()+10
   while time.monotonic()<end and 'DM_HOST_READY' not in log.read_text():
    if process.poll() is not None:break
    time.sleep(.05)
 passed=True
 for role,process in processes:
  process.wait(timeout=45)
  text=(logs/f'rotation_{role}.log').read_text();print(role,text)
  passed &= process.returncode==0 and 'MAP_ROTATION_RESULT' in text and 'FAIL ' not in text and 'ERROR:' not in text
 raise SystemExit(0 if passed else 1)
finally:
 for _,process in processes:
  if process.poll() is None:process.terminate();process.wait(timeout=5)
 for handle in handles:handle.close()
