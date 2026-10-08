#!/usr/bin/env python3
"""Recover DE textures from downloaded packs; explicit aliases cover absent art."""
import argparse,hashlib,json,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).parent;LOCAL=HERE/'local'
sys.path.insert(0,str(ROOT/'tools/cs16_map_converter'))
from bsp import BSP
from textures import records,texture,Wads
from convert import convert
TARGETS=['de_dust2','de_westwood','de_abaddon','de_perfect_inferno','de_dust2_snow']
def digest(b):return hashlib.sha256(b).hexdigest()
def bank():
 result={}
 # Prefer non-seasonal original art over winter variants with shared names.
 files=sorted(LOCAL.glob('*/assets/*'),key=lambda p:(any(w in str(p) for w in ['snow','winter','xmas']),str(p)))
 for file in files:
  raw=file.read_bytes()
  if file.suffix=='.bsp':
   at,size=struct.unpack_from('<ii',raw,20);lump=raw[at:at+size];count=struct.unpack_from('<i',lump)[0];slots=struct.unpack_from('<'+'i'*count,lump,4)
   rows=records(lump,[i for i,p in enumerate(slots) if p==-1])
  elif file.suffix=='.wad':rows=[texture(r[0]) for r in Wads([file]).entries.values()]
  else:continue
  for name,w,h,mips,pal in rows:
   if mips:result.setdefault(name,[]).append((w,h,mips,pal,file,digest(raw)))
 return result

def encode(name,w,h,mips,pal):
 raw=bytearray(struct.pack('<16s6I',name.encode(),w,h,0,0,0,0))
 for level,pixels in enumerate(mips):struct.pack_into('<I',raw,24+4*level,len(raw));raw.extend(pixels)
 return bytes(raw)+struct.pack('<H',256)+pal

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);a=parser.parse_args()
 donors=bank();aliases=json.loads((HERE/'texture_aliases.json').read_text());results=json.loads((HERE/'results.json').read_text());receipt=[]
 retired=set(json.loads((ROOT/"deathmatch/maps/retired.json").read_text()))
 for name in TARGETS:
  if "de_varq_"+name[3:] in retired:continue
  folder=LOCAL/name;source=folder/'assets'/(name+'.bsp');base=Wads(sorted((folder/'assets').glob('*.wad')));bsp=BSP(source.read_bytes());mapping=[]
  for tex,w,h,mips,pal in records(bsp.lumps[2]):
   if mips or tex in base.entries:continue
   chosen=tex if tex in donors else aliases[tex]
   options=donors[chosen];dw,dh,dm,dp,file,sha=min(options,key=lambda t:(t[0]!=w or t[1]!=h,options.index(t)))
   assert tex.startswith('{')==chosen.startswith('{'),(tex,chosen)
   base.entries[tex]=(encode(tex,dw,dh,dm,dp),'recovered:'+chosen)
   mapping.append({'texture':tex,'donor_texture':chosen,'match':'exact-name' if chosen==tex else 'material-alias','source':str(file.relative_to(ROOT)),'source_sha256':sha})
  raw,report=convert(source.read_bytes(),base,name+' | CS 1.6 conversion',replace_missing=False)
  dest=ROOT/'maps'/('de_varq_'+name[3:]+'.bsp');previous=dest.read_bytes();old=BSP(previous,29);new=BSP(raw,29)
  assert all(old.lumps[i]==new.lumps[i] for i in range(15) if i!=2),'Nontexture BSP data changed'
  prior_report=folder/'converted'/(name+'_fps.conversion.json');assert report['layout']==json.loads(prior_report.read_text())['layout']
  out=folder/'retextured';out.mkdir(exist_ok=True);candidate=out/(name+'_fps.bsp');candidate.write_bytes(raw)
  log=out/'validation.log'
  with log.open('w') as f:code=subprocess.run([a.godot,'--headless','--audio-driver','Dummy','--xr-mode','off','--path',str(ROOT),'--script','tools/cs16_map_converter/validate.gd','--',str(candidate.resolve())],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=300).returncode
  text=log.read_text();assert code==0 and 'CS_MAP_VALIDATION_PASS' in text and 'ERROR:' not in text,text[-2500:]
  backup=out/'before.bsp'
  if not backup.exists():backup.write_bytes(previous)
  report.update(runtime_validation='passed',recovered_textures=mapping)
  (out/(name+'_fps.conversion.json')).write_text(json.dumps(report,indent=2)+'\n')
  dest.write_bytes(raw)
  for r in results['maps']:
   if r['name']==name:r.update(sha256=digest(raw),bytes=len(raw),replaced_textures=0,recovered_textures=len(mapping),texture_aliases=sum(m['match']=='material-alias' for m in mapping),warnings=report['warnings'],runtime_checks=sum(l.startswith('PASS ') for l in text.splitlines()))
  receipt.append({'map':dest.stem,'before_sha256':digest(backup.read_bytes()),'after_sha256':digest(raw),'preserved_nontexture_lumps':True,'runtime_checks':sum(l.startswith('PASS ') for l in text.splitlines()),'textures':mapping})
  (HERE/'results.json').write_text(json.dumps(results,indent=2)+'\n');(HERE/'texture_validation.json').write_text(json.dumps(receipt,indent=2)+'\n')
  print(name,len(mapping),'recovered; validation passed',flush=True)
if __name__=='__main__':main()
