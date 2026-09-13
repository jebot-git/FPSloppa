"""Aggregate the supplied JSONL session without publishing player names or addresses."""
from pathlib import Path
import json,collections,statistics,re
ROOT=Path(__file__).resolve().parents[1]
source=Path('/home/blux/Downloads/FPSloppa-Linux/demos/serverup.log')
rows=[];session=-1
for line in source.open():
 try:r=json.loads(line.removeprefix('SERVER_LOG '))
 except ValueError:continue
 if r['event']=='server_started':session+=1
 r['session']=session;rows.append(r)
def stats(xs):
 xs=sorted(xs)
 if not xs:return {'count':0}
 return {'count':len(xs),'median':round(statistics.median(xs),3),'p95':round(xs[min(len(xs)-1,int(len(xs)*.95))],3),'p99':round(xs[min(len(xs)-1,int(len(xs)*.99))],3),'max':round(xs[-1],3)}
def summarise(sub):
 hs=[r for r in sub if r['event']=='health'];players=[p for r in hs for p in r['data']['players']]
 ds=[r for r in sub if r['event']=='damage'];weapons={}
 for weapon in sorted({r['data']['weapon'] for r in ds}):
  w=[r['data'] for r in ds if r['data']['weapon']==weapon]
  weapons[weapon]={'damage_events':len(w),'fatal_events':sum(r['fatal'] for r in w),'self_damage_events':sum(r['attacker']==r['victim'] for r in w),'median_nonfatal_postarmor_damage':stats([r['damage'] for r in w if not r['fatal']])}
 return {'health_samples':len(hs),'peak_players':max([0]+[len(r['data']['players']) for r in hs]),'physics_ms':stats([r['data']['physics_ms'] for r in hs]),'process_ms':stats([r['data']['process_ms'] for r in hs]),'physics_samples_over_16_67ms':sum(r['data']['physics_ms']>16.667 for r in hs),'ping_ms':stats([p['ping_ms'] for p in players]),'input_age_ms':stats([p['input_age_ms'] for p in players]),'player_samples_over_100ms_ping':sum(p['ping_ms']>100 for p in players),'player_samples':len(players),'weapons':weapons,'suicides':sum(r['event']=='suicide' for r in sub),'team_sizes':dict(collections.Counter(f"{sum(not p['spectator'] and p['team']==0 for p in r['data']['players'])}v{sum(not p['spectator'] and p['team']==1 for p in r['data']['players'])}" for r in hs)), 'outcomes':[dict(r['data'], result=re.sub(r'^.*? wins', 'Player wins', r['data'].get('result',''))) for r in sub if r['event']=='round_ended']}
health=[r for r in rows if r['event']=='health'];top=[]
for r in sorted(health,key=lambda r:r['data']['physics_ms'],reverse=True)[:12]:
 nearby=[x for x in rows if x['session']==r['session'] and abs(x['uptime_ms']-r['uptime_ms'])<=2500 and x['event'] not in ['health','damage','pickup','match_event']]
 top.append({'utc':r['utc'],'map':r['map'],'mode':r['mode'],'physics_ms':r['data']['physics_ms'],'process_ms':r['data']['process_ms'],'players':len(r['data']['players']),'nearby_events':dict(collections.Counter(x['event'] for x in nearby))})
report={'source':source.name,'sessions':session+1,'event_counts':dict(collections.Counter(r['event'] for r in rows)),'overall':summarise(rows),'per_mode':{m:summarise([r for r in rows if r['mode']==m and r['map']!='__waiting_lobby__']) for m in sorted({r['mode'] for r in rows})},'per_map':{m:summarise([r for r in rows if r['map']==m]) for m in sorted({r['map'] for r in rows if r['map']!='__waiting_lobby__'})},'largest_physics_samples':top}
# Explicit announcements are the only objective telemetry in this release.
report['assault_objectives']=[{'utc':r['utc'],'time_ms':r['uptime_ms'],'map':r['map'],'message':r['data']['message']} for r in rows if r['mode']=='as' and r['event']=='match_event' and any(t in r['data']['message'] for t in ['AS objective','forward spawn','attacks','completed','WINS THE ASSAULT'])]
(ROOT/'test-results/live-session-analysis.json').write_text(json.dumps(report,indent=2)+'\n')
print('OVERALL',json.dumps({k:v for k,v in report['overall'].items() if k!='weapons'}))
for m in ['as','tf','cc','koth','ig','ft','dm']:
 s=report['per_mode'][m];print('MODE',m,json.dumps({k:s[k] for k in ['health_samples','physics_ms','process_ms','ping_ms','input_age_ms','team_sizes','outcomes']}))
print('TOP_SPIKES',json.dumps(top))
