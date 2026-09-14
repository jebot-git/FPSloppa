"""Real ENet admissions against the packaged console server, controlled over RCON."""
from pathlib import Path
import json, os, subprocess, sys, time
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from rcon import command
work=ROOT/'test-results/server-bots';work.mkdir(exist_ok=True)
processes=[];handles=[];checks=[]
def wait(predicate,seconds=40):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  try:
   value=predicate()
   if value:return value
  except (OSError,ValueError):pass
  time.sleep(.1)
 raise AssertionError('Timeout waiting for '+str(predicate))
def launch(name,args):
 path=work/(name+'.stdout');f=path.open('w');handles.append(f)
 p=subprocess.Popen(args,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT);processes.append(p)
 return p,path
def client(name):
 (work/('stop-'+name)).unlink(missing_ok=True)
 return launch(name,['godot','--headless','--xr-mode','off','--path',str(ROOT),'--log-file',str(work/(name+'.log')),'--script','res://deathmatch/tests/server_bots_client.gd','--',name])
last_rcon=0.0
def rcon(text='status'):
 global last_rcon
 time.sleep(max(0,5.2-(time.monotonic()-last_rcon)))
 last_rcon=time.monotonic()
 return command('127.0.0.1',28943,'local-bot-test',text)
def check(ok,name):
 assert ok,name
 checks.append(name);print('PASS',name,flush=True)
def counts(s):return (sum(not p['bot'] for p in s['players']),sum(p['bot'] for p in s['players']))
cfg=work/'server.cfg'
cfg.write_text('set net_ip 127.0.0.1\nset net_port 28942\nset rcon_port 28943\nset rcon_password local-bot-test\nset sv_maxclients 4\nset sv_bot_fill 4\nset fraglimit 100\nset sv_log_level verbose\nset sv_gametypes "dm tb"\nset dm_maplist "qsrc_dm1 qsrc_dm7"\nset tb_maplist tb_ashfall\n')
try:
 server,log=launch('network-server',[str(ROOT/'Builds/ConsoleServer/FPSloppaServer.x86_64'),'--log-file',str(work/'network-server.log'),'--','--config',str(cfg)])
 s=wait(lambda:rcon())
 check(counts(s)==(0,4) and s['bot_fill']==4 and s['tb_heavy_ordnance'],'Startup config populates four bots; TB protection needs no setting')
 first,path=client('First');wait(lambda:'BOT_CLIENT_JOINED' in path.read_text())
 check(counts(rcon())==(1,3),'Real human replaces one bot at capacity')
 wait(lambda:'BOT_CLIENT_MOVEMENT' in path.read_text());check(True,'Remote client observes moving dedicated bots')
 guests=[client('Guest'+str(i)) for i in range(3)]
 wait(lambda:all('BOT_CLIENT_JOINED' in p.read_text() for _,p in guests))
 check(counts(rcon())==(4,0),'Three concurrent joins replace remaining bots without overflow')
 extra,path_extra=client('extra');wait(lambda:extra.poll() is not None)
 check(extra.returncode==0 and 'BOT_CLIENT_REJECTED' in path_extra.read_text(),'Human-only full server explicitly rejects fifth client')
 (work/'stop-First').touch();first.wait(timeout=10)
 wait(lambda:counts(rcon())==(3,1));check(True,'Bot refills after human departure')
 check(rcon('map qsrc_dm7').get('ok'),'Map rotation accepted')
 wait(lambda:(lambda s:s['map']=='qsrc_dm7' and counts(s)==(3,1) and s['pending']==0)(rcon()))
 check(True,'Rotation restores connected humans and bot fill')
 check(rcon()['tb_heavy_ordnance'],'Heavy policy persists through rotation')
 for i,(p,_) in enumerate(guests):(work/('stop-Guest'+str(i))).touch()
 for p,_ in guests:p.wait(timeout=10);assert p.returncode==0
 wait(lambda:counts(rcon())==(0,4));check(True,'Population returns to four bots after all humans leave')
 check(rcon('match tb tb_ashfall quake').get('ok'),'Dedicated TF-class TB switch accepted')
 s=wait(lambda:(lambda s:s if s['mode']=='tb' and s['map']=='tb_ashfall' and len(s['players'])==4 else None)(rcon()))
 check(s['weapon_rules']=='quake' and len(set(p['class'] for p in s['players']))>=2,'TB bots receive balanced teams and varied TF classes')
 check(sorted(sum(p['team']==team for p in s['players']) for team in [0,1])==[2,2],'TB bot teams split evenly')
 check(not any('SCRIPT ERROR:' in p.read_text() or 'ERROR:' in p.read_text() for p in work.glob('*.stdout') if p.name in ['network-server.stdout','First.stdout','extra.stdout'] or p.name.startswith('Guest')),'Live server and clients produce no engine/script errors')
finally:
 for p in processes:
  if p.poll() is None:p.terminate();p.wait(timeout=10)
 for f in handles:f.close()
 for p in work.glob('stop-*'):p.unlink()
 (work/'network-results.json').write_text(json.dumps({'checks':checks,'passed':len(checks)==14},indent=2)+'\n')
