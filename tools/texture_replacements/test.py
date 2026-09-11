"""Exercise shared missing-texture imports against a real BSP. Python 3; CC0 tool."""
from pathlib import Path
import argparse,os,struct,subprocess,json
from convert import convert
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('bsp',type=Path);a=p.parse_args();raw=a.bsp.read_bytes();out=ROOT/'test-results/texture-fallback';out.mkdir(parents=True,exist_ok=True)
o,n=struct.unpack_from('<II',raw,20);count=struct.unpack_from('<I',raw,o)[0]
for variant in ['external','unnamed','malformed']:
 data=bytearray(raw)
 for i in range(count):
  relative=struct.unpack_from('<i',raw,o+4+4*i)[0]
  if relative<0:continue
  if variant=='external':struct.pack_into('<4I',data,o+relative+24,0,0,0,0)
  elif variant=='unnamed':struct.pack_into('<i',data,o+4+4*i,-1)
  else:struct.pack_into('<I',data,o+relative+24,0x7fffffff)
 (out/(variant+'.bsp')).write_bytes(data)
# Default missing-only conversion must leave every embedded tile's four mip levels alone.
converted,report=convert(raw)
assert all(r['status'] in ['embedded preserved','unnamed; runtime neutral fallback'] for r in report['textures'])
for i in range(15):
 if i==2:continue
 old,size=struct.unpack_from('<II',raw,4+8*i);new,length=struct.unpack_from('<II',converted,4+8*i)
 assert size==length and raw[old:old+size]==converted[new:new+length],i
repaired,report=convert((out/'external.bsp').read_bytes())
assert all(r['status']=='named replacement' for r in report['textures'])
(out/'repaired.bsp').write_bytes(repaired)
with (out/'runtime.log').open('w') as log:
 r=subprocess.run([os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64')),'--headless','--path',str(ROOT),'--xr-mode','off','--script','res://deathmatch/tests/texture_replacements.gd','--',str(a.bsp.resolve())],stdout=log,stderr=subprocess.STDOUT,timeout=120)
text=(out/'runtime.log').read_text();assert r.returncode==0 and 'TEXTURE_RESULT' in text and 'ERROR:' not in text,text[-4000:]
(out/'RESULT.json').write_text(json.dumps({'pass':True,'conversion':'embedded pixels preserved; missing names filled; other lumps identical','runtime_result':next(line for line in text.splitlines() if line.startswith('TEXTURE_RESULT'))},indent=2))
print('PASS texture import, precedence, dimensions, fallback, bounds and conversion preservation')
