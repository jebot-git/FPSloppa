#!/usr/bin/env python3
"""Real loopback ENet clients. Always reap all owned server/client processes."""
import argparse,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--label',required=True);p.add_argument('--baseline',action='store_true');p.add_argument('--seconds',type=int,default=60);a=p.parse_args()
out=ROOT/'test-results/ai-study'/a.label;out.mkdir(parents=True,exist_ok=True)
stop=out/'stop';stop.unlink(missing_ok=True)
status=out/'status.json';status.unlink(missing_ok=True)
control=out/'control.json';control.unlink(missing_ok=True)
source=(ROOT/'deathmatch/arena.tscn').read_text().replace('res://deathmatch/arena.gd','res://tools/ai_study/baseline/client_arena.gd' if a.baseline else 'res://tools/remote_match/client_arena.gd')
(out/'client.tscn').write_text(source)
children=[];handles=[];results=[]
def launch(tag,script,opts):
 h=(out/(tag+'.log')).open('w');handles.append(h)
 cmd=['godot','--headless','--xr-mode','off','--max-fps','60','--path',str(ROOT),'--script',script,'--',json.dumps(opts),'--asset-root',str(ROOT)]
 children.append(subprocess.Popen(cmd,stdout=h,stderr=subprocess.STDOUT,env={**os.environ,'XDG_DATA_HOME':'/tmp/fpsloppa-ai-network-'+tag}))
def observed():
 try:return json.loads(status.read_text())
 except (FileNotFoundError,json.JSONDecodeError):return {}
try:
 launch('server','res://tools/ai_study/network_server.gd',dict(map='ctf_crownreach',mode='ctf',rules='ut99',port=29777,stop=str(stop),control=str(control)))
 time.sleep(3)
 for index in range(9):
  launch('observer' if index==8 else 'bot-'+str(index),'res://tools/remote_match/client.gd',dict(scene=str(out/'client.tscn'),index=index,observer=index==8,host='127.0.0.1',port=29777,stop=str(stop),demo=str(out/'match.fpsdemo'),status=str(status)))
  time.sleep(.15)
 for mode,map_id,rules in [('ctf','ctf_crownreach','ut99'),('koth','koth_alichar','doom')]:
  if mode=='koth':control.write_text(json.dumps(dict(mode=mode,map=map_id,rules=rules)))
  deadline=time.monotonic()+90
  while True:
   assert all(x.poll() is None for x in children),'Process exited during admission'
   s=observed()
   if s.get('active') and s.get('mode')==mode and len(s['players'])==9:break
   if time.monotonic()>deadline:raise RuntimeError('Admission timeout '+str(s))
   time.sleep(.25)
  control.write_text(json.dumps(dict(restart=True,mode=mode)))
  start=time.monotonic()
  while time.monotonic()-start<a.seconds:
   assert all(x.poll() is None for x in children),'Process exited'
   time.sleep(1)
  results.append(observed());print('FINISHED',mode,results[-1]['scores'],flush=True)
finally:
 stop.touch()
 for child in children:
  try:child.wait(timeout=12)
  except subprocess.TimeoutExpired:
   child.terminate()
   try:child.wait(timeout=3)
   except subprocess.TimeoutExpired:child.kill();child.wait()
 for h in handles:h.close()
 errors={f.name:[l for l in f.read_text(errors='replace').splitlines() if l.startswith(('ERROR:','SCRIPT ERROR:'))] for f in out.glob('*.log')}
 (out/'results.json').write_text(json.dumps(dict(rounds=results,exits=[c.returncode for c in children],errors=errors),indent=2))
 print('REAPED',[c.returncode for c in children],flush=True)
if any(c.returncode for c in children) or any(errors.values()):raise SystemExit(1)
