"""Run an isolated standalone server and real ENet clients on loopback."""
import argparse,json,platform,signal,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--clients',type=int,default=64);p.add_argument('--seconds',type=int,default=30);p.add_argument('--port',type=int,default=17779);p.add_argument('--tracked',action='store_true');p.add_argument('--bots',action='store_true');p.add_argument('--bundle',type=Path);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);bundle=a.bundle.resolve() if a.bundle else ROOT/'native_server/build';world=bundle/'world' if a.bundle else ROOT/'native_server/cooked';binary=bundle/'cq-server';client=ROOT/'native_server/build/cq-load-client'
 config=out/'server.cfg';config.write_text(f'set net_port {a.port}\nset sv_cq_maxclients 64\nset sv_cq_adaptive_tick 1\nset sv_cq_bot_fill {a.clients if a.bots else 0}\n')
 result={'loopback':True,'rendering':False,'tracked':a.tracked,'bot_case':a.bots,'requested_clients':a.clients,'requested_seconds':a.seconds,'platform':platform.platform(),'cpu':next((line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')),'unknown')}
 with (out/'server.log').open('w') as log:
  server=subprocess.Popen([str(binary),'--world',str(world),'--config',str(config),'--state',str(out/'state'),'--report',str(out/'server.json')],stdout=log,stderr=subprocess.STDOUT)
  try:
   deadline=time.monotonic()+90
   while '"event":"ready"' not in (out/'server.log').read_text():
    if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Native server did not start')
    time.sleep(.1)
   if a.bots:time.sleep(a.seconds)
   else:
    command=[str(client),str(world/'world.json'),str(a.port),str(a.clients),str(a.seconds),str(out/'clients.json')]+(['--tracked'] if a.tracked else [])
    with (out/'clients.log').open('w') as client_log:run=subprocess.run(command,stdout=client_log,stderr=subprocess.STDOUT,timeout=a.seconds+20)
    result['client_exit']=run.returncode;result['clients']=json.loads((out/'clients.json').read_text())
  finally:
   if server.poll() is None:server.send_signal(signal.SIGINT)
   try:server.wait(timeout=20)
   except subprocess.TimeoutExpired:server.kill();server.wait()
  result['server_exit']=server.returncode;result['server']=json.loads((out/'server.json').read_text()) if (out/'server.json').exists() else None
 result['passed']=result['server_exit']==0 and bool(result['server']) and result['server']['input_overflow']==0 and result['server']['projectile_full']==0
 if not a.bots:result['passed']=result['passed'] and result['client_exit']==0 and result['clients']['minimum_steady_snapshot_hz']>=18 and result['clients']['maximum_steady_snapshot_gap']<.3
 else:result['passed']=result['passed'] and result['server']['bots']==a.clients and result['server']['shots']>0
 (out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ['clients','server']}),flush=True)
 if not result['passed']:raise SystemExit(1)
if __name__=='__main__':main()
