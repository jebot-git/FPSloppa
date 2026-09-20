"""Real ENet waiting-room/deployment test with three independently launched workers.

Only the fixture master adds logical capacity residents; these are not simulated bots.
"""
import argparse, json, secrets, subprocess, time
from pathlib import Path
from external_config import create
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--binary',type=Path,default=ROOT/'Builds/CQCapacity/FPSloppaServer.x86_64');args=p.parse_args()
out=ROOT/'test-results/cq-gateway/waiting-room';out.mkdir(parents=True,exist_ok=True)
children=[];handles=[];report={}
def spawn(label,argv):
    f=(out/(label+'.log')).open('w');handles.append(f)
    proc=subprocess.Popen(argv,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT);children.append(proc);return proc
def wait(predicate,seconds=60):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if predicate():return
        time.sleep(.1)
    raise RuntimeError('Fixture timed out')
def godot(script):return ['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tools/cq_gateway/'+script+'.gd','--','--experimental-cq']
try:
    inventory=create(out/('private-'+secrets.token_hex(4)),[0,1,15],29483,{z:29483 for z in [0,1,15]})
    config=out/'server.cfg'
    config.write_text('set sv_gametype cq\nset sv_gametypes cq\nset sv_cq_backend districts\nset sv_cq_worker_limit 3\nset sv_cq_maxclients 64\nset sv_cq_bot_fill 0\nset sv_voice 0\nset sv_lobby 0\nset sv_votes 0\nset net_ip 127.0.0.1\nset net_port 29482\n')
    master=spawn('master',godot('waiting_master')+['--server','--config',str(config),'--cq-external-workers',str(inventory)])
    wait(lambda:'SERVER_CONFIG' in (out/'master.log').read_text())
    for z in [0,1,15]:spawn('worker-'+str(z),[str(args.binary.resolve()),'--','--experimental-cq','--cq-worker',str(z),'--worker-session-file',str(inventory.parent/f'worker-{z}.json')])
    wait(lambda:(out/'master.log').read_text().count('CQ_WORKER_READY')==3)
    client=spawn('client',godot('waiting_client')+['--test-port','29482'])
    wait(lambda:client.poll() is not None,90)
    assert client.returncode==0,(out/'client.log').read_text()[-5000:]
    for label,prefix in [('master','CQ_WAITING_MASTER '),('client','CQ_WAITING_CLIENT ')]:
        text=(out/(label+'.log')).read_text()
        assert 'SCRIPT ERROR' not in text,text[-5000:]
        report[label]=json.loads(next(line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)))
        assert not report[label]['failures'],report
    report['ok']=True
    print('CQ_WAITING_NETWORK',json.dumps(report))
finally:
    for proc in children:
        if proc.poll() is None:
            proc.terminate()
            try:proc.wait(timeout=5)
            except subprocess.TimeoutExpired:proc.kill();proc.wait()
    for handle in handles:handle.close()
    (out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
