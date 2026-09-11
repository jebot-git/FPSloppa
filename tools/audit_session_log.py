"""Summarize server JSONL without publishing player names or message contents."""
from pathlib import Path
import argparse,collections,hashlib,json,re
def audit(path):
    raw=path.read_bytes();rows=[json.loads(line.removeprefix('SERVER_LOG ')) for line in raw.decode().splitlines() if line.strip()]
    counts=collections.Counter(r['event'] for r in rows);weapons=collections.Counter();modes=collections.defaultdict(collections.Counter);hazards=collections.Counter()
    peers=set();names=set();live=set();last_deaths={};intervals=[];idle_rounds=[];unknown_killers=[];lobby_kills=[];same_name=0;opponent=0;scores={};peer_names={};score_checks=[]
    for r in rows:
        kind=r['event'];d=r['data']
        if kind=='peer_connected':peers.add(d['peer']);live.add(d['peer'])
        if kind=='peer_disconnected':live.discard(d['peer']);scores.pop(peer_names.get(d['peer'],''),None)
        if kind=='map_rotated':scores={}
        if kind=='player_joined':names.add(d['name']);scores[d['name']]=0;peer_names[d['peer']]=d['name']
        if kind=='round_ended':
            if not live:idle_rounds.append(r['seq'])
            found=re.fullmatch(r'(.+) wins · (-?\d+) frags',d.get('result',''))
            if found and r['mode'] in ['dm','ig','cc']:
                expected=scores.get(found[1]);score_checks.append({'seq':r['seq'],'reported':int(found[2]),'reconstructed':expected,'match':expected==int(found[2])})
        if kind!='match_event':continue
        message=d.get('message','')
        if '  →  ' not in message or '   ·   ' not in message:continue
        attacker,tail=message.split('  →  ',1);victim,weapon=tail.rsplit('   ·   ',1)
        weapons[weapon]+=1;modes[r['mode']][weapon]+=1
        if attacker==victim:same_name+=1
        else:opponent+=1
        if weapon in ['environment','fell out of the arena','DROWNING']:hazards[r['map']]+=1
        if r['map']=='__waiting_lobby__':lobby_kills.append(r['seq'])
        if attacker in scores:scores[attacker]+=(-1 if attacker==victim else 1)
        else:unknown_killers.append(r['seq'])
        key=(r['epoch'],victim)
        if key in last_deaths:intervals.append({'milliseconds':r['uptime_ms']-last_deaths[key],'seq':r['seq']})
        last_deaths[key]=r['uptime_ms']
    return {'source_sha256':hashlib.sha256(raw).hexdigest(),'records':len(rows),'start':rows[0]['utc'],'end':rows[-1]['utc'],'minutes':round((rows[-1]['uptime_ms']-rows[0]['uptime_ms'])/60000,2),'server_version':rows[0]['data'].get('version'),'events':dict(counts),'unique_connections':len(peers),'distinct_display_names':len(names),'sequence_gaps':[[a['seq'],b['seq']] for a,b in zip(rows,rows[1:]) if b['seq']!=a['seq']+1],'uptime_regressions':sum(b['uptime_ms']<a['uptime_ms'] for a,b in zip(rows,rows[1:])),'kill_announcements':sum(weapons.values()),'same_name_kills_including_environment':same_name,'opponent_kills':opponent,'weapons':dict(weapons),'weapons_by_mode':{k:dict(v) for k,v in modes.items()},'hazard_deaths_by_map':dict(hazards),'shortest_same_life_epoch_death_interval_ms':min((r['milliseconds'] for r in intervals),default=None),'deaths_less_than_2_seconds_apart':[r for r in intervals if r['milliseconds']<2000],'kills_in_waiting_lobby':lobby_kills,'unrecognized_killer_sequences':unknown_killers,'individual_round_score_checks':score_checks,'rounds_ending_without_connected_peers':idle_rounds,'hit_registration_verdict':'Insufficient evidence: no shots, misses, damage, ping, rewind time, projectile contact or input telemetry in this normal-level log.'}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    result=audit(a.log);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n');print(a.output)
