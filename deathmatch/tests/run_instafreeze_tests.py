"""Exercise IF rules, existing IG/FT/CC, host selection and real ENet replication."""
from pathlib import Path
import json, os, subprocess, time, sys, importlib.util, secrets, tempfile
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/instafreeze'
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 env=dict(os.environ,XDG_DATA_HOME=str(OUT/'user'))
 base=[os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(ROOT),'--script']
 results=[]
 def record(name,process,path,marker):
  log=path.read_text();errors=[s for s in log.splitlines() if 'ERROR:' in s or s.startswith('FAIL ')]
  row=dict(test=name,exit=process.returncode,checks=sum(s.startswith('PASS ') for s in log.splitlines()),passed=process.returncode==0 and marker in log and not errors,errors=errors)
  results.append(row);print(json.dumps(row),flush=True)
 for name,marker in [('instafreeze','INSTAFREEZE_RESULT []'),('special_modes','SPECIAL_MODES_RESULT []'),('host_modes','HOST_MODES_RESULT []')]:
  path=OUT/(name+'.log')
  with path.open('w') as out:p=subprocess.run(base+['res://deathmatch/tests/'+name+'.gd'],cwd=ROOT,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=90)
  record(name,p,path,marker)
 processes=[];handles=[]
 try:
  for role in ['server','red','blue']:
   path=OUT/('network-'+role+'.log');out=path.open('w');handles.append(out)
   p=subprocess.Popen(base+['res://deathmatch/tests/special_network.gd','--',role],cwd=ROOT,env=env,stdout=out,stderr=subprocess.STDOUT);processes.append((role,p,path))
   if role=='server':
    deadline=time.monotonic()+10
    while p.poll() is None and time.monotonic()<deadline and 'DM_HOST_READY' not in path.read_text():time.sleep(.05)
  deadline=time.monotonic()+45
  for role,p,path in processes:
   try:p.wait(timeout=max(1,deadline-time.monotonic()))
   except subprocess.TimeoutExpired:
    results.append(dict(test='network-'+role,exit=None,checks=0,passed=False,errors=['Process timed out']));break
   record('network-'+role,p,path,'SPECIAL_NETWORK_RESULT '+role+' []')
 finally:
  for _,p,_ in processes:
   if p.poll() is None:
    p.terminate()
    try:p.wait(timeout=3)
    except subprocess.TimeoutExpired:p.kill();p.wait(timeout=3)
  for handle in handles:handle.close()
 report=dict(passed=all(r['passed'] for r in results),checks=sum(r['checks'] for r in results),results=results)
 (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
 return 0 if report['passed'] else 1
def console_checks(binary):
 OUT.mkdir(parents=True,exist_ok=True)
 spec=importlib.util.spec_from_file_location('rcon',ROOT/'tools/rcon.py');rcon=importlib.util.module_from_spec(spec);spec.loader.exec_module(rcon)
 binary=Path(binary).resolve();results=[]
 for explicit in [True,False]:
  password=secrets.token_hex(20);path=OUT/('console-explicit.log' if explicit else 'console-file.log')
  expected=['lqdm2','lqdm1'] if explicit else [line.strip() for line in (binary.parent/'maps/ig_maplist.txt').read_text().splitlines() if line.strip() and not line.startswith('#')]
  with tempfile.TemporaryDirectory(prefix='fpsloppa-if-config-') as tmp:
   cfg=Path(tmp)/'server.cfg';cfg.write_text('set net_ip 127.0.0.1\nset net_port 28884\nset sv_gametype if\nset sv_gametypes "ig if"\nset rcon_bind 127.0.0.1\nset rcon_port 28885\nset rcon_password "'+password+'"\n'+('set ig_maplist "lqdm2 lqdm1"\n' if explicit else ''))
   with path.open('w') as out:
    p=subprocess.Popen([str(binary),'--','--config',str(cfg)],cwd=binary.parent,stdout=out,stderr=subprocess.STDOUT)
    try:
     deadline=time.monotonic()+20
     while p.poll() is None and time.monotonic()<deadline and 'SERVER_CONFIG' not in path.read_text():time.sleep(.05)
     assert 'SERVER_CONFIG' in path.read_text(),path.read_text()[-2500:]
     status=rcon.command('127.0.0.1',28885,password,'status')
     assert status['mode']=='if' and status['rotation']==expected and status['map']==expected[0],status
     for mode in ['ig','if']:
      assert rcon.command('127.0.0.1',28885,password,'mode '+mode)['ok'];time.sleep(.3)
      status=rcon.command('127.0.0.1',28885,password,'status')
      assert status['mode']==mode and status['rotation']==expected,status
     assert 'ERROR:' not in path.read_text(),path.read_text()[-2500:]
     results.append(dict(source='ig_maplist setting' if explicit else 'maps/ig_maplist.txt',passed=True,rotation=expected,mode_switches=['ig','if']))
    finally:
     if p.poll() is None:p.terminate();p.wait(timeout=5)
 report=dict(passed=True,results=results)
 (OUT/'console-config.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));return 0
if __name__=='__main__':raise SystemExit(console_checks(sys.argv[2]) if len(sys.argv)>2 and sys.argv[1]=='--console' else main())
