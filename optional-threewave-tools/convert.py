"""Local ThreeWave BSP adaptation. No ThreeWave map is distributed with this tool.
python3 convert.py /path/to/3wctfc.zip --output /path/to/FPSloppa/maps
"""
import argparse,hashlib,json,struct,zipfile,re
from pathlib import Path
BASE=Path(__file__).resolve().parent
# Only original community custom maps, excluding ctfstart / id-authored ctf2m7/8.
ALLOWED={f'ctf2m{i}' for i in range(1,7)}
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
 data=bytearray(raw);assert struct.unpack_from('<i',data)[0]==29,'BSP29 required'
 offset,size=struct.unpack_from('<ii',data,20);count=struct.unpack_from('<i',data,offset)[0];report=[]
 for i in range(count):
  rel=struct.unpack_from('<i',data,offset+4+i*4)[0];assert rel>=0,'External textures are unsupported'
  at=offset+rel;name=data[at:at+16].split(b'\0')[0].decode();source_name=donor(name);source=donors[source_name]
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
def maps_from_archive(path):
 with zipfile.ZipFile(path) as archive:
  for pak_name in ['pak0.pak','pak1.pak']:
   if pak_name not in archive.namelist():continue
   pak=archive.read(pak_name);assert pak[:4]==b'PACK';offset,size=struct.unpack_from('<ii',pak,4)
   for i in range(offset,offset+size,64):
    name=pak[i:i+56].split(b'\0')[0].decode();at,length=struct.unpack_from('<ii',pak,i+56);stem=Path(name).stem
    if name.endswith('.bsp') and stem in ALLOWED:yield stem,pak[at:at+length]
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('archive',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 args.output.mkdir(parents=True,exist_ok=True);donors=wad_textures(BASE/'librequake.wad');manifest=[]
 for name,raw in maps_from_archive(args.archive):
  data,textures=convert(raw,donors);id='threewave_'+name;dest=args.output/(id+'.bsp')
  if dest.exists():raise SystemExit(f'Refusing to overwrite {dest}')
  dest.write_bytes(data)
  manifest.append({'id':id,'sha256':digest(data),'original_sha256':digest(raw),'textures':textures})
  print('CONVERTED',id,len(data),'bytes')
 (args.output/'ThreeWave-local-conversion.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('Local conversion complete. Rescan in FPSloppa; add these IDs to ctf_maplist.txt. Read RIGHTS.md before sharing.')
if __name__=='__main__':main()
