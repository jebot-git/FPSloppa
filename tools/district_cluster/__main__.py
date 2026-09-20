"""Run opt-in cluster services. No normal server configuration is changed."""
import argparse
import asyncio
import json
from pathlib import Path
from . import config,model
from .coordinator import Coordinator
from .gateway import Gateway
from .store import SQLiteStore,EtcdStore
from .transport import rpc


async def run(args):
    if args.role=='init':
        config.write_private(args.config,config.campaign(args.base_port) if args.campaign else config.grid(args.districts,args.base_port));return
    settings=config.read(args.config)
    if args.role=='admin':
        message=json.loads(Path(args.request).read_text()) if args.request else {'op':'status'}
        message['token']=settings['admin_token']
        print(json.dumps(await rpc(settings['coordinators'][0],message),indent=2));return
    if args.role=='edge-config':
        address=settings['gateways'][args.name]['address']
        routes={f"{g['address'][0]}:{g['address'][1]}":[g['address'][0],g['address'][1]+100] for g in settings['gateways'].values()}
        config.write_private(args.output,dict(backend=address,listen=[address[0],address[1]+100],routes=routes));return
    if args.role=='client-config':
        row=settings['districts'][args.district];address=settings['gateways'][row['gateway']]['address']
        config.write_private(args.output,dict(address=[address[0],address[1]+100],district=args.district,token=settings['client_token'],team=args.team,name=args.player_name));return
    if args.role=='worker-config':
        district=settings['districts'][args.district]
        value=dict(district=args.district,map_slot=district['map_slot'],address=settings['gateways'][district['gateway']]['address'],token=settings['worker_tokens'][args.district],state_dir=str((Path(args.state_dir)/args.district).resolve()))
        if 'asset_id' in district:value['asset_id']=district['asset_id']
        config.write_private(args.output,value)
        return
    if args.role=='coordinator':
        state=model.initial(settings['districts'],settings['waiting_limit'])
        if args.etcd:
            if any(not e.startswith('http://127.0.0.1:') for e in args.etcd):raise ValueError('Tunnel etcd endpoints to loopback')
            store=EtcdStore(args.etcd,args.key,state)
        else:
            Path(args.database).parent.mkdir(parents=True,exist_ok=True)
            store=SQLiteStore(args.database,state)
        service=Coordinator(settings,store)
        server=await service.start(settings['coordinators'][args.index])
    else:
        service=Gateway(settings,args.name)
        server=await service.start()
    print('CLUSTER_READY '+args.role,flush=True)
    async with server:
        await server.serve_forever()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('role',choices=['init','coordinator','gateway','admin','worker-config','edge-config','client-config'])
    parser.add_argument('--config',type=Path,required=True)
    parser.add_argument('--districts',type=int,default=4)
    parser.add_argument('--campaign',action='store_true',help='Create the fixed 81-district campaign atlas')
    parser.add_argument('--base-port',type=int,default=41000)
    parser.add_argument('--database',default='test-results/district-cluster/coordinator.sqlite')
    parser.add_argument('--etcd',nargs='+')
    parser.add_argument('--key',default='/fpsloppa/cluster/control')
    parser.add_argument('--index',type=int,default=0)
    parser.add_argument('--name',default='g00')
    parser.add_argument('--district',default='d00')
    parser.add_argument('--team',type=int,choices=[0,1],default=0)
    parser.add_argument('--player-name',default='Campaign Explorer')
    parser.add_argument('--state-dir',default='test-results/district-cluster/worker')
    parser.add_argument('--output',default='test-results/district-cluster/worker.json')
    parser.add_argument('--request')
    args=parser.parse_args()
    try:asyncio.run(run(args))
    except KeyboardInterrupt:pass


if __name__=='__main__':main()
