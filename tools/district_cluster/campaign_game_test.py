"""Actual hub and relay BSP workers: no-fire, terminals, contested capture and UI."""
import argparse,asyncio,hashlib,json,os,subprocess,time
from pathlib import Path
from . import campaign,config,model
from .coordinator import Coordinator
from .gateway import Gateway
from .store import SQLiteStore
from .transport import rpc
from .network_test import eventually
from .game_test import decode
ROOT=Path(__file__).resolve().parents[2]

async def run(binary,out):
    out.mkdir(parents=True,exist_ok=True);settings=config.campaign(47400)
    state=model.initial(settings['districts']);campaign.advance(state,time.time())
    state['campaign']['owners']['d13']=0
    # Test fixture places an enemy in the relay circle. It still uses the real
    # worker's positions/death checks and 30 real seconds of coordinator capture.
    state['actors']['blue-fixture']=dict(id=1000,name='Capture probe',team=1,resume_hash=hashlib.sha256(b'fixture').hexdigest(),district='d13',preferred='d13',phase='active',generation=1,arrival=None,gateway='g03')
    state['next_id']=1001
    store=SQLiteStore(out/'coordinator.sqlite',state);coordinator=Coordinator(settings,store)
    servers=[await coordinator.start(settings['coordinators'][0])];gateways={};processes=[];logs=[]
    try:
        for name in ('g03','g10'):
            gateway=Gateway(settings,name);gateways[name]=gateway;servers.append(await gateway.start())
        for d,spawn in (('d13',[0,1,0]),('d40',[-13,1,-13])):
            row=settings['districts'][d];path=out/(d+'.json')
            config.write_private(path,dict(district=d,map_slot=row['map_slot'],asset_id=row['asset_id'],address=settings['gateways'][row['gateway']]['address'],token=settings['worker_tokens'][d],state_dir=str((out/d).resolve()),spawn=spawn))
            log=(out/(d+'.log')).open('w');logs.append(log)
            processes.append(subprocess.Popen([str(binary.resolve()),'--','--asset-root',str(binary.resolve().parent),'--experimental-cq','--cq-district-maps','--cq-worker',str(row['map_slot']),'--cluster-worker',str(path.resolve())],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME=str((out/'profile').resolve()))))
        async def control():return await rpc(settings['coordinators'][0],dict(op='status',token=settings['admin_token']))
        async def ready():
            view=await control();return all(view['districts'][d]['online'] for d in ('d13','d40'))
        await eventually(ready,45)
        source=settings['gateways']['g10']['address'];dest=settings['gateways']['g03']['address']
        joined=await rpc(source,dict(op='join',token=settings['client_token'],district='d40',team=0,name='Red terminal probe'))
        auth=dict(actor=joined['identity'],resume=joined['resume'])
        async def request(address,op,**fields):return await rpc(address,dict(op=op,**auth,**fields))
        await asyncio.sleep(.8)
        before=await asyncio.to_thread(decode,await request(source,'snapshot'),out,'hub-before')
        for seq in range(1,11):
            await request(source,'input',generation=1,command=dict(seq=seq,move=[0,0],fire=True));await asyncio.sleep(.05)
        after=await asyncio.to_thread(decode,await request(source,'snapshot'),out,'hub-after')
        assert after[0]['ammo']==before[0]['ammo'] and not after[0]['fire']
        public=await request(source,'status');assert public['links']['d13']['open'] and public['links']['d13']['owner']==0
        moved=await request(source,'transfer',target='d13');assert moved['actor']['district']=='d13'
        await request(dest,'resume');await asyncio.sleep(.8)
        occupied=(await control())['campaign']['points']['d13'][1]
        await asyncio.sleep(1.2)
        paused=(await control())['campaign']['points']['d13'][1]
        assert abs(paused-occupied)<.05,(occupied,paused)
        for seq in range(11,61):
            await request(dest,'input',generation=2,command=dict(seq=seq,move=[0,1],yaw=0));await asyncio.sleep(.035)
        await request(dest,'input',generation=2,command=dict(seq=61,move=[0,0]))
        async def captured():return (await control())['campaign']['owners']['d13']==1
        await eventually(captured,40)
        second=await rpc(source,dict(op='join',token=settings['client_token'],district='d40',team=0,name='Locked terminal probe'))
        await asyncio.sleep(.6)
        denied=False
        try:await rpc(source,dict(op='transfer',actor=second['identity'],resume=second['resume'],target='d13'))
        except ValueError as e:denied='Campaign gate locked' in str(e)
        assert denied
        # Render and drive the separate desktop client against this live hub.
        edge_path=out/'edge.json';config.write_private(edge_path,dict(backend=source,listen=['127.0.0.1',47520],routes={f'{source[0]}:{source[1]}':['127.0.0.1',47520],f'{dest[0]}:{dest[1]}':['127.0.0.1',47513]}))
        log=(out/'edge.log').open('w');logs.append(log)
        processes.append(subprocess.Popen(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','tools/district_cluster/edge_main.gd','--',str(edge_path.resolve())],stdout=log,stderr=subprocess.STDOUT))
        client_path=out/'client.json';config.write_private(client_path,dict(address=['127.0.0.1',47520],token=settings['client_token'],district='d40',team=0,name='Vulkan campaign probe',smoke_output=str((out/'desktop.png').resolve())))
        await asyncio.sleep(.5)
        result=await asyncio.create_subprocess_exec('godot','--path',str(ROOT),'--xr-mode','off','--rendering-method','mobile','--rendering-driver','vulkan','--resolution','1280x720','--script','tools/district_cluster/desktop.gd','--',str(client_path.resolve()),stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
        output=await asyncio.wait_for(result.communicate(),25);(out/'desktop.log').write_bytes(output[0])
        assert result.returncode==0 and b'CAMPAIGN_DESKTOP_SMOKE' in output[0],output[0].decode()
        return dict(scope='Two real Godot BSP workers, regional gateways, durable coordinator and Vulkan desktop over loopback.',checks=['distinct_campaign_BSP_boot','hub_no_fire','controlled_terminal_handoff','contested_capture_pauses','worker_measured_30_point_capture','lost_relay_locks_terminal','live_Vulkan_hub_scoreboard'],captured_owner=1)
    finally:
        if coordinator.clock_task:coordinator.clock_task.cancel()
        for g in gateways.values():g.task.cancel()
        await asyncio.gather(*(g.task for g in gateways.values()),return_exceptions=True)
        for p in processes:
            if p.poll() is None:p.terminate()
        for p in processes:
            try:p.wait(timeout=5)
            except subprocess.TimeoutExpired:p.kill();p.wait()
        for server in servers:server.close();await server.wait_closed()
        for log in logs:log.close()
        with store.lock:store.db.close()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--binary',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=asyncio.run(run(a.binary,a.output));(a.output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
