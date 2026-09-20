"""Real cfg-launched CQ services, VRM persistence and external-client resource probe."""
import argparse
import asyncio
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import time
import urllib.request
import urllib.error
from . import config,model,profiles
from .store import SQLiteStore
from .network_test import eventually
from .transport import rpc

ROOT=Path(__file__).resolve().parents[2]


def sample(pid):
    stat=Path(f'/proc/{pid}/stat').read_text().split(') ',1)[1].split()
    status=dict(line.split(':',1) for line in Path(f'/proc/{pid}/status').read_text().splitlines() if ':' in line)
    return dict(cpu=(int(stat[11])+int(stat[12]))/os.sysconf('SC_CLK_TCK'),rss_mib=int(status['VmRSS'].split()[0])/1024,threads=int(status['Threads']))


def tree(pid):
    result=[]
    try:children=Path(f'/proc/{pid}/task/{pid}/children').read_text().split()
    except OSError:return result
    for child in children:
        args=Path(f'/proc/{child}/cmdline').read_bytes().split(b'\0')
        result.append((int(child),[a.decode(errors='replace') for a in args if a]))
        result+=tree(int(child))
    return result


async def run(out,binary,seconds,client_binary=None):
    out=out.resolve();out.mkdir(parents=True,exist_ok=True);binary=binary.resolve()
    settings=config.campaign(49500)
    config.write_private(out/'cluster.json',settings)
    limited=json.loads(json.dumps(settings));limited['admin_token']='0'*64;limited['local_gateways']=['g10']
    config.write_private(out/'regional.json',limited)
    for role in ('master','workers'):
        folder=out/role;folder.mkdir()
        cfg=f'[cq]\nrole = {role}\ncluster = {out/("cluster.json" if role=="master" else "regional.json")}\nstate = {folder}\nbinary = {binary}\n'
        cfg+=('index = 0\ncontent_listen = 127.0.0.1:49700\n' if role=='master' else 'districts = d40 d41 d42 d43\n')
        (out/(role+'.cfg')).write_text(cfg)
    # These are returning combat-load fixtures; genuinely new players now enter d40.
    seed=SQLiteStore(out/'master/control.sqlite',model.initial(settings['districts']))
    for i in range(16):
        actor=dict(id=1000+i,name=f'Live probe {i}',team=0,generation=1,preferred='d41',district='d41',resume_hash=hashlib.sha256(f'secret{i}'.encode()).hexdigest())
        seed.db.execute('INSERT INTO players VALUES (?,?)',(f'live{i}',json.dumps(profiles.record(actor,time.time()))))
    body=json.loads(seed.db.execute('SELECT body FROM state WHERE id=1').fetchone()[0]);body['next_id']=1016
    seed.db.execute('UPDATE state SET body=? WHERE id=1',(json.dumps(body),));seed.db.commit();seed.db.close()
    procs=[];logs=[];clients=[]
    try:
        for role in ('master','workers'):
            log=(out/(role+'-supervisor.log')).open('w');logs.append(log)
            procs.append(subprocess.Popen([sys.executable,'-m','tools.district_cluster.service',str(out/(role+'.cfg'))],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT))
            if role=='master':await asyncio.sleep(.5)
        async def status():return await rpc(settings['coordinators'][0],dict(op='status',token=settings['admin_token']))
        async def ready():
            try:
                s=await status();return all(s['districts'][f'd{i}']['online'] for i in range(40,44))
            except OSError:return False
        await eventually(ready,45)
        address=settings['gateways']['g10']['address']
        async def join(i,team=0):
            return await rpc(address,dict(op='join',token=settings['client_token'],district='d41',identity=f'live{i}',resume=f'secret{i}',team=team,name=f'Live probe {i}'))
        async def request(i,op,**fields):
            return await rpc(address,dict(op=op,actor=f'live{i}',resume=f'secret{i}',**fields))
        pids=tree(procs[0].pid)+tree(procs[1].pid)
        baseline={pid:sample(pid) for pid,_ in pids}
        await asyncio.sleep(5)
        idle={pid:sample(pid) for pid,_ in pids}
        for i in range(16):clients.append(await join(i))
        async def populated():return (await status())['districts']['d41']['reservations']==16
        await eventually(populated)
        await asyncio.sleep(.8)
        state=await status();generations={i:state['actors'][f'live{i}']['generation'] for i in range(16)}
        active_before={pid:sample(pid) for pid,_ in pids};started=time.monotonic()
        latencies=[];snapshot_bytes=[];failures=[]
        async def drive(i):
            seq=0
            while time.monotonic()-started<seconds:
                seq+=1;begin=time.monotonic()
                try:
                    await request(i,'input',generation=generations[i],command=dict(seq=seq,move=[(-1 if i%2 else 1)*.1,0],fire=True,yaw=0))
                    snapshot=await request(i,'snapshot');snapshot_bytes.append(len(json.dumps(snapshot).encode()))
                    latencies.append((time.monotonic()-begin)*1000)
                except (ValueError,OSError,TimeoutError) as error:failures.append(str(error))
                await asyncio.sleep(max(0,.05-(time.monotonic()-begin)))
        await asyncio.gather(*(drive(i) for i in range(16)))
        elapsed=time.monotonic()-started;active_after={pid:sample(pid) for pid,_ in pids}
        assert not failures,failures[:5]
        resources=[]
        for pid,args in pids:
            label='worker '+args[-1].split('/')[-1] if '--cluster-worker' in args else 'ENet facade' if '--cq-service' in args else 'master' if 'coordinator' in args else 'regional gateway'
            resources.append(dict(service=label,idle_core_fraction=round((idle[pid]['cpu']-baseline[pid]['cpu'])/5,3),
                active_core_fraction=round((active_after[pid]['cpu']-active_before[pid]['cpu'])/elapsed,3),rss_mib=round(active_after[pid]['rss_mib'],1),threads=active_after[pid]['threads']))
        config.write_private(out/'enet.json',dict(address=['127.0.0.1',49620],token=settings['client_token'],clients=16,seconds=15))
        enet_before={pid:sample(pid) for pid,_ in pids};enet_started=time.monotonic()
        enet=await asyncio.create_subprocess_exec('godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','tools/district_cluster/enet_load.gd','--',str(out/'enet.json'),stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
        try:output=await asyncio.wait_for(enet.communicate(),40)
        except BaseException:enet.kill();await enet.wait();raise
        (out/'enet.log').write_bytes(output[0]);assert enet.returncode==0,output[0].decode()
        enet_result=json.loads(next(line.removeprefix('CQ_ENET_LOAD ') for line in output[0].decode().splitlines() if line.startswith('CQ_ENET_LOAD ')))
        enet_elapsed=time.monotonic()-enet_started
        for resource,(pid,_) in zip(resources,pids):resource['enet_core_fraction']=round((sample(pid)['cpu']-enet_before[pid]['cpu'])/enet_elapsed,3)
        body=(ROOT/'vrm/sample_d.vrm').read_bytes();digest=hashlib.sha256(body).hexdigest()
        def upload(i,data):
            req=urllib.request.Request('http://127.0.0.1:49700/vrm',data,headers={'Content-Type':'application/octet-stream','X-CQ-ID':f'live{i}','X-CQ-Secret':f'secret{i}'})
            return json.load(urllib.request.urlopen(req,timeout=35))
        uploaded=await asyncio.to_thread(upload,0,body);assert uploaded['hash']==digest
        await asyncio.to_thread(upload,1,body)
        try:await asyncio.to_thread(upload,0,b'not a VRM'*128)
        except urllib.error.HTTPError as error:assert error.code==400
        else:raise AssertionError('Non-VRM content accepted')
        def fetch():
            data=urllib.request.urlopen('http://127.0.0.1:49700/vrm/'+digest+'.vrm',timeout=10).read()
            assert hashlib.sha256(data).hexdigest()==digest
            page=urllib.request.urlopen('http://127.0.0.1:49700/',timeout=10).read().decode()
            assert page.count('<article ')==81 and 'resume_hash' not in page
        await asyncio.to_thread(fetch)
        first_id=(await status())['actors']['live0']['id']
        await request(0,'leave');returned=await join(0,1)
        assert returned['actor']['id']==first_id and returned['actor']['team']==0 and returned['actor']['avatar']==digest
        await asyncio.sleep(.7);await request(0,'resume');await request(0,'leave')
        config.write_private(out/'identity.json',dict(actor='live0',resume='secret0'))
        config.write_private(out/'client.json',dict(address=['127.0.0.1',49620],district='d40',token=settings['client_token'],team=1,name='Returning client',content_url='http://127.0.0.1:49700',identity_file=str(out/'identity.json'),smoke_output=str(out/'desktop.png'),require_avatar=True))
        command=[str(client_binary.resolve()),'--rendering-method','mobile','--rendering-driver','vulkan','--',str(out/'client.json')] if client_binary else [str(ROOT/'launch-conquest.sh'),str(out/'client.json')]
        desktop=await asyncio.create_subprocess_exec(*command,cwd=ROOT,stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
        try:output=await asyncio.wait_for(desktop.communicate(),35)
        except BaseException:desktop.kill();await desktop.wait();raise
        (out/'desktop.log').write_bytes(output[0])
        assert desktop.returncode==0 and b'CAMPAIGN_DESKTOP_SMOKE' in output[0],output[0].decode()
        for i in range(1,16):await request(i,'leave')
        assert (await status())['player_count']==0
        edge_log=(out/'workers/g10-edge.log').read_text()
        assert 'ERROR:' not in edge_log,edge_log
        return dict(scope='One cfg master, one regional gateway, console ENet facade, four actual campaign BSP workers; 16 external protocol actors at ~20 input/snapshot cycles per second in one district, no server bots. Local desktop CPU, not a VPS certification.',
            elapsed_seconds=elapsed,actors=16,resources=resources,enet_probe=enet_result,request_cycles=len(latencies),cycle_p95_ms=sorted(latencies)[int(len(latencies)*.95)],
            snapshot_mean_bytes=statistics.mean(snapshot_bytes),snapshot_application_mbit_s=sum(snapshot_bytes)*8/elapsed/1e6,
            checks=['cfg_master_and_workers','bounded_16_player_real_worker_load','VRM_upload_and_hash_download','non_VRM_rejected','static_81_district_page','persistent_ID_team_avatar_after_logout','returning_Vulkan_desktop','all_slots_released','ENet_connect_disconnect_without_gateway_errors'])
    finally:
        for process in reversed(procs):
            if process.poll() is None:process.terminate()
        for process in reversed(procs):
            try:process.wait(timeout=15)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        for log in logs:log.close()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--binary',type=Path,default=ROOT/'Builds/CQLive/FPSloppaServer.x86_64');parser.add_argument('--seconds',type=int,default=20)
    parser.add_argument('--client-binary',type=Path)
    args=parser.parse_args();result=asyncio.run(run(args.output,args.binary,args.seconds,args.client_binary));(args.output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
