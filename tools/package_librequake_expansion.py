"""Move known bundled LibreQuake maps to an optional pack; never replace user edits."""
from pathlib import Path
import json,hashlib,shutil,zipfile,argparse
ROOT=Path(__file__).resolve().parents[1];PACK=ROOT/'optional-librequake';MAPS=PACK/'maps';DOC=MAPS/'LibreQuakeExpansion'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def stage():
 DOC.mkdir(parents=True,exist_ok=True);(PACK/'.gdignore').write_text('')
 catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text());rows=[]
 for r in catalog:
  if r.get('expansion')!='librequake':continue
  id=r['id'];src=ROOT/'maps'/(id+'.bsp');dest=MAPS/src.name
  if src.exists():
   if sha(src)!=r['sha256']:raise ValueError('Preserving modified map; review before relocating '+str(src))
   shutil.copy2(src,dest)
  assert dest.exists() and sha(dest)==r['sha256']
  for sub,suffix in [('', '.bsp'),('', '.lit'),('cache/','.scn'),('cache/','-lightmap1.scn'),('navigation/','.res')]:
   src=ROOT/'maps'/sub/(id+suffix);dst=MAPS/sub/src.name
   if src.exists():dst.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(src),dst)
  rows.append(r)
 for src in (ROOT/'optional-map-pack').glob('lqdm*.bsp'):
  shutil.copy2(src,MAPS/src.name)
  if src.with_suffix('.lit').exists():shutil.copy2(src.with_suffix('.lit'),MAPS/src.with_suffix('.lit').name)
 for src in (ROOT/'maps').glob('LibreQuake-*.txt'):shutil.copy2(src,DOC/src.name)
 shutil.copy2(ROOT/'maps/KOTH/Makkon_License.txt',DOC/'Makkon_License.txt')
 for src in (ROOT/'optional-map-pack').iterdir():
  if src.is_file() and src.suffix in ['.md','.txt','.json']:shutil.copy2(src,DOC/('extra-'+src.name))
 (DOC/'catalog.json').write_text(json.dumps(rows,indent=2)+'\n')
 originals=['lqdm'+str(i) for i in range(1,9)]
 for mode in ['dm','tdm','ig','ft','cc']:(DOC/(mode+'_maplist.example.txt')).write_text('set '+mode+'_maplist "'+' '.join(originals)+'"\n')
 # Previously bundled community arenas are retained outside base installation too.
 for r in catalog:
  if r.get('expansion')!='community':continue
  id=r['id'];base=ROOT/'optional-community/maps';base.mkdir(parents=True,exist_ok=True)
  for sub,suffix in [('', '.bsp'),('', '.lit'),('cache/','.scn'),('cache/','-lightmap1.scn'),('navigation/','.res')]:
   src=ROOT/'maps'/sub/(id+suffix);dst=base/sub/src.name
   if src.exists():
    if suffix=='.bsp' and sha(src)!=r['sha256']:raise ValueError('Preserving modified community map '+id)
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(src),dst)
 (ROOT/'optional-community/.gdignore').write_text('')
def package():
 version=(ROOT/'VERSION').read_text().strip();out=ROOT.parent/'Builds'/f'FPSloppa-{version}-LibreQuake-Expansion.zip'
 with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in sorted(MAPS.rglob('*')):
   if p.is_file():z.write(p,p.relative_to(PACK))
 with zipfile.ZipFile(out) as z:
  assert z.testzip() is None
  assert {Path(n).stem for n in z.namelist() if n.endswith('.bsp')}=={'lqdm'+str(i) for i in range(1,14)}
  assert not any(n in ['maps/'+mode+'_maplist.txt' for mode in ['dm','tdm','ig','ft','cc']] for n in z.namelist())
 out.with_suffix('.sha256').write_text(sha(out)+'  '+out.name+'\n');print(out,sha(out))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--stage',action='store_true');p.add_argument('--package',action='store_true');a=p.parse_args()
 if a.stage:stage()
 if a.package:package()
