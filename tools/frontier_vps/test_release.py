"""Verify shipped Linux/Windows clients against a private destruction/adaptive server.

Windows execution uses Wine, not a native Windows GPU/XR validation.
"""
import argparse,json,os,signal,subprocess,time
from pathlib import Path
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--config',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--port',type=int,default=28818);p.add_argument('--wine',action='store_true');a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);build=a.bundle.resolve()
 (out/'server.cfg').write_text(a.config.read_text().replace('28817',str(a.port)))
 env=os.environ.copy();env['XDG_DATA_HOME']=str(out/'data');env['XDG_CACHE_HOME']=str(out/'cache')
 # Admission uses a headless arena and never loads the VR hand/menu graph.
 # Compile that graph explicitly so missing class registrations fail the build.
 for platform in ['Linux']+(['Windows'] if a.wine else []):
  probe_env=env.copy();command=[str(build/'Linux/FPSloppaCQ.x86_64')]
  if platform=='Windows':
   command=['wine',str(build/'Windows/FPSloppaCQ.exe')];probe_env['WINEPREFIX']=str(out/'wine');probe_env['WINEDEBUG']='-all'
  probe=subprocess.run(command+['--headless','--xr-mode','off','--','--release-resource-check'],env=probe_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
  (out/(platform.lower()+'-resources.log')).write_text(probe.stdout)
  assert probe.returncode==0 and 'RELEASE_RESOURCES PASS' in probe.stdout and 'SCRIPT ERROR' not in probe.stdout,platform+' VR resource validation failed'
 with (out/'server.log').open('w') as log:server=subprocess.Popen(['stdbuf','-oL','-eL',str(build/'Server/cq-server'),'--headless','--xr-mode','off','--','--server','--config',str(out/'server.cfg'),'--cq-destruction'],stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
 cases=[]
 try:
  deadline=time.monotonic()+150
  while 'CQ_RESIDENT_READY' not in (out/'server.log').read_text():
   if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Packaged server startup failed')
   time.sleep(.1)
  for name,tracked in [('linux-desktop',False),('linux-tracked',True)]+([('windows-wine',False)] if a.wine else []):
   command=[str(build/'Linux/FPSloppaCQ.x86_64')];client_env=env.copy()
   if name=='windows-wine':
    command=['wine',str(build/'Windows/FPSloppaCQ.exe')];client_env['WINEPREFIX']=str(out/'wine');client_env['WINEDEBUG']='-all'
   report=str(out/(name+'.json'));report='Z:'+report.replace('/','\\') if name=='windows-wine' else report
   command+=['--headless','--xr-mode','off','--','--authority-arena-client','--connect','127.0.0.1','--port',str(a.port),'--authority-client-report',report]
   if tracked:command+=['--authority-tracked']
   with (out/(name+'.log')).open('w') as log:result=subprocess.run(command,env=client_env,stdout=log,stderr=subprocess.STDOUT,timeout=150)
   row={'name':name,'exit':result.returncode,'report':json.loads((out/(name+'.json')).read_text()) if (out/(name+'.json')).exists() else None};cases.append(row);print(json.dumps(row),flush=True)
 finally:
  if server.poll() is None:
   os.killpg(server.pid,signal.SIGINT)
   try:server.wait(timeout=10)
   except subprocess.TimeoutExpired:os.killpg(server.pid,signal.SIGTERM);server.wait(timeout=10)
  (out/'summary.json').write_text(json.dumps(cases,indent=2)+'\n')
 if not cases or any(row['exit'] or not row['report'] or row['report']['failures'] for row in cases):raise SystemExit(1)
if __name__=='__main__':main()
