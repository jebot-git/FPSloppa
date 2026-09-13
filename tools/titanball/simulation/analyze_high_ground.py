#!/usr/bin/env python3
"""Measure actual occupancy and damage from authored high ground, not just goals."""
import argparse, collections, json, re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('file');p.add_argument('--baseline');a=p.parse_args()
path=Path(a.file);d=json.loads(path.read_text())
def vector(value):
 return [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',value)]
vantages=[vector(v['position']) for v in d['vantages']]
stations=[vector(v) for v in d['stations']]
def near(pos,point,radius=3):return sum((a-b)**2 for a,b in zip(pos,point))<radius*radius and abs(pos[1]-point[1])<.7
def occupancy(data):
 rows=[]
 for team in [0,1]:
  alive=0;high=0;goals=0;ids=set();by_position=collections.Counter();supply=collections.Counter()
  for sample in data['samples']:
   for b in sample['bots']:
    if b['team']!=team or b['dead']:continue
    alive+=1;pos=vector(b['position'])
    goals+=b['goal'].startswith('tb:high:')
    for i,point in enumerate(vantages):
     if near(pos,point):high+=1;ids.add(b['id']);by_position[i]+=1;break
    for i,point in enumerate(stations):
     if near(pos,point):supply[i]+=1;break
  rows.append({'team':team,'alive_bot_samples':alive,'high_ground_bot_seconds_approx':high,'high_ground_alive_percent':100*high/max(1,alive),'distinct_high_ground_bots':sorted(ids),'high_goal_samples':goals,'high_ground_position_samples':dict(by_position),'near_station_samples':dict(supply)})
 return rows
result={'file':a.file,'station_count':len(stations),'vantage_count':len(vantages),'occupancy':occupancy(d)}
for row in result['occupancy']:
 events=[e for e in d['damage_events'] if e['attacker_team']==row['team'] and e['victim_team']!=row['team'] and e.get('attacker_vantage',-1)>=0]
 row.update(high_ground_damage_events=len(events),high_ground_logged_damage=sum(e['damage'] for e in events),high_ground_kills=sum(e['fatal'] for e in events))
if a.baseline:result['baseline_file']=a.baseline;result['baseline_occupancy']=occupancy(json.loads(Path(a.baseline).read_text()))
target=path.with_name(path.stem+'-high-ground.json');target.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
