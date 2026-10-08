"""Classify deliberately unbaked DE BSP faces separately from missing opaque bakes."""
import collections,json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/arena_imports'))
from build import unpack
reports=[];failures=[]
for row in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()):
 if 'de' not in row.get('modes',[]):continue
 parts,_=unpack((ROOT/row['path'].removeprefix('res://')).read_bytes())
 textures=[]
 for i in range(struct.unpack_from('<i',parts[2])[0]):
  offset=struct.unpack_from('<i',parts[2],4+4*i)[0]
  textures.append(parts[2][offset:offset+16].split(b'\0')[0].decode('latin1') if offset>=0 else '<missing>')
 texinfo=list(struct.iter_unpack('<8fii',parts[6]));unlit=collections.Counter()
 for face in struct.iter_unpack('<Hhihh4Bi',parts[7]):
  if face[-1]<0 or face[5]==255:unlit[textures[texinfo[face[4]][8]]]+=1
 unexpected={name:count for name,count in unlit.items() if not (name.lower().startswith(('sky','*')) or name.lower() in ('skip','hint','clip','origin','null','nodraw'))}
 if unexpected:failures.append({'map':row['id'],'unexpected':unexpected})
 reports.append({'id':row['id'],'unlit_textures':dict(unlit),'unexpected_opaque':unexpected})
output=ROOT/'test-results/de-lighting/source-faces.json';output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps({'maps':reports,'failures':failures},indent=2)+'\n')
print('DE source lighting:',len(reports),'maps;',len(failures),'failures')
sys.exit(bool(failures))
