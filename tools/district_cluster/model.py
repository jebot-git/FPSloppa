"""Deterministic control state. No movement, snapshots or map geometry live here."""
import copy
import hashlib
import math

MAX_DISTRICTS = 64
MIN_DISTRICTS = 4
CAPACITY = 16
LEASE = 6.0  # Worker authority expires after at most 2 s; allow fencing margin.


class Rejected(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Rejected(message)


def integer(value, low, high):
    return type(value) is int and low <= value <= high


def identifier(value):
    return isinstance(value, str) and 0 < len(value) <= 64 and all(c.isalnum() or c in '-_' for c in value)


def topology(rows):
    require(isinstance(rows, dict) and MIN_DISTRICTS <= len(rows) <= MAX_DISTRICTS, 'Topology must contain 4–64 districts')
    for key, row in rows.items():
        require(identifier(key) and isinstance(row, dict), 'Invalid district identity')
        require(identifier(row.get('gateway')), 'Invalid gateway identity')
        require(integer(row.get('map_slot'), 0, 15), 'Map template must be one of the 16 existing district assets')
        require(isinstance(row.get('links'), dict) and len(row['links']) <= 4, 'At most four portal links per district')
        require(len([r for r in rows.values() if r.get('gateway') == row['gateway']]) <= 4, 'At most four districts per regional gateway')
        for neighbor, edge in row['links'].items():
            require(neighbor != key and neighbor in rows and key in rows[neighbor].get('links', {}), 'Portal links must be reciprocal')
            require(isinstance(edge, dict), 'Invalid portal metadata')
            for field in ('exit', 'entry'):
                point = edge.get(field)
                require(isinstance(point, list) and len(point) == 3 and all(type(x) in (int, float) and math.isfinite(x) and abs(x) <= 125 for x in point), 'Invalid local portal position')
            require(type(edge.get('yaw', 0)) in (int, float) and math.isfinite(edge.get('yaw', 0)), 'Invalid portal yaw')
    seen, pending = set(), [next(iter(rows))]
    while pending:
        d = pending.pop()
        if d not in seen:
            seen.add(d)
            pending.extend(rows[d]['links'])
    require(len(seen) == len(rows), 'Configured topology must be connected')


def initial(rows, waiting_limit=128):
    topology(rows)
    require(integer(waiting_limit, 0, 1024), 'Invalid waiting allowance')
    return dict(revision=0, districts=copy.deepcopy(rows), workers={}, gateways={}, actors={}, next_id=1000, waiting_limit=waiting_limit)


def counts(state):
    result = dict.fromkeys(state['districts'], 0)
    for actor in state['actors'].values():
        for district in {actor.get('district'), actor.get('target'), actor.get('previous')} - {None}:
            if district in result:
                result[district] += 1
    return result


def online(state, district, now, incoming=True):
    if district not in state['districts']:
        return False
    row = state['districts'][district]
    worker = state['workers'].get(district, {})
    gateway = state['gateways'].get(row['gateway'], {})
    return (worker.get('until', 0) > now and gateway.get('until', 0) > now
            and worker.get('gateway_session') == gateway.get('session')
            and (not incoming or not row.get('draining', False)))


def owned_gateway(state, district, gateway):
    require(district in state['districts'] and state['districts'][district]['gateway'] == gateway, 'District belongs to a different gateway')


def authenticate_actor(state, message):
    actor = state['actors'].get(message.get('actor'))
    require(actor is not None and isinstance(message.get('resume'), str)
            and hashlib.sha256(message['resume'].encode()).hexdigest() == actor['resume_hash'], 'Invalid actor session')
    return actor


def public_actor(actor):
    return {k: v for k, v in actor.items() if k != 'resume_hash'}


def apply(state, message, gateway, now):
    """Mutates a private transaction copy. Store commits only successful calls.

    gateway=None denotes the separate administrative credential.
    Every regional write is fenced by the gateway incarnation and lease.
    """
    op = message.get('op')
    if op == 'register_gateway':
        require(gateway is not None, 'Gateway credential required')
        require(identifier(message.get('session')), 'Invalid gateway incarnation')
        old = state['gateways'].get(gateway, {})
        require(old.get('until', 0) <= now or old.get('session') == message['session'], 'Previous gateway lease is still valid')
        state['gateways'][gateway] = dict(session=message['session'], until=now+LEASE)
        return {'lease': LEASE}
    if gateway is not None:
        lease = state['gateways'].get(gateway, {})
        require(lease.get('session') == message.get('session') and lease.get('until', 0) > now, 'Gateway fenced or lease expired')
    if op == 'heartbeat':
        require(gateway is not None, 'Gateway credential required')
        state['gateways'][gateway]['until'] = now+LEASE
        live = message.get('workers', {})
        require(isinstance(live, dict) and len(live) <= 4, 'Invalid regional heartbeat')
        for district, incarnation in live.items():
            owned_gateway(state, district, gateway)
            require(identifier(incarnation), 'Invalid worker incarnation')
            old = state['workers'].get(district, {})
            require(old.get('until', 0) <= now or (old.get('instance') == incarnation and old.get('gateway_session') == message['session']), 'Previous worker lease is still valid')
            state['workers'][district] = dict(instance=incarnation, gateway_session=message['session'], until=now+LEASE)
        # Missing workers are not immediately reassigned: let old authority expire.
        return view(state, gateway, now)
    if op == 'topology':
        require(gateway is None, 'Administrative credential required')
        rows = message.get('districts')
        topology(rows)
        occupancy = counts(state)
        for district, old in state['districts'].items():
            replacement=rows.get(district)
            relocated=replacement is None or any(replacement.get(k)!=old[k] for k in ('gateway','map_slot'))
            if relocated:
                require(occupancy[district]==0, 'Drain residents and pending transfers before removal or relocation')
                require(not online(state,district,now,incoming=False), 'Stop the drained worker and await its lease before removal or reassignment')
            if replacement is not None and replacement['links']!=old['links']:
                require(not any(a['phase'] in ('moving','committed') and district in (a.get('district'),a.get('target'),a.get('previous')) for a in state['actors'].values()), 'Resolve transfers before rewiring their portals')
        state['districts'] = copy.deepcopy(rows)
        state['workers'] = {k:v for k,v in state['workers'].items() if k in rows}
        return {'districts': len(rows)}
    if op == 'drain':
        require(gateway is None and message.get('district') in state['districts'], 'Unknown district or administrative credential required')
        state['districts'][message['district']]['draining'] = bool(message.get('enabled', True))
        return {'reservations': counts(state)[message['district']]}
    require(gateway is not None, 'Regional credential required')
    if op == 'join':
        key = message.get('actor')
        require(identifier(key) and identifier(message.get('resume')), 'Invalid new actor identity')
        if key in state['actors']:
            return public_actor(authenticate_actor(state, message))
        require(len(state['actors']) < 16*len(state['districts'])+state['waiting_limit'], 'Global connection/waiting budget full')
        district = message.get('district')
        owned_gateway(state, district, gateway)
        free = online(state, district, now) and counts(state)[district] < CAPACITY
        if not free:
            require(sum(a['phase']=='waiting' for a in state['actors'].values()) < state['waiting_limit'], 'Waiting budget full')
        require(state['next_id']<=2147483647, 'Actor identity namespace exhausted')
        actor = dict(id=state['next_id'], name=str(message.get('name','Player'))[:48], resume_hash=hashlib.sha256(message['resume'].encode()).hexdigest(), district=district if free else None, preferred=district, phase='active' if free else 'waiting', generation=1, arrival=None, gateway=gateway)
        state['next_id'] += 1
        state['actors'][key] = actor
        return public_actor(actor)
    actor = authenticate_actor(state, message)
    if op == 'locate':
        return public_actor(actor)
    if op == 'resume':
        require(actor['gateway'] == gateway, 'Reconnect to the owning regional gateway')
        return public_actor(actor)
    if op == 'finish' and actor['phase']=='active' and actor.get('arrival')==message.get('tx'):
        return public_actor(actor)
    require(actor['gateway'] == gateway, 'Actor belongs to a different gateway')
    if op == 'leave':
        require(actor['phase'] not in ('moving','committed'), 'Resolve pending transfer before leaving')
        del state['actors'][message['actor']]
        return {'left': True}
    if op == 'deploy':
        if actor['phase']=='active':return public_actor(actor)
        require(actor['phase'] == 'waiting', 'Actor is not waiting')
        # Generic graph-nearest deployment; no CQ team/homebase assumptions.
        queue, seen = ([actor['preferred']] if actor['preferred'] in state['districts'] else sorted(state['districts'])), set()
        occupancy = counts(state)
        while queue:
            district = queue.pop(0)
            if district in seen or district not in state['districts']:
                continue
            seen.add(district)
            if online(state, district, now) and occupancy[district] < CAPACITY:
                actor.update(district=district, phase='active', generation=actor['generation']+1, gateway=state['districts'][district]['gateway'], arrival=None)
                return public_actor(actor)
            queue.extend(sorted(state['districts'][district]['links']))
        return public_actor(actor)
    if op == 'begin':
        target, tx = message.get('target'), message.get('tx')
        require(identifier(tx), 'Invalid transfer identity')
        if actor['phase'] == 'moving':
            require(actor.get('tx') == tx and actor['target'] == target, 'Another transfer is pending')
            return public_actor(actor)
        require(actor['phase'] == 'active' and online(state, actor['district'], now, incoming=False), 'Source authority unavailable')
        require(target in state['districts'][actor['district']]['links'], 'Districts are not connected')
        require(online(state, target, now) and counts(state)[target] < CAPACITY, 'Destination gate disabled')
        actor.update(phase='moving', target=target, tx=tx, prepared=False, next_generation=actor['generation']+1)
        return public_actor(actor)
    if op == 'prepared':
        require(actor['phase']=='moving' and actor.get('tx') == message.get('tx'), 'Unknown transfer')
        digest = message.get('digest')
        require(isinstance(digest,str) and len(digest)==64 and all(c in '0123456789abcdef' for c in digest), 'Invalid state digest')
        require(not actor['prepared'] or actor['digest']==digest, 'Prepared state changed')
        actor.update(prepared=True, digest=digest)
        return public_actor(actor)
    if op == 'commit':
        if actor['phase'] in ('active','committed') and actor.get('arrival')==message.get('tx'):
            return public_actor(actor)
        require(actor['phase']=='moving' and actor.get('tx')==message.get('tx') and actor.get('prepared'), 'Transfer is not prepared')
        require(online(state, actor['target'], now, incoming=False), 'Destination authority unavailable')
        # Keep source reservation until its worker explicitly acknowledges retirement.
        actor.update(phase='committed', previous=actor['district'], district=actor['target'], generation=actor['next_generation'], arrival=actor['tx'])
        return public_actor(actor)
    if op == 'finish':
        require(actor['phase']=='committed' and actor.get('tx')==message.get('tx'), 'Transfer is not committed')
        actor.update(phase='active', gateway=state['districts'][actor['district']]['gateway'])
        for field in ('target','previous','next_generation','prepared','tx'):
            actor.pop(field,None)
        return public_actor(actor)
    if op == 'abort':
        require(actor['phase']=='moving' and actor.get('tx')==message.get('tx'), 'Only an uncommitted transfer can abort')
        actor['phase']='active'
        for field in ('target','tx','prepared','next_generation','digest'):
            actor.pop(field,None)
        return public_actor(actor)
    if op == 'wait':
        require(actor['phase']=='active', 'Cannot wait during transfer')
        require(sum(a['phase']=='waiting' for a in state['actors'].values()) < state['waiting_limit'], 'Waiting budget full')
        actor.update(preferred=actor['district'], district=None, phase='waiting', generation=actor['generation']+1, arrival=None)
        return public_actor(actor)
    raise Rejected('Unknown operation')


def view(state, gateway, now):
    occupancy = counts(state)
    districts = {k:v for k,v in state['districts'].items() if gateway is None or v['gateway']==gateway}
    visible = set(districts)
    for row in districts.values():
        visible.update(row['links'])
    return dict(revision=state['revision'], deployment_slots=sum(max(0,CAPACITY-occupancy[d]) for d in state['districts'] if online(state,d,now)), districts={k:dict(**state['districts'][k], online=online(state,k,now,incoming=False), open=online(state,k,now) and occupancy[k]<CAPACITY, reservations=occupancy[k]) for k in sorted(visible)}, actors={k:public_actor(a) for k,a in state['actors'].items() if gateway is None or a['gateway']==gateway or a.get('district') in districts or a.get('target') in districts or a.get('previous') in districts})
