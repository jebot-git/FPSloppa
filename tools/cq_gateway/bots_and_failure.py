"""Exercise populated workers and real worker loss through the packaged gateway."""
import json,os,re,secrets,signal,subprocess,sys,time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from rcon import command
ROOT=Path(__file__).resolve().parents[2];out=ROOT/'test-results/cq-gateway/bots-failure';out.mkdir(parents=True,exist_ok=True)
password=secrets.token_hex(24);config=out/'server.cfg'
config.write_text(f'set sv_gametype cq\nset sv_gametypes cq\nset sv_cq_backend districts\nset sv_cq_worker_limit 8\nset sv_cq_maxclients 8\nset sv_cq_bot_fill 8\nset sv_voice 0\nset sv_lobby 0\nset sv_votes 0\nset net_ip 127.0.0.1\nset net_port 28991\nset rcon_port 28992\nset rcon_password "{password}"\n');config.chmod(0o600)
report={}
def status():return command('127.0.0.1',28992,password,'status')
def position(row):return tuple(float(n) for n in re.findall(r'-?\d+(?:\.\d+)?',row['position']))
with (out/'server.log').open('w') as log:
    proc=subprocess.Popen([str(ROOT/'Builds/CQGatewayFinal/FPSloppaServer.x86_64'),'--log-file',str(out/'engine.log'),'--','--experimental-cq','--config',str(config),'--quit-after-seconds','120'],stdout=log,stderr=subprocess.STDOUT,cwd=ROOT)
    try:
        deadline=time.monotonic()+40
        while time.monotonic()<deadline:
            if proc.poll() is not None:raise RuntimeError('Gateway exited during startup')
            try:
                first=status()['cq_backend']
                if len(first['actors'])==8 and all(a['phase']=='active' for a in first['actors']):break
            except (OSError,ValueError):pass
            time.sleep(.5)
        else:raise RuntimeError('Eight bots did not become active')
        initial={row['id']:position(row) for row in first['actors']}
        time.sleep(35)
        last=status()['cq_backend'];assert len(last['actors'])==8,last
        moved=sum(sum((a-b)**2 for a,b in zip(position(row),initial[row['id']]))>1 for row in last['actors'])
        assert moved==8,(moved,last)
        assert 'SCRIPT ERROR' not in (out/'server.log').read_text()
        report.update(population=8,moved=moved,seconds=35,workers=last['workers'],transfers=last['stats']['transfers'])
        zone=last['actors'][0]['zone'];pid=int(last['worker_pids'][str(zone)])
        os.kill(pid,signal.SIGKILL)
        report['worker_loss_exit_code']=proc.wait(timeout=10)
        assert report['worker_loss_exit_code']==3,report
        assert 'CQ_GATEWAY_FAILURE' in (out/'server.log').read_text()
        report['ok']=True;print('CQ_BOTS_AND_FAILURE',json.dumps(report))
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:proc.wait(timeout=5)
            except subprocess.TimeoutExpired:proc.kill();proc.wait()
        (out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
