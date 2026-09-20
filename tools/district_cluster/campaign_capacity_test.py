"""Loopback admission and reinforcement test; synthetic workers, no FPS load claim."""
import argparse
import asyncio
import json
import tempfile
from pathlib import Path

from . import config, model
from .coordinator import Coordinator
from .fixture_worker import FixtureWorker
from .gateway import Gateway
from .network_test import eventually
from .store import SQLiteStore
from .transport import rpc


async def run():
    settings = config.campaign(48200)
    districts = ('d00','d01','d39','d40')
    gateways, tasks, servers, workers = {}, [], [], {}
    with tempfile.TemporaryDirectory() as tmp:
        store = SQLiteStore(Path(tmp)/'state.sqlite', model.initial(settings['districts']))
        coordinator = Coordinator(settings, store)
        try:
            servers.append(await coordinator.start(settings['coordinators'][0]))
            for name in sorted({settings['districts'][d]['gateway'] for d in districts}):
                gateways[name] = Gateway(settings, name)
                servers.append(await gateways[name].start())
            for d in districts:
                workers[d] = FixtureWorker(settings, d)
                tasks.append(asyncio.create_task(workers[d].run()))
            async def status():
                return await rpc(settings['coordinators'][0], dict(op='status', token=settings['admin_token']))
            async def ready():
                current = await status()
                return all(current['districts'][d]['online'] for d in districts)
            await eventually(ready)
            def address(gateway):
                return settings['gateways'][gateway]['address']
            semaphore = asyncio.Semaphore(8)
            async def join(i):
                async with semaphore:
                    d = districts[i%len(districts)]
                    try:
                        return await rpc(address(settings['districts'][d]['gateway']), dict(op='join',
                            token=settings['client_token'], identity=f'client{i}', resume=f'resume{i}', district=d, team=0))
                    except ValueError as error:
                        assert 'Global player limit' in str(error), str(error)
                        return None
            clients = [c for c in await asyncio.gather(*(join(i) for i in range(140))) if c]
            assert len(clients)==128, len(clients)
            async def filled():
                current = await status()
                return all(current['districts'][d]['reservations']==16 for d in districts)
            await eventually(filled)
            state = await status()
            assert state['player_count']==state['player_limit']==128
            assert sum(a['phase']=='waiting' for a in state['actors'].values())==64
            assert all(not state['districts'][d]['open'] for d in districts)
            checks = ['128_admitted_12_rejected_across_three_gateways',
                      '64_waiting_count_toward_global_cap', 'four_districts_at_16_close_incoming_gates']
            # Free one allied slot and one neutral hub slot in turn. Only the
            # coordinator can choose deployment; the gateway retries it itself.
            for destination in ('d01','d40'):
                before = await status()
                victim = next(k for k,a in before['actors'].items() if a['district']==destination)
                client = next(c for c in clients if c['identity']==victim)
                owner = before['actors'][victim]['gateway']
                auth = dict(actor=victim, resume=client['resume'])
                await rpc(address(owner), dict(op='resume', **auth))
                await rpc(address(owner), dict(op='leave', **auth))
                waiting = {k for k,a in before['actors'].items() if a['phase']=='waiting'}
                async def deployed():
                    current = await status()
                    return any(current['actors'][k]['district']==destination for k in waiting)
                await eventually(deployed)
                current = await status()
                assert current['districts'][destination]['reservations']==16
                assert current['player_count']==127
                replacement = await join(200 if destination=='d01' else 201)
                assert replacement is not None
                clients.append(replacement)
            checks += ['allied_slot_automatically_redeploys_waiting_player',
                       'neutral_hub_slot_automatically_redeploys_when_allies_full',
                       'logout_frees_global_admission_slot']
            current = await status()
            assert current['player_count']==128
            return dict(player_limit=128, district_capacity=16, configured_districts=81,
                        online_districts=4, gateways=3, checks=checks,
                        scope='Real loopback coordinator and regional gateway TCP; synthetic workers, no combat performance measurement.')
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            pending = [g.task for g in gateways.values()]
            if coordinator.clock_task:
                pending.append(coordinator.clock_task)
            for task in pending:
                task.cancel()
            await asyncio.gather(*pending, return_exceptions=True)
            for server in servers:
                server.close()
                await server.wait_closed()
            with store.lock:
                store.db.close()


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = json.dumps(asyncio.run(run()), indent=2)+'\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(result)
    print(result)
