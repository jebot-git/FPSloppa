"""Run opt-in cluster services. No normal server configuration is changed."""
import argparse
import asyncio
import json
import threading
from urllib.parse import urlparse
from pathlib import Path
from . import config,model
from .coordinator import Coordinator
from .gateway import Gateway
from .store import SQLiteStore,EtcdStore
from .transport import rpc


async def run(args):
    if args.role=='init':
        config.write_private(args.config,config.campaign(args.base_port) if args.districts is None else config.grid(args.districts,args.base_port));return
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
        config.write_private(args.output,dict(address=[address[0],address[1]+100],district=args.district,token=settings['client_token'],campaign_id=settings['campaign_id'],team=args.team,name=args.player_name));return
    if args.role=='worker-config':
        district=settings['districts'][args.district]
        value=dict(district=args.district,map_slot=district['map_slot'],address=settings['gateways'][district['gateway']]['address'],token=settings['worker_tokens'][args.district],state_dir=str((Path(args.state_dir)/args.district).resolve()))
        if 'asset_id' in district:value['asset_id']=district['asset_id']
        config.write_private(args.output,value)
        return
    if args.role=='coordinator':
        if args.status_file:settings['status_file']=args.status_file
        state=model.initial(settings['districts'],settings['waiting_limit'])
        if args.etcd:
            if any(urlparse(e).scheme!='http' or not config.private_host(urlparse(e).hostname or '') for e in args.etcd):raise ValueError('etcd must use private WireGuard or loopback endpoints')
            store=EtcdStore(args.etcd,args.key,state)
        else:
            Path(args.database).parent.mkdir(parents=True,exist_ok=True)
            store=SQLiteStore(args.database,state)
        service=Coordinator(settings,store)
        server=await service.start(settings['coordinators'][args.index])
        if args.content_listen:
            from .content import server as content_server
            host,port=args.content_listen.rsplit(':',1)
            if not config.private_host(host):raise ValueError('Content service must bind a private address; use a TLS proxy for public HTTP')
            http=content_server([host,int(port)],store,args.content_root,args.worker_binary,args.status_file)
            threading.Thread(target=http.serve_forever,daemon=True).start()
    else:
        service=Gateway(settings,args.name)
        deadline=asyncio.get_running_loop().time()+model.LEASE+3
        while True:
            try:
                server=await service.start()
                break
            except ValueError as error:
                if (not args.wait_lease or 'Previous gateway lease is still valid' not in str(error)
                        or asyncio.get_running_loop().time()>=deadline):raise
                await asyncio.sleep(.25)
    print('CLUSTER_READY '+args.role,flush=True)
    async with server:
        await server.serve_forever()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('role',choices=['init','coordinator','gateway','admin','worker-config','edge-config','client-config'])
    parser.add_argument('--config',type=Path,required=True)
    profile=parser.add_mutually_exclusive_group()
    profile.add_argument('--districts',type=int,help='Explicit generic, non-CQ topology (4–81 districts)')
    profile.add_argument('--campaign',action='store_true',help='Create the default 81-district CQ campaign atlas')
    parser.add_argument('--base-port',type=int,default=41000)
    parser.add_argument('--database',default='test-results/district-cluster/coordinator.sqlite')
    parser.add_argument('--etcd',nargs='+')
    parser.add_argument('--key',default='/fpsloppa/cluster/control')
    parser.add_argument('--index',type=int,default=0)
    parser.add_argument('--name',default='g00')
    parser.add_argument('--wait-lease',action='store_true',help='Wait for a previous gateway lease during supervised restart')
    parser.add_argument('--district',default='d00')
    parser.add_argument('--team',type=int,choices=[0,1],default=0)
    parser.add_argument('--player-name',default='Campaign Explorer')
    parser.add_argument('--state-dir',default='test-results/district-cluster/worker')
    parser.add_argument('--output',default='test-results/district-cluster/worker.json')
    parser.add_argument('--request')
    parser.add_argument('--status-file')
    parser.add_argument('--content-listen')
    parser.add_argument('--content-root',default='test-results/cq-content/vrm')
    parser.add_argument('--worker-binary',default='Builds/CQLive/FPSloppaServer.x86_64')
    args=parser.parse_args()
    try:asyncio.run(run(args))
    except KeyboardInterrupt:pass


if __name__=='__main__':main()
