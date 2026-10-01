#!/usr/bin/env python3
"""Verify an external headless controller against an unmodified local dedicated server."""
from pathlib import Path
import argparse,json,os,re,secrets,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from rcon import command

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',required=True,type=Path);args=parser.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 project=Path('/tmp/fps-external-bot-probe-'+str(time.time_ns()));project.mkdir()
 for p in ROOT.iterdir():
  if not p.name.startswith('.') and p.name not in ['Builds','project.godot','server.cfg']:(project/p.name).symlink_to(p,target_is_directory=p.is_dir())
 cache=project/'.godot';cache.mkdir()
 for name in ['global_script_class_cache.cfg','uid_cache.bin']:shutil.copy2(ROOT/'.godot'/name,cache/name)
 (cache/'imported').symlink_to(ROOT/'.godot/imported',target_is_directory=True)
 (cache/'extension_list.cfg').write_text('res://addons/fps_native/fps_native.gdextension\nres://addons/twovoip/twovoip.gdextension\n')
 config=re.sub(r'run/main_scene=.*','run/main_scene="res://probe.tscn"',(ROOT/'project.godot').read_text())
 config=re.sub(r'\[autoload\].*?(?=\[)','',config,flags=re.S);(project/'project.godot').write_text(config)
 (project/'probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/bot_service/client_probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript=ExtResource("1")\n')
 shutil.copy2(ROOT/'Builds/ClientTemplates/linux.x86_64',project/'FPSloppa')
 secret=secrets.token_hex(24);cfg=project/'server.cfg'
 values=dict(sv_hostname='External bot feasibility',net_ip='127.0.0.1',net_port=29883,sv_query_port=0,sv_public=0,sv_maxclients=2,sv_bot_fill=0,
  sv_gametype='dm',sv_gametypes='dm',sv_weapon_rules='quake',dm_maplist='qsrc_dm6',sv_lobby=0,sv_voice=0,sv_log_level='verbose',sv_log_file=str(out/'server-events.jsonl'),
  rcon_password=secret,rcon_bind='127.0.0.1',rcon_port=29884)
 cfg.write_text(''.join(f'set {k} "{v}"\n' for k,v in values.items())+'map "qsrc_dm6"\n');cfg.chmod(0o600)
 server=None
 try:
  with (out/'server.log').open('w') as server_log:
   server=subprocess.Popen([str(ROOT/'Builds/JoltValidationServer/FPSloppaServer.x86_64'),'--','--config',str(cfg),'--asset-root',str(ROOT/'Builds/JoltValidationServer')],cwd=project,
    env=dict(os.environ,XDG_DATA_HOME=str(project/'server-user')),stdout=server_log,stderr=subprocess.STDOUT)
   for _ in range(200):
    assert server.poll() is None,'Server exited early'
    if 'SERVER_PHYSICS backend=Jolt' in (out/'server.log').read_text():break
    time.sleep(.1)
   else:raise RuntimeError('Server startup timed out')
   before=command('127.0.0.1',29884,secret,'status')
   assert not before['players'] and before['bot_fill']==0
   with (out/'client.log').open('w') as client_log:
    code=subprocess.run([str(project/'FPSloppa'),'--headless','--xr-mode','off','--',json.dumps({'host':'127.0.0.1','port':29883,'output':str(out/'client.json')}),
      '--asset-root',str(ROOT),'--client-config',str(project/'client.cfg'),'--no-avatar-disk-cache'],cwd=project,env=dict(os.environ,XDG_DATA_HOME=str(project/'client-user')),
      stdout=client_log,stderr=subprocess.STDOUT,timeout=60).returncode
   assert code==0, 'Client probe failed; see client.log'
   time.sleep(1)
   after=command('127.0.0.1',29884,secret,'status')
   assert not after['players'],'Client slot was not released'
   result=json.loads((out/'client.json').read_text());result['server_before']=before;result['server_after']=after
   events=[json.loads(l) for l in (out/'server-events.jsonl').read_text().splitlines()]
   result['server_events']=len(events)
   (out/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
 finally:
  if server and server.poll() is None:
   server.terminate()
   try:server.wait(timeout=8)
   except subprocess.TimeoutExpired:server.kill();server.wait()
  cfg.unlink(missing_ok=True)
 for name in ['client.log','server.log']:
  text=(out/name).read_text();assert not any(s in text for s in ['ERROR:','WARNING:','leaked']),name
 print((out/'summary.json').read_text())
if __name__=='__main__':main()
