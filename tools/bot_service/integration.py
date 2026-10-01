#!/usr/bin/env python3
"""Real headless worker/server integration; use a fresh output directory."""
from pathlib import Path
import argparse,json,os,secrets,subprocess,sys,time,tempfile,signal,re,shutil
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from rcon import command

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);p.add_argument('--port-base',type=int,default=29883);p.add_argument('--binary',type=Path,default=ROOT/'Builds/BotServiceServer/FPSloppaServer.x86_64');p.add_argument('--asset-root',type=Path,default=ROOT);p.add_argument('--reconnect',action='store_true');p.add_argument('--graceful-worker',action='store_true');p.add_argument('--human',action='store_true');p.add_argument('--local',action='store_true');p.add_argument('--lifecycle',action='store_true');p.add_argument('--seconds',type=int,default=20);p.add_argument('--next-map',default='qsrc_dm1');p.add_argument('--weapons',default='quake');p.add_argument('--mode',default='dm');p.add_argument('--map',default='qsrc_dm6');p.add_argument('--bots',type=int,default=4);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 binary=a.binary.resolve();base=a.port_base
 processes=[];logs=[];samples=[];server=None;worker=None
 with tempfile.TemporaryDirectory(prefix='fps-bot-service-') as tmp:
  temp=Path(tmp);key=temp/'worker.key';key.write_bytes(secrets.token_bytes(32));key.chmod(0o600);secret=secrets.token_hex(24)
  config=temp/'server.cfg'
  values=dict(sv_hostname='Bot worker integration',net_ip='127.0.0.1',net_port=base,sv_query_port=0,sv_public=0,sv_maxclients=a.bots if a.human else 16,sv_bot_fill=a.bots if a.local else 0,
   sv_gametype=a.mode,sv_gametypes=a.mode,sv_weapon_rules='cs16' if a.mode=='de' else a.weapons,sv_lobby=0,sv_voice=0,sv_log_level='verbose',sv_log_file=str(out/'events.jsonl'),rcon_password=secret,rcon_bind='127.0.0.1',rcon_port=base+1,
   sv_bot_worker_port=base+2,sv_bot_worker_key_file=str(key),sv_bot_worker_limit=16)
  values[a.mode+'_maplist']=a.map+(' '+a.next_map if a.lifecycle else '')
  config.write_text(''.join(f'set {k} "{v}"\n' for k,v in values.items())+f'map "{a.map}"\n');config.chmod(0o600)
  def start(name,args):
   f=(out/(name+'.log')).open('w');logs.append(f)
   proc=subprocess.Popen([str(binary),'--',*args,'--asset-root',str(a.asset_root.resolve())],cwd=temp,env=dict(os.environ,XDG_DATA_HOME=str(temp/name)),stdout=f,stderr=subprocess.STDOUT);processes.append(proc);return proc
  last_rcon=0.0
  def rpc(text):
   nonlocal last_rcon
   time.sleep(max(0,5.2-(time.monotonic()-last_rcon)));last_rcon=time.monotonic()
   return command('127.0.0.1',base+1,secret,text)
  def status():return rpc('status')
  def wait_ready(predicate,timeout=60):
   end=time.monotonic()+timeout
   while time.monotonic()<end:
    if server.poll() is not None:raise RuntimeError('server exited: '+str(server.returncode))
    if worker is not None and worker.poll() is not None:raise RuntimeError('worker exited: '+str(worker.returncode))
    try:
     s=status()
     if predicate(s):return s
    except (ConnectionError,OSError,json.JSONDecodeError):pass
    time.sleep(6.2)
   raise TimeoutError('status condition timeout')
  try:
   server=start('server',['--config',str(config),'--bot-benchmark-output',str(out/'profile.json')])
   wait_ready(lambda s:True)
   worker=None
   if not a.local:
    worker=start('worker',['--bot-worker','--bot-host','127.0.0.1','--bot-port',str(base+2),'--bot-key-file',str(key),'--bot-count',str(a.bots),'--bot-stats',str(out/'worker.json')]+(['--quit-after-seconds','25'] if a.graceful_worker else []))
    wait_ready(lambda s:s['bot_worker']['leased']==a.bots)
   for _ in range(max(1,a.seconds//6)):
    assert worker is None or worker.poll() is None,'worker exited'
    samples.append(status());time.sleep(6.2)
   if worker:
    assert all(s['bot_worker']['connected'] and s['bot_worker']['disconnects']==0 for s in samples),'unexpected worker reconnect during steady-state test'
    assert samples[-1]['bot_worker']['leased']==a.bots,'worker lost its bot leases'
   human={}
   if a.human and worker:
    project=temp/'client';project.mkdir()
    for path in ROOT.iterdir():
     if not path.name.startswith('.') and path.name not in ['Builds','project.godot']:(project/path.name).symlink_to(path,target_is_directory=path.is_dir())
    cache=project/'.godot';cache.mkdir()
    for name in ['global_script_class_cache.cfg','uid_cache.bin']:shutil.copy2(ROOT/'.godot'/name,cache/name)
    (cache/'imported').symlink_to(ROOT/'.godot/imported',target_is_directory=True)
    (cache/'extension_list.cfg').write_text('res://addons/fps_native/fps_native.gdextension\nres://addons/twovoip/twovoip.gdextension\n')
    source=re.sub(r'run/main_scene=.*','run/main_scene="res://probe.tscn"',(ROOT/'project.godot').read_text())
    source=re.sub(r'\[autoload\].*?(?=\[)','',source,flags=re.S);(project/'project.godot').write_text(source)
    (project/'probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/bot_service/client_probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript=ExtResource("1")\n')
    shutil.copy2(ROOT/'Builds/ClientTemplates/linux.x86_64',project/'FPSloppa')
    log=(out/'human.log').open('w');logs.append(log)
    client=subprocess.Popen([str(project/'FPSloppa'),'--headless','--xr-mode','off','--',json.dumps({'host':'127.0.0.1','port':base,'output':str(out/'human.json')}),'--asset-root',str(a.asset_root.resolve()),'--client-config',str(temp/'client.cfg'),'--no-avatar-disk-cache'],cwd=project,env=dict(os.environ,XDG_DATA_HOME=str(temp/'human-user')),stdout=log,stderr=subprocess.STDOUT);processes.append(client)
    human['joined']=wait_ready(lambda s:any(row['id']>0 for row in s['players']))
    assert len(human['joined']['players'])==a.bots
    assert sum(row['bot'] for row in human['joined']['players'])==a.bots-1
    assert client.wait(timeout=45)==0,'human controller failed'
    human['refilled']=wait_ready(lambda s:len(s['players'])==a.bots and all(row['bot'] for row in s['players']) and s['bot_worker']['leased']==a.bots)
   lifecycle={}
   if a.lifecycle and worker:
    worker.send_signal(signal.SIGSTOP);time.sleep(1)
    lifecycle['suspended']=status()
    assert lifecycle['suspended']['bot_worker']['leased']==0,'expired leases still delegated'
    worker.send_signal(signal.SIGCONT)
    lifecycle['resumed']=wait_ready(lambda s:s['bot_worker']['leased']==a.bots)
    rpc('map '+a.next_map)
    lifecycle['rotated']=wait_ready(lambda s:s['map']==a.next_map and s['bot_worker']['leased']==a.bots)
    rpc('restart')
    lifecycle['restarted']=wait_ready(lambda s:s['bot_worker']['leased']==a.bots)
   if a.reconnect and worker:
    server.terminate();server.wait(timeout=10);time.sleep(2)
    server=start('server-restarted',['--config',str(config)])
    lifecycle['reconnected']=wait_ready(lambda s:s['bot_worker']['leased']==a.bots)
   if worker:
    if a.graceful_worker:assert worker.wait(timeout=35)==0,'worker graceful exit failed'
    else:worker.terminate();worker.wait(timeout=10)
    worker=None # Expected shutdown; keep detecting unexpected exits during active phases.
   released=wait_ready(lambda s:not s['bot_worker']['connected'] and (a.local or not s['players']),10)
   (out/'summary.json').write_text(json.dumps({'samples':samples,'released':released,'lifecycle':lifecycle,'human':human},indent=2)+'\n')
  finally:
   for proc in reversed(processes):
    if proc.poll() is None:
     proc.terminate()
     try:proc.wait(timeout=8)
     except subprocess.TimeoutExpired:proc.kill();proc.wait()
   for f in logs:f.close()
 for file in out.glob('*.log'):
  assert not any(s in file.read_text() for s in ['ERROR:','SCRIPT ERROR:','WARNING:','leaked']),file
 print(json.dumps(samples[-1]['bot_worker'],indent=2))
if __name__=='__main__':main()
