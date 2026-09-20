"""Real console-worker, cross-region moderator and broadcast regression."""
import argparse,asyncio,base64,hashlib,json,math,struct,subprocess,sys,time
from pathlib import Path
from . import config,model,moderation,campaign
from .store import SQLiteStore
from .transport import rpc
from .network_test import eventually
ROOT=Path(__file__).resolve().parents[2]
PASSWORD='local test password only'
async def run(out,binary):
    out=out.resolve();out.mkdir(parents=True);binary=binary.resolve()
    settings=config.campaign(50100);config.write_private(out/'cluster.json',settings)
    limited=json.loads(json.dumps(settings));limited['admin_token']='0'*64;limited['local_gateways']=['g03','g10'];config.write_private(out/'regional.json',limited)
    now=time.time();state=model.initial(settings['districts']);campaign.advance(state,now)
    for i,(key,d,g) in enumerate([('mod','d41','g10'),('target','d12','g03')]):
        state['actors'][key]=dict(id=1000+i,name=key,resume_hash=hashlib.sha256((key+'-secret').encode()).hexdigest(),district=d,preferred=d,phase='active',generation=1,arrival=None,gateway=g,seen_at=now,created=now,joins=1,avatar='',stats=dict(kills=0,deaths=0),team=i)
    state['next_id']=1002;(out/'master').mkdir();store=SQLiteStore(out/'master/control.sqlite',state);store.db.close()
    for role in ['master','workers']:
        (out/role).mkdir(exist_ok=True)
        cfg=f'[cq]\nrole = {role}\ncluster = {out/("cluster.json" if role=="master" else "regional.json")}\nstate = {out/role}\nbinary = {binary}\n'
        cfg+=('index = 0\nmoderator_password_hash = '+moderation.verifier(PASSWORD)+'\n' if role=='master' else 'districts = d12 d13 d14 d15 d40 d41 d42 d43\n')
        (out/(role+'.cfg')).write_text(cfg);(out/(role+'.cfg')).chmod(0o600)
    procs=[];logs=[];checks=[]
    async def status():return await rpc(settings['coordinators'][0],dict(op='status',token=settings['admin_token']))
    def address(g):return settings['gateways'][g]['address']
    async def req(key,g,op,**fields):return await rpc(address(g),dict(op=op,actor=key,resume=key+'-secret',**fields))
    async def rejects(call,word):
        try:await call
        except ValueError as e:assert word in str(e),str(e)
        else:raise AssertionError('Unauthorized request accepted')
    async def located(key,d,generation):
        a=(await status())['actors'][key];return a['phase']=='active' and a['district']==d and a['generation']==generation
    try:
        for role in ['master','workers']:
            log=(out/(role+'.log')).open('w');logs.append(log);procs.append(subprocess.Popen([sys.executable,'-m','tools.district_cluster.service',str(out/(role+'.cfg'))],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT))
            if role=='master':
                async def ready_master():
                    try:return bool(await status())
                    except OSError:return False
                await eventually(ready_master)
        async def ready():
            current=await status();return all(current['districts'][d]['online'] for d in ['d12','d13','d14','d15','d40','d41','d42','d43'])
        await eventually(ready,50)
        await req('mod','g10','resume');await req('target','g03','resume');await asyncio.sleep(1)
        newcomer=await rpc(address('g03'),dict(op='join',identity='newcomer',resume='new-secret',token=settings['client_token'],district='d12',team=0))
        assert newcomer['actor']['district']=='d40' and newcomer['gateway']==address('g10')
        await rpc(address('g10'),dict(op='resume',actor='newcomer',resume='new-secret'));await asyncio.sleep(.6)
        await rpc(address('g10'),dict(op='leave',actor='newcomer',resume='new-secret'));checks.append('new_identity_redirected_to_inner_city')
        await rejects(req('target','g03','moderator_move',moderator_token='forged',action='district',district='d41'),'unauthorized')
        await rejects(req('mod','g10','moderator_login',password='wrong',_moderator_grant='a'*64),'rejected')
        login=await req('mod','g10','moderator_login',password=PASSWORD);token=login['moderator_token'];checks.append('master_password_required')
        listing=await req('mod','g10','moderator_list',moderator_token=token);assert len(listing['districts'])==81 and len(listing['players'])==2
        assert token not in json.dumps(await status());checks.append('moderator_secret_not_public')
        await asyncio.sleep(.6)
        await req('mod','g10','moderator_move',moderator_token=token,action='goto',player=1001)
        await eventually(lambda:located('mod','d12',2));redirect=await req('mod','g10','status');assert redirect['redirect']==address('g03')
        await req('mod','g03','resume');await asyncio.sleep(.8);checks.append('cross_region_goto_and_redirect')
        await req('mod','g03','moderator_move',moderator_token=token,action='district',district='d41');await eventually(lambda:located('mod','d41',3));await req('mod','g10','resume');await asyncio.sleep(.8);checks.append('arbitrary_district_teleport')
        pcm=base64.b64encode(b''.join(struct.pack('<h',int(math.sin(i*2*math.pi*440/16000)*8000)) for i in range(1600))).decode()
        await rejects(req('target','g03','moderator_voice',moderator_token='forged',sequence=1,pcm=pcm),'unauthorized')
        frames=[]
        for seq in range(1,8):
            await req('mod','g10','moderator_voice',moderator_token=token,sequence=seq,pcm=pcm);await asyncio.sleep(.12)
            packet=await req('target','g03','voice_poll',cursor=frames[-1]['cursor'] if frames else 0);frames+=packet['frames']
        assert len(frames)>=5 and all(f['id']==1000 and f['pcm']==pcm for f in frames),len(frames);checks.append('cross_region_global_voice_and_unauthorized_rejection')
        await req('mod','g10','moderator_move',moderator_token=token,action='bring',player=1001);await eventually(lambda:located('target','d41',2))
        assert (await req('target','g03','status'))['redirect']==address('g10');await req('target','g10','resume');await asyncio.sleep(.8);checks.append('bring_player_cross_region')
        await req('mod','g10','moderator_move',moderator_token=token,action='goto',player=1001);await eventually(lambda:located('mod','d41',4));await asyncio.sleep(.8);checks.append('same_district_safe_teleport')
        snap=await req('mod','g10','snapshot');(out/'snapshot.json').write_text(json.dumps(snap))
        config.write_private(out/'identity.json',dict(actor='mod',resume='mod-secret'))
        config.write_private(out/'client.json',dict(address=['127.0.0.1',50220],district='d41',token=settings['client_token'],team=0,name='Moderator test',identity_file=str(out/'identity.json'),smoke_output=str(out/'moderator.png'),moderator_test_password=PASSWORD))
        client=await asyncio.create_subprocess_exec('godot','--xr-mode','off','--path',str(ROOT),'--script','tools/district_cluster/moderator_smoke.gd','--',str(out/'client.json'),stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
        try:output=await asyncio.wait_for(client.communicate(),40)
        except BaseException:client.kill();await client.wait();raise
        (out/'client.log').write_bytes(output[0]);assert client.returncode==0 and b'CQ_MODERATOR_SMOKE' in output[0] and b'CQ_LOCATION_RESTORED' in output[0],output[0].decode();checks+=['Vulkan_moderator_UI_and_voice_playback','saved_position_restored_in_real_BSP_worker']
        return dict(checks=checks,received_voice_frames=len(frames),scope='Local real master, two regions, eight console BSP workers, Vulkan desktop; simulated PCM announcement, no microphone capture.')
    finally:
        for p in reversed(procs):
            if p.poll() is None:p.terminate()
        for p in reversed(procs):
            try:p.wait(timeout=15)
            except subprocess.TimeoutExpired:p.kill();p.wait()
        for log in logs:log.close()
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--binary',type=Path,required=True);a=p.parse_args();result=asyncio.run(run(a.output,a.binary));(a.output/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
