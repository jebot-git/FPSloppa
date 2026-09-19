"""Two real CQ ENet clients, district prediction/handoff, isolation and round reset."""
import argparse,json,os,subprocess,sys,time,secrets
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from rcon import command
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--server-binary',type=Path,default=ROOT/'Builds/CQGatewayServer/FPSloppaServer.x86_64');p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=28987);p.add_argument('--remote',action='store_true');p.add_argument('--config',type=Path);p.add_argument('--rcon-port',type=int,default=28988);p.add_argument('--name',default='local');p.add_argument('--clients',type=int,default=2);p.add_argument('--worker-limit',type=int,default=4);p.add_argument('--pool-route',action='store_true');args=p.parse_args()
out=ROOT/'test-results/cq-gateway'/args.name;out.mkdir(parents=True,exist_ok=True)
children=[];handles=[];report={}
def spawn(label,argv):
    f=(out/(label+'.log')).open('w');handles.append(f)
    proc=subprocess.Popen(argv,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT);children.append(proc);return proc
if args.config:
    config=args.config
    import re
    password=re.search(r'^set rcon_password "([^"\n]+)"$',config.read_text(),re.M)[1]
else:
    password=secrets.token_hex(24);config=out/'server.cfg'
    config.write_text(f'set sv_hostname "CQ gateway test"\nset sv_gametype cq\nset sv_gametypes cq\nset sv_cq_backend districts\nset sv_cq_worker_limit {args.worker_limit}\nset sv_cq_maxclients 64\nset sv_cq_bot_fill 0\nset sv_voice 0\nset sv_lobby 0\nset sv_votes 0\nset net_ip 127.0.0.1\nset net_port {args.port}\nset rcon_port {args.rcon_port}\nset rcon_password "{password}"\n')
    config.chmod(0o600)
def control(text):return command('127.0.0.1',args.rcon_port,password,text)
try:
    if not args.remote:
        spawn('server',[str(args.server_binary.resolve()),'--log-file',str(out/'server-engine.log'),'--','--experimental-cq','--config',str(config),'--quit-after-seconds','180'])
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            if 'SERVER_CONFIG' in (out/'server.log').read_text():break
            time.sleep(.1)
        else:raise RuntimeError('Local server failed to start')
    for index in range(args.clients):
        spawn(f'client-{index}',['godot','--headless','--xr-mode','off','--path',str(ROOT),'--log-file',str(out/f'client-{index}-engine.log'),'--script','res://tools/cq_gateway/client.gd','--','--experimental-cq','--host',args.host,'--test-port',str(args.port),'--hold-seconds','20',*(['--pool-route'] if args.pool_route else [])])
        time.sleep(.3)
    deadline=time.monotonic()+100
    while time.monotonic()<deadline:
        if all('CQ_ROUTE ' in (out/f'client-{i}.log').read_text() for i in range(args.clients)):break
        time.sleep(.2)
    else:raise RuntimeError('Clients did not finish physical route')
    status=control('status');report['before_restart']=status['cq_backend'];report['capacity']=status['capacity']
    assert status['cq_backend']['stats']['transfers']>=args.clients*(4 if args.pool_route else 2),status
    assert status['cq_backend']['workers']<=args.worker_limit,status
    assert status['cq_backend']['stats']['stale_inputs']>=args.clients,status
    assert len(status['cq_backend']['actors'])==args.clients,status
    report['restart']=control('restart');time.sleep(3)
    report['after_restart']=control('status')['cq_backend']
    assert report['after_restart']['epoch']==report['before_restart']['epoch']+1,report
    assert all(a['phase']=='active' for a in report['after_restart']['actors']),report
    client_procs=children[-args.clients:]
    for proc in client_procs:assert proc.wait(timeout=30)==0,'Client failed'
    report['clients']=[]
    for i in range(args.clients):
        text=(out/f'client-{i}.log').read_text()
        assert 'SCRIPT ERROR' not in text and 'body_test_motion' not in text,text[-2000:]
        result=json.loads(next(x.removeprefix('CQ_GATEWAY_CLIENT ') for x in text.splitlines() if x.startswith('CQ_GATEWAY_CLIENT ')))
        route=json.loads(next(x.removeprefix('CQ_ROUTE ') for x in text.splitlines() if x.startswith('CQ_ROUTE ')))
        assert result['handoffs']>=4 and not result['failures'],result
        assert route['roster']==args.clients and len(route['visible'])<route['roster'] if args.clients>1 else True,route
        report['clients'].append({'result':result,'route':route})
    report['ok']=True
    print('CQ_GATEWAY_NETWORK',json.dumps(report))
finally:
    for proc in children:
        if proc.poll() is None:
            proc.terminate()
            try:proc.wait(timeout=5)
            except subprocess.TimeoutExpired:proc.kill();proc.wait()
    for h in handles:h.close()
    (out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
