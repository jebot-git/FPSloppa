"""Attempt RCMD Quake II/III brush-source conversion to the supported Quake BSP."""
from pathlib import Path
import json,zipfile,io,re,struct,subprocess,sys,hashlib,concurrent.futures,math,os
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).parent;OUT=HERE/'local/rcmd-source-conversion';OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(ROOT/'tools'));from quake_source.build import blocks,fields,setkey
from makkon.theme import wad_textures
sys.path.insert(0,str(ROOT/'tools/cs16_map_converter'));from make_fixture import box,tile
COMPILER=Path(os.environ.get('ERICW_TOOLS_BIN','/tmp/st-toolchain/ericw-tools-v0.18.1-Linux/bin'))
BANK=wad_textures((ROOT/'tools/fortressone/librequake.wad').read_bytes())
# Original donor pixels and all four mip levels stay intact.
for tool in ['clip','trigger','skip']:
 if tool not in BANK:BANK[tool]=tile(tool,0)
from rcmd_materials import Materials
MAPPING={'weapon_blaster':'weapon_shotgun','weapon_machinegun':'weapon_nailgun','weapon_chaingun':'weapon_supernailgun','weapon_railgun':'weapon_lightning','weapon_bfg':'weapon_lightning','weapon_plasmagun':'weapon_supernailgun','ammo_bullets':'item_spikes','ammo_shells':'item_shells','ammo_rockets':'item_rockets','ammo_cells':'item_cells','ammo_slugs':'item_cells','ammo_grenades':'item_rockets','ammo_lightning':'item_cells','ammo_railgun':'item_cells','ammo_plasma':'item_spikes','ammo_bfg':'item_cells','item_armor_body':'item_armorInv','item_armor_combat':'item_armor2','item_armor_jacket':'item_armor1','item_armor_shard':'item_armor1','item_armor_small':'item_armor1','item_health_small':'item_health','item_health_large':'item_health','item_health_mega':'item_health','item_quad':'item_artifact_super_damage','item_enviro':'item_artifact_envirosuit','item_invulnerability':'item_artifact_invulnerability','misc_teleporter':'trigger_teleport','misc_teleporter_dest':'info_teleport_destination','target_position':'info_teleport_destination','info_player_start':'info_player_start'}
def attempt(task):
 source,member,raw,files=task;materials=Materials(BANK,files);bank=materials.bank;key=Path(member).stem;id='dm_rcmd_'+key;folder=OUT/id;folder.mkdir(exist_ok=True);(folder/'original.map').write_bytes(raw)
 row={'id':id,'collection':source['collection'],'source_url':source['url'],'archive_sha256':source['sha256'],'member':member,'source_sha256':hashlib.sha256(raw).hexdigest()}
 try:
  text=raw.decode('latin1');assert not re.search(r'\b(?:patchDef2|patchDef3|brushDef3)\b',text),'Curved patches/brush primitives require a separate geometry adapter; not discarded'
  used=set();mapping={};parts=[];emitters={};emission_aliases={}
  for block in blocks(text):
   e=fields(block);kind=e.get('classname','')
   if kind.startswith('monster_') or kind in ['info_player_coop','trigger_changelevel','target_changelevel','target_speaker','misc_model','misc_gamemodel','team_CTF_redflag','team_CTF_blueflag']:continue
   if kind=='worldspawn':
    for k,v in {'wad':'arena.wad','message':key+' (RCMD arena adaptation)','_fpsloppa_bake':'1','_fpsloppa_light_response':'quake','_fpsloppa_atlas':'4096','_minlight':'24','_bounce':'1'}.items():block=setkey(block,k,v)
   if kind in MAPPING:block=setkey(block,'classname',MAPPING[kind])
   if kind in ['info_player_team1','info_player_team2','team_CTF_redplayer','team_CTF_blueplayer','team_CTF_redspawn','team_CTF_bluespawn']:block=setkey(block,'classname','info_player_deathmatch')
   if kind=='item_health_mega':block=setkey(block,'spawnflags','2')
   elif kind=='item_health_small':block=setkey(block,'spawnflags','1')
   if kind.startswith('light'):block=re.sub(r'^"(?:targetname|style)"[^\n]*\n?','',block,flags=re.M)
   # Adapt Q2 point teleporters to bounded brush triggers at their authored locations.
   if kind=='misc_teleporter':
    x,y,z=map(float,e['origin'].split());target=e.get('target','');assert target,'Untargeted Q2 teleporter'
    block='{\n"classname" "trigger_teleport"\n"target" "'+target+'"\n'+box((x-16,y-16,z+8),(x+16,y+16,z+56),'trigger')+'\n}';used.add('trigger')
   parts.append(block)
  text='\n'.join(parts)
  face=re.compile(r'^(\s*\([^\n]+?\)\s*\([^\n]+?\)\s*\([^\n]+?\)\s+)(\S+)([^\n]*)$',re.M)
  def replace(m):
   old=m[2];new=materials.material(old);values=m[3].split();assert len(values)>=5
   radiance=0.
   if len(values)>=8:
    try:
     if int(values[6])&1:radiance=max(0.,float(values[7]))
    except ValueError:pass
   if radiance>0 or source['collection']=='rcmd_quake3' and 'light' in old.lower():
    power=min(400.,max(40.,math.sqrt(radiance)*2.)) if radiance>0 else 180.
    if new.startswith('sky'):
     emitters[new]={'source':old,'source_radiance':radiance,'light':max(power,emitters.get(new,{}).get('light',0))}
    else:
     key=(old,radiance)
     if key not in emission_aliases:
      alias='emit%03d'%len(emission_aliases);emission_aliases[key]=alias
      donor=bytearray(bank[new]);donor[:16]=alias.encode().ljust(16,b'\0');bank[alias]=bytes(donor)
     new=emission_aliases[key];emitters[new]={'source':old,'source_radiance':radiance,'light':power}
   mapping[old]=new;used.add(new)
   return m[1]+new+' '+' '.join(values[:5])
  text=face.sub(replace,text);assert used,'No convertible brush faces'
  for alias,emission in emitters.items():
   text+='\n{\n"classname" "light"\n"_surface" "'+alias+'"\n"light" "'+str(emission['light'])+'"\n"_surface_offset" "2"\n}\n'
  row['surface_emitters']=emitters
  (folder/(id+'.map')).write_text('// RCMD geometry adaptation; original source and notices retained.\n'+text)
  wad=bytearray(b'WAD2'+bytes(8));directory=[]
  for name in sorted(used):
   data=bank[name];at=len(wad);wad.extend(data);directory.append(struct.pack('<iiiBBH16s',at,len(data),len(data),68,0,0,name.encode()))
  at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at);(folder/'arena.wad').write_bytes(wad);row['texture_mapping']=mapping;row['texture_sources']=materials.sources;row['unique_colour_materials']=len({n for n in used if n not in ['clip','trigger','skip']})
  for stage,args in [('qbsp',[]),('vis',['-fast']),('light',['-extra','-bspxlit'])]:
   args=['-threads','2']+args if stage!='qbsp' else []
   with (folder/(stage+'.log')).open('w') as log:
    p=subprocess.run([str(COMPILER/stage),*args,str(folder/(id+('.map' if stage=='qbsp' else '.bsp')))],cwd=folder,stdout=log,stderr=subprocess.STDOUT,timeout=180)
   assert p.returncode==0,stage+' failed: '+(folder/(stage+'.log')).read_text()[-700:]
  assert not (folder/(id+'.pts')).exists(),'Compiler found a leak'
  row.update(status='compiled',compiled=str((folder/(id+'.bsp')).relative_to(ROOT)))
 except Exception as e:row.update(status='unsupported',reason=str(e))
 print(id,row['status'],row.get('reason','')[:160],flush=True);return row

def main():
 tasks=[]
 for source in json.loads((HERE/'sources.json').read_text()):
  if source['collection'] not in ['rcmd_quake2','rcmd_quake3','rcmd_q2w']:continue
  z=zipfile.ZipFile(HERE/'local'/source['archive']);files={n:z.read(n) for n in z.namelist() if not n.endswith('/')}
  for n,b in list(files.items()):
   if n.endswith('.pk3'):
    zz=zipfile.ZipFile(io.BytesIO(b));files.update({m:zz.read(m) for m in zz.namelist() if not m.endswith('/')})
   elif n.endswith('.pak') and b[:4]==b'PACK':
    at,size=struct.unpack_from('<ii',b,4)
    for pos in range(at,at+size,64):
     name,off,length=struct.unpack_from('<56sii',b,pos);files[name.rstrip(b'\0').decode()]=b[off:off+length]
  names={Path(n).stem for n in files if n.endswith('.bsp')}
  for n,b in files.items():
   if n.endswith('.map') and Path(n).stem in names:tasks.append((source,n,b,files))
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:reports=list(pool.map(attempt,tasks))
 (HERE/'rcmd-attempts.json').write_text(json.dumps(reports,indent=2)+'\n')
if __name__=='__main__':main()
