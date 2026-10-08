"""Compile independent BSP solids matching the native combat test lanes."""
import json,sys,subprocess
from pathlib import Path
from build import ROOT,profile
sys.path.insert(0,str(ROOT/'tools/cs16_map_converter'))
from make_fixture import box,tile,wad
out=ROOT/'test-results/de-restoration';out.mkdir(parents=True,exist_ok=True)
rows=[('wood',.25,0),('wood',2,5),('metal',.125,10),('metal',.3,15),('concrete',.2,20),('unknown',.02,25),('wood',.125,30),('wood',.125,35),('wood',.125,40)]
brushes=[]
def add(x,width,z,material):brushes.append(box((-(z+1)*32,-(x+width)*32,0),(-(z-1)*32,-x*32,96),material))
for mat,width,z in rows:add(0,width,z,mat)
add(.125,.125,30,'wood');add(.5,.125,35,'wood');add(.125,.5,40,'metal')
(out/'cover.wad').write_bytes(wad({n:tile(n,64) for n in ['wood','metal','concrete','unknown']}))
source=out/'bsp-cover.map';source.write_text('{\n"classname" "worldspawn"\n"wad" "cover.wad"\n'+ '\n'.join(brushes)+'\n}\n')
with (out/'bsp-cover-build.log').open('w') as f:subprocess.run(['/tmp/st-toolchain/ericw-tools-v0.18.1-Linux/bin/qbsp','-wadpath',str(out),str(source)],stdout=f,stderr=subprocess.STDOUT,check=True)
data,_,_=profile(source.with_suffix('.bsp').read_bytes(),lambda n:'stop' if n=='unknown' else n)
(out/'bsp-cover.json').write_text(json.dumps(data,separators=(',',':')))
print('Compiled independent BSP test fixture')
