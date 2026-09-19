"""Refresh authored objective fill lights without changing compiled geometry/visibility."""
from pathlib import Path
import concurrent.futures,hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/makkon'))
from theme import lumps,repack
OUT=ROOT/'test-results/koth-rotation';LIGHT=Path('/tmp/fpsloppa-ericw/ericw-tools-v0.18.1-Linux/bin/light')
FLAGS=['-novisapprox','-threads','4','-extra4','-bspxlit','-bounce','1','-bouncecolorscale','0.25','-sunlight_penumbra','4','-dirt','1','-dirtdepth','32','-dirtscale','0.5','-minlight_dirt','1']
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def lights(hills):
 return '\n'.join('{\n"classname" "light"\n"_koth_site_light" "1"\n"origin" "%g %g %g"\n"light" "250"\n"_color" "1 0.9 0.75"\n}'%(-p[2]*32,-p[0]*32,(p[1]+2.25)*32) for p in hills)+'\n'
def clean(text):return re.sub(r'\{\s*"classname" "light"[^{}]*"_koth_site_light"[^{}]*\}\s*','',text)
def main():
 catalog_path=ROOT/'deathmatch/maps/manifest.json';catalog=json.loads(catalog_path.read_text());rows=[r for r in catalog if r['id'].startswith('koth_') and r.get('distribution','base')=='base'];receipts=[]
 def bake(row):
  name=row['id'];path=ROOT/'maps'/(name+'.bsp');old=path.read_bytes();parts,extra=lumps(old);hills=row['objectives']['hills'];addition=lights(hills)
  parts[0]=(clean(parts[0].decode('latin1').rstrip('\0')).rstrip()+'\n'+addition+'\0').encode('latin1');path.write_bytes(repack(parts,extra))
  source=ROOT/'maps/KOTH/source'/(name+'.map');source.write_text(clean(source.read_text()).rstrip()+'\n'+addition)
  with (OUT/name/'objective-light.log').open('w') as log:subprocess.run([str(LIGHT),*FLAGS,str(path)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
  after,_=lumps(path.read_bytes());before,_=lumps(old)
  assert all(before[i]==after[i] for i in range(15) if i not in (0,7,8)),name+' geometry or visibility changed'
  assert len(before[7])==len(after[7]) and all(before[7][i:i+12]==after[7][i:i+12] for i in range(0,len(before[7]),20)),name+' face topology changed'
  return {'id':name,'sha256':sha(path),'size':path.stat().st_size,'source_sha256':sha(source),'objective_fill_lights':len(hills),'geometry_visibility_preserved':True}
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:receipts=list(pool.map(bake,rows))
 sky_path=ROOT/'deathmatch/maps/skies/SOURCES.json';sky=json.loads(sky_path.read_text())
 for result in receipts:
  row=next(r for r in catalog if r['id']==result['id']);row.update(sha256=result['sha256'],size=result['size']);sky['map_sources'][result['sha256']]=result['id']
 for file in [OUT/'build.json',ROOT/'maps/KOTH/ROTATION.json']:
  data=json.loads(file.read_text())
  for result in receipts:next(r for r in data['maps'] if r['id']==result['id']).update(result)
  file.write_text(json.dumps(data,indent=2)+'\n')
 catalog_path.write_text(json.dumps(catalog,indent=2)+'\n');sky_path.write_text(json.dumps(sky,indent=2)+'\n');(OUT/'objective-lights.json').write_text(json.dumps(receipts,indent=2)+'\n');print('KOTH_OBJECTIVE_LIGHTS_BAKED')
if __name__=='__main__':main()
