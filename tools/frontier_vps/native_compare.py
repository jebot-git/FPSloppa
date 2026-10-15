"""Isolated candidate server/fleet comparison; never changes the production service."""
import argparse,json,signal,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary',type=Path,required=True);p.add_argument('--fleet',type=Path,required=True);p.add_argument('--config',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--server-arg',action='append',default=[]);p.add_argument('--client-arg',action='append',default=[]);p.add_argument('--stagger-ms',type=int,default=0)
p.add_argument('--fleet-tail',type=int,default=35);p.add_argument('--seconds',type=int,default=120);p.add_argument('--players',type=int,nargs='+',default=[32,64]);p.add_argument('--port',type=int,default=7779);p.add_argument('--reference',action='store_true')
a=p.parse_args();
if a.fleet_tail<5:p.error("fleet-tail must be at least 5 seconds")
a.binary=a.binary.resolve();a.output.mkdir(parents=True,exist_ok=True)
for count in a.players:
 out=a.output/str(count);out.mkdir(exist_ok=True)
 cfg=out/'server.cfg';cfg.write_text(a.config.read_text()+f'\nset sv_cq_maxclients "{count}"\nset net_ip "127.0.0.1"\nset net_port "{a.port}"\n')
 args=['stdbuf','-oL','-eL',str(a.binary),'--headless','--xr-mode','off','--','--server','--config',str(cfg.resolve()),'--port',str(a.port),'--profile-players',str(count),'--profile-seconds',str(a.seconds),'--stress-test']
 args+=a.server_arg
 if a.reference:args+=['--gdscript-codec','--gdscript-network-packing','--gdscript-backend','--sync-snapshots']
 log=out/'server.log'
 with log.open('w') as f:
  server=subprocess.Popen(args,stdout=f,stderr=subprocess.STDOUT)
  try:
   deadline=time.monotonic()+90
   while 'CQ_FRONTIER_SERVER_READY' not in log.read_text():
    if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Candidate did not start: '+str(log))
    time.sleep(.2)
   print('NATIVE_COMPARE_STARTED',count,flush=True)
   with (out/'fleet.log').open('w') as fleetlog:
    fleet=subprocess.run(['python3',str(a.fleet),'--binary',str(a.binary),'--players',str(count),'--seconds',str(a.seconds+a.fleet_tail),'--port',str(a.port),'--output',str(out/'fleet'),'--stagger-ms',str(a.stagger_ms)]+['--client-arg='+value for value in a.client_arg],stdout=fleetlog,stderr=subprocess.STDOUT,timeout=a.seconds+200)
   report=None
   for line in log.read_text().splitlines():
    if line.startswith('CQ_LIVE_PROFILE_RESULT '):report=json.loads(line.removeprefix('CQ_LIVE_PROFILE_RESULT '))
   if report:(out/'report.json').write_text(json.dumps(report,indent=2))
   print('NATIVE_COMPARE_FINISHED',count,'fleet_exit',fleet.returncode,'profile',bool(report),flush=True)
  finally:
   if server.poll() is None:
    server.send_signal(signal.SIGINT)
    try:server.wait(timeout=20)
    except subprocess.TimeoutExpired:server.terminate();server.wait(timeout=10)
