"""Indexed LibreQuake texture substitution (CC0); no original TF assets."""
import hashlib,struct,json
from pathlib import Path
def digest(data):return hashlib.sha256(data).hexdigest()
def wad_textures(path):
 d=path.read_bytes();n,offset=struct.unpack_from('<ii',d,4);result={}
 for i in range(n):
  at,size,_,kind,compression,_,name=struct.unpack_from('<iiiBBH16s',d,offset+i*32)
  assert kind==68 and not compression
  result[name.split(b'\0')[0].decode()]=d[at:at+size]
 return result
def donor(name):
 n=name.lower()
 if n.startswith('sky'):return 'sky_star'
 if n.startswith('*'):
  return '*lava1' if 'lava' in n else '*slime1' if 'slime' in n else '*water2'
 if 'red' in n or 'rflag' in n:return 'wall_red_a'
 if 'blue' in n or 'bflag' in n:return 'wall_blue_a'
 if 'door' in n or 'dr' in n:return 'tek_door1'
 if 'light' in n or 'lite' in n:return 'tlight12'
 if 'ceil' in n:return 'met_brn_pan1'
 if 'floor' in n or 'flr' in n:return 'met_brn_tile2'
 if 'comp' in n or n.startswith('+'):return 'compbase'
 return ['med_csl_brk7_2','met_brn_block','met_brn_slat','t_wall1aa'][int(digest(n.encode())[:8],16)%4]
def convert(raw,donors):
 pack=Path(__file__).resolve().parents[2]/'deathmatch/maps/texture_replacements'
 shared=json.loads((pack/'manifest.json').read_text())['textures'] if (pack/'manifest.json').exists() else {}
 payload=(pack/'replacement-miptex.lmp').read_bytes() if shared else b''
 data=bytearray(raw);assert struct.unpack_from('<i',data)[0]==29,'BSP29 required'
 offset,size=struct.unpack_from('<ii',data,20);count=struct.unpack_from('<i',data,offset)[0];report=[]
 for i in range(count):
  rel=struct.unpack_from('<i',data,offset+4+i*4)[0]
  if rel==-1:
   ti,tn=struct.unpack_from('<ii',data,4+6*8)
   assert all(struct.unpack_from('<i',data,t+32)[0]!=i for t in range(ti,ti+tn,40)), 'Referenced external texture needs a donor'
   report.append({'unused_slot':i});continue
  assert rel>=0
  at=offset+rel;name=data[at:at+16].split(b'\0')[0].decode();source_name=donor(name);source=donors[source_name]
  if name.lower() in shared:
   entry=shared[name.lower()];source=payload[entry['offset']:entry['offset']+entry['size']];source_name='shared:'+name.lower()
  width,height=struct.unpack_from('<II',data,at+16);sw,sh=struct.unpack_from('<II',source,16)
  for mip in range(4):
   dest_start=struct.unpack_from('<I',data,at+24+mip*4)[0];source_start=struct.unpack_from('<I',source,24+mip*4)[0]
   w,h=max(1,width>>mip),max(1,height>>mip);sx,sy=max(1,sw>>mip),max(1,sh>>mip)
   assert dest_start>=40 and rel+dest_start+w*h<=size
   # Nearest-neighbor indexed sampling preserves the LibreQuake palette.
   pixels=bytes(source[source_start+(y*sy//h)*sx+x*sx//w] for y in range(h) for x in range(w))
   data[at+dest_start:at+dest_start+w*h]=pixels
  report.append({'original_name':name,'librequake_texture':source_name,'source_sha256':digest(source)})
 # All geometry, lighting, entities, collision and texture dimensions stay intact.
 return data,report
