"""Exercise delayed teleport input through a real server and two ENet clients."""
import json, os, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/teleport-exits';OUT.mkdir(parents=True,exist_ok=True)
processes=[];handles=[];rows=[]
try:
 for role in ['server','traveler','observer']:
  log=OUT/f'network-{role}.log';handle=log.open('w');handles.append(handle)
  child=subprocess.Popen(['godot','--headless','--xr-mode','off','--audio-driver','Dummy','--path',str(ROOT),'--script','res://deathmatch/tests/teleport_network.gd','--',role,'--client-config',str(OUT/f'{role}.cfg')],env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-teleport-network'),stdout=handle,stderr=subprocess.STDOUT)
  processes.append((role,child))
  if role=='server':
   deadline=time.monotonic()+15
   while child.poll() is None and time.monotonic()<deadline:
    if 'DM_HOST_READY' in log.read_text():break
    time.sleep(.1)
 deadline=time.monotonic()+65
 for role,child in processes:
  child.wait(timeout=max(1,deadline-time.monotonic()))
  text=(OUT/f'network-{role}.log').read_text()
  row={'role':role,'passed':child.returncode==0 and 'TELEPORT_NETWORK_RESULT' in text and 'SCRIPT ERROR:' not in text,'checks':text.count('PASS ')}
  rows.append(row);print(json.dumps(row),flush=True)
  if not row['passed']:print(text[-5000:],flush=True)
 (OUT/'network.json').write_text(json.dumps(rows,indent=2)+'\n')
finally:
 for _,child in processes:
  if child.poll() is None:
   child.terminate()
   try:child.wait(timeout=3)
   except subprocess.TimeoutExpired:child.kill();child.wait()
 for handle in handles:handle.close()
raise SystemExit(0 if len(rows)==3 and all(r['passed'] for r in rows) else 1)
