"""Finalize only cleanly validated, local-use AD conversions; never build a release ZIP."""
from pathlib import Path
import argparse,hashlib,json,math,re,shutil,struct
from prepare import entities,entity_bytes,unpack,pack,MAX_BYTES

def quake(p,eye=False,pickup=False):
 x,y,z=p
 if eye:y+=.70
 if pickup:x+=.5;y-=.05;z+=.5
 return ' '.join(f'{v:.6f}' for v in (-z*32,-x*32,y*32))
def distance(a,b):return math.dist(a,b)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);p.add_argument('--install',type=Path,help='Optional external maps directory; existing rotations are preserved');a=p.parse_args()
 inventory=json.loads((a.output/'inventory.json').read_text());validation={r['id']:r for r in json.loads((a.output/'validation.json').read_text())}
 dest=a.output/'maps';dest.mkdir(exist_ok=True);(dest/'navigation').mkdir(exist_ok=True)
 readme=(a.output/'ad_v1_80_readme.txt').read_text(errors='replace');credits={m[0]:m[1].strip() for m in re.findall(r'^\*\s+(\w+)\s+-\s+(.+)$',readme,re.M)}
 result=[];lists={m:[] for m in ['dm','tdm','ig','ft','cc','ctf','tf','koth']}
 for row in inventory['maps']:
  row=row.copy();id=row['id'];layout=validation.get(id,{})
  if row['status']!='candidate' or not layout.get('passed'):
   row['status']='excluded';row.setdefault('reason','; '.join(layout.get('errors',[])) or 'Failed geometry/navigation screening');result.append(row);continue
  source=a.output/'candidates'/(id+'.bsp');raw=source.read_bytes()
  if layout.get('candidate_sha256') and hashlib.sha256(raw).hexdigest()!=layout['candidate_sha256']:raise ValueError(id+': candidate changed since validation')
  lumps=unpack(raw);rows=entities(lumps[0]);title=credits.get(row['source_map'],rows[0].get('message',id));rows[0]['message']='AD arena: '+title.split(' (')[0];rows[0]['_fpsloppa_conversion']='1'
  spawns=layout['spawns'];goals=layout['goals'];middle=[sum(p[i] for p in spawns)/len(spawns) for i in range(3)]
  def spawn(kind,pos,**fields):
   yaw=layout['spawn_yaws'][spawns.index(pos)] if 'spawn_yaws' in layout and pos in spawns else math.degrees(math.atan2(-(middle[0]-pos[0]),-(middle[2]-pos[2])))
   rows.append(dict(classname=kind,origin=quake(pos,eye=True),angle=f'{yaw:.2f}',**fields))
  for pos in spawns:spawn('info_player_deathmatch',pos)
  for team,color in enumerate(['red','blue']):
   base=goals[team];other=goals[1-team]
   # Choose distinct existing clear positions on each base's side.
   nearby=sorted([s for s in spawns if distance(s,base)<=distance(s,other)],key=lambda s:distance(s,base))[:4]
   for pos in nearby:
    rows[:]=[e for e in rows if not (e.get('classname')=='info_player_deathmatch' and e.get('origin')==quake(pos,eye=True))]
    spawn('info_player_team'+str(team+1),pos)
   spawn('item_flag_team'+str(team+1),base);spawn('info_tf_capture_'+color,base)
   spawn('info_tf_resupply_'+color,nearby[min(1,len(nearby)-1)])
  spawn('info_koth_control',goals[2])
  pickup_kinds=['weapon_shotgun','item_shells','item_health','weapon_rocketlauncher','item_rockets','item_armor1','weapon_supershotgun','item_shells','item_health','weapon_nailgun','item_spikes','weapon_supernailgun','item_cells','item_health','item_armor2','item_rockets']
  # Farthest-point ordering prevents source entity order clustering the useful equipment.
  pending=layout['pickups'][:];chosen=[]
  while pending:
   point=max(pending,key=lambda p:min(distance(p,q) for q in chosen) if chosen else distance(p,middle));chosen.append(point);pending.remove(point)
  if len(chosen)<8:
   row['status']='excluded';row['reason']='Fewer than eight separate reachable pickup locations';result.append(row);continue
  for i,pos in enumerate(chosen):rows.append({'classname':pickup_kinds[i%len(pickup_kinds)],'origin':quake(pos,pickup=True)})
  fixtures=[]
  for e in rows:
   if '_fpsloppa_fixture' in e and 'origin' in e:fixtures.append({'classname':'misc_librequake_fixture','origin':e['origin'],'fixture':e.pop('_fpsloppa_fixture'),'angle':e.get('angle','0')})
  rows.extend(fixtures[:384]);lumps[0]=entity_bytes(rows)
  end=max(o+n for o,n in [struct.unpack_from('<II',raw,4+i*8) for i in range(15)]);at=(end+3)&~3;rgb=None
  if raw[at:at+4]==b'BSPX':
   for i in range(struct.unpack_from('<I',raw,at+4)[0]):
    entry=at+8+i*32;name=raw[entry:entry+24].split(b'\0')[0];off,size=struct.unpack_from('<II',raw,entry+24)
    if name==b'RGBLIGHTING':rgb=raw[off:off+size]
  output=pack(struct.unpack_from('<I',raw)[0],lumps,rgb)
  if len(output)>MAX_BYTES:row['status']='excluded';row['reason']='Final entity data exceeds 25 MB';result.append(row);continue
  target=dest/(id+'.bsp');target.write_bytes(output);shutil.copy2(source.with_name(id+'-navigation.res'),dest/'navigation'/(id+'.res'))
  row.update(status='installed-candidate',title=title,bytes=len(output),sha256=hashlib.sha256(output).hexdigest(),modes=layout['modes'],spawns=len(spawns),pickups=len(chosen),fixtures=min(len(fixtures),384),validation=layout)
  for mode in row['modes']:lists[mode].append(id)
  (dest/(id+'-README.txt')).write_text(f'{title}\nSource: Arcane Dimensions 1.80 patch 1, {row["source_map"]}.bsp\nSource SHA256: {row["original_sha256"]}\n\nLOCAL TESTING ONLY. Original notices in AD-NOTICES must accompany this file.\nThis is an unofficial FPSloppa conversion, not an AD release.\nEmbedded textures and original lighting retained; absent texture pixels use LibreQuake.\nSingle-player scripts, monsters, gates, breakables and external decorations removed.\nStatic brush movers, connected capsule-clear arena spawns, game-native pickups and\nflag/capture/resupply/hill objectives added. External flame props use LibreQuake.\nSupported experimental rotations: {", ".join(row["modes"])}.\nTeam layouts are asymmetric and not competitively balanced. Automated geometry and\nnavigation screening is not a complete playtest. PC first; headset FPS unverified.\n')
  result.append(row)
 # Quarantine outputs rejected by a later run; never leave them in the picker.
 accepted={r['id'] for r in result if r['status']=='installed-candidate'}
 for old in dest.glob('ad_arena_*.bsp'):
  if old.stem in accepted:continue
  quarantine=a.output/'quarantine';quarantine.mkdir(exist_ok=True)
  if a.install:
   installed=a.install/old.name
   if installed.exists() and hashlib.sha256(installed.read_bytes()).digest()==hashlib.sha256(old.read_bytes()).digest():installed.replace(quarantine/('installed-'+old.name))
  for item in [old,old.with_name(old.stem+'-README.txt'),dest/'navigation'/(old.stem+'.res')]:
   if item.exists():item.replace(quarantine/item.name)
 notices=dest/'AD-NOTICES';notices.mkdir(exist_ok=True)
 if (a.output/'notices').exists():shutil.copytree(a.output/'notices',notices,dirs_exist_ok=True)
 for f in a.output.glob('ad_*.txt'):shutil.copy2(f,notices/f.name)
 (notices/'LOCAL-ONLY.txt').write_text('Do not upload these converted maps to GitHub or a public release. The original AD distribution clause requires its current state; non-commercial is not a blanket adaptation/redistribution permission. Retain the original archive and all credits.\n')
 for mode,ids in lists.items():(dest/(mode+'_ad_maplist.txt')).write_text('\n'.join(ids)+'\n')
 (a.output/'adaptation-report.json').write_text(json.dumps({'archive_sha256':inventory['archive_sha256'],'excluded_test_maps':inventory['excluded_test_maps'],'maps':result,'mode_counts':{m:len(ids) for m,ids in lists.items()}},indent=2))
 config='// Local AD testing only. Existing maplists remain untouched.\n'
 for mode,ids in lists.items():config+=f'seta {mode}_maplist "'+ ' '.join(ids)+'"\n'
 (dest/'ad-maplists.cfg').write_text(config)
 if a.install:
  a.install.mkdir(parents=True,exist_ok=True)
  for file in dest.rglob('*'):
   if file.is_file():target=a.install/file.relative_to(dest);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(file,target)
 print(json.dumps({'included':sum(r['status']=='installed-candidate' for r in result),'excluded':sum(r['status']=='excluded' for r in result),'modes':{m:len(ids) for m,ids in lists.items()},'maps':str(dest),'installed':str(a.install)},indent=2))
if __name__=='__main__':main()
