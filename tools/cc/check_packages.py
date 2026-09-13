"""Verify exact base/optional map contents, hashes, sources and editable-list separation."""
from pathlib import Path
import json,hashlib,zipfile,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from map_distribution import check_selection
version=(ROOT/'VERSION').read_text().strip();base=ROOT.parent/'Builds'/f'FPSloppa-{version}-Base-Assets.zip';optional=ROOT.parent/'Builds'/f'FPSloppa-{version}-LibreQuake-Expansion.zip'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((ROOT/'deathmatch/assets/base_manifest.json').read_text());assert sha(base)==m['sha256']
expected={r['id'] for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()) if r.get('distribution','base')=='base'}
with zipfile.ZipFile(base) as z:
 assert z.testzip() is None
 check_selection(z.namelist());actual={Path(p).stem for p in z.namelist() if p.endswith('.bsp')};assert actual==expected and len(actual)==25,(actual,expected)
 assert not any(Path(n).name.startswith('lqdm') and Path(n).suffix in ['.bsp','.lit','.scn','.res'] for n in z.namelist())
 for r in m['files']:assert hashlib.sha256(z.read(r['path'])).hexdigest()==r['sha256'],r['path']
 for i in range(1,8):
  assert f'maps/Quake/sources/original/DM{i}.MAP' in z.namelist()
  assert f'maps/Quake/sources/adapted/qsrc_dm{i}.map' in z.namelist()
 assert 'maps/Quake/COPYING-GPL-2.0.txt' in z.namelist()
 for mode in ['dm','ig','ft','tdm']:assert z.read('maps/'+mode+'_maplist.txt').decode().split()==['qsrc_dm'+str(i) for i in range(1,8)]
with zipfile.ZipFile(optional) as z:
 assert z.testzip() is None
 assert {Path(p).stem for p in z.namelist() if p.endswith('.bsp')}=={'lqdm'+str(i) for i in range(1,14)}
 assert not any(n in ['maps/'+m+'_maplist.txt' for m in ['dm','tdm','ig','ft','cc','ctf','koth']] for n in z.namelist())
 assert 'maps/LibreQuakeExpansion/README.md' in z.namelist()
receipt={'passed':True,'base_maps':sorted(expected),'base_files':len(m['files']),'base_sha256':sha(base),'optional_sha256':sha(optional),'optional_maps':13,'editable_maplists_not_overwritten':True}
(ROOT/'docs/validation/cc-packages.json').write_text(json.dumps(receipt,indent=2)+'\n');print('PACKAGE_SELECTION_PASS',json.dumps(receipt))
