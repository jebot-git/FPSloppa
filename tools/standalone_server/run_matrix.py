"""Fixed-rate standalone CQ benchmark; isolated loopback only, no live-service changes."""
import argparse,json,os,platform,signal,subprocess,time
from pathlib import Path

def resources(pid):
 try:
  stat=Path(f'/proc/{pid}/stat').read_text().split(') ',1)[1].split()
  return {'cpu_seconds':(int(stat[11])+int(stat[12]))/os.sysconf('SC_CLK_TCK'),'rss_mib':int(stat[21])*os.sysconf('SC_PAGE_SIZE')/1048576,'threads':int(stat[17])}
 except FileNotFoundError:return None

def case(a,players,hz,port):
 out=a.output/f'{players}-{hz}';out.mkdir(parents=True,exist_ok=False)
 cfg=out/'server.cfg';cfg.write_text(f'set net_ip 127.0.0.1\nset net_port {port}\nset sv_cq_maxclients 64\nset sv_cq_tick_rate {hz}\nset sv_cq_adaptive_tick {int(a.adaptive)}\nset sv_cq_bot_fill 0\nset sv_cq_destruction {int(a.destruction)}\nset sv_cq_snapshot_delta {int(a.snapshot_mode in ["both","delta"])}\nset sv_cq_snapshot_relevance {int(a.snapshot_mode in ["both","relevance"])}\n')
 command=[str(a.bundle/'cq-server'),'--world',str(a.bundle/'world'),'--config',str(cfg),'--state',str(out/'state'),'--report',str(out/'server.json'),'--benchmark-players',str(players),'--benchmark-seconds',str(a.seconds)]
 samples=[];clients=[];begin=time.monotonic();first=None
 with (out/'server.log').open('w') as slog:
  server=subprocess.Popen(command,stdout=slog,stderr=subprocess.STDOUT)
  try:
   while '"event":"ready"' not in (out/'server.log').read_text():
    if server.poll() is not None or time.monotonic()-begin>120:raise RuntimeError('Server failed to start')
    time.sleep(.1)
   for base in range(0,players,4):
    with (out/f'clients-{base}.log').open('w') as clog:
     clients.append(subprocess.Popen([str(a.bundle/'cq-load-client'),str(a.bundle/'world/world.json'),str(port),'4',str(a.seconds),str(out/f'clients-{base}.json'),'--benchmark',str(a.bundle/'world/benchmark-inputs.bin'),str(base)],stdout=clog,stderr=subprocess.STDOUT))
   while server.poll() is None:
    s=resources(server.pid);c=[resources(p.pid) for p in clients];samples.append({'elapsed':time.monotonic()-begin,'server':s,'clients':c})
    if any(p.poll() is not None and p.returncode for p in clients):raise RuntimeError('Client failed; inspect clients logs')
    if time.monotonic()-begin>a.seconds+200:raise RuntimeError('Benchmark timed out')
    time.sleep(.5)
   for p in clients:p.wait(timeout=15)
  finally:
   for p in clients+[server]:
    if p and p.poll() is None:p.send_signal(signal.SIGINT)
   for p in clients+[server]:
    if p:
     try:p.wait(timeout=15)
     except subprocess.TimeoutExpired:p.kill();p.wait()
 server_data=json.loads((out/'server.json').read_text());rows=[json.loads((out/f'clients-{base}.json').read_text()) for base in range(0,players,4)];client_data={k:sum(r[k] for r in rows) for k in ['welcomed','active','frames','inputs','validated_frames','rejects','disconnects']};client_data['minimum_steady_snapshot_hz']=min(r['minimum_steady_snapshot_hz'] for r in rows);client_data['maximum_steady_snapshot_gap']=max(r['maximum_steady_snapshot_gap'] for r in rows);client_data['peers']=[p for r in rows for p in r['peers']];(out/'clients.json').write_text(json.dumps(client_data,indent=2)+'\n');b=server_data['benchmark'];baseline=b['baseline']
 steady=[s for s in samples if s['elapsed']>=samples[-1]['elapsed']-a.seconds and s['server']]
 cpu=(steady[-1]['server']['cpu_seconds']-steady[0]['server']['cpu_seconds'])/(steady[-1]['elapsed']-steady[0]['elapsed'])*100 if len(steady)>1 else 0
 resource={'peak_rss_mib':max(s['server']['rss_mib'] for s in samples if s['server']),'mean_cpu_one_core_percent':cpu,'samples':samples}
 checks={'server_exit':server.returncode==0,'client_exit':all(p.returncode==0 for p in clients),'admitted':b['peak_players']==players and client_data['welcomed']==players,'tick_rate':abs(b['hz']-hz)<hz*.01,'snapshots':client_data['minimum_steady_snapshot_hz']>=18 and client_data['maximum_steady_snapshot_gap']<.3,'no_rejections':server_data['core_rejected']-baseline['core_rejected']==0 and client_data['rejects']==0,'no_overflow':server_data['input_overflow']==0 and server_data['projectile_full']==0,'no_disconnect':b['disconnected']==0 and client_data['disconnects']==0,'four_classes_firing':all(x>0 for x in b['shots_by_class'])}
 result={'players':players,'configured_hz':hz,'passed':all(checks.values()),'checks':checks,'actual_hz':b['hz'],'callback_us':b['callback_us'],'shots_by_class':b['shots_by_class'],'accepted_inputs':server_data['accepted_inputs']-baseline['accepted_inputs'],'resource':{k:v for k,v in resource.items() if k!='samples'}}
 (out/'resources.json').write_text(json.dumps(resource,indent=2)+'\n');(out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True);return result

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--seconds',type=int,default=120);p.add_argument('--port',type=int,default=27969);p.add_argument('--adaptive',action='store_true');p.add_argument('--destruction',action='store_true');p.add_argument('--snapshot-mode',choices=['full','relevance','delta','both'],default='both');p.add_argument('--cases',default='64:30,64:60,128:30,128:60');a=p.parse_args();a.bundle=a.bundle.resolve();a.output=a.output.resolve();a.output.mkdir(parents=True,exist_ok=False)
 metadata={'platform':platform.platform(),'cpu':next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'logical_cpus':os.cpu_count(),'date_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'seconds':a.seconds,'warmup_seconds':8,'loopback':True,'rendering':False,'stress':False,'destruction':a.destruction,'adaptive':a.adaptive,'tracked':True,'snapshot_mode':a.snapshot_mode,'client_group_size':4}
 (a.output/'machine.json').write_text(json.dumps(metadata,indent=2)+'\n');results=[]
 for i,c in enumerate(a.cases.split(',')):
  players,hz=map(int,c.split(':'));results.append(case(a,players,hz,a.port+i))
 (a.output/'matrix.json').write_text(json.dumps(results,indent=2)+'\n')
 if not all(c['passed'] for c in results):raise SystemExit(1)
if __name__=='__main__':main()
