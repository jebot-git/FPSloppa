from pathlib import Path
import os,subprocess,time
ROOT=Path(__file__).resolve().parents[1];GODOT=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64');LOGS=ROOT/'test-results'
def run(script,name):
 with (LOGS/name).open('w') as log:
  result=subprocess.run([GODOT,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/'+script+'.gd'],stdout=log,stderr=subprocess.STDOUT,timeout=120)
 text=(LOGS/name).read_text();assert result.returncode==0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text,(name,text[-4000:]);print('PASS',name,flush=True)
run('new_features','new-features.log')
run('votes','new-features-votes.log')
processes=[];handles=[]
try:
 for role in ['server','early','late']:
  handle=(LOGS/('lobby-network-'+role+'.log')).open('w');handles.append(handle)
  cmd=[GODOT,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/lobby_network.gd','--','--role',role]
  processes.append((role,subprocess.Popen(cmd,stdout=handle,stderr=subprocess.STDOUT)))
  if role=='server':time.sleep(1)
 for role,proc in processes:
  code=proc.wait(timeout=90);text=(LOGS/('lobby-network-'+role+'.log')).read_text()
  assert code==0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text,(role,text[-5000:]);print('PASS lobby',role,flush=True)
finally:
 for _,proc in processes:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
 for handle in handles:handle.close()
