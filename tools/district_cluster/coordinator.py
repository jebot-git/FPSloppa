import asyncio
import hmac
import time
import hashlib
import secrets
from . import status_page,moderation
from .transport import LIMIT,read,send


class Coordinator:
    def __init__(self,config,store):
        self.config,self.store=config,store
        self.connections=0
        self.last_page=0
        self.login_attempts={};self.global_login=[]

    async def connection(self,reader,writer):
        self.connections+=1
        try:
            if self.connections>128:
                return
            message=await read(reader)
            token=message.pop('token','')
            if not isinstance(token,str):
                raise ValueError('Invalid credential')
            gateway=next((key for key,row in self.config['gateways'].items() if hmac.compare_digest(token,row['token'])),False)
            if hmac.compare_digest(token,self.config['admin_token']):
                gateway=None
            if gateway is False:
                raise ValueError('Unauthorized coordinator request')
            # Never accept internal authorization flags from a regional/client request.
            for key in list(message):
                if key.startswith('_moderator'):message.pop(key)
            encoded=self.config.get('moderator_password_hash','')
            message['_moderator_config']=hashlib.sha256(encoded.encode()).hexdigest() if encoded else ''
            if message.get('op')=='moderator_login':
                identity=await asyncio.to_thread(self.store.execute,dict(message,op='locate'),gateway)
                if identity['gateway']!=gateway:raise ValueError('Reconnect to your owning gateway')
                now=time.monotonic();key=message.get('actor')
                attempts=[v for v in self.login_attempts.get(key,[]) if now-v<60]
                self.global_login=[v for v in self.global_login if now-v<10]
                if len(attempts)>=5 or len(self.global_login)>=10:raise ValueError('Moderator login rate limit; retry in a minute')
                self.login_attempts[key]=attempts+[now];self.global_login.append(now)
                if len(self.login_attempts)>256:self.login_attempts={k:v for k,v in self.login_attempts.items() if v[-1]>now-60}
                password=message.pop('password',None)
                if not encoded or not await asyncio.to_thread(moderation.verify,password,encoded):raise ValueError('Moderator password rejected or moderation disabled')
                message['_moderator_grant']=secrets.token_hex(32)
            if message.get('op')=='topology'  and isinstance(message.get('districts'),dict):
                if any(d not in self.config['worker_tokens'] or not isinstance(row,dict) or row.get('gateway') not in self.config['gateways'] for d,row in message['districts'].items()):
                    raise ValueError('Topology uses an unprovisioned district or gateway identity')
            result=await asyncio.to_thread(self.store.execute,message,gateway)
            await send(writer,{'result':result})
        except (ValueError,KeyError,TypeError,ConnectionError,TimeoutError) as error:
            try:
                await send(writer,{'error':str(error)})
            except (OSError,TimeoutError):
                pass
        finally:
            self.connections-=1
            writer.close()
            await writer.wait_closed()

    async def start(self,address):
        self.clock_task=asyncio.create_task(self.clock()) if any(r.get('campaign_role') for r in self.config['districts'].values()) else None
        return await asyncio.start_server(self.connection,*address,limit=LIMIT)

    async def clock(self):
        while True:
            try:
                await asyncio.to_thread(self.store.execute,{'op':'tick'},None)
                if self.config.get('status_file') and time.monotonic()-self.last_page>=5:
                    state=await asyncio.to_thread(self.store.execute,{'op':'status'},None)
                    await asyncio.to_thread(status_page.write,self.config['status_file'],state,time.time())
                    self.last_page=time.monotonic()
            except (OSError,ValueError,ConnectionError):pass
            await asyncio.sleep(.25)
