"""Durable campaign clock and rules, advanced inside the coordinator's CAS.

Workers report identities inside the circle, never points or ownership. Reports
expire after one second; duplicates cannot extend them. UTC boundaries and
capture/lockdown events are processed in chronological order, including restart.
"""
import copy
import math
from .world import atlas, HUB

DAY = 86400
HOUR = 3600
REPORT_TTL = 1.0
PLAYER_LIMIT = 128


def new(now, epoch=1, history=None):
    return dict(epoch=epoch, started=now, at=now, next_award=(math.floor(now/DAY)+1)*DAY,
        scores=[0,0], history=history or [], points={d:[0.,0.] for d,r in atlas().items() if r['threshold']},
        owners={d:r['initial_owner'] if r['campaign_role'] in ('homebase','perimeter') else -1 for d,r in atlas().items()},
        holds={}, locks={}, reports={})


def enabled(state):
    return any(r.get('campaign_role')=='hub' for r in state['districts'].values())


def can_enter(state, actor, target, source=None):
    if not state.get('campaign'):return True
    c=state['campaign'];rows=state['districts'];team=actor['team'];row=rows[target]
    if source and target in rows[source].get('terminals',{}):
        return c['owners'].get(target)==team
    if row.get('campaign_role')=='homebase':
        return c['owners'][target]==team or all(c['owners'].get(d)==team for d in row['perimeter'])
    return True


def can_spawn(state, actor, district):
    return 'campaign' not in state or state['campaign']['owners'].get(district)==actor['team']


def neutral_spawn(state, district):
    """Only non-capturable neutral territory is a reinforcement fallback."""
    return ('campaign' in state
            and state['districts'][district].get('campaign_role') in ('hub', 'outskirts')
            and state['campaign']['owners'].get(district) == -1)


def wait(actor):
    actor.update(preferred=actor.get('district') or actor['preferred'], district=None, phase='waiting', generation=actor['generation']+1, arrival=None)
    actor.pop('reset_pending',None)
    actor.pop('entry_kind',None);actor.pop('spawn_location',None);actor['last_location']=None


def reset(state, at, winners):
    old=state['campaign']
    history=(old['history']+[dict(epoch=old['epoch'],started=old['started'],ended=at,scores=old['scores'][:],winner=winners[0] if len(winners)==1 else -1)])[-32:]
    state['campaign']=new(at,old['epoch']+1,history)
    for actor in state['actors'].values():
        if actor['phase']=='active':wait(actor)
        elif actor['phase'] in ('moving','committed'):actor['reset_pending']=True


def teams_present(state,district,t):
    c=state['campaign'];report=c['reports'].get(district,{})
    if report.get('until',0)<=t:return [False,False]
    present=[False,False]
    for key,generation in report.get('actors',{}).items():
        a=state['actors'].get(key,{})
        if a.get('district')==district and a.get('phase')=='active' and a.get('generation')==generation:
            present[a['team']]=True
    return present


def advance(state, now):
    if not enabled(state):return
    if 'campaign' not in state:state['campaign']=new(now)
    c=state['campaign'];t=c['at'];now=max(now,t)
    while True:
        c=state['campaign'];owners=c['owners'];rows=state['districts']
        # Expiring lockdowns start a fresh holding interval even if still held.
        for base,lock in list(c['locks'].items()):
            if lock['until']<=t:del c['locks'][base];c['holds'].pop(base,None)
        for base,row in rows.items():
            if row.get('campaign_role')!='homebase':continue
            team=owners[base];secure=team in (0,1) and all(owners.get(d)==team for d in row['perimeter'])
            if not secure:c['holds'].pop(base,None)
            elif base not in c['locks']:
                hold=c['holds'].setdefault(base,dict(team=team,since=t))
                if hold['team']!=team:c['holds'][base]=dict(team=team,since=t)
                elif hold['since']+HOUR<=t:c['locks'][base]=dict(team=team,until=t+HOUR);c['holds'].pop(base,None)
        # Ownership at the boundary determines the daily award. No instant win.
        if c['next_award']<=t:
            for d,row in rows.items():
                team=owners[d]
                if row.get('campaign_role')=='homebase' and team in (0,1):c['scores'][team]+=1
            c['next_award']+=DAY
            winners=[team for team in (0,1) if c['scores'][team]>=20]
            if winners:reset(state,t,winners);continue
        rates={}
        for d,points in c['points'].items():
            present=teams_present(state,d,t)
            for team in (0,1):
                if not present[team]:points[team]=0.
            if sum(present)!=1:continue
            team=present.index(True);row=rows[d]
            lock=c['locks'].get(row.get('homebase'),{})
            if owners[d]==team:continue
            if (lock and lock['team']!=team) or (row['campaign_role']=='homebase' and not can_enter(state,{'team':team},d)):
                points[team]=0.;continue
            rates[d]=team
        if t>=now:break
        end=min([now,c['next_award']]+[r['until'] for r in c['reports'].values() if r['until']>t]+[r['until'] for r in c['locks'].values()]+[h['since']+HOUR for h in c['holds'].values()]+[t+rows[d]['threshold']-c['points'][d][team] for d,team in rates.items()])
        for d,team in rates.items():
            c['points'][d][team]+=end-t
            if c['points'][d][team]>=rows[d]['threshold']-1e-7:
                owners[d]=team;c['points'][d]=[0.,0.]
        t=end;c['at']=t


def report(state,district,data,instance,now):
    from .model import require, integer
    if 'campaign' not in state:return
    c=state['campaign']
    if district not in c['points']:return
    require(isinstance(data,dict) and integer(data.get('sequence'),0,2147483647), 'Invalid capture report')
    if data.get('epoch')!=c['epoch']:return
    actors=data.get('actors')
    require(isinstance(actors,dict) and len(actors)<=16 and all(isinstance(k,str) and integer(v,1,2147483647) for k,v in actors.items()), 'Invalid capture occupants')
    previous=c['reports'].get(district,{})
    if previous.get('instance')==instance and data['sequence']<=previous.get('sequence',-1):return
    # Gateway sets received_at when the authenticated worker frame arrives;
    # retries cannot make an old frame fresh. Unbounded future clocks fail shut.
    stamp=data.get('received_at')
    require(type(stamp) in (int,float) and math.isfinite(stamp) and stamp<=now+.1, 'Invalid capture timestamp')
    c['reports'][district]=dict(instance=instance,sequence=data['sequence'],actors=actors,until=min(now+REPORT_TTL,stamp+REPORT_TTL))


def public(state):
    if 'campaign' not in state:return None
    return {k:copy.deepcopy(v) for k,v in state['campaign'].items() if k!='reports'}
