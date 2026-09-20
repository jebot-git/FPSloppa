"""Master-owned moderator grants and durable, capacity-preserving move orders."""
import hashlib,hmac,secrets
SESSION_SECONDS=3600

def verifier(password,salt=None):
    if not isinstance(password,str) or not 10<=len(password)<=256:raise ValueError('Use a moderator password of 10–256 characters')
    salt=salt or secrets.token_bytes(16)
    digest=hashlib.scrypt(password.encode(),salt=salt,n=16384,r=8,p=1,dklen=32)
    return 'scrypt$'+salt.hex()+'$'+digest.hex()

def verify(password,encoded):
    try:
        _,salt,digest=encoded.split('$')
        return hmac.compare_digest(verifier(password,bytes.fromhex(salt)),encoded)
    except (ValueError,TypeError,AttributeError):return False

def audit(state,now,issuer,action,subject,result):
    log=state.setdefault('moderation_audit',[])
    log.append(dict(at=now,moderator=issuer,action=action,player=subject,result=result))
    del log[:-64]

def authorize(actor,message,now):
    from .model import require
    grant=actor.get('_moderator',{})
    token=message.get('moderator_token')
    require(isinstance(token,str) and grant.get('until',0)>now and grant.get('config')==message.get('_moderator_config')
        and hmac.compare_digest(grant.get('hash',''),hashlib.sha256(token.encode()).hexdigest()),'Moderator session expired or unauthorized')

def apply(state,message,actor,now):
    from . import model
    op=message['op'];key=message['actor']
    if op=='moderator_login':
        token=message.get('_moderator_grant')
        model.require(isinstance(token,str) and len(token)==64 and message.get('_moderator_config'),'Master password verification required')
        actor['_moderator']=dict(hash=hashlib.sha256(token.encode()).hexdigest(),until=now+SESSION_SECONDS,config=message['_moderator_config'])
        audit(state,now,actor['id'],'login',actor['id'],'authorized')
        return dict(moderator_token=token,expires=now+SESSION_SECONDS)
    authorize(actor,message,now)
    if op=='moderator_logout':
        actor.pop('_moderator',None)
        if state.get('global_voice',{}).get('actor')==key:state.pop('global_voice',None)
        return dict(locked=True)
    if op=='moderator_list':
        return dict(players=[dict(id=a['id'],name=a['name'],team=a.get('team',0),district=a.get('district'),phase=a['phase']) for a in state['actors'].values()],
            districts=[dict(id=d,name=r.get('name',d),online=model.online(state,d,now),count=model.counts(state)[d]) for d,r in state['districts'].items()],
            audit=state.get('moderation_audit',[])[-12:])
    if op=='moderator_voice_claim':
        old=state.get('global_voice',{})
        model.require(old.get('until',0)<=now or old.get('actor')==key,'Another moderator is broadcasting')
        state['global_voice']=dict(actor=key,id=actor['id'],name=actor['name'],gateway=actor['gateway'],until=now+2,stream=actor['_moderator']['hash'][:24])
        return state['global_voice']
    if op=='moderator_move':
        action=message.get('action');selected=next(((k,a) for k,a in state['actors'].items() if a['id']==message.get('player')),None)
        model.require(action in ('district','goto','bring'),'Unknown moderator action')
        model.require(actor['phase']=='active','Spawn before using teleport controls')
        if action=='district':subject_key,subject=key,actor;target=message.get('district');anchor=None
        else:
            model.require(selected is not None,'Player is no longer connected')
            selected_key,selected_actor=selected
            model.require(selected_actor['phase']=='active','Player must finish spawning or transferring first')
            if action=='goto':subject_key,subject=key,actor;target=selected_actor['district'];anchor=selected_actor['id']
            else:subject_key,subject=selected_key,selected_actor;target=actor['district'];anchor=actor['id']
        model.require(subject.get('mod_move') is None,'A moderator move is already pending')
        model.require(target in state['districts'] and model.online(state,target,now),'Destination unavailable or draining')
        model.require(target==subject['district'] or model.counts(state)[target]<model.CAPACITY,'Destination is full (16 players)')
        order=dict(id=secrets.token_hex(16),issuer=key,moderator=actor['id'],target=target,anchor=anchor,until=now+30,action=action)
        subject['mod_move']=order
        audit(state,now,actor['id'],action,subject['id'],'queued')
        return dict(queued=True,order=order['id'],player=subject['id'],district=target)
    raise model.Rejected('Unknown moderator operation')
