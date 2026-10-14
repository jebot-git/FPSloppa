"""Run one headless ENet client per OS process to avoid multiplexed receive starvation."""
import argparse,json,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--players',type=int,required=True);p.add_argument('--port',type=int,default=7777);p.add_argument('--address',default='127.0.0.1');p.add_argument("--client-arg",action="append",default=[]);p.add_argument("--stagger-ms",type=int,default=0);p.add_argument('--seconds',type=int,default=155);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
args.output.mkdir(parents=True,exist_ok=True);jobs=[];started=time.monotonic()
for i in range(args.players):
 log=(args.output/f'client-{i:02d}.log').open('w')
 proc=subprocess.Popen([args.binary,'--headless','--xr-mode','off','--','--clients','--players','1','--seconds',str(args.seconds),'--address',args.address,'--port',str(args.port),'--client-label',str(i)]+args.client_arg,stdout=log,stderr=subprocess.STDOUT)
 jobs.append((proc,log))
 if args.stagger_ms:time.sleep(args.stagger_ms/1000)
try:
 codes=[proc.wait(timeout=args.seconds+110) for proc,_ in jobs]
finally:
 for proc,log in jobs:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=15)
  log.close()
reports=[]
for log in sorted(args.output.glob('client-*.log')):
 for line in log.read_text().splitlines():
  if line.startswith('LOAD_CLIENTS_RESULT '):reports.append(json.loads(line.removeprefix('LOAD_CLIENTS_RESULT ')))
result={'players':args.players,'processes':len(jobs),'successful_clients':sum(code==0 for code in codes),'exit_codes':codes,'wall_seconds':time.monotonic()-started,'clients':reports}
(args.output/'fleet.json').write_text(json.dumps(result,indent=2));print('CQ_CLIENT_FLEET_RESULT',json.dumps(result));raise SystemExit(0 if all(code==0 for code in codes) else 1)
