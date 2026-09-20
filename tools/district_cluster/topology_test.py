"""Live expansion 4 → 8 → 64 and drained contraction back to four."""
import argparse
import asyncio
import json
import tempfile
from pathlib import Path
from .config import grid
from .coordinator import Coordinator
from .gateway import Gateway
from .fixture_worker import FixtureWorker
from .store import SQLiteStore
from .model import initial
from .transport import rpc
from .network_test import eventually


async def run():
    config=grid(4,46000);servers=[];gateways=[];workers={};tasks={};checks=[]
    with tempfile.TemporaryDirectory() as tmp:
        store=SQLiteStore(Path(tmp)/'db',initial(config['districts']))
        servers.append(await Coordinator(config,store).start(config['coordinators'][0]))
        async def admin(op,**fields):return await rpc(config['coordinators'][0],dict(op=op,token=config['admin_token'],**fields))
        try:
            for name in config['gateways']:
                gateway=Gateway(config,name);gateways.append(gateway);servers.append(await gateway.start())
            async def grow(count):
                rows=grid(count)['districts']
                await admin('topology',districts=rows)
                config['districts']=rows
                await asyncio.gather(*(g.refresh() for g in gateways))
                for district in rows:
                    if district not in tasks:
                        worker=FixtureWorker(config,district);workers[district]=worker;tasks[district]=asyncio.create_task(worker.run())
                async def ready():return all(r['online'] for r in (await admin('status'))['districts'].values())
                await eventually(ready)
            await grow(4)
            client=await rpc(config['gateways']['g00']['address'],dict(op='join',token=config['client_token'],district='d00',name='Persistent across resize'))
            await grow(8);checks.append('hot_add_4_to_8')
            await grow(64);checks.append('hot_add_8_to_64')
            try:await admin('topology',districts=grid(4)['districts'])
            except ValueError:checks.append('online_worker_removal_rejected')
            else:raise AssertionError('Removed running workers')
            for district in list(tasks)[4:]:
                await admin('drain',district=district)
                tasks[district].cancel()
            await asyncio.gather(*(task for d,task in tasks.items() if int(d[1:])>=4),return_exceptions=True)
            await asyncio.sleep(6.5)
            await admin('topology',districts=grid(4)['districts'])
            state=await admin('status')
            assert len(state['districts'])==4 and state['actors'][client['identity']]['district']=='d00'
            checks.append('drained_remove_64_to_4_preserves_resident')
            rows=grid(4)['districts'];rows.pop('d03');rows['d02']['links'].pop('d03')
            try:await admin('topology',districts=rows)
            except ValueError:checks.append('minimum_four_enforced')
            else:raise AssertionError('Accepted three districts')
            return dict(scope='Live loopback services with synthetic workers; no map-authoring or game-load claim.',checks=checks)
        finally:
            for task in tasks.values():task.cancel()
            await asyncio.gather(*tasks.values(),return_exceptions=True)
            for g in gateways:g.task.cancel()
            await asyncio.gather(*(g.task for g in gateways),return_exceptions=True)
            for s in servers:s.close();await s.wait_closed()
            await asyncio.sleep(.1);store.db.close()


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    report=asyncio.run(run());text=json.dumps(report,indent=2)+'\n';args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(text);print(text)
