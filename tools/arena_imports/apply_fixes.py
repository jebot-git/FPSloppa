"""Apply measured spawn corrections and translate remaining source entity semantics."""
from pathlib import Path
import json,math,struct,sys
from build import ROOT,HERE,unpack,pack,sha,parse_entities
sys.path.insert(0,str(ROOT/'tools'));from quake_source.build import blocks,fields
rows=json.loads((HERE/'conversions.json').read_text());catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text());changes=[]
for row in rows:
 id=row['id']
 if row.get('status')!='candidate' and id!='dm_q30_violacea':continue
 file=ROOT/'maps'/(id+'.bsp');raw=file.read_bytes();parts,extra=unpack(raw);entities=parse_entities(parts[0]);fixes=[];out=[]
 corrections=json.loads((ROOT/'test-results/arena-imports'/(id+'-spawn-fixes.json')).read_text()) if row.get('status')=='candidate' else []
 safe_starts=json.loads((ROOT/'test-results/arena-imports'/(id+'-gameplay.json')).read_text()).get('spawns',[])
 intermissions=[]
 if row.get('compiled'):
  original=(ROOT/row['compiled']).parent/'original.map'
  intermissions=[e.get('origin') for b in blocks(original.read_text(encoding='latin1')) if (e:=fields(b)).get('classname')=='info_player_intermission']
 target_positions={e.get('targetname'):list(map(float,e['origin'].split())) for e in entities if 'origin' in e and 'targetname' in e}
 models=list(struct.iter_unpack('<9f7i',parts[14]))
 for e in entities:
  kind=e.get('classname','')
  if kind=='info_player_deathmatch':
   if e.get('origin') in intermissions:fixes.append({'removed':'spectator intermission camera was not a player spawn','origin':e['origin']});continue
   q=list(map(float,e['origin'].split()));p=[-q[1]/32,q[2]/32-.7,-q[0]/32]
   correction=next((f for f in corrections if sum((a-b)**2 for a,b in zip(p,f['original']))<.001),None)
   already_safe=any(f['safe'] and sum((a-b)**2 for a,b in zip(p,f['position']))<.001 for f in safe_starts)
   if correction and 'error' in correction and not already_safe:
    assert sum(f['safe'] for f in safe_starts)>=2
    fixes.append({'removed':'unsafe converted spawn with no clear floor within two metres','origin':e['origin']});continue
   if correction and 'corrected' in correction and not already_safe:
    delta=correction['corrected'][1]-p[1]
    if abs(delta)>.005:
     q[2]+=delta*32;e['origin']=' '.join(f'{v:.5f}' for v in q);fixes.append({'spawn_vertical_adjustment_metres':delta,'from':p,'to':correction['corrected']})
  if kind=='target_teleporter':e['classname']='info_teleport_destination';fixes.append({'entity':'target_teleporter -> info_teleport_destination'})
  if kind=='trigger_teleport' and id=='dm_q30_violacea' and e.get('targetname','').startswith('monsteractivate') and e.get('target') not in target_positions:
   fixes.append({'removed':'inactive single-player monster teleport without a DM destination'});continue
  if kind=='trigger_push' and e.get('target') in target_positions and row['collection']=='rcmd_quake3':
   m=models[int(e['model'][1:])];start=[(a+b)/2 for a,b in zip(m[:3],m[3:6])];target=target_positions[e['target']];dz=target[2]-start[2];assert dz>0
   vz=math.sqrt(2*640*dz);t=vz/640;vx=(target[0]-start[0])/t;vy=(target[1]-start[1])/t;speed=math.sqrt(vx*vx+vy*vy+vz*vz)
   e['angles']=f'{-math.degrees(math.atan2(vz,math.hypot(vx,vy))):.6f} {math.degrees(math.atan2(vy,vx)):.6f} 0';e['speed']=f'{speed:.6f}';e['fpsloppa_push_scale']='1';fixes.append({'pad_target':e['target'],'velocity_bsp_units':[vx,vy,vz],'gravity_bsp_units':640})
  out.append(e)
 parts[0]=('\n'.join('{\n'+'\n'.join('"'+k+'" "'+v.replace('"',"'")+'"' for k,v in e.items())+'\n}' for e in out)+'\n\0').encode('latin1');updated=pack(parts,extra,raw[:4]);file.write_bytes(updated)
 assert all(a==b for a,b in zip(unpack(raw)[0][1:],unpack(updated)[0][1:])) and unpack(raw)[1]==unpack(updated)[1]
 row.update(sha256=sha(updated),bytes=len(updated),runtime_fixes=row.get('runtime_fixes',[])+[f for f in fixes if f not in row.get('runtime_fixes',[])]);changes.append({'id':id,'changes':fixes,'sha256':row['sha256']})
 for c in catalog:
  if c['id']==id:c['sha256']=row['sha256']
 (ROOT/'maps/ArenaImports'/id/'conversion.json').write_text(json.dumps(row,indent=2)+'\n')
(ROOT/'deathmatch/maps/manifest.json').write_text(json.dumps(catalog,indent=2)+'\n');(HERE/'conversions.json').write_text(json.dumps(rows,indent=2)+'\n');(HERE/'runtime-fixes.json').write_text(json.dumps(changes,indent=2)+'\n')
print('Corrected',len(changes),'maps; geometry and all light samples unchanged')
