"""Drive the CQ soundscape from real ENet/BSP worker events and record the mix."""
import argparse,asyncio,json,subprocess,sys
from pathlib import Path
from . import config
from .transport import rpc
from .network_test import eventually
ROOT=Path(__file__).resolve().parents[2]
async def run(out):
    out=out.resolve();out.mkdir(parents=True,exist_ok=True)
    settings=config.campaign(49900);config.write_private(out/'cluster.json',settings)
    binary=ROOT/'Builds/CQLive/FPSloppaServer.x86_64';procs=[];logs=[]
    try:
        for role in ('master','workers'):
            cfg=out/(role+'.cfg');cfg.write_text(f'[cq]\nrole = {role}\nstate = {out/role}\ncluster = {out/"cluster.json"}\nbinary = {binary}\n'+('districts = d40 d41 d42 d43\n' if role=='workers' else 'index = 0\n'))
            log=(out/(role+'.log')).open('w');logs.append(log)
            procs.append(subprocess.Popen([sys.executable,'-m','tools.district_cluster.service',str(cfg)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT))
            if role=='master':
                async def master_ready():
                    try:
                        await rpc(settings['coordinators'][0],dict(op='status',token=settings['admin_token']));return True
                    except (OSError,ValueError):return False
                await eventually(master_ready,15)
        async def ready():
            try:
                state=await rpc(settings['coordinators'][0],dict(op='status',token=settings['admin_token']))
                return all(state['districts'][f'd{i}']['online'] for i in range(40,44))
            except (OSError,ValueError):return False
        await eventually(ready,50)
        config.write_private(out/'client.json',dict(address=['127.0.0.1',50020],district='d41',team=0,token=settings['client_token'],campaign_id=settings['campaign_id'],
            identity_file=str(out/'identity.json'),smoke_output=str(out/'unused.png'),audio_recording=str(out/'combat-transition.wav'),music_volume=.8,ambience_volume=.7))
        client=await asyncio.create_subprocess_exec('godot','--path',str(ROOT),'--xr-mode','off','--rendering-method','mobile','--rendering-driver','vulkan','--script','tools/district_cluster/audio_live_client.gd','--',str(out/'client.json'),stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
        try:result=await asyncio.wait_for(client.communicate(),50)
        except BaseException:client.kill();await client.wait();raise
        output=result[0].decode();(out/'client.log').write_text(output)
        assert client.returncode==0 and 'CQ_LIVE_AUDIO ' in output,output
        receipt=json.loads(next(l.split('CQ_LIVE_AUDIO ',1)[1] for l in output.splitlines() if 'CQ_LIVE_AUDIO ' in l))
        (out/'result.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
    finally:
        for p in reversed(procs):
            if p.poll() is None:p.terminate()
        for p in reversed(procs):
            try:p.wait(timeout=10)
            except subprocess.TimeoutExpired:p.kill();p.wait()
        for log in logs:log.close()
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();asyncio.run(run(args.output))
