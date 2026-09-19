"""Real ENet CQ isolation, admission and capacity checks against the source server."""
import json, os, shutil, subprocess, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/conquest';OUT.mkdir(parents=True,exist_ok=True)
engine=os.environ.get('GODOT_BIN',shutil.which('godot'))
processes=[];handles=[];results={}
def start(name,args):
    log=OUT/(name+'.log');handle=log.open('w');handles.append(handle)
    p=subprocess.Popen([engine,'--headless','--xr-mode','off','--path',str(ROOT),'--log-file',str(OUT/(name+'-engine.log')),*args],stdout=handle,stderr=subprocess.STDOUT)
    processes.append(p);return p,log
def marker(p,log,word,seconds=30):
    end=time.monotonic()+seconds
    while time.monotonic()<end and p.poll() is None:
        if word in log.read_text():return
        time.sleep(.1)
    raise RuntimeError(f'{word} missing: {log.read_text()[-3000:]}')
def client(name,profile,expect,port=28987,hold=None,roster=0):
    args=['--script','res://deathmatch/tests/conquest_client.gd','--','--expect',expect,'--test-port',str(port)]
    if roster:args += ["--roster-size",str(roster)]
    if profile:args+=['--experimental-cq']
    if hold:args+=['--hold-file',str(hold)]
    return start(name,args)
try:
    with tempfile.TemporaryDirectory(prefix='cq-test-') as temp:
        folder=Path(temp);config=folder/'cq.cfg'
        config.write_text('set sv_gametype cq\nset sv_gametypes cq\nset sv_maxclients 1\nset sv_cq_maxclients 2\nset sv_cq_bot_fill 2\nset sv_lobby 0\nset sv_voice 0\nset sv_votes 0\nset net_ip 127.0.0.1\nset net_port 28987\n')
        server,log=start('server',['--','--experimental-cq','--server','--config',str(config)])
        marker(server,log,'SERVER_CONFIG');results['own_capacity']='maxclients=2' in log.read_text()
        rejected,rlog=client('ordinary_rejected',False,'profile');results['ordinary_rejected']=rejected.wait(timeout=40)==0
        release=folder/'release'
        a,alog=client('cq_first',True,'accepted',hold=release);marker(a,alog,'CQ_CLIENT_READY true')
        b,blog=client('cq_second',True,'accepted',hold=release);marker(b,blog,'CQ_CLIENT_READY true')
        extra,elog=client('cq_full',True,'full');results['full_rejected']=extra.wait(timeout=40)==0
        release.touch();results['first_accepted']=a.wait(timeout=10)==0;results['second_accepted']=b.wait(timeout=10)==0
        normal=folder/'normal.cfg';normal.write_text('set sv_maxclients 1\nset sv_cq_maxclients 64\nset sv_voice 0\nset net_ip 127.0.0.1\nset net_port 28988\n')
        ordinary,olog=start('normal_server',['--','--server','--config',str(normal)]);marker(ordinary,olog,'SERVER_CONFIG')
        results['normal_capacity_unchanged']='maxclients=1' in olog.read_text()
        reverse,revlog=client('cq_cannot_join_normal',True,'profile',28988);results['cq_cannot_join_normal']=reverse.wait(timeout=40)==0
        invalid,ilog=start('cq_without_launcher',['--','--server','--config',str(config)])
        results['server_requires_launcher']=invalid.wait(timeout=30)==2 and 'separate launch' in ilog.read_text()
        full_config=folder/'cq64.cfg'
        full_config.write_text(config.read_text().replace('sv_cq_maxclients 2','sv_cq_maxclients 64').replace('sv_cq_bot_fill 2','sv_cq_bot_fill 64').replace('28987','28989'))
        full_server,full_log=start('cq64_server',['--','--experimental-cq','--server','--config',str(full_config)])
        marker(full_server,full_log,'SERVER_CONFIG',60)
        full_client,full_client_log=client('cq64_client',True,'accepted',28989,roster=64)
        results['64_actor_real_client_admission']=full_client.wait(timeout=45)==0
        results['no_script_errors']=all('SCRIPT ERROR' not in p.read_text() for p in OUT.glob('*.log'))
        (OUT/'network.json').write_text(json.dumps(results,indent=2))
        print('CQ_NETWORK_RESULT',json.dumps(results));assert all(results.values()),results
finally:
    for p in processes:
        if p.poll() is None:
            p.terminate()
            try:p.wait(timeout=5)
            except subprocess.TimeoutExpired:p.kill();p.wait()
    for h in handles:h.close()
