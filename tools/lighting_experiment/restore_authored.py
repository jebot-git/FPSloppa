"""Relight the eight LibreQuake derivatives while preserving shipping geometry."""
import hashlib,json,re,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.makkon.theme import lumps,repack
OUT=ROOT/'test-results/authored-base';OUT.mkdir(parents=True,exist_ok=True)
LIGHT=Path('/tmp/hislop-ericw/ericw-tools-v0.18-Linux/bin/light')
FLAGS=['-threads','2','-extra4','-bspxlit','-bounce','0']
def main():
 report=[]
 for group in ['koth','cc']:
  for row in json.loads((ROOT/f'tools/{group}/recipes.json').read_text()):
   name=row['id'];source=ROOT/'maps'/f'{name}.bsp';original=source.read_bytes();parts,extras=lumps(original)
   (OUT/f'{name}-before.bsp').write_bytes(original)
   world,rest=parts[0].split(b'}',1)
   world=re.sub(rb'"_minlight"\s*"[^"]*"',b'',world)
   world=re.sub(rb'"_fpsloppa_light_response"\s*"[^"]*"',b'',world)
   parts[0]=world+b'"_fpsloppa_light_response" "quake"\n}'+rest
   prepared=repack(parts,extras);candidate=OUT/f'{name}.bsp';candidate.write_bytes(prepared)
   with (OUT/f'{name}.log').open('w') as log:subprocess.run([str(LIGHT),*FLAGS,str(candidate)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
   after,ax=lumps(candidate.read_bytes())
   for i in range(15):
    if i not in (0,7,8):assert parts[i]==after[i],(name,i)
   assert len(parts[7])==len(after[7])
   for i in range(0,len(parts[7]),20):assert parts[7][i:i+12]==after[7][i:i+12]
   def entities(data):return [dict(re.findall(rb'"([^"\n]*)"\s*"([^"\n]*)"',e)) for e in re.findall(rb'\{([^{}]*)\}',data)]
   assert entities(parts[0])==entities(after[0]),name
   rgb=next(v for k,v in ax if k.rstrip(b'\0')==b'RGBLIGHTING');assert len(rgb)==len(after[8])*3
   report.append({'id':name,'before_sha256':hashlib.sha256(original).hexdigest(),'sha256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'light_bytes':len(after[8]),'rgb_bytes':len(rgb),'geometry_vis_collision_textures_gameplay_preserved':True,'flags':FLAGS})
   (OUT/'build.json').write_text(json.dumps(report,indent=2)+'\n');print('BAKED',name,flush=True)
if __name__=='__main__':main()
