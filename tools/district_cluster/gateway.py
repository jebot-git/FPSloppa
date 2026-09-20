"""Regional data plane: at most four workers, district-local snapshot caches.

The first transport adapter uses bounded private TCP/JSON. It is deliberately
separate from the shipping ENet client protocol; see the cluster README.
"""
import asyncio
import hashlib
import hmac
import math
import secrets
import time
from .transport import LIMIT,read,send,rpc,encode
from . import campaign


class WorkerLink:
    def __init__(self,writer,instance):
        self.writer,self.instance=writer,instance
        self.pending={}
        self.last=time.monotonic()
        self.lock=asyncio.Lock()
        self.capture=None

    async def write(self,message):
        async with self.lock:
            await send(self.writer,message)

    async def call(self,op,**fields):
        key=secrets.token_hex(12)
        future=asyncio.get_running_loop().create_future()
        self.pending[key]=future
        try:
            await self.write(dict(op=op,request=key,**fields))
            return await asyncio.wait_for(future,2)
        finally:
            self.pending.pop(key,None)


class Gateway:
    def __init__(self,config,name):
        self.config,self.name=config,name
        self.settings=config['gateways'][name]
        self.session=secrets.token_hex(16)
        self.workers={}
        self.clients={}
        self.locks={}
        self.cache={}
        self.state={'districts':{},'actors':{}}
        self.fresh=0
        self.connections=0
        self.refresh_lock=asyncio.Lock()
        self.control_lock=asyncio.Lock()
        self.deployment_signature=None
        self.budgets={}
        self.stats=dict(snapshot_encodes=0,snapshot_deliveries=0,inputs=0,transfers=0)

    async def control(self,op,**fields):
        async with self.control_lock:
            return await self._control(op,**fields)

    async def _control(self,op,**fields):
        message=dict(op=op,token=self.settings['token'],session=self.session,**fields)
        last=None
        for address in self.config['coordinators']:
            try:
                return await rpc(address,message)
            except (OSError,TimeoutError) as error:
                last=error
        raise ConnectionError('No coordinator frontend available') from last

    async def refresh(self):
        async with self.refresh_lock:
            await self._refresh()

    async def _refresh(self):
        began=time.monotonic()
        live={d:w.instance for d,w in self.workers.items() if began-w.last<2}
        captures={d:w.capture for d,w in self.workers.items() if d in live and w.capture is not None}
        self.state=await self.control('heartbeat',workers=live,captures=captures)
        self.fresh=began  # Never start a fresh lease from an old delayed reply.
        for key in list(self.clients):
            if key not in self.state['actors']:
                self.clients.pop(key,None);self.budgets.pop((key,'input'),None);self.budgets.pop((key,'snapshot'),None)
                if key in self.locks and not self.locks[key].locked():self.locks.pop(key)
        left=2-(time.monotonic()-began)
        if left<=0:
            return
        for district,worker in list(self.workers.items()):
            row=self.state['districts'].get(district)
            if row is None or row['gateway']!=self.name:
                continue
            actors={k:a for k,a in self.state['actors'].items() if district in (a.get('district'),a.get('target'),a.get('previous'))}
            await worker.write(dict(op='authority',revision=self.state['revision'],valid_for=max(0,2-(time.monotonic()-began)),expires_at=time.time()+max(0,2-(time.monotonic()-began)),district=district,metadata=row,actors=actors,campaign=self.state.get('campaign')))

    async def heartbeat(self):
        while True:
            try:
                await self.refresh()
                signature=(self.state['deployment_signature'],tuple(k for k,a in self.state['actors'].items() if a['phase']=='waiting'))
                if signature!=self.deployment_signature:
                    self.deployment_signature=signature
                    if self.state['deployment_slots']>0:
                        for key,actor in sorted(self.state['actors'].items(),key=lambda item:item[1]['id']):
                            if actor['phase']=='waiting' and actor['gateway']==self.name and key in self.clients:
                                self.state['actors'][key]=await self.control('deploy',actor=key,resume=self.clients[key])
            except ValueError as error:
                if 'lease expired' in str(error):
                    try:await self.control('register_gateway')
                    except (OSError,ValueError,TimeoutError):pass
            except (OSError,TimeoutError):
                pass  # Cached authority expires; never extend it on failure.
            await asyncio.sleep(.4)

    def actor(self,message):
        key=message.get('actor')
        secret=self.clients.get(key)
        if not isinstance(message.get('resume'),str) or secret is None or not hmac.compare_digest(secret,message['resume']):
            raise ValueError('Resume through this gateway first')
        if time.monotonic()-self.fresh>=2:
            raise ValueError('Coordinator authority unavailable')
        actor=self.state['actors'].get(key)
        if actor is None or actor['gateway']!=self.name:
            raise ValueError('Actor moved; reconnect to its owning gateway')
        return actor

    def rate_limit(self,key,kind,rate,burst):
        now=time.monotonic()
        tokens,at=self.budgets.get((key,kind),(burst,now))
        tokens=min(burst,tokens+(now-at)*rate)
        if tokens<1:
            raise ValueError('Regional request rate exceeded')
        self.budgets[(key,kind)]=(tokens-1,now)

    async def worker_connection(self,hello,reader,writer):
        district=hello.get('district')
        token=self.config['worker_tokens'].get(district)
        if token is None or not isinstance(hello.get('token'),str) or not hmac.compare_digest(token,hello['token']):
            raise ValueError('Invalid worker credential')
        row=self.state['districts'].get(district)
        if row is None or row['gateway']!=self.name or district in self.workers:
            raise ValueError('District unassigned or worker already connected')
        instance=hello.get('instance','')
        if not isinstance(instance,str) or not 1<=len(instance)<=64 or not instance.isalnum():
            raise ValueError('Invalid worker incarnation')
        link=WorkerLink(writer,instance)
        self.workers[district]=link
        await link.write(dict(op='welcome',district=district,map_slot=row['map_slot']))
        try:
            while True:
                message=await read(reader,4)
                link.last=time.monotonic()
                if 'request' in message:
                    future=link.pending.get(message['request'])
                    if future is not None and not future.done():
                        if 'error' in message:future.set_exception(ValueError(message['error']))
                        else:future.set_result(message.get('result',{}))
                elif message.get('op')=='snapshot':
                    payload=message.get('payload')
                    if not isinstance(payload,str) or len(payload)>512000:
                        raise ValueError('Invalid snapshot payload')
                    previous=self.cache.get(district,{})
                    sequence=message.get('sequence')
                    if type(sequence) is not int or sequence<=previous.get('sequence',-1):
                        continue
                    # Encode once per district frame; recipients receive identical bytes.
                    actors={k:a['generation'] for k,a in self.state['actors'].items() if a.get('district')==district and a['phase']=='active'}
                    result=dict(district=district,sequence=sequence,payload=payload,actors=actors,campaign=self.state.get('campaign'))
                    self.cache[district]=dict(sequence=sequence,at=time.monotonic(),bytes=encode({'result':result}))
                    self.stats['snapshot_encodes']+=1
                elif message.get('op')=='capture':
                    data=message.get('capture')
                    if not isinstance(data,dict) or not isinstance(data.get('actors'),dict) or len(data['actors'])>16:raise ValueError('Invalid worker capture frame')
                    if type(data.get('sequence')) is not int:raise ValueError('Invalid capture sequence')
                    if link.capture is None or data['sequence']>link.capture['sequence']:
                        link.capture=dict(data,received_at=time.time())
        finally:
            if self.workers.get(district) is link:
                del self.workers[district]
                self.cache.pop(district,None)
            for future in link.pending.values():
                if not future.done():future.set_exception(ConnectionError('Worker disconnected'))

    async def local(self,district,op,**fields):
        worker=self.workers.get(district)
        if worker is None or time.monotonic()-worker.last>=2:
            raise ValueError('Worker unavailable; reservation retained')
        return await worker.call(op,**fields)

    async def remote(self,district,op,**fields):
        row=self.state['districts'][district]
        if row['gateway']==self.name:
            await self.refresh()
            return await self.local(district,op,**fields)
        address=self.config['gateways'][row['gateway']]['address']
        return await rpc(address,dict(op='mesh',action=op,district=district,token=self.config['mesh_token'],**fields))

    async def transfer(self,message):
        key=message['actor']
        async with self.locks.setdefault(key,asyncio.Lock()):
            actor=self.actor(message)
            auth=dict(actor=key,resume=message['resume'])
            if actor['phase']=='active':
                tx=secrets.token_hex(16)
                actor=await self.control('begin',**auth,target=message.get('target'),tx=tx)
            else:
                tx=actor.get('tx')
                if actor['phase'] not in ('moving','committed') or message.get('target') not in (actor.get('target'),actor.get('district')):
                    raise ValueError('Cannot transfer this actor')
            self.state['actors'][key]=actor
            if actor['phase']=='moving':
                source,target=actor['district'],actor['target']
                row=self.state['districts'][source]
                edge=(row['links']|row.get('terminals',{}))[target]
                try:
                    frozen=await self.local(source,'freeze',actor=key,id=actor['id'],generation=actor['generation'],tx=tx,exit=edge['exit'],terminal=edge.get('terminal',False))
                except ValueError:
                    # A definite refusal precedes escrow; transport uncertainty must not abort.
                    actor=await self.control('abort',**auth,tx=tx)
                    self.state['actors'][key]=actor
                    raise
                payload=frozen['payload']
                if not isinstance(payload,str) or len(payload)>512000:
                    raise ValueError('Invalid migration payload')
                digest=hashlib.sha256(payload.encode()).hexdigest()
                await self.control('prepared',**auth,tx=tx,digest=digest)
                await self.remote(target,'stage',actor=key,id=actor['id'],tx=tx,generation=actor['next_generation'],payload=payload,digest=digest,entry=edge['entry'],exit=edge['exit'],yaw=edge.get('yaw',0))
                try:actor=await self.control('commit',**auth,tx=tx)
                except ValueError as error:
                    if 'Campaign gate locked' in str(error):
                        self.state['actors'][key]=await self.control('abort',**auth,tx=tx)
                        await self.refresh()
                    raise
                self.state['actors'][key]=actor
            # A durable commit is never rolled back. Retry release/finish after interruption.
            await self.local(actor['previous'],'release',actor=key,id=actor['id'],generation=actor['generation']-1,tx=tx)
            actor=await self.control('finish',**auth,tx=tx)
            self.state['actors'][key]=actor
            self.stats['transfers']+=1
            return dict(actor=actor,gateway=self.config['gateways'][actor['gateway']]['address'])

    async def request(self,message):
        op=message.get('op')
        if op=='mesh':
            if not isinstance(message.get('token'),str) or not hmac.compare_digest(message['token'],self.config['mesh_token']):
                raise ValueError('Invalid regional credential')
            if message.get('action')!='stage':
                raise ValueError('Invalid regional action')
            await self.refresh()
            actor=self.state['actors'].get(message.get('actor'),{})
            if actor.get('phase')!='moving' or actor.get('target')!=message.get('district') or actor.get('tx')!=message.get('tx') or actor.get('digest')!=message.get('digest'):
                raise ValueError('Stage has no matching reservation')
            return await self.local(message['district'],'stage',**{k:v for k,v in message.items() if k not in ('op','action','district','token')})
        if op=='join':
            if not isinstance(message.get('token'),str) or not hmac.compare_digest(message['token'],self.config['client_token']):
                raise ValueError('Invalid cluster access credential')
            key,resume=message.get('identity',secrets.token_hex(16)),message.get('resume',secrets.token_hex(32))
            actor=await self.control('join',actor=key,resume=resume,district=message.get('district'),name=message.get('name','Player'),team=message.get('team'))
            self.clients[key]=resume;self.state['actors'][key]=actor
            return dict(identity=key,resume=resume,actor=actor,gateway=self.config['gateways'][actor['gateway']]['address'])
        if op=='resume':
            actor=await self.control('locate',actor=message.get('actor'),resume=message.get('resume'))
            if actor['gateway']!=self.name:
                return dict(redirect=self.config['gateways'][actor['gateway']]['address'],actor=actor)
            self.clients[message['actor']]=message['resume'];self.state['actors'][message['actor']]=actor
            return actor
        actor=self.actor(message)
        if op=='status':
            district=actor.get('district')
            row=self.state['districts'].get(district,{})
            links={k:dict(open=self.state['districts'][k]['open'] and (not self.state.get('campaign') or campaign.can_enter(self.state,actor,k,district)),gateway=self.config['gateways'][self.state['districts'][k]['gateway']]['address'],terminal=edge.get('terminal',False),owner=(self.state.get('campaign') or {}).get('owners',{}).get(k,-1)) for k,edge in (row.get('links',{})|row.get('terminals',{})).items()}
            return dict(actor=actor,links=links,stats=self.stats,campaign=self.state.get('campaign'),metadata=row)
        if op=='transfer':
            return await self.transfer(message)
        if op=='deploy':
            actor=await self.control('deploy',actor=message['actor'],resume=message['resume'])
            self.state['actors'][message['actor']]=actor
            return dict(actor=actor,gateway=self.config['gateways'][actor['gateway']]['address'])
        if op=='leave':
            if actor['phase'] not in ('active','waiting'):
                raise ValueError('Resolve transfer first')
            if actor['district'] is not None:
                await self.local(actor['district'],'retire',id=actor['id'],generation=actor['generation'])
            result=await self.control('leave',actor=message['actor'],resume=message['resume'])
            self.clients.pop(message['actor'],None);self.state['actors'].pop(message['actor'],None);self.locks.pop(message['actor'],None)
            return result
        if op=='respawn':
            if actor['phase']!='active':raise ValueError('Actor is not resident')
            if self.state.get('campaign'):
                await self.local(actor['district'],'check_dead',id=actor['id'],generation=actor['generation'])
                actor=await self.control('wait',actor=message['actor'],resume=message['resume'])
                self.state['actors'][message['actor']]=actor
                await self.refresh()
                actor=await self.control('deploy',actor=message['actor'],resume=message['resume'])
                self.state['actors'][message['actor']]=actor
                return dict(actor=actor,gateway=self.config['gateways'][actor['gateway']]['address'])
            # Worker validates death; same-district respawn reuses its existing slot.
            return await self.local(actor['district'],'respawn',id=actor['id'],generation=actor['generation'])
        if op=='input':
            self.rate_limit(message['actor'],'input',60,12)
            if actor['phase']!='active' or message.get('generation')!=actor['generation']:
                raise ValueError('Stale actor generation')
            command=message.get('command')
            if not isinstance(command,dict):raise ValueError('Invalid input')
            if set(command)-{'seq','move','yaw','pitch','fire','jump','weapon'}:raise ValueError('Unknown input field')
            if type(command.get('seq')) is not int or not 0<=command['seq']<=2147483647:raise ValueError('Invalid input sequence')
            move=command.get('move',[0,0])
            if not isinstance(move,list) or len(move)!=2 or any(type(x) not in (int,float) or not math.isfinite(x) or abs(x)>1 for x in move):raise ValueError('Invalid movement')
            for field in ('yaw','pitch'):
                if type(command.get(field,0)) not in (int,float) or not math.isfinite(command.get(field,0)):raise ValueError('Invalid aim')
            for field in ('fire','jump'):
                if type(command.get(field,False)) is not bool:raise ValueError('Invalid button')
            if type(command.get('weapon',2)) is not int or not 0<=command.get('weapon',2)<=64:raise ValueError('Invalid weapon')
            result=await self.local(actor['district'],'input',id=actor['id'],generation=actor['generation'],command=command)
            self.stats['inputs']+=1
            return result
        raise ValueError('Unknown client operation')

    async def connection(self,reader,writer):
        self.connections+=1
        try:
            if self.connections>256:return
            message=await read(reader)
            if message.get('op')=='worker':
                await self.worker_connection(message,reader,writer)
            elif message.get('op')=='snapshot':
                actor=self.actor(message)
                self.rate_limit(message['actor'],'snapshot',30,3)
                cached=self.cache.get(actor['district'])
                if actor['phase']!='active' or cached is None or time.monotonic()-cached['at']>1:
                    raise ValueError('District baseline unavailable')
                writer.write(cached['bytes'])
                await asyncio.wait_for(writer.drain(),3)
                self.stats['snapshot_deliveries']+=1
            else:
                await send(writer,{'result':await self.request(message)})
        except (OSError,ValueError,KeyError,TypeError,TimeoutError) as error:
            try:await send(writer,{'error':str(error)})
            except (OSError,TimeoutError):pass
        finally:
            self.connections-=1
            writer.close()
            try:await writer.wait_closed()
            except OSError:pass

    async def start(self):
        await self.control('register_gateway')
        await self.refresh()
        server=await asyncio.start_server(self.connection,*self.settings['address'],limit=LIMIT)
        self.task=asyncio.create_task(self.heartbeat())
        return server
