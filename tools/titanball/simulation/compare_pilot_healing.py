#!/usr/bin/env python3
"""Compare matched cockpit health/healing trials and validate recorded invariants."""
import argparse, collections, json, statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('files',nargs='+');p.add_argument('--output',required=True);p.add_argument('--pilot-damage',choices=['heavy','contact'],default='heavy',help='Require the selected hull-damage policy in every trial');p.add_argument('--include-healing-only',action='store_true',help='Require a fourth class-HP + healing trial for every seed');a=p.parse_args()
TREATMENTS=['previous','200_hp','200_hp_healing']+(['class_hp_healing'] if a.include_healing_only else [])
CLASSES={'scout':75,'soldier':150,'demoman':120,'medic':110,'heavy':200,'engineer':100}
rows=[];checks=0
for file in a.files:
 d=json.loads(Path(file).read_text());o=d['options'];heals=d.get('pilot_healing',[])
 treatment=('class_hp_healing' if o['pilot_healing']=='station' else 'previous') if o['pilot_health']=='class' else '200_hp_healing' if o['pilot_healing']=='station' else '200_hp'
 assert d['winner'] in [0,1] and d['profile']=='tf' and d['effective_rules']=='quake' and o['pilot_damage']==a.pilot_damage,file;checks+=1
 roster=d['samples'][0]['bots'];classes={b['id']:b['class'] for b in roster}
 assert collections.Counter(b['team'] for b in roster)=={0:6,1:6},file;checks+=1
 for team in [0,1]:assert collections.Counter(b['class'] for b in roster if b['team']==team)==collections.Counter(CLASSES.keys()),file;checks+=1
 assert all(s['distance']==0 for s in d['samples'] if s['preparation']>0),file;checks+=1
 assert len(d['stations'])==6,file;checks+=1
 for b in d['boardings']:
  expected=CLASSES[b['class']] if o['pilot_health']=='class' else 200
  assert b['hp']==b['max_hp']==expected and b['exit_lock']==3,file
 checks+=1
 hits=[e for e in d['damage_events'] if e['pilot']]
 assert all(e['hull_contact'] for e in hits),file;checks+=1
 light_hits=[e for e in hits if not (e['weapon'] in ['ROCKET LAUNCHER','GRENADE LAUNCHER','PIPEBOMB','DETPACK','ASSAULT CANNON','SENTRY','TITAN CANNON'] or e['weapon']=='SUPER NAILGUN' and classes[e['attacker']]=='heavy')]
 if a.pilot_damage=='heavy':assert not light_hits,file
 else:assert light_hits and not d.get('blocked_hull_hits'),file
 checks+=1
 if o['pilot_healing']=='off':assert not heals,file
 else:assert heals and all(0<e['amount']<=e['hp']<=e['max_hp']==(CLASSES[classes[e['pilot']]] if o['pilot_health']=='class' else 200) for e in heals),file
 checks+=1
 tenures=[];death_tenures=[];censored=[];occupied=0;short_deaths=0;class_tenures=collections.defaultdict(list)
 for i,c in enumerate(d['pilot_changes']):
  if c['to']==0:continue
  end=d['pilot_changes'][i+1]['time'] if i+1<len(d['pilot_changes']) else d['seconds'];occupied+=end-c['time']
  if end<=60:continue
  seconds=end-max(60,c['time']);tenures.append(seconds);class_tenures[classes[c['to']]].append(seconds)
  fatal=any(e['victim']==c['to'] and e['fatal'] and abs(e['time']-end)<.025 for e in hits)
  (death_tenures if fatal else censored).append(seconds)
  if fatal and end-c['time']<=3.000001:short_deaths+=1
 assert sum(e['amount'] for e in heals)<=occupied*10+.1,file;checks+=1
 hp_damage=sum(e['damage'] for e in hits);deaths=sum(e['fatal'] for e in hits)
 arrivals={str(m):next((s['time']-60 for s in d['samples'] if s['distance']>=m),None) for m in [100,200,290]}
 new_fields={'class_tenures':dict(class_tenures),'pilot_deaths_within_boarding_lock':short_deaths,'arrivals':arrivals,'moving_seconds':d['moving_seconds'],'manned_stopped_seconds':d['manned_stopped_seconds'],'light_weapon_pilot_hp_damage':sum(e['damage'] for e in light_hits),'light_weapon_pilot_deaths':sum(e['fatal'] for e in light_hits),'final_10m_seconds':d['seconds']-60-arrivals['290'] if arrivals['290'] is not None else None}

 rows.append({**new_fields,'file':file,'treatment':treatment,'seed':o['seed'],'map_sha256':d['map_sha256'],'attacker_win':d['winner']==0,'active_seconds':d['seconds']-60,'distance_m':d['progress'],'seconds_to_290m':next((s['time']-60 for s in d['samples'] if s['distance']>=290),None),'pilot_seconds':d['pilot_seconds'],'tenures':tenures,'censored_tenures':len(censored),'mean_tenure_s':statistics.mean(tenures),'median_tenure_s':statistics.median(tenures),'pilot_deaths':deaths,'pilot_deaths_per_manned_minute':60*deaths/max(1,d['pilot_seconds']),'pilot_hp_damage':hp_damage,'pilot_hp_healed':sum(e['amount'] for e in heals),'active_pilot_hp_healed':sum(e['amount'] for e in heals if e['time']>=60),'cannon_kills':sum(e['fatal'] and e['weapon']=='TITAN CANNON' and e['victim_team']==1 for e in d['damage_events']),'attacker_deaths':sum(e['team']==0 for e in d['deaths']),'defender_deaths':sum(e['team']==1 for e in d['deaths'])})
assert len({r['map_sha256'] for r in rows})==1;checks+=1
for seed in {r['seed'] for r in rows}:
 assert collections.Counter(r['treatment'] for r in rows if r['seed']==seed)==collections.Counter(TREATMENTS);checks+=1
summaries={}
for treatment in TREATMENTS:
 group=[r for r in rows if r['treatment']==treatment];tenures=[t for r in group for t in r['tenures']];manned=sum(r['pilot_seconds'] for r in group)
 arrivals=[r['seconds_to_290m'] for r in group if r['seconds_to_290m'] is not None]
 summaries[treatment]={'matches':len(group),'attacker_wins':sum(r['attacker_win'] for r in group),'mean_active_seconds':statistics.mean(r['active_seconds'] for r in group),'pooled_mean_tenure_s':statistics.mean(tenures),'pooled_median_tenure_s':statistics.median(tenures),'pilot_deaths_per_manned_minute':60*sum(r['pilot_deaths'] for r in group)/manned,'pilot_hp_damage_per_manned_second':sum(r['pilot_hp_damage'] for r in group)/manned,'cockpit_healing_per_manned_second':sum(r['active_pilot_hp_healed'] for r in group)/manned,'total_cockpit_healing':sum(r['pilot_hp_healed'] for r in group),'pilot_duty_percent':100*manned/sum(r['active_seconds'] for r in group),'mean_seconds_to_290m':statistics.mean(arrivals) if arrivals else None,'mean_cannon_kills':statistics.mean(r['cannon_kills'] for r in group),'censored_tenures':sum(r['censored_tenures'] for r in group)}
report={'pilot_damage':a.pilot_damage,'passed':True,'integrity_checks':checks,'groups':summaries,'matches':rows,'limits':['Small matched-seed bot sample, not a human balance certification.',f'All arms use the {a.pilot_damage} hull-damage policy and the same current navigation fixes.','200 HP arms include full class-health restoration on living exit; class-HP arms retain prior exit behavior.','Mean/median observed tenures include surviving round-end pilots and voluntary exits, not uncensored life expectancy.','Winning requires the existing stopped-robot finish tolerance; 290 m arrival is less sensitive to that threshold.','Matched seeds cannot guarantee identical trajectories after gameplay outcomes or asynchronous physics work diverge.']}
Path(a.output).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(summaries,indent=2))
