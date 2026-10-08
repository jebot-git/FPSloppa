"""Audit distinct RCMD colour pixels, excluding alias names and mip headers."""
from pathlib import Path
import struct,json,hashlib,shutil
from build import ROOT,HERE,unpack
from PIL import Image,ImageDraw
rows=[r for r in json.loads((HERE/'conversions.json').read_text()) if r.get('status')=='candidate'];reports=[];palette=(ROOT/'deathmatch/maps/palette.lmp').read_bytes();out=ROOT/'test-results/rcmd-textures';out.mkdir(exist_ok=True)
for row in rows:
 name=row['id'];parts,_=unpack((ROOT/'maps'/(name+'.bsp')).read_bytes());lump=parts[2];count=struct.unpack_from('<i',lump)[0];unique={}
 for i in range(count):
  at=struct.unpack_from('<i',lump,4+i*4)[0]
  if at<0:continue
  texture=lump[at:at+16].split(b'\0')[0].decode();w,h,offset=struct.unpack_from('<III',lump,at+16)
  if texture in ['skip','clip','trigger']:continue
  pixels=lump[at+offset:at+offset+w*h];assert len(pixels)==w*h
  digest=hashlib.sha256(struct.pack('<II',w,h)+pixels).hexdigest()
  if digest in unique:continue
  im=Image.frombytes('P',(w,h),pixels);im.putpalette(palette);unique[digest]=(texture,im.convert('RGB'))
 report=dict(id=name,bsp_sha256=row['sha256'],texture_slots=count,distinct_colour_images=len(unique));assert len(unique)>=5,name+' collapsed to too few images'
 sheet=Image.new('RGB',(6*176,((len(unique)+5)//6)*164),(28,28,30));draw=ImageDraw.Draw(sheet)
 for i,(texture,im) in enumerate(unique.values()):
  x=(i%6)*176;y=(i//6)*164;im.thumbnail((160,136));sheet.paste(im,(x+(160-im.width)//2,y));draw.text((x+4,y+140),texture,fill=(240,240,240))
 sheet.save(out/(name+'.png'));reports.append(report)
 folder=ROOT/'maps/ArenaImports'/name;shutil.copy2(ROOT/'tools/makkon/Makkon_License.txt',folder/'Makkon_License.txt')
(HERE/'texture-validation.json').write_text(json.dumps(reports,indent=2)+'\n');print(json.dumps(reports,indent=2))
