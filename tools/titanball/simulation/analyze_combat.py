#!/usr/bin/env python3
"""Pilot survival and cannon contribution, with explicit legacy logging limits."""
import argparse,collections,json,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('files',nargs='+');p.add_argument('--output',required=True);a=p.parse_args()
rows=[]
for file in a.files:
 d=json.loads(Path(file).read_text());profile=d['profile'];episodes=[];tenures=[];causes=collections.Counter()
 for i,c in enumerate(d['pilot_changes']):
  if not c['to']:continue
  end=d['pilot_changes'][i+1]['time'] if i+1<len(d['pilot_changes']) else d['seconds']
  if end<=60:continue
  episodes.append(end-max(60,c['time']))
  tenures.append((c['distance'],episodes[-1]))
  for event in d['deaths']:
   if event['victim']==c['to'] and abs(event['time']-end)<.02:causes[event['weapon']]+=1
 episodes.sort();deaths=collections.Counter(x['team'] for x in d['deaths'])
 fresh='damage_events' in d
 cannon_titles={'TITAN CANNON'} if fresh else {'TITAN CANNON','SENTRY'}
 cannon_deaths=[e for e in d['deaths'] if e['team']==1 and e['weapon'] in cannon_titles]
 ambiguous=[]
 if profile=='tf' and not fresh:
  classes={b['id']:b['class'] for b in d['samples'][0]['bots']}
  ambiguous=[e for e in cannon_deaths if e['weapon']=='SENTRY' and classes.get(e['attacker'])=='engineer']
 damage=sum(d['damage'].get(w,0) for w in cannon_titles)
 row={'file':file,'profile':profile,'winner':d['winner'],'distance':d['progress'],'active_seconds':d['seconds']-60,'mean_pilot_seconds':statistics.mean(episodes),'median_pilot_seconds':statistics.median(episodes),'pilot_p25_seconds':episodes[int((len(episodes)-1)*.25)],'pilot_p75_seconds':episodes[int((len(episodes)-1)*.75)],'pilot_p90_seconds':episodes[int((len(episodes)-1)*.9)],'pilot_episodes':len(episodes),'pilot_under_one_second_percent':100*sum(e<1 for e in episodes)/len(episodes),'pilot_duty_percent':100*d['pilot_seconds']/(d['seconds']-60),'pilot_death_weapons':dict(causes),'cannon_kills_min':len(cannon_deaths)-len(ambiguous),'cannon_kills_max':len(cannon_deaths),'defender_deaths':deaths[1],'cannon_kill_share_min_percent':100*(len(cannon_deaths)-len(ambiguous))/max(1,deaths[1]),'cannon_kill_share_max_percent':100*len(cannon_deaths)/max(1,deaths[1]),'cannon_logged_damage':damage,'damage_is_upper_bound':profile=='tf' and not fresh,'logged_damage_per_piloted_second':damage/max(1,d['pilot_seconds']),'notes':[]}
 if row['damage_is_upper_bound']:row['notes'].append('Old SENTRY totals include ordinary engineer sentries; five engineer-owned kills in this run are also conservatively marked ambiguous.')
 if fresh:
  hits=[e for e in d['damage_events'] if e['weapon']=='TITAN CANNON']
  pilot_hits=[e for e in d['damage_events'] if e['pilot']]
  fired=sum(v['barrels'] for v in d['cannon_volleys'])
  row.update({'fired_rounds':fired,'pair_volleys':len(d['cannon_volleys']),'direct_damage_events':sum(not e.get('blast') for e in hits),'splash_damage_events':sum(bool(e.get('blast')) for e in hits),'overheat_entries':sum(v['heat']>=100 for v in d['cannon_volleys']),'direct_damage_events_per_fired_round_percent':100*sum(not e.get('blast') for e in hits)/max(1,fired),'attacker_logged_damage':sum(e['damage'] for e in d['damage_events'] if e['attacker_team']==0 and e['victim_team']==1)})
  row.update({'pilot_logged_damage':sum(e['damage'] for e in pilot_hits),'pilot_surface_blast_damage':sum(e['damage'] for e in pilot_hits if e['blast']),'pilot_noncontact_damage_events':sum(not e['hull_contact'] for e in pilot_hits),'peak_pair_heat':max((v['heat'] for v in d['cannon_volleys']),default=0)})
 row['death_ended_pilot_episodes']=sum(causes.values())
 if 'boardings' in d:
  healed=[max(0,b['hp']-b['hp_before']) for b in d['boardings']]
  row['boarding_heal']={'events':len(healed),'wounded_boardings':sum(h>0 for h in healed),'hp_restored':sum(healed),'mean_hp_restored':statistics.mean(healed) if healed else 0,'all_class_maximum':all(b['hp']==b['max_hp'] for b in d['boardings']),'all_three_second_lock':all(b['exit_lock']==3 for b in d['boardings'])}
 row['censored_pilot_episodes']=len(episodes)-sum(causes.values())
 row['tenures_by_boarding_distance']={}
 for label,low,high in [('first_90m',0,90),('90_to_190m',90,190),('final_110m',190,301),('first_155m',0,155)]:
  values=[duration for distance,duration in tenures if low<=distance<high]
  row['tenures_by_boarding_distance'][label]={'episodes':len(values),'mean_seconds':statistics.mean(values) if values else None,'median_seconds':statistics.median(values) if values else None}
 if row['censored_pilot_episodes']:row['notes'].append('Mean and median describe observed active cockpit tenures; a final surviving pilot is censored by round end.')
 rows.append(row)
Path(a.output).write_text(json.dumps(rows,indent=2)+'\n')
for r in rows:print(r['profile'], 'pilot mean/median',round(r['mean_pilot_seconds'],2),round(r['median_pilot_seconds'],2),'cannon kills',r['cannon_kills_min'],r['cannon_kills_max'],'damage',r['cannon_logged_damage'])
