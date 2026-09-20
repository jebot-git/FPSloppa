"""Real loopback control/data transport, synthetic workers; no FPS gameplay claim."""
import argparse
import asyncio
import base64
import copy
import json
import tempfile
import time
from pathlib import Path
from .config import grid
from .coordinator import Coordinator
from .gateway import Gateway
from .fixture_worker import FixtureWorker
from .store import SQLiteStore
from .model import initial
from .transport import rpc


async def eventually(predicate,timeout=12):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        if await predicate():return
        await asyncio.sleep(.1)
    raise AssertionError('Timed out waiting for cluster state')


async def run(count=8):
    config=grid(count,43000)
    servers=[];gateways={};worker_tasks=[];workers={};checks=[]
    with tempfile.TemporaryDirectory() as tmp:
        store=SQLiteStore(Path(tmp)/'state.db',initial(config['districts']))
        coordinator=Coordinator(config,store)
        servers.append(await coordinator.start(config['coordinators'][0]))
        try:
            for name in sorted({r['gateway'] for r in config['districts'].values()}):
                gateway=Gateway(config,name);gateways[name]=gateway;servers.append(await gateway.start())
            for d in config['districts']:
                w=FixtureWorker(config,d);workers[d]=w;worker_tasks.append(asyncio.create_task(w.run()))
            async def status():return await rpc(config['coordinators'][0],dict(op='status',token=config['admin_token']))
            async def all_online():return all(r['online'] for r in (await status())['districts'].values())
            await eventually(all_online)
            checks.append('all_workers_registered')
            def address(d):return config['gateways'][config['districts'][d]['gateway']]['address']
            async def join(d):return await rpc(address(d),dict(op='join',token=config['client_token'],district=d,name='Fixture'))
            async def request(client,d,op,**fields):return await rpc(address(d),dict(op=op,actor=client['identity'],resume=client['resume'],**fields))
            # Test real cross-gateway escrow, migration and reconnect.
            a=await join('d03')
            async def resident():return a['identity'] in workers['d03'].actors
            await eventually(resident)
            initial_body=copy.deepcopy(workers['d03'].actors[a['identity']])
            moved=await request(a,'d03','transfer',target='d04')
            await request(a,'d04','resume')
            async def arrived():return a['identity'] in workers['d04'].actors
            await eventually(arrived)
            body=workers['d04'].actors[a['identity']]
            assert body['hp']==initial_body['hp'] and body['jetpack']==initial_body['jetpack']
            assert a['identity'] not in workers['d03'].actors
            assert moved['actor']['generation']==2
            checks.append('cross_region_handoff_state_and_unique_owner')
            try:await request(a,'d04','input',generation=1,command={'seq':1,'move':[1,0]})
            except ValueError:pass
            else:raise AssertionError('Accepted obsolete generation')
            good=await request(a,'d04','input',generation=2,command={'seq':1,'move':[1,0]})
            assert good['accepted']
            duplicate=await request(a,'d04','input',generation=2,command={'seq':1,'move':[1,0]})
            assert not duplicate['accepted']
            checks.append('stale_generation_and_duplicate_input_rejected')
            await request(a,'d04','leave')
            # Lose a destination prepare acknowledgment after it has staged the actor.
            interrupted=await join('d03')
            async def source_ready():return interrupted['identity'] in workers['d03'].actors
            await eventually(source_ready)
            workers['d04'].fail_after_stage=True
            try:await request(interrupted,'d03','transfer',target='d04')
            except (OSError,ValueError):pass
            else:raise AssertionError('Injected handoff failure was not observed')
            pending=(await status())['actors'][interrupted['identity']]
            assert pending['phase']=='moving' and pending['target']=='d04'
            assert interrupted['identity'] in workers['d03'].escrow
            async def disconnected():return 'd04' not in gateways['g01'].workers
            await eventually(disconnected)
            worker_tasks.append(asyncio.create_task(workers['d04'].run()))
            async def reconnected():return 'd04' in gateways['g01'].workers and time.monotonic()<workers['d04'].until
            await eventually(reconnected)
            recovered=await request(interrupted,'d03','transfer',target='d04')
            assert recovered['actor']['phase']=='active'
            await request(interrupted,'d04','resume')
            async def recovered_actor():return interrupted['identity'] in workers['d04'].actors
            await eventually(recovered_actor)
            await request(interrupted,'d04','leave')
            checks.append('lost_prepare_ack_holds_reservations_and_retry_recovers')
            # All districts really reach 16 reservations; the 17th enters waiting.
            clients={}
            semaphore=asyncio.Semaphore(16)
            async def populate(d):
                async with semaphore:clients[d]=[await join(d) for _ in range(16)]
            await asyncio.gather(*(populate(d) for d in config['districts']))
            async def all_resident():return all(len(w.actors)==16 for w in workers.values())
            await eventually(all_resident)
            state=await status()
            assert all(r['reservations']==16 and not r['open'] for r in state['districts'].values())
            waiting=await join('d03');assert waiting['actor']['phase']=='waiting'
            blocked=await request(waiting,'d03','deploy');assert blocked['actor']['phase']=='waiting'
            checks.append('16_per_district_full_world_gates_closed_waiting')
            snapshots=await asyncio.gather(*(request(clients[d][0],d,'snapshot') for d in config['districts']))
            for d,snapshot in zip(config['districts'],snapshots):
                rows=json.loads(base64.b64decode(snapshot['payload']))
                assert len(rows)==16 and set(rows)=={c['identity'] for c in clients[d]}
            checks.append('district_scoped_shared_snapshots')
            victim=clients['d03'].pop()
            await request(victim,'d03','leave')
            async def automatically_deployed():return (await status())['actors'][waiting['identity']]['phase']=='active'
            await eventually(automatically_deployed)
            deployed=await request(waiting,'d03','deploy');assert deployed['actor']['district']=='d03'
            checks.append('released_slot_automatically_deploys_waiting_actor')
            # Draining remains closed even after a slot clears; unrelated workers live.
            await rpc(config['coordinators'][0],dict(op='drain',token=config['admin_token'],district='d04'))
            victim=clients['d04'].pop();await request(victim,'d04','leave')
            state=await status();assert not state['districts']['d04']['open']
            assert state['districts']['d05']['online']
            checks.append('drain_closes_incoming_gate_without_global_stop')
            # Simulate coordinator outage. Workers must stop granting inputs.
            servers[0].close();await servers[0].wait_closed()
            await asyncio.sleep(2.4)
            assert all(time.monotonic()>=w.until for w in workers.values())
            try:await request(clients['d00'][0],'d00','input',generation=1,command={'seq':2,'move':[1,0]})
            except ValueError:pass
            else:raise AssertionError('Accepted input after authority expiry')
            checks.append('coordinator_outage_fences_all_authority')
            servers[0]=await coordinator.start(config['coordinators'][0])
            await eventually(all_online)
            checks.append('coordinator_restart_preserves_ownership')
            return dict(districts=count,gateways=len(gateways),active_slots=16*count,checks=checks,scope='Actual loopback TCP services and synthetic worker payloads; no rendered or physics load certification.')
        finally:
            for task in worker_tasks:task.cancel()
            await asyncio.gather(*worker_tasks,return_exceptions=True)
            for gateway in gateways.values():gateway.task.cancel()
            await asyncio.gather(*(g.task for g in gateways.values()),return_exceptions=True)
            for server in servers:server.close();await server.wait_closed()
            await asyncio.sleep(.05)
            store.db.close()


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--districts',type=int,default=8);p.add_argument('--output',type=Path)
    args=p.parse_args();report=asyncio.run(run(args.districts))
    data=json.dumps(report,indent=2)+'\n'
    if args.output:args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(data)
    print(data)
