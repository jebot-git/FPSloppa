"""Direct-only LUX data aligned to the current production luxels; outputs test copies."""
from pathlib import Path
import hashlib,json,struct,subprocess,sys,time
import numpy as np
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT))
from tools.makkon.theme import lumps
from tools.lighting_experiment.candidates789.bake_density import face_data
from tools.lighting_experiment.static_bake import FLAGS,LIGHT
OUT=ROOT/'test-results/candidates1011'
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 OUT.mkdir(exist_ok=True)
 paths=[p for folder in ['maps','deathmatch/maps','deathmatch/settings'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in ['.bsp','.scn','.gd','.gdshader','.json','.png','.import']]
 paths += [ROOT/'project.godot',ROOT/'deathmatch/assets/base_manifest.json']
 snapshot=OUT/'production-before.json'
 if not snapshot.exists():snapshot.write_text(json.dumps({str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in paths},indent=2)+'\n')
 records=[]
 for name in ['tf_vesper','tf_pressureworks']:
  original=(ROOT/'maps'/f'{name}.bsp').read_bytes();parts,bx=lumps(original);extras={k.rstrip(b'\0'):v for k,v in bx};faces=len(parts[7])//20;shifts=extras.get(b'LMSHIFT',bytes([4]*faces))
  folder=OUT/'bake';folder.mkdir(exist_ok=True);compiled=folder/f'{name}.bsp';compiled.write_bytes(original)
  flags=FLAGS.copy();flags[flags.index('-bounce')+1]='0';flags+=['-minlight','0','-sunlight2','0','-sunlight3','0','-bspxlux']
  started=time.monotonic()
  with compiled.with_suffix('.log').open('w') as log:subprocess.run([str(LIGHT),*flags,str(compiled)],stdout=log,stderr=subprocess.STDOUT,check=True)
  new,nx=lumps(compiled.read_bytes());data={k.rstrip(b'\0'):v for k,v in nx}
  assert len(data[b'LIGHTINGDIR'])==len(new[8])*3
  for i in range(15):
   if i not in [0,7,8]:assert new[i]==parts[i]
  oldrgb=np.frombuffer(extras[b'RGBLIGHTING'],np.uint8).reshape(-1,3)
  rgba=np.zeros((len(parts[8]),4),dtype=np.uint8);rgba[:,:3]=[128,128,255]
  valid=0;axis=0;missing=0;nonzero=0
  for face in range(faces):
   at=face*20;oldoff=struct.unpack_from('<i',parts[7],at+16)[0]
   if oldoff<0:continue
   oldstyle=parts[7][at+12]
   size,_,_=face_data(parts,at,1<<shifts[face]);count=size[0]*size[1]
   off=struct.unpack_from('<i',data[b'LMOFFSET'],face*4)[0] if b'LMOFFSET' in data else struct.unpack_from('<i',new[7],at+16)[0]
   styles=list(data[b'LMSTYLE'][face*4:face*4+4]) if b'LMSTYLE' in data else list(new[7][at+12:at+16])
   if off<0 or oldstyle not in styles:missing+=1;continue
   off+=styles.index(oldstyle)*count;assert off+count<=len(new[8]) and oldoff+count<=len(parts[8])
   direct=np.frombuffer(data[b'RGBLIGHTING'],np.uint8).reshape(-1,3)[off:off+count].astype(float)
   directions=np.frombuffer(data[b'LIGHTINGDIR'],np.uint8).reshape(-1,3)[off:off+count]
   # LUX is (+texture S, -texture T, face normal), not world space.
   rgba[oldoff:oldoff+count,:3]=directions
   fraction=np.clip(direct.max(axis=1)/np.maximum(oldrgb[oldoff:oldoff+count].max(axis=1),1),0,1)
   rgba[oldoff:oldoff+count,3]=np.rint(fraction*255).astype(np.uint8)
   nonzero+=int((fraction>0).sum());valid+=1
  target=OUT/'direction';target.mkdir(exist_ok=True);(target/f'{name}.bsp').write_bytes(original);(target/f'{name}.rgba').write_bytes(rgba.tobytes())
  records.append({'map':name,'source_sha256':sha(original),'direct_bake_sha256':sha(compiled.read_bytes()),'geometry_preserved':True,'flags':flags,'compiler_sha256':sha(LIGHT.read_bytes()),'seconds':time.monotonic()-started,'aligned_faces':valid,'no_direct_light_faces':missing,'direction_luxels_with_direct_light':nonzero,'direction_format':'RGBA8: ericw tangent (+S,-T,N) direction RGB, direct/current irradiance fraction A','baseline_irradiance_preserved':True})
  (OUT/'bake.json').write_text(json.dumps(records,indent=2)+'\n');print(name,valid,'aligned faces',flush=True)
if __name__=='__main__':main()
