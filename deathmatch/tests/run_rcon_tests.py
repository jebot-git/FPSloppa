from pathlib import Path
import importlib.util,subprocess,tempfile,secrets,time,json,socket,hmac,hashlib,sys
root=Path(__file__).resolve().parents[2];spec=importlib.util.spec_from_file_location('rcon',root/'tools/rcon.py');rcon=importlib.util.module_from_spec(spec);spec.loader.exec_module(rcon)
password=secrets.token_hex(20);log=root/'test-results/rcon-server.log';report={}
with tempfile.TemporaryDirectory(prefix='fpsloppa-rcon-') as tmp:
 cfg=Path(tmp)/'server.cfg';cfg.write_text(f'set net_ip 127.0.0.1\nset net_port 28894\nset sv_maxclients 16\nset timelimit 17\nset sv_gametype koth\nset sv_gametypes "koth dm"\nset koth_maplist "koth_solstice koth_torture"\nset dm_maplist "qsrc_dm1 qsrc_dm2"\nset koth_move_points 7\nset hilllimit 55\nset rcon_password "{password}"\nset rcon_port 28895\nset sv_log_level verbose\n')
 with log.open('w') as f:
  command=[str(Path(sys.argv[1]).resolve()),'--','--config',str(cfg)] if len(sys.argv)>1 else ['godot','--headless','--xr-mode','off','--audio-driver','Dummy','--path',str(root),'--','--server','--config',str(cfg)]
  p=subprocess.Popen(command,stdout=f,stderr=subprocess.STDOUT)
  try:
   deadline=time.monotonic()+30
   while 'SERVER_CONFIG' not in log.read_text() and time.monotonic()<deadline and p.poll() is None:time.sleep(.1)
   assert p.poll() is None and 'SERVER_CONFIG' in log.read_text(),log.read_text()[-3000:]
   status=rcon.command('127.0.0.1',28895,password,'status');assert status['capacity']==16 and status['mode']=='koth' and status['allowed_modes']==['koth','dm'] and status['time_remaining']==1020,status
   report['configured_status']=status
   assert 'error' in rcon.command('127.0.0.1',28895,password,'map nonexistent')
   assert 'error' in rcon.command('127.0.0.1',28895,password,'mode as')
   assert 'error' in rcon.command('127.0.0.1',28895,password,'restart; status')
   try:rcon.command('127.0.0.1',28895,'wrong','status');raise AssertionError('wrong password accepted')
   except ValueError:report['wrong_password_rejected']=True
   with socket.create_connection(('127.0.0.1',28895),timeout=3) as sock:
    old=json.loads(sock.makefile('rb').readline())['nonce']
   with socket.create_connection(('127.0.0.1',28895),timeout=3) as sock:
    stream=sock.makefile('rb');new=json.loads(stream.readline())['nonce'];assert old!=new
    sock.sendall((json.dumps({'command':'status','mac':hmac.new(password.encode(),(old+'\nstatus').encode(),hashlib.sha256).hexdigest()})+'\n').encode())
    response=json.loads(stream.readline());assert json.loads(response['result'])['error']=='Authentication failed';report['replay_rejected']=True
   assert rcon.command('127.0.0.1',28895,password,'mode dm')['ok'];time.sleep(.3)
   assert rcon.command('127.0.0.1',28895,password,'status')['mode']=='dm';report['allowed_mode_change']=True
   assert rcon.command('127.0.0.1',28895,password,'map qsrc_dm2')['ok'];time.sleep(.3)
   assert rcon.command('127.0.0.1',28895,password,'status')['map']=='qsrc_dm2';report['allowed_map_change']=True
   assert password not in log.read_text();report['secret_absent_from_log']=True
   assert 'SCRIPT ERROR:' not in log.read_text() and 'ERROR:' not in log.read_text(),log.read_text()[-2500:]
  finally:
   p.terminate();p.wait(timeout=10)
(root/'test-results/rcon-summary.json').write_text(json.dumps(report,indent=2)+'\n');print('RCON_PASS',json.dumps(report))
