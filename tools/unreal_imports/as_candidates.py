"""Review shortlist grounded in decoded objective properties and event recipients."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
rows=json.loads((HERE/'attempts.json').read_text())
choices=[
 ('AS-Pumpfac','First batch','Shaft switch, destructible hall target, final pump-engine switch.','No moving brushes or dispatchers; preserve the three stages rather than merging them.'),
 ('AS-Skyville','First batch','Ventilation switch, destructible hall target, final fusebox switch.','No moving brushes or dispatchers. Geometry, spawns and routes still need runtime conversion.'),
 ('AS-Twintower','First batch','Bridge control followed by final control switch.','One ordinary lift is traversal, not a separate objective mechanic; validate its navigation.'),
 ('AS-Atlantica','First batch','Generator, power switch and lighthouse control switches.','Two moving brushes and triggered lighting can follow ordinary switch events; preserve water traversal.'),
 ('AS-HyperBlast','Second batch','Disable the middle and lower control buttons.','Mission events open three brushes. The two dispatchers loop cosmetic sky/star events; do not treat the ship theme as a vehicle objective.'),
 ('AS-UrbanAssault','Second batch','Destroy the radio, then activate the final control.','Two AssaultRandomizer actors and team-triggered spawn toggles need explicit checkpoint mapping or documented removal of randomization.')]
result=[]
for rank,(name,priority,implementation,caveat) in enumerate(choices,1):
 row=next(r for r in rows if r['name']==name);actors=json.loads((HERE/row['artifacts']/'actors.json').read_text());objectives=[]
 for a in actors:
  if a['class_path'].split('.')[-1]!='FortStandard':continue
  p=a['properties'];events=[v for k,v in p.items() if k=='Event' or k.startswith('DamageEvent') and isinstance(v,str)]
  recipients=[{'name':b['name'],'class':b['class_path'],'properties':{k:v for k,v in b['properties'].items() if k in ['Tag','Event','InitialState'] or k.startswith(('OutEvents','OutDelays'))}} for b in actors if str(b['properties'].get('Tag','')).lower() in [str(e).lower() for e in events]]
  objectives.append({'actor':a['name'],'title':p.get('FortName',p.get('Tag',a['name'])),'interaction':'trigger/touch -> existing switch' if p.get('bTriggerOnly',False) else 'damage -> existing destructible target','health':p.get('Health',100),'final':p.get('bFinalFort',False),'fallback':p.get('FallBackFort'),'properties':p,'event_recipients':recipients})
 result.append({'rank':rank,'name':name,'priority':priority,'players':row['players'],'page':row['page'],'archive_sha1':row['archive_sha1'],'source_sha256':row['source_sha256'],'player_starts':row['player_starts'],'world_polygons':row['world_polygons'],'implementation':implementation,'caveat':caveat,'objectives':objectives,'status':'recommended for conversion; not installed'})
report={'criterion':'Actual objective compatibility with switches/destructible targets; objective count is secondary. No escort, NPC-kill, driveable-vehicle or puzzle-chain objectives.','selection_basis':'Decoded package actor properties and event recipients from 383 capacity-qualified archives, plus source archive player declarations. This is a conversion-readiness recommendation, not playtested balance.','runtime_note':'AS currently checks for exactly two steps. Maps with additional ordinary objectives need a bounded objective-count extension, not a new mechanic; do not merge or drop their stages.','candidates':result,'deprioritized':[{'name':'AS-Hankz2','reason':'Final kill-Nalis/Cyberninja event depends on scripted NPC behavior.'},{'name':'AS-SubmarineBase','reason':'182 TriggeredDeath actors and several cannons require more than the apparent simple FortStandard list to be validated.'},{'name':'AS-300kB3TheWarehouse','reason':'Thirteen linked mm1/mm2 damage targets require checking grouped completion/event semantics; not a first simple-switch conversion.'}]}
(HERE/'as-candidates.json').write_text(json.dumps(report,indent=2)+'\n');print('Ranked',len(result),'AS candidates by objective mechanics')
