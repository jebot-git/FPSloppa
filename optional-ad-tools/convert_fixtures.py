"""Convert first-frame LibreQuake MDL flame fixtures to portable mesh/skin data."""
import argparse,base64,hashlib,json,struct
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('pak',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();data=a.pak.read_bytes();o,l=struct.unpack_from('<II',data,4);files={}
for at in range(o,o+l,64):
 name=data[at:at+56].split(b'\0')[0].decode();offset,size=struct.unpack_from('<II',data,at+56);files[name]=data[offset:offset+size]
palette=files['gfx/palette.lmp'];a.output.mkdir(exist_ok=True,parents=True);reports=[]
for name in ['flame','flame2']:
 raw=files['progs/'+name+'.mdl'];assert raw[:4]==b'IDPO' and struct.unpack_from('<I',raw,4)[0]==6
 scale=struct.unpack_from('<3f',raw,8);offset=struct.unpack_from('<3f',raw,20);skins,w,h,nverts,ntris,frames,_,_=struct.unpack_from('<8i',raw,48);at=84
 assert skins==1 and struct.unpack_from('<I',raw,at)[0]==0
 skin=raw[at+4:at+4+w*h];at+=4+w*h
 st=[struct.unpack_from('<3i',raw,at+i*12) for i in range(nverts)];at+=12*nverts
 triangles=[struct.unpack_from('<4i',raw,at+i*16) for i in range(ntris)];at+=16*ntris
 frame_type=struct.unpack_from('<I',raw,at)[0];at+=4
 if frame_type==1:
  group_count=struct.unpack_from('<I',raw,at)[0];at+=12+4*group_count
 else:assert frame_type==0
 at+=24;vertices=[]
 for i in range(nverts):
  v=raw[at+i*4:at+i*4+3];x,y,z=[v[j]*scale[j]+offset[j] for j in range(3)];vertices.append([-y/32,z/32,-x/32])
 pos=[];uv=[]
 for front,*ids in triangles:
  for i in reversed(ids):
   seam,s,t=st[i];pos.append(vertices[i]);uv.append([(s+(.5*w if seam and not front else 0)+.5)/w,(t+.5)/h])
 pixels=b''.join(palette[c*3:c*3+3]+b'\xff' for c in skin)
 glow=b''.join((palette[c*3:c*3+3] if c>=224 else b'\0\0\0')+b'\xff' for c in skin)
 (a.output/(name+'.json')).write_text(json.dumps({'size':[w,h],'positions':pos,'uv':uv,'rgba':base64.b64encode(pixels).decode(),'glow':base64.b64encode(glow).decode()},separators=(',',':')))
 reports.append({'model':name,'source':'progs/'+name+'.mdl','sha256':hashlib.sha256(raw).hexdigest(),'triangles':ntris,'conversion':'first frame, original UV/skin, Quake-to-Godot coordinates'})
(a.output/'SOURCES.json').write_text(json.dumps({'source':'LibreQuake full release used by FPSloppa base assets','pak_sha256':hashlib.sha256(data).hexdigest(),'license':'BSD-3-Clause','models':reports},indent=2))
