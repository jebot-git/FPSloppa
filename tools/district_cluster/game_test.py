"""Two real Godot BSP workers, two gateways and durable control over loopback."""
import argparse
import asyncio
import json
import os
from pathlib import Path
import subprocess
import time
from .config import grid,write_private
from .coordinator import Coordinator
from .gateway import Gateway
from .store import SQLiteStore
from .model import initial
from .transport import rpc
from .network_test import eventually

ROOT=Path(__file__).resolve().parents[2]


def decode(snapshot,out,label):
    path=out/(label+'.base64');path.write_text(snapshot['payload'])
    result=subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','tools/district_cluster/decode_snapshot.gd','--',str(path.resolve())],capture_output=True,text=True,check=True,timeout=15)
    return json.loads(next(line.removeprefix('CLUSTER_DECODE ') for line in result.stdout.splitlines() if line.startswith('CLUSTER_DECODE ')))


async def run(binary,out):
    config=grid(4,44000)
    config['districts']['d01']['gateway']='g01'
    config['districts']['d03']['gateway']='g01'
    out.mkdir(parents=True,exist_ok=True)
    store=SQLiteStore(out/'coordinator.sqlite',initial(config['districts']))
    coordinator=Coordinator(config,store)
    server=await coordinator.start(config['coordinators'][0])
    gateways={};servers=[server];processes=[];logs=[]
    try:
        for name in ('g00','g01'):
            gw=Gateway(config,name);gateways[name]=gw;servers.append(await gw.start())
        for i in (0,1):
            district=f'd{i:02}';row=config['districts'][district]
            settings=dict(district=district,map_slot=i,address=config['gateways'][row['gateway']]['address'],token=config['worker_tokens'][district],state_dir=str((out/district).resolve()),spawn=[120 if i==0 else -120,1,0])
            path=out/(district+'.json');write_private(path,settings)
            log=(out/(district+'.log')).open('w');logs.append(log)
            command=[str(binary.resolve()),'--','--asset-root',str(binary.resolve().parent),'--experimental-cq','--cq-district-maps','--cq-worker',str(i),'--cluster-worker',str(path.resolve())]
            processes.append(subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME=str((out/'profile').resolve()))))
        async def status():return await rpc(config['coordinators'][0],dict(op='status',token=config['admin_token']))
        async def ready():
            state=await status();return all(state['districts'][f'd{i:02}']['online'] for i in (0,1))
        await eventually(ready,45)
        source=config['gateways']['g00']['address'];destination=config['gateways']['g01']['address']
        client=await rpc(source,dict(op='join',token=config['client_token'],district='d00',name='Cluster BSP probe'))
        auth=dict(actor=client['identity'],resume=client['resume'])
        await asyncio.sleep(.8)
        for seq in range(1,6):
            assert (await rpc(source,dict(op='input',**auth,generation=1,command=dict(seq=seq,move=[0,0],jump=seq in (2,4)))))['accepted']
            await asyncio.sleep(.08)
        snapshot=await rpc(source,dict(op='snapshot',**auth))
        source_state=await asyncio.to_thread(decode,snapshot,out,'source')
        assert source_state[0]['jetpack']['activation']>0 and source_state[0]['jetpack']['cooldown']>0
        # Freeze transfers the real opaque State.actor blob including jetpack state.
        began=time.monotonic()
        result=await rpc(source,dict(op='transfer',target='d01',**auth))
        pause=time.monotonic()-began
        await rpc(destination,dict(op='resume',**auth))
        await asyncio.sleep(.8)
        new=await rpc(destination,dict(op='snapshot',**auth))
        assert new['district']=='d01' and new['actors'][client['identity']]==2
        assert snapshot['district']=='d00'
        destination_state=await asyncio.to_thread(decode,new,out,'destination')
        assert destination_state[0]['jetpack']['activation']==source_state[0]['jetpack']['activation']
        assert 0<destination_state[0]['jetpack']['cooldown']<=source_state[0]['jetpack']['cooldown']
        assert destination_state[0]['hp']==source_state[0]['hp']
        applied=await rpc(destination,dict(op='input',**auth,generation=2,command=dict(seq=10,move=[0,0],jump=False)))
        assert applied['accepted']
        # Return through the opposite portal, exercising actor ID reuse.
        back=await rpc(destination,dict(op='transfer',target='d00',**auth))
        await rpc(source,dict(op='resume',**auth));await asyncio.sleep(.8)
        assert back['actor']['generation']==3
        await rpc(source,dict(op='input',**auth,generation=3,command=dict(seq=11,move=[0,0])))
        await rpc(source,dict(op='leave',**auth))
        # Public ENet facade uses a separate RPC tree, exercised against real BSP workers.
        edge_config=out/'edge.json'
        write_private(edge_config,dict(backend=source,listen=['127.0.0.1',44110],routes={'127.0.0.1:44010':['127.0.0.1',44110],'127.0.0.1:44011':['127.0.0.1',44111]}))
        edge_log=(out/'edge.log').open('w');logs.append(edge_log)
        processes.append(subprocess.Popen(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','tools/district_cluster/edge_main.gd','--',str(edge_config.resolve())],stdout=edge_log,stderr=subprocess.STDOUT))
        await asyncio.sleep(.8)
        client_config=out/'edge-client.json'
        write_private(client_config,dict(address=['127.0.0.1',44110],token=config['client_token'],district='d00'))
        probe=await asyncio.create_subprocess_exec('godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','tools/district_cluster/edge_client.gd','--',str(client_config.resolve()),stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
        output=await asyncio.wait_for(probe.communicate(),20)
        (out/'edge-client.log').write_bytes(output[0])
        assert probe.returncode==0 and b'CLUSTER_ENET_TEST' in output[0],output[0].decode()
        return dict(scope='Two real Godot workers loading distinct split BSP collision maps, two regional gateways; protocol clients, no desktop rendering.',checks=['BSP_worker_boot','real_input_and_double_jump','cross_gateway_state_handoff','destination_input','return_handoff_same_actor_id','explicit_logout','ENet_join_input_snapshot_logout'],handoff_seconds=pause,source_payload_bytes=len(snapshot['payload']),destination_payload_bytes=len(new['payload']),source_state=source_state,destination_state=destination_state)
    finally:
        for proc in processes:
            if proc.poll() is None:proc.terminate()
        for proc in processes:
            try:proc.wait(timeout=5)
            except subprocess.TimeoutExpired:proc.kill();proc.wait()
        for gw in gateways.values():gw.task.cancel()
        await asyncio.gather(*(g.task for g in gateways.values()),return_exceptions=True)
        for s in servers:s.close();await s.wait_closed()
        for log in logs:log.close()
        await asyncio.sleep(.05);store.db.close()


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--binary',type=Path,default=ROOT/'Builds/ClusterPrototype/FPSloppaServer.x86_64');p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();result=asyncio.run(run(args.binary,args.output));text=json.dumps(result,indent=2)+'\n';(args.output/'result.json').write_text(text);print(text)
