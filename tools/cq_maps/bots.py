"""Bounded 64-bot smoke test: sixteen independent district-map server processes."""
import json,os,re,secrets,signal,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(ROOT/'tools/cq_gateway'))
from rcon import command
from external_config import create
OUT=ROOT/'test-results/cq-maps/bots';OUT.mkdir(parents=True,exist_ok=True)
password=secrets.token_hex(24);config=OUT/'server.cfg'
config.write_text(f'set sv_gametype cq\nset sv_gametypes cq\nset sv_cq_backend districts\nset sv_cq_worker_limit 16\nset sv_cq_maxclients 64\nset sv_cq_bot_fill 64\nset sv_voice 0\nset sv_lobby 0\nset sv_votes 0\nset net_ip 127.0.0.1\nset net_port 29532\nset rcon_port 29533\nset rcon_password "{password}"\n');config.chmod(0o600)
inventory=create(OUT/('private-'+secrets.token_hex(4)),list(range(16)),29534)
binary=ROOT/'Builds/CQDistrictMaps/FPSloppaServer.x86_64';children=[];handles=[];report={}
def spawn(label,args):
 handle=(OUT/(label+'.log')).open('w');handles.append(handle)
 child=subprocess.Popen([str(binary),'--','--experimental-cq','--cq-district-maps',*args],cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT);children.append(child);return child
def status():return command('127.0.0.1',29533,password,'status')
def position(row):return tuple(float(n) for n in re.findall(r'-?\d+(?:\.\d+)?',row['position']))
try:
 master=spawn('master',['--config',str(config),'--cq-external-workers',str(inventory)])
 deadline=time.monotonic()+30
 while 'SERVER_CONFIG' not in (OUT/'master.log').read_text():
  if master.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Master startup failed')
  time.sleep(.1)
 for zone in range(16):spawn(f'worker-{zone:02d}',['--cq-worker',str(zone),'--worker-session-file',str(inventory.parent/f'worker-{zone}.json')])
 deadline=time.monotonic()+90
 while True:
  if master.poll() is not None:raise RuntimeError((OUT/'master.log').read_text()[-4000:])
  first=status();actors=first['cq_backend']['actors']
  if len(actors)==64 and all(a['phase']=='active' for a in actors):break
  if time.monotonic()>deadline:raise TimeoutError('64 actors did not become active')
  time.sleep(.5)
 initial={a['id']:position(a) for a in actors};start=time.monotonic()
 time.sleep(25)
 last=status();backend=last['cq_backend']
 assert len(backend['actors'])==64 and backend['workers']==16
 assert max(backend['occupancy'])<=16
 moved=sum(sum((a-b)**2 for a,b in zip(position(row),initial[row['id']]))>1 for row in backend['actors'])
 assert moved==64,(moved,backend)
 assert backend['stats']['transfers']>0,backend
 for zone in range(16):
  text=(OUT/f'worker-{zone:02d}.log').read_text()
  assert f'CQ_ATLAS_READY district={zone} geometry_instances=1' in text,text[-2000:]
  assert 'SCRIPT ERROR' not in text and 'ERROR:' not in text,text[-2000:]
 assert 'geometry_instances=0' in (OUT/'master.log').read_text()
 assert 'SCRIPT ERROR' not in (OUT/'master.log').read_text()
 report=dict(ok=True,population=64,moved=moved,workers=16,wall_seconds=time.monotonic()-start,match_seconds_advanced=first['time_remaining']-last['time_remaining'],backend=backend)
 print('CQ_DISTRICT_BOTS',json.dumps(report))
finally:
 for child in children:
  if child.poll() is None:
   child.terminate()
   try:child.wait(timeout=5)
   except subprocess.TimeoutExpired:child.kill();child.wait()
 for handle in handles:handle.close()
 (OUT/'result.json').write_text(json.dumps(report,indent=2)+'\n')
