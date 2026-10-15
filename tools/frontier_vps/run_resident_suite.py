#!/usr/bin/env python3
"""Isolated native-authority loopback tests; optionally suspend a same-user CQ service.

The detached guardian always resumes the original PID identity. No service files,
ports, release symlinks or production defaults are changed.
"""
import argparse,hashlib,json,os,signal,subprocess,time
from pathlib import Path

def identity(pid):
 try:
  row=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split();return row[19],row[0]
 except FileNotFoundError:return None

def stop(job):
 if job.poll() is not None:return
 os.killpg(job.pid,signal.SIGTERM)
 try:job.wait(timeout=5)
 except subprocess.TimeoutExpired:os.killpg(job.pid,signal.SIGKILL);job.wait()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--seconds',type=int,default=120);p.add_argument('--suspend-service');a=p.parse_args()
 bundle=a.bundle.resolve();out=a.output.resolve()
 if out.exists():p.error('Output must be new')
 out.mkdir(parents=True)
 manifest=json.loads((bundle/'release-sha256.json').read_text())
 for name,sha in manifest.items():
  path=(bundle/name).resolve()
  if not path.is_relative_to(bundle) or hashlib.sha256(path.read_bytes()).hexdigest()!=sha:raise RuntimeError('Bundle mismatch: '+name)
 pid=0;original=None
 if a.suspend_service:
  fields=dict(row.split('=',1) for row in subprocess.check_output(['systemctl','show',a.suspend_service,'-p','MainPID','-p','WatchdogUSec'],text=True).splitlines());pid=int(fields['MainPID'])
  if not pid or fields['WatchdogUSec']!='0' or Path(f'/proc/{pid}').stat().st_uid!=os.getuid() or b'--server' not in Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0'):raise RuntimeError('Unsafe service suspension')
  original=identity(pid)
  if not original or original[1] in ['T','t']:raise RuntimeError('Service must be running')
 def resume():
  now=identity(pid) if pid else None
  if now and now[0]==original[0]:os.kill(pid,signal.SIGCONT);return True
  return False
 parent=os.getpid();parent_identity=identity(parent);deadline=time.monotonic()+1800
 if pid and os.fork()==0:
  os.setsid()
  while time.monotonic()<deadline:
   now=identity(parent)
   if not now or now[0]!=parent_identity[0] or now[1]=='Z':break
   time.sleep(2)
  (out/'guardian.json').write_text(json.dumps({'resumed':resume()}));os._exit(0)
 def interrupted(signum,frame):raise RuntimeError('Interrupted '+str(signum))
 for sig in [signal.SIGINT,signal.SIGTERM,signal.SIGHUP,signal.SIGALRM]:signal.signal(sig,interrupted)
 signal.alarm(1700);status={'pid':pid,'identity':original,'passed':False};results=[];jobs=[]
 base=[str(bundle/'cq-server'),'--headless','--xr-mode','off','--','--resident-suite']
 try:
  if pid:os.kill(pid,signal.SIGSTOP)
  for stress in [False,True]:
   for count in [32,64]:
    case=out/f'{count}-{"stress" if stress else "normal"}'
    case.mkdir();report=case/'server.json';common=['--players',str(count),'--seconds',str(a.seconds),'--port','27939','--cq-core','--tracked','--jungle-map']+(['--stress-test'] if stress else [])
    handles=[];groups=[]
    try:
     log=(case/'server.log').open('w');handles.append(log);server=subprocess.Popen(base+common+['--role','server','--report',str(report)],stdout=log,stderr=subprocess.STDOUT,start_new_session=True);jobs.append(server);time.sleep(1)
     for first in range(0,count,4):
      log=(case/f'clients-{first}.log').open('w');handles.append(log);client=subprocess.Popen(base+common+['--role','clients','--client-count',str(min(4,count-first))],stdout=log,stderr=subprocess.STDOUT,start_new_session=True);groups.append(client);jobs.append(client)
     for job in groups+[server]:
      if job.wait(timeout=a.seconds+90):raise RuntimeError('Fixture process failed')
    finally:
     for job in jobs:stop(job)
     jobs.clear()
     for handle in handles:handle.close()
    logs=[file.read_text() for file in case.glob('*.log')]
    if any('ERROR:' in log or 'WARNING:' in log for log in logs):raise RuntimeError('Fixture diagnostics')
    clients=[json.loads(line.split(' ',1)[1]) for log in logs for line in log.splitlines() if line.startswith('AUTHORITY_CLIENTS ')]
    row=json.loads(report.read_text());row['clients']=clients;row['stress']=stress
    if len(clients)!=count//4 or row['hz']<29.5 or row['disconnected'] or row['native']['overflow'] or row['native']['projectile_full']:raise RuntimeError('Server capacity/transport gate')
    for client in clients:
     if client['bad_frames'] or client['disconnected'] or client['minimum_frames']<a.seconds*15 or client['minimum_inputs_sent']<a.seconds*29:raise RuntimeError('Client delivery gate')
    offered=sum(client['total_inputs_sent'] for client in clients);row['accepted_fraction']=row['native']['accepted']/offered
    if row['accepted_fraction']<.9:raise RuntimeError('Input delivery gate')
    results.append(row);(out/'results.json').write_text(json.dumps(results,indent=2));print(json.dumps({'case':case.name,'hz':row['hz'],'accepted_fraction':row['accepted_fraction']}),flush=True)
  status['passed']=True
 finally:
  for job in jobs:stop(job)
  status['resumed_original_process']=resume() if pid else False;status['finished_epoch']=time.time();(out/'status.json').write_text(json.dumps(status,indent=2));signal.alarm(0);print(json.dumps(status),flush=True)
if __name__=='__main__':main()
