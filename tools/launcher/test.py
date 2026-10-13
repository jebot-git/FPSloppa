"""Isolated real-runtime launcher checks: queries, downloads, upload ACKs, and music."""
from pathlib import Path
import hashlib, importlib.util, json, os, shutil, socket, subprocess, tempfile, time, struct
ROOT=Path(__file__).resolve().parents[2]
LOG=ROOT/'test-results/launcher'; LOG.mkdir(parents=True,exist_ok=True)
GODOT=os.environ.get('GODOT_BIN') or shutil.which('godot')
spec=importlib.util.spec_from_file_location('master',ROOT/'tools/master_server/server.py')
master=importlib.util.module_from_spec(spec);spec.loader.exec_module(master)
def free_port():
 with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
def wait_for(fn, seconds=90):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  result=fn()
  if result:return result
  time.sleep(.1)
 raise AssertionError('Timed out')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 with tempfile.TemporaryDirectory(prefix='fps-launcher-') as tmp:
  temp=Path(tmp);env=dict(os.environ,XDG_DATA_HOME=str(temp/'data'),XDG_CONFIG_HOME=str(temp/'config'),XDG_CACHE_HOME=str(temp/'cache'))
  base=[GODOT,'--headless','--xr-mode','off','--audio-driver','Dummy','--path',str(ROOT)]
  client=temp/'client';server=temp/'server';server.mkdir();client.mkdir()
  profile=temp/'client.cfg'
  def run_job(name, data, assets=client, error=None):
   job=temp/(name+'.json');job.write_text(json.dumps(data))
   with (LOG/(name+'.log')).open('w') as log:
    p=subprocess.Popen(base+['--','--launcher-worker','--asset-root',str(assets),'--client-config',str(profile),'--job',str(job)],env=env,stdout=log,stderr=subprocess.STDOUT)
    try:p.wait(timeout=280)
    except BaseException:p.kill();p.wait();raise
   status=Path(str(job)+'.status');assert status.exists(),(LOG/(name+'.log')).read_text()[-4000:]
   result=json.loads(status.read_text());output=(LOG/(name+'.log')).read_text()
   assert 'SCRIPT ERROR' not in output,output[-4000:]
   assert result['state']==('error' if error else 'complete'),(name,result,output[-3000:])
   if error:assert error in result['message'],result
   print(name,result['message'],flush=True)
  visual='--visual' in os.sys.argv
  cmd=base.copy()
  if visual:cmd.remove('--headless')
  with (LOG/'checks.log').open('w') as log:
   result=subprocess.run(cmd+['--script','res://tools/launcher/check.gd','--','--asset-root',str(temp/'checks'),'--client-config',str(profile)]+(['--visual'] if visual else []),env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90)
  output=(LOG/'checks.log').read_text();assert result.returncode==0 and 'LAUNCHER_CHECK_RESULT []' in output and 'SCRIPT ERROR' not in output,output[-6000:]
  print('UI, favourite persistence, admission rules, and game playlist ordering passed.',flush=True)
  identity_assets=temp/'identity';(identity_assets/'vrm').mkdir(parents=True)
  shutil.copy2(ROOT/'vrm/sample_d.vrm',identity_assets/'vrm/sample_d.vrm')
  with (LOG/'identity.log').open('w') as log:
   result=subprocess.run(cmd+['--script','res://tools/launcher/identity_check.gd','--','--asset-root',str(identity_assets),'--client-config',str(temp/'identity.cfg')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90)
  output=(LOG/'identity.log').read_text();assert result.returncode==0 and 'IDENTITY_CHECK_RESULT []' in output and 'SCRIPT ERROR' not in output,output[-6000:]
  print('Identity editor, direct connection options, colour rendering and avatar choice passed.',flush=True)

  bad=temp/'bad.vrm';bad.write_bytes(b'not a VRM')
  run_job('invalid-vrm',{'action':'import','files':[str(bad)]},error='Not a valid binary VRM')
  run_job('cancelled',{'action':'preload','address':'127.0.0.1','game_port':free_port(),'heartbeat':True},error='Cancelled')
  for path in ['maps/qsrc_dm1.bsp','vrm/sample_d.vrm','vrm/sample_f.vrm','vrm/sample_g.vrm']:
   dest=server/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/path,dest)
  port,query=free_port(),free_port()
  cfg=temp/'server.cfg';cfg.write_text(f'set net_ip "127.0.0.1"\nset net_port "{port}"\nset sv_query_port "{query}"\nset sv_maxclients "8"\nset sv_bot_fill "0"\nset sv_voice "0"\nset sv_gametypes "dm"\nset dm_maplist "qsrc_dm1"\n')
  with (LOG/'server.log').open('w') as log:
   host=subprocess.Popen(base+['--','--server','--config',str(cfg),'--asset-root',str(server)],env=env,stdout=log,stderr=subprocess.STDOUT)
   try:
    def status():
     try:return master.query_status('127.0.0.1',query,timeout=.3)
     except (OSError,ValueError):return None
    live=wait_for(status);assert live['map']=='qsrc_dm1' and live['humans']==0
    endpoint={'address':'127.0.0.1','game_port':port}
    run_job('preload',{'action':'preload',**endpoint})
    assert any(sha(p)==sha(server/'maps/qsrc_dm1.bsp') for p in (client/'maps').glob('*.bsp'))
    assert list((client/'vrm').glob('*.vrm'))
    imported=temp/'dm_launcher_fixture.bsp';imported.write_bytes((ROOT/'maps/qsrc_dm1.bsp').read_bytes()+b'launcher-fixture')
    avatar=temp/'launcher-avatar.vrm'
    raw=(ROOT/'vrm/sample_d.vrm').read_bytes();length=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+length]);doc['extensions']['VRM']['meta']['title']='Launcher transfer fixture'
    chunk=json.dumps(doc,separators=(',',':')).encode();chunk+=b' '*((-len(chunk))%4)
    tail=raw[20+length:];avatar.write_bytes(struct.pack('<III',0x46546c67,2,20+len(chunk)+len(tail))+struct.pack('<II',len(chunk),0x4e4f534a)+chunk+tail)
    run_job('import',{'action':'import','files':[str(imported),str(avatar)]})
    run_job('submit-map',{'action':'submit','files':[str(imported)],**endpoint})
    assert (server/'maps'/('custom_'+sha(imported)+'.bsp')).is_file()
    run_job('submit-vrm',{'action':'submit','files':[str(avatar)],**endpoint})
    assert (server/'vrm'/(sha(avatar)+'.vrm')).is_file()
    with (LOG/'identity-network.log').open('w') as output:
     identity=subprocess.run(base+['--script','res://tools/launcher/identity_client.gd','--','--asset-root',str(client),'--client-config',str(profile),'--connect','127.0.0.1','--port',str(port),'--spectate','--name','^1Red^7Fox','--clan','^5VR','--avatar',sha(avatar)],env=env,stdout=output,stderr=subprocess.STDOUT,timeout=140)
    text=(LOG/'identity-network.log').read_text();assert identity.returncode==0 and 'IDENTITY_NETWORK_RESULT ' in text and 'SCRIPT ERROR' not in text,text[-5000:]
    received=json.loads(text.split('IDENTITY_NETWORK_RESULT ')[1].splitlines()[0]);assert received['plain']=='[VR] RedFox' and received['avatar']==sha(avatar) and received['spectator'],received
    print('Real server admitted the coloured clan/name and acknowledged the selected avatar.',flush=True)

   finally:host.terminate();host.wait(timeout=15)
 print('Launcher integration passed.',flush=True)
if __name__=='__main__':main()
