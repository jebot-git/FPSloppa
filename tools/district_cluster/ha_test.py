"""Local three-member etcd quorum and two stateless coordinator frontends."""
import argparse
import asyncio
import json
import secrets
import subprocess
import time
from pathlib import Path
from .config import grid
from .coordinator import Coordinator
from .store import EtcdStore
from .model import initial
from .transport import rpc
from unittest.mock import patch
from . import campaign
from .world import atlas


async def run(binary,out):
    out.mkdir(parents=True,exist_ok=True)
    processes=[];logs=[];servers=[]
    endpoints=[f'http://127.0.0.1:{45100+i*2}' for i in range(3)]
    peers=[f'http://127.0.0.1:{45101+i*2}' for i in range(3)]
    cluster=','.join(f'n{i}={peers[i]}' for i in range(3))
    token=secrets.token_hex(16)
    try:
        for i in range(3):
            log=(out/f'etcd-{i}.log').open('w');logs.append(log)
            args=[str(binary),'--name',f'n{i}','--data-dir',str(out/f'data-{i}'),'--listen-client-urls',endpoints[i],'--advertise-client-urls',endpoints[i],'--listen-peer-urls',peers[i],'--initial-advertise-peer-urls',peers[i],'--initial-cluster',cluster,'--initial-cluster-token',token,'--log-level','error']
            processes.append(subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT))
        config=grid(4,45200);config['coordinators'].append(['127.0.0.1',45201])
        state=initial(config['districts'])
        stores=[EtcdStore(endpoints,'/test/'+token,state) for _ in range(2)]
        deadline=time.monotonic()+15
        while True:
            try:await asyncio.to_thread(stores[0].execute,{'op':'status'},None);break
            except (OSError,ValueError):
                if time.monotonic()>deadline:raise
                await asyncio.sleep(.2)
        for i in range(2):servers.append(await Coordinator(config,stores[i]).start(config['coordinators'][i]))
        async def call(index,op,**fields):return await rpc(config['coordinators'][index],dict(op=op,token=config['gateways']['g00']['token'],session='gateway',**fields))
        await call(0,'register_gateway')
        await call(1,'heartbeat',workers={d:'worker'+d for d in config['districts']})
        # Concurrent compare-and-swap writers must agree on exactly sixteen slots.
        results=await asyncio.gather(*(call(i%2,'join',actor=f'a{i}',resume=f's{i}',district='d00',name='HA') for i in range(24)))
        assert sum(r['phase']=='active' for r in results)==16
        assert sum(r['phase']=='waiting' for r in results)==8
        left=await call(0,'status');right=await call(1,'status')
        assert left==right
        # Campaign clock shares the same CAS: concurrent frontends crossing UTC
        # midnight must publish one result and one reset, never duplicate points.
        campaign_state=initial(atlas());campaign.advance(campaign_state,86390)
        campaign_state['campaign']['scores']=[18,8]
        campaign_stores=[EtcdStore(endpoints,'/test/'+token+'/campaign',campaign_state) for _ in range(2)]
        with patch('tools.district_cluster.store.time.time',return_value=86400):
            awards=await asyncio.gather(*(asyncio.to_thread(campaign_stores[i%2].execute,{'op':'status'},None) for i in range(16)))
        assert all(a['campaign']['epoch']==2 and len(a['campaign']['history'])==1 and a['campaign']['history'][0]['scores']==[20,10] for a in awards)
        status=await asyncio.to_thread(stores[0].post,'/v3/maintenance/status',{})
        leader=status['leader'];leader_index=None
        for i,endpoint in enumerate(endpoints):
            store=EtcdStore([endpoint],'/unused',state)
            info=await asyncio.to_thread(store.post,'/v3/maintenance/status',{})
            if info['header']['member_id']==leader:leader_index=i
        assert leader_index is not None
        processes[leader_index].terminate();processes[leader_index].wait(timeout=5)
        servers[0].close();await servers[0].wait_closed()
        deadline=time.monotonic()+10
        while True:
            try:
                restored=await call(1,'status')
                assert len(restored['actors'])==24
                await call(1,'heartbeat',workers={d:'worker'+d for d in config['districts']})
                break
            except (OSError,ValueError):
                if time.monotonic()>deadline:raise
                await asyncio.sleep(.2)
        # Lose quorum: no mutation may succeed through the surviving frontend.
        with patch('tools.district_cluster.store.time.time',return_value=86400):
            recovered_campaign=await asyncio.to_thread(campaign_stores[1].execute,{'op':'status'},None)
        assert recovered_campaign['campaign']['history']==awards[0]['campaign']['history']
        other=next(i for i in range(3) if i!=leader_index)
        processes[other].terminate();processes[other].wait(timeout=5)
        rejected=False
        try:await call(1,'join',actor='partition',resume='partition',district='d01',name='No quorum')
        except (OSError,ValueError):rejected=True
        assert rejected
        return dict(scope='Three actual local etcd processes and two coordinator frontends; functional failover, not throughput or geographic certification.',checks=['concurrent_CAS_capacity_16','two_frontends_identical_state','concurrent_UTC_award_exactly_once','campaign_reset_survives_leader_loss','leader_and_frontend_failure_survived','committed_actors_retained','quorum_loss_rejects_mutation'])
    finally:
        for server in servers:server.close();await server.wait_closed()
        for process in processes:
            if process.poll() is None:process.terminate()
        for process in processes:
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        for log in logs:log.close()


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--etcd',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();report=asyncio.run(run(args.etcd,args.output));text=json.dumps(report,indent=2)+'\n';(args.output/'result.json').write_text(text);print(text)
