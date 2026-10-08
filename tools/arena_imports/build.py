"""Adapt native Quake arenas while preserving geometry, UVs and authored light samples."""
from pathlib import Path
import json,zipfile,struct,sys,re,hashlib,subprocess
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).parent
sys.path.insert(0,str(ROOT/'tools'));from makkon.theme import repack
sys.path.insert(0,str(ROOT/'tools/cs16_map_converter'));from bsp import parse_entities

def sha(b):return hashlib.sha256(b).hexdigest()
def unpack(b):
 assert b[:4] in [struct.pack('<i',29),b'BSP2']
 ranges=[struct.unpack_from('<ii',b,4+8*i) for i in range(15)];assert all(o>=0 and n>=0 and o+n<=len(b) for o,n in ranges)
 parts=[b[o:o+n] for o,n in ranges];end=(max(o+n for o,n in ranges)+3)&~3;extra=[]
 if b[end:end+4]==b'BSPX':
  for i in range(struct.unpack_from('<i',b,end+4)[0]):
   k,o,n=struct.unpack_from('<24sii',b,end+8+32*i);assert 0<=o<=o+n<=len(b);extra.append((k,b[o:o+n]))
 return parts,extra
def pack(parts,extra,version):return version+repack(parts,extra)[4:]
def compact_mips(lump):
 count=struct.unpack_from('<i',lump)[0];out=bytearray(struct.pack('<i',count)+bytes(4*count))
 for i in range(count):
  at=struct.unpack_from('<i',lump,4+4*i)[0]
  if at<0:struct.pack_into('<i',out,4+4*i,-1);continue
  w,h,start=struct.unpack_from('<III',lump,at+16);assert start>=40
  raw=lump[at+start:at+start+w*h];assert len(raw)==w*h
  struct.pack_into('<i',out,4+4*i,len(out));out.extend(lump[at:at+24]+struct.pack('<4I',40,0,0,0)+raw)
 return bytes(out)
def adapt(raw,lit,title):
 parts,extra=unpack(raw);original=list(parts);entities=parse_entities(parts[0]);kept=[];removed=[]
 for e in entities:
  kind=e.get('classname','')
  if kind.startswith('monster_') or kind in ['trigger_changelevel','info_player_coop','item_key1','item_key2','item_sigil'] or int(float(e.get('spawnflags','0') or '0'))&2048:
   removed.append(kind);continue
  if kind=='worldspawn':e.update(_fpsloppa_bake='1',_fpsloppa_atlas='4096',_fpsloppa_light_response='quake',message=title)
  kept.append(e)
 parts[0]=('\n'.join('{\n'+'\n'.join('"'+k+'" "'+v.replace('"',"'")+'"' for k,v in e.items())+'\n}' for e in kept)+'\n\0').encode('latin1',errors='replace')
 invalid_lit=bool(lit and (lit[:8]!=b'QLIT\x01\0\0\0' or len(lit)!=8+3*len(parts[8])))
 if invalid_lit:lit=None
 if lit:
  extra=[(k,v) for k,v in extra if k.rstrip(b'\0')!=b'RGBLIGHTING'];extra.append((b'RGBLIGHTING',lit[8:]))
 result=pack(parts,extra,raw[:4]);compact=False
 if len(result)>25_000_000:parts[2]=compact_mips(parts[2]);result=pack(parts,extra,raw[:4]);compact=True
 assert len(result)<=25_000_000
 assert all(parts[i]==original[i] for i in range(1,15) if i!=2)
 return result,{'removed_entities':removed,'invalid_external_lit':invalid_lit,'source_spawns':sum(e.get('classname')=='info_player_deathmatch' for e in kept),'geometry_uvs_collision_light_samples_unchanged':True,'base_texture_pixels_unchanged':True,'legacy_lower_mips_omitted':compact,'mipmap_policy':'Full color mip chain regenerated at import; packed lightmaps remain lossless and unmipped.'}
def main():
 sources=json.loads((HERE/'sources.json').read_text());catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text());reports=[]
 for source in sources:
  if source['collection'] not in ['q30','rcmd_quake1']:continue
  z=zipfile.ZipFile(HERE/'local'/source['archive']);readme=z.read('readme.md').decode() if source['collection']=='q30' else '';titles={}
  for line in readme.splitlines():
   if '.bsp`' in line:
    cells=line.split('|');name=re.search(r'`([^`]+)\.bsp`',cells[1])[1];titles[name]=(cells[2].strip(' *'),cells[3].strip(' _'))
  for n in z.namelist():
   if not n.endswith('.bsp') or '_start.bsp' in n or '/negke_sp_remix/' in n:continue
   key=Path(n).stem;id='dm_'+key if source['collection']=='q30' else 'dm_rcmd_'+key
   title,author=titles.get(key,(key,'spirit'));folder=ROOT/'maps/ArenaImports'/id;folder.mkdir(parents=True,exist_ok=True)
   for doc in z.namelist():
    if doc.lower().endswith(('.txt','.md','.map')):
     dest=folder/'original'/doc;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(doc))
   raw=z.read(n);lit=z.read(n[:-4]+'.lit') if n[:-4]+'.lit' in z.namelist() else None
   adapted,changes=adapt(raw,lit,title+' (Arena conversion)');(ROOT/'maps'/(id+'.bsp')).write_bytes(adapted)
   if changes['invalid_external_lit']:
    dest=ROOT/'maps'/(id+'.bsp')
    with (folder/'rebake.log').open('w') as log:
     subprocess.run(['/tmp/st-toolchain/ericw-tools-v0.18.1-Linux/bin/light','-threads','2','-extra','-bspxlit',str(dest)],stdout=log,stderr=subprocess.STDOUT,check=True)
    adapted=dest.read_bytes();changes['lighting_rebaked']=True;changes['geometry_uvs_collision_light_samples_unchanged']=False
   row={'id':id,'title':title,'author':author,'collection':source['collection'],'source_url':source['url'],'archive_sha256':source['sha256'],'member':n,'source_sha256':sha(raw),'sha256':sha(adapted),'bytes':len(adapted),**changes}
   (folder/'conversion.json').write_text(json.dumps(row,indent=2)+'\n');reports.append(row)
   catalog=[r for r in catalog if r['id']!=id]+[{'id':id,'title':title+' (Q30)' if source['collection']=='q30' else title+' (RCMD)','author':author,'modes':['dm','tdm','ig','if','ft','cc'],'path':'res://maps/'+id+'.bsp','scene':'res://maps/cache/'+id+'.scn','sha256':sha(adapted),'distribution':'local','recommended_players':[2,8]}]
 (ROOT/'deathmatch/maps/manifest.json').write_text(json.dumps(catalog,indent=2)+'\n');(HERE/'conversions.json').write_text(json.dumps(reports,indent=2)+'\n');print('Prepared',len(reports),'native maps')
if __name__=='__main__':main()
