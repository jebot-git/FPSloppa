#!/usr/bin/env python3
"""Validate experiment integrity, summarize objective/combat evidence, plot progress."""
import argparse, collections, json, math, os
os.environ.setdefault("MPLCONFIGDIR", "/tmp/fpsloppa-matplotlib")
from pathlib import Path
root=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('files',nargs='+');p.add_argument('--output',default='test-results/titanball/simulation/comparison.json');a=p.parse_args()
results=[]
for path in a.files:
 d=json.loads(Path(path).read_text());samples=d['samples'];active=[s for s in samples if s['preparation']<=0]
 initial=samples[0]['bots'];checks={
 'six_per_team':collections.Counter(b['team'] for b in initial)=={0:6,1:6},
 'correct_rules':d['effective_rules']==('quake' if d['profile']=='tf' else d['profile']),
 'class_policy':d['classes']==(d['profile']=='tf'),
 'prep_keeps_robot_stationary':all(s['distance']<0.0001 for s in samples if s['preparation']>0),
 'bots_boarded':any(s['pilot'] for s in samples),
 'only_attackers_pilot':all(not s['pilot'] or next(b for b in s['bots'] if b['id']==s['pilot'])['team']==0 for s in samples),
 'pilot_replaced':len({c['to'] for c in d['pilot_changes'] if c['to']})>1,
 'pilot_departures_match_deaths':all(any(x['victim']==c['from'] and abs(x['time']-c['time'])<.02 for x in d['deaths']) for c in d['pilot_changes'] if c['from']),
 'both_teams_fought':all(any(b['shots']>0 for s in active for b in s['bots'] if b['team']==team) for team in [0,1]),
 'no_motion_before_gate':all(s['distance']==0 for s in samples if s['time']<60),
 }
 if d['profile']!='tf':
  checks['all_classless']=all(b['class']=='none' for s in samples for b in s['bots'])
  checks['both_teams_acquire_weapons']=all(any(r['team']==t and r['kind']=='weapon' for r in d['pickups']) for t in [0,1])
  checks['starter_loadouts']=all(set(b['owned'])<={0,2,3 if d['profile']=='ut99' else 5} for b in initial) if any(p.get('basic') for p in d['placements']) else all(set(b['owned'])<={0,2} for b in initial)
  if any(p.get('basic') for p in d['placements']) and len(samples)>60:
   prepared=min(samples,key=lambda s:abs(s['time']-59))
   checks['all_twelve_armed_before_gate']=all(any(w not in [0,2] for w in b['owned']) for b in prepared['bots'])
   checks['advanced_guns_unavailable_in_preparation']=all(p.get('basic') or p['release_seconds']==60 for p in d['placements'])
   basic_slot=3 if d['profile']=='ut99' else 5
   checks['preparation_pickups_only_basic_guns']=all(e['kind']=='weapon' and e['item']==basic_slot for e in d['pickups'] if e['time']<60)
   checks['sixteen_basic_plus_fortyeight_advanced']=len(d['placements'])==64 and sum(p.get('basic',False) for p in d['placements'])==16
  checks['no_superweapons']=all(p['item'] not in [8,11] for p in d['placements'] if p['kind']=='weapon')
 else:checks['symmetric_classes']=collections.Counter(b['class'] for b in initial if b['team']==0)==collections.Counter(b['class'] for b in initial if b['team']==1)
 if 'damage_events' in d:
  checks['pilot_damage_requires_hull_contact']=all(e.get('hull_contact',False) for e in d['damage_events'] if e['pilot'])
  checks['cannon_pair_ids_valid']=all(v['pair'] in [0,1] and v['barrels'] in [1,2] and 0<v['heat']<=100 for v in d['cannon_volleys'])
 if 'boardings' in d:
  checks['boarding_events_recorded']=len(d['boardings'])>0
  checks['every_boarding_restores_class_maximum']=all(b['hp']==b['max_hp'] and b['hp']>0 for b in d['boardings'])
  checks['every_boarding_starts_three_second_lock']=all(b['exit_lock']==3 for b in d['boardings'])
 if 'robot_state' in samples[0]:
  checks['no_occupied_endpoint_restart_deadlock']=not any(s['pilot'] and s['pilot']==prev['pilot'] and s['robot_state']=='parked' and s['speed']==0 and 299.2<s['distance']<299.98 and s['distance']==prev['distance'] for prev,s in zip(samples,samples[1:]))
 if 'body_yaw' in samples[0]:
  checks['torso_stays_within_7_5_degrees']=all(abs(s['body_yaw'])<=math.pi/24+1e-6 for s in samples)
  checks['no_ladder_while_moving_or_manned']=all(not s['ladder_deployed'] or (s['pilot']==0 and s['speed']<=.0001) for s in samples)
  crush=[e for e in d.get('damage_events',[]) if e['weapon']=='TITAN CRUSH']
  checks['recorded_crush_deaths_are_gibbed']=all(e['fatal'] and e.get('gibbed',False) and e['victim_team']==1 for e in crush)
 if d['options'].get('seconds',0)>=1030:checks['round_finished']=d['winner'] in [0,1]
 if d.get('vantages') and d['options'].get('seconds',0)>=1030:
  checks['six_shared_stations']=len(d['stations'])==6
  checks['twelve_authored_vantages']=len(d['vantages'])==12
  for team in [0,1]:checks[f'team_{team}_physically_occupies_high_ground']=any(b['team']==team and not b['dead'] and b.get('vantage',-1)>=0 for s in samples for b in s['bots'])
  checks['combat_from_high_ground']=any(e.get('attacker_vantage',-1)>=0 and e['attacker_team']!=e['victim_team'] for e in d.get('damage_events',[]))
 deaths=collections.Counter(x['team'] for x in d['deaths'])
 occupied=max(0,d['seconds']-60)
 combat_samples=collections.Counter();player_samples=collections.Counter();idle=collections.Counter();starter=collections.Counter();held=collections.Counter()
 for s in active:
  for b in s['bots']:
   if b['dead']:continue
   t=b['team'];player_samples[t]+=1
   idle[t]+=b['goal']=='' or b['goal'].startswith('idle')
   if b['id']!=s['pilot']:
    combat_samples[t]+=1;starter[t]+=set(b['owned'])<={0,2}
   held[(t,b['weapon'])]+=1
 cps={}
 for s in samples:
  if s['checkpoint'] and s['checkpoint'] not in cps:cps[s['checkpoint']]=round(s['time']-60,1)
 pilots=[c for c in d['pilot_changes'] if c['to']]
 episode=[]
 for i,c in enumerate(d['pilot_changes']):
  if not c['to']:continue
  end=d['pilot_changes'][i+1]['time'] if i+1<len(d['pilot_changes']) else d['seconds']
  start=max(60,c['time'])
  if end>start:episode.append(end-start)
 summary={'file':str(path),'profile':d['profile'],'seed':int(d['options']['seed']),'winner':{0:'Attackers',1:'Defenders',-1:'Unfinished'}[d['winner']],'active_seconds':round(occupied,2),'distance_m':round(d['progress'],2),'checkpoints':cps,'pilot_duty_percent':round(100*d['pilot_seconds']/max(1,occupied),1),'moving_percent':round(100*d['moving_seconds']/max(1,occupied),1),'manned_stopped_seconds':round(d['manned_stopped_seconds'],1),'boardings':len(pilots),'mean_active_pilot_episode_seconds':round(sum(episode)/max(1,len(episode)),2),'deaths_attack_defend':[deaths[t] for t in [0,1]],'weapon_pickups_attack_defend':[sum(r['team']==t and r['kind']=='weapon' for r in d['pickups']) for t in [0,1]],'starter_only_nonpilot_alive_percent':[round(100*starter[t]/max(1,combat_samples[t]),1) for t in [0,1]],'idle_goal_alive_percent':[round(100*idle[t]/max(1,player_samples[t]),1) for t in [0,1]],'damage_by_weapon':d['damage'],'checks':checks}
 results.append(summary)
 print(json.dumps(summary,indent=2))
out=root/a.output;out.write_text(json.dumps(results,indent=2)+'\n')
try:
 import matplotlib
 matplotlib.use('Agg')
 import matplotlib.pyplot as plt
 fig,ax=plt.subplots(figsize=(10,5))
 for path,r in zip(a.files,results):
  d=json.loads(Path(path).read_text());ss=d['samples'];ax.plot([s['time']-60 for s in ss],[s['distance'] for s in ss],label=f"{d['options'].get('revision',r['profile']).upper()} — {r['winner']}")
 for y in [90,190]:ax.axhline(y,color='#999999',linestyle=':',linewidth=1)
 ax.set(xlabel='Active round time (seconds; preparation is −60 to 0)',ylabel='Titan route distance (m)',ylim=(0,305),title='TITANBALL • Ashfall Boulevard • 6v6 exploratory comparison')
 ax.grid(alpha=.2);ax.legend();fig.tight_layout();fig.savefig(out.with_suffix('.png'),dpi=150)
except ImportError:pass
raise SystemExit(0 if all(all(r['checks'].values()) for r in results) else 1)
