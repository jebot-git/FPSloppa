"""Bounded moderator PCM voice fanout; no media stored in the coordinator."""
import asyncio,base64,collections,time
from .transport import rpc

class GlobalVoice:
    def __init__(self,gateway):
        self.g=gateway;self.grant={};self.checked=0;self.ring=collections.deque(maxlen=24);self.cursor=0;self.queue=asyncio.Queue(maxsize=2);self.task=None;self.last={};self.deliveries={}
    async def push(self,message):
        g=self.g;g.actor(message);g.rate_limit(message['actor'],'voice',10,3)
        packet=message.get('pcm');sequence=message.get('sequence')
        if not isinstance(packet,str) or len(packet)>4300 or type(sequence) is not int or not 0<=sequence<=2147483647:raise ValueError('Invalid voice frame')
        try:raw=base64.b64decode(packet,validate=True)
        except ValueError:raise ValueError('Invalid voice frame')
        if len(raw)!=3200:raise ValueError('Voice requires 100 ms mono PCM16 at 16 kHz')
        now=time.monotonic();signature=(message['actor'],message.get('moderator_token'))
        if self.grant.get('auth')!=signature or now-self.checked>.75:
            self.grant=await g.control('moderator_voice_claim',actor=message['actor'],resume=message['resume'],moderator_token=message.get('moderator_token'))
            self.grant['auth']=signature;self.checked=now
        frame={k:self.grant[k] for k in ('actor','id','name','gateway','stream','until')};frame.update(sequence=sequence,pcm=packet)
        await self.receive(frame,local=True)
        if self.queue.full():self.queue.get_nowait()
        self.queue.put_nowait(frame)
        if self.task is None or self.task.done():self.task=asyncio.create_task(self.fanout())
        return {'sent':True}
    async def fanout(self):
        while not self.queue.empty():
            frame=await self.queue.get()
            async def deliver(name,row,packet):
                if name==self.g.name:return
                try:await asyncio.wait_for(rpc(row['address'],dict(op='mesh',action='voice',token=self.g.config['mesh_token'],frame=packet)),.3)
                except (ValueError,OSError,TimeoutError):pass
            for name,row in self.g.config['gateways'].items():
                if name==self.g.name:continue
                pending=self.deliveries.get(name)
                if pending is not None and not pending.done():continue
                # One bounded in-flight frame per region. An unreachable region
                # cannot stall speech to healthy regions or grow a media queue.
                self.deliveries[name]=asyncio.create_task(deliver(name,row,frame))
    async def receive(self,frame,local=False):
        if not isinstance(frame,dict) or not isinstance(frame.get('pcm'),str) or len(frame['pcm'])>4300 or type(frame.get('sequence')) is not int:raise ValueError('Invalid voice frame')
        if not local:
            # The live master lease authorizes the speaker, including across regions.
            now=time.monotonic()
            if self.grant.get('stream')!=frame.get('stream') or now-self.checked>.75:
                self.grant=await self.g.control('voice_status');self.checked=now
            if any(self.grant.get(k)!=frame.get(k) for k in ('actor','gateway','stream')) or self.grant.get('until',0)<time.time():raise ValueError('Voice grant expired')
        key=frame['stream'];sequence=frame['sequence']
        if sequence<=self.last.get(key,-1):return
        self.last[key]=sequence
        if len(self.last)>4:self.last={key:sequence}
        self.cursor+=1;self.ring.append(dict(cursor=self.cursor,at=time.monotonic(),**frame))
    def poll(self,message):
        self.g.actor(message);self.g.rate_limit(message['actor'],'voice_poll',12,3)
        cursor=message.get('cursor',0)
        if type(cursor) is not int:raise ValueError('Invalid voice cursor')
        now=time.monotonic()
        rows=[{k:r[k] for k in ('cursor','id','name','stream','sequence','pcm')} for r in self.ring if r['cursor']>cursor and now-r['at']<.35]
        return dict(cursor=self.cursor,frames=rows[-3:])
