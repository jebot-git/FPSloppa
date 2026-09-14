#!/usr/bin/env python3
"""Compare matched TF pilot-damage trials; observed tenures are not survival estimates."""
import argparse,collections,json,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('files',nargs='+');p.add_argument('--output',required=True);a=p.parse_args()
rows=[]
for file in a.files:
 d=json.loads(Path(file).read_text());policy=d['options'].get('pilot_damage','contact');initial=d['samples'][0]['bots'];classes={b['id']:b['class'] for b in initial}
 assert collections.Counter(b['team'] for b in initial)=={0:6,1:6},file
 assert d['winner'] in [0,1] and d['profile']=='tf' and d['effective_rules']=='quake',file
 assert all(e['hull_contact'] for e in d['damage_events'] if e['pilot']),file
 assert all(b['hp']==b['max_hp'] and b['exit_lock']==3 for b in d['boardings']),file
 tenures=[];death_tenures=[];censored=[]
 for i,c in enumerate(d['pilot_changes']):
  if not c['to']:continue
  end=d['pilot_changes'][i+1]['time'] if i+1<len(d['pilot_changes']) else d['seconds']
  if end<=60:continue
  duration=end-max(60,c['time']);tenures.append(duration)
  fatal=any(e['pilot'] and e['fatal'] and e['victim']==c['to'] and abs(e['time']-end)<.025 for e in d['damage_events'])
  (death_tenures if fatal else censored).append(duration)
 hits=[e for e in d['damage_events'] if e['pilot']];weapons=collections.Counter();blocked=collections.Counter()
 for e in hits:weapons[e['weapon']]+=e['damage']
 for e in d.get('blocked_hull_hits',[]):blocked[e['weapon']]+=1
 if policy=='heavy':
  assert all(e['weapon'] in ['ROCKET LAUNCHER','GRENADE LAUNCHER','PIPEBOMB','DETPACK','ASSAULT CANNON','SENTRY','TITAN CANNON'] or e['weapon']=='SUPER NAILGUN' and classes[e['attacker']]=='heavy' for e in hits),file
 pilot_damage=sum(e['damage'] for e in hits);pilot_deaths=sum(e['fatal'] for e in hits)
 rows.append({'file':file,'policy':policy,'seed':d['options']['seed'],'map_sha256':d['map_sha256'],'winner':'Attackers' if d['winner']==0 else 'Defenders','distance_m':d['progress'],'seconds_to_290m':next((s['time']-60 for s in d['samples'] if s['distance']>=290),None),'active_seconds':d['seconds']-60,'pilot_seconds':d['pilot_seconds'],'pilot_duty_percent':100*d['pilot_seconds']/max(1,d['seconds']-60),'tenures':len(tenures),'mean_tenure_seconds':statistics.mean(tenures) if tenures else None,'median_tenure_seconds':statistics.median(tenures) if tenures else None,'tenure_samples':tenures,'death_ended_samples':death_tenures,'censored_samples':censored,'pilot_deaths':pilot_deaths,'pilot_deaths_per_manned_minute':60*pilot_deaths/max(1,d['pilot_seconds']),'pilot_hp_damage_per_manned_second':pilot_damage/max(1,d['pilot_seconds']),'pilot_hp_damage':pilot_damage,'pilot_damage_by_weapon':dict(weapons),'blocked_hits':dict(blocked),'blocked_hit_count':sum(blocked.values()),'cannon_kills':sum(e['fatal'] and e['weapon']=='TITAN CANNON' and e['victim_team']==1 for e in d['damage_events']),'attacker_deaths':sum(e['team']==0 for e in d['deaths']),'defender_deaths':sum(e['team']==1 for e in d['deaths'])})
assert len({r['map_sha256'] for r in rows})==1
pairs=[]
for seed in sorted({r['seed'] for r in rows}):
 pair={r['policy']:r for r in rows if r['seed']==seed};assert set(pair)=={'contact','heavy'}
 b,h=pair['contact'],pair['heavy'];pairs.append({'seed':seed,'baseline_winner':b['winner'],'heavy_winner':h['winner'],'active_seconds_delta':h['active_seconds']-b['active_seconds'],'mean_tenure_delta':h['mean_tenure_seconds']-b['mean_tenure_seconds'],'pilot_duty_delta_points':h['pilot_duty_percent']-b['pilot_duty_percent']})
groups={}
for policy in ['contact','heavy']:
 group=[r for r in rows if r['policy']==policy];tenures=[v for r in group for v in r['tenure_samples']];manned=sum(r['pilot_seconds'] for r in group)
 groups[policy]={'matches':len(group),'attacker_wins':sum(r['winner']=='Attackers' for r in group),'mean_active_seconds':statistics.mean(r['active_seconds'] for r in group),'mean_seconds_to_290m':(statistics.mean(r['seconds_to_290m'] for r in group if r['seconds_to_290m'] is not None) if any(r['seconds_to_290m'] is not None for r in group) else None),'pooled_mean_tenure_seconds':statistics.mean(tenures),'pooled_median_tenure_seconds':statistics.median(tenures),'pilot_deaths':sum(r['pilot_deaths'] for r in group),'pilot_deaths_per_manned_minute':60*sum(r['pilot_deaths'] for r in group)/manned,'pilot_hp_damage_per_manned_second':sum(r['pilot_hp_damage'] for r in group)/manned,'pilot_duty_percent':100*manned/sum(r['active_seconds'] for r in group),'blocked_hit_count':sum(r['blocked_hit_count'] for r in group),'mean_cannon_kills':statistics.mean(r['cannon_kills'] for r in group),'censored_tenures':sum(len(r['censored_samples']) for r in group)}
report={'matches':rows,'pairs':pairs,'groups':groups,'limitations':['Small bot-only sample, not a human balance certification.','Strict delivery requires stopping at or beyond 299.98 m. Near-finish baseline losses are sensitive to this existing rule; compare 290 m arrival times as well.','Bots keep their existing targeting and weapon-selection policy, including ineffective small-arms attacks.','Observed cockpit tenures include round-end censoring; they are not estimates of uncensored life expectancy.','Matched seeds start comparable rosters but physics/navigation scheduling and changed combat outcomes can diverge.']}
Path(a.output).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'groups':groups,'pairs':pairs},indent=2))
