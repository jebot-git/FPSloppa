"""Persistent identities, stored outside the bounded live coordinator document."""
import copy

IDLE_SECONDS = 90


def record(actor, now):
    return dict(id=actor['id'], resume_hash=actor['resume_hash'], name=actor['name'],
                team=actor.get('team',0), generation=actor['generation'],
                preferred=actor.get('district') or actor['preferred'],
                avatar=actor.get('avatar',''), stats=copy.deepcopy(actor.get('stats',dict(kills=0,deaths=0))),
                created=actor.get('created',now), last_seen=actor.get('seen_at',now),
                joins=actor.get('joins',1),first_spawn_pending=actor.get('entry_kind')=='new',last_location=copy.deepcopy(actor.get('last_location')))


def expire(state, now):
    if not any(r.get('campaign_role') for r in state['districts'].values()):return
    removed=0
    for key, actor in list(state['actors'].items()):
        # A durable handoff must resolve before either reservation is released.
        # A reconnect resumes that transaction; no timeout can undo its commit.
        if actor['phase'] in ('active','waiting') and now-actor.get('seen_at',now)>IDLE_SECONDS:
            del state['actors'][key]
            removed+=1
            if removed==32:break # Bound a single etcd transaction below 128 ops.


def changes(before, state, now):
    result = {}
    for key in before.keys() | state['actors'].keys():
        old, new = before.get(key), state['actors'].get(key)
        if new is None:
            result[key] = record(old,now)
        elif old is None:
            # Live profiles already persist in the control document. Archive
            # them on departure; keep a permanent identity on initial admission.
            result[key] = record(new,now)
    return result
