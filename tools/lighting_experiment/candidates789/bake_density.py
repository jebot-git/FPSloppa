"""Isolated 8-unit luxels on selected faces; preserve all other baked samples."""
from pathlib import Path
import json,struct,math,subprocess,sys,time,hashlib
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT))
from tools.makkon.theme import lumps,repack
from tools.lighting_experiment.static_bake import FLAGS,LIGHT
OUT=ROOT/'test-results/candidates789'
def sha(b):return hashlib.sha256(b).hexdigest()
def face_data(parts,at,scale=16):
 _,_,first,count,tid=struct.unpack_from('<HHiHH',parts[7],at);tex=struct.unpack_from('<8fii',parts[6],tid*40);points=[]
 for i in range(first,first+count):
  e=struct.unpack_from('<i',parts[13],i*4)[0];v=struct.unpack_from('<HH',parts[12],abs(e)*4)[0 if e>=0 else 1];points.append(struct.unpack_from('<3f',parts[3],v*12))
 coords=[[sum(p[k]*tex[d*4+k] for k in range(3))+tex[d*4+3] for d in range(2)] for p in points]
 shape=[math.ceil(max(c[d] for c in coords)/scale)-math.floor(min(c[d] for c in coords)/scale)+1 for d in range(2)]
 centre=[sum(p[d] for p in points)/len(points) for d in range(3)]
 return shape,centre,tex[8]
def main():
 report=[]
 for name,bounce in [('tf_vesper','1.20'),('tf_pressureworks','1.15')]:
  original=(ROOT/'maps'/f'{name}.bsp').read_bytes();parts,bx=lumps(original);n=len(parts[7])//20
  texoff=parts[2];names=[]
  for i in range(struct.unpack_from('<i',texoff)[0]):
   off=struct.unpack_from('<i',texoff,4+i*4)[0];names.append(texoff[off:off+16].split(b'\0')[0].decode() if off>=0 else '')
  selected=[];shifts=bytearray([4]*n)
  for i in range(n):
   at=i*20;offset=struct.unpack_from('<i',parts[7],at+16)[0]
   if offset<0:continue
   size,p,tex=face_data(parts,at);x,y,z=-p[1]/32,p[2]/32,-p[0]/32
   eligible=(names[tex] in ['stn_gw02_gry1','med_dbrick6','stn_gs01_gry1'] and abs(x)<21 and abs(z)<33 and y<20) if name=='tf_vesper' else (names[tex] in ['med_cobstn1_2','med_cobstn1_2a','ind_brk02_gry1','med_flat5a'] and abs(x)<27 and abs(z)<35 and y<12)
   if eligible:selected.append(i);shifts[i]=3
  assert selected
  folder=OUT/'density';folder.mkdir(exist_ok=True);target=folder/(name+'.bsp')
  extras=[(k,v) for k,v in bx if k.rstrip(b'\0') not in [b'LMSHIFT',b'LMOFFSET',b'LMSTYLE']]+[(b'LMSHIFT'.ljust(24,b'\0'),bytes(shifts))]
  target.write_bytes(repack(parts,extras));start=time.monotonic()
  with target.with_suffix('.log').open('w') as log:subprocess.run([str(LIGHT),*FLAGS,'-bouncescale',bounce,str(target)],stdout=log,stderr=subprocess.STDOUT,check=True)
  after,ax=lumps(target.read_bytes());extra=dict(ax);rgb=extra[b'RGBLIGHTING'.ljust(24,b'\0')];offsets=extra[b'LMOFFSET'.ljust(24,b'\0')];styles=extra[b'LMSTYLE'.ljust(24,b'\0')]
  for j in range(15):
   if j not in [0,7,8]:assert after[j]==parts[j],j
  assert all(parts[7][i:i+12]==after[7][i:i+12] for i in range(0,len(parts[7]),20))
  # Original style order and all unselected samples retained byte for byte.
  oldrgb=dict(bx)[b'RGBLIGHTING'.ljust(24,b'\0')];faces=bytearray(parts[7]);gray=bytearray();colours=bytearray();upgraded=[]
  for i in range(n):
   at=i*20;oldoff=struct.unpack_from('<i',faces,at+16)[0]
   if oldoff<0:continue
   wanted=[s for s in faces[at+12:at+16] if s!=255];available=list(styles[i*4:i*4+4]);fineoff=struct.unpack_from('<i',offsets,i*4)[0]
   fine=i in selected and fineoff>=0 and all(s in available for s in wanted)
   if fine:upgraded.append(i)
   else:shifts[i]=4
   size,_,_=face_data(parts,at,8 if fine else 16);count=size[0]*size[1]
   padding=(-len(gray))%4;gray.extend(bytes(padding));colours.extend(bytes(padding*3));struct.pack_into('<i',faces,at+16,len(gray))
   for slot,style in enumerate(wanted):
    off=fineoff+available.index(style)*count if fine else oldoff+slot*count
    src=after[8] if fine else parts[8];rgb_src=rgb if fine else oldrgb
    assert off>=0 and off+count<=len(src)
    gray.extend(src[off:off+count]);colours.extend(rgb_src[off*3:(off+count)*3])
  mixed=parts.copy();mixed[7]=bytes(faces);mixed[8]=bytes(gray)
  extras=[(k,bytes(colours) if k.rstrip(b'\0')==b'RGBLIGHTING' else v) for k,v in bx if k.rstrip(b'\0') not in [b'LMSHIFT',b'LMOFFSET',b'LMSTYLE']]+[(b'LMSHIFT'.ljust(24,b'\0'),bytes(shifts))]
  final=repack(mixed,extras);target.write_bytes(final)
  assert (ROOT/'maps'/f'{name}.bsp').read_bytes()==original
  entry={'map':name,'source_sha256':sha(original),'candidate_sha256':sha(final),'selected_faces':len(selected),'fine_faces':len(upgraded),'total_faces':n,'lighting_bytes_before':len(parts[8]),'lighting_bytes_after':len(gray),'geometry_unchanged':True,'unselected_light_samples_unchanged':True,'original_styles_preserved':True,'seconds':time.monotonic()-start,'flags':FLAGS+['-bouncescale',bounce]}
  report.append(entry);(OUT/'density.json').write_text(json.dumps(report,indent=2)+'\n');print(entry,flush=True)
if __name__=='__main__':main()
