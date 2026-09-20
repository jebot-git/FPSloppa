"""Protocol load fixture only. Does not simulate FPSloppa physics or render maps."""
import asyncio
import base64
import hashlib
import json
import secrets
import time
from .transport import LIMIT,read,send


class FixtureWorker:
    def __init__(self,config,district):
        self.config,self.district=config,district
        self.instance=secrets.token_hex(16)
        self.actors={};self.escrow={};self.staged={};self.retired={}
        self.until=0;self.sequence=0;self.revision=-1
        self.writer=None;self.metadata={};self.grants={}
        self.lock=asyncio.Lock()
        self.fail_after_stage=False

    async def write(self,message):
        async with self.lock:await send(self.writer,message)

    async def snapshot(self):
        while True:
            await asyncio.sleep(.05)
            self.sequence+=1
            active=self.actors if time.monotonic()<self.until else {}
            payload=base64.b64encode(json.dumps(active,sort_keys=True).encode()).decode()
            await self.write(dict(op='snapshot',sequence=self.sequence,payload=payload))

    def command(self,m):
        op=m['op']
        if op=='welcome':return {}
        if op=='authority':
            if m['revision']<self.revision:return {}
            self.revision=m['revision'];self.until=time.monotonic()+max(0,min(2,m['valid_for'],m.get('expires_at',0)-time.time()))
            self.metadata=m['metadata'];self.grants=m['actors']
            for key,a in self.grants.items():
                if a['district']!=self.district or a['phase']!='active' or self.retired.get(a['id'],-1)>=a['generation']:continue
                if key not in self.actors:
                    if a.get('arrival'):
                        staged=self.staged.get(a['arrival'])
                        if staged is None:continue
                        self.actors[key]=json.loads(base64.b64decode(staged['payload']))
                        self.actors[key]['position']=staged['entry'][:]
                    elif key in self.escrow:self.actors[key]=self.escrow.pop(key)['state']
                    else:self.actors[key]=dict(id=a['id'],position=[120,1,0],hp=100,sequence=-1,jetpack={'cooldown':4.25})
                self.actors[key]['generation']=a['generation']
            for key in list(self.actors):
                a=self.grants.get(key)
                if a is None or a.get('district')!=self.district or a['phase']=='committed':self.actors.pop(key)
            return {}
        if time.monotonic()>=self.until:raise ValueError('Worker lease expired')
        if op=='stage':
            if hashlib.sha256(m['payload'].encode()).hexdigest()!=m['digest']:raise ValueError('Migration checksum mismatch')
            if m['tx'] in self.staged and self.staged[m['tx']]['digest']!=m['digest']:raise ValueError('Conflicting stage')
            self.staged[m['tx']]=dict(m)
            return {'prepared':True}
        key=next((k for k,a in self.actors.items() if a['id']==m.get('id')),m.get('actor'))
        if op=='freeze':
            if key in self.escrow:
                if self.escrow[key]['tx']!=m['tx']:raise ValueError('Different escrow')
                state=self.escrow[key]['state']
            else:
                state=self.actors.get(key)
                if state is None or state['generation']!=m['generation']:raise ValueError('No matching resident')
                if sum((a-b)**2 for a,b in zip(state['position'],m['exit']))>64:raise ValueError('Actor is not at the gate')
                self.escrow[key]=dict(tx=m['tx'],state=state)
                del self.actors[key]
            return {'payload':base64.b64encode(json.dumps(state,sort_keys=True).encode()).decode()}
        if op=='release':
            self.escrow.pop(m['actor'],None);self.actors.pop(m['actor'],None);self.retired[m['id']]=self.grants.get(m.get('actor',key),{}).get('generation',1)
            return {'released':True}
        if op=='retire':
            if key:self.actors.pop(key,None)
            self.retired[m['id']]=self.grants.get(m.get('actor',key),{}).get('generation',1);return {'retired':True}
        actor=self.actors.get(key)
        if actor is None or actor['generation']!=m.get('generation'):raise ValueError('Actor generation not active')
        if op=='respawn':
            if actor['hp']>0:raise ValueError('Living actor cannot respawn')
            actor['hp']=100;return {'respawned':True}
        if op=='input':
            command=m['command']
            if command['seq']<=actor['sequence']:return {'accepted':False}
            actor['sequence']=command['seq']
            actor['position'][0]+=command.get('move',[0,0])[0]*.2
            actor['position'][2]+=command.get('move',[0,0])[1]*.2
            return {'accepted':True}
        raise ValueError('Unknown worker operation')

    async def run(self):
        row=self.config['districts'][self.district]
        reader,self.writer=await asyncio.open_connection(*self.config['gateways'][row['gateway']]['address'],limit=LIMIT)
        await self.write(dict(op='worker',district=self.district,instance=self.instance,token=self.config['worker_tokens'][self.district]))
        task=asyncio.create_task(self.snapshot())
        try:
            while True:
                message=await read(reader,10)
                try:
                    result=self.command(message)
                    if message.get('op')=='stage' and self.fail_after_stage:
                        self.fail_after_stage=False
                        raise ConnectionError('Injected lost prepared acknowledgment')
                    if 'request' in message:await self.write(dict(request=message['request'],result=result))
                except ValueError as error:
                    if 'request' in message:await self.write(dict(request=message['request'],error=str(error)))
        finally:
            task.cancel();await asyncio.gather(task,return_exceptions=True)
            self.writer.close();await self.writer.wait_closed()
