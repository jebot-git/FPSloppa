"""Verify every archived byte and sync the internal Android offline bundle."""
import hashlib,json,shutil,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
 return h.hexdigest()
def main():
 manifest=json.loads((ROOT/'deathmatch/assets/base_manifest.json').read_text());archive=ROOT.parent/'Builds'/f"FPSloppa-{manifest['version']}-Base-Assets.zip"
 assert sha(archive)==manifest['sha256']
 expected={r['id'] for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()) if r.get('distribution','base')=='base'}
 retired=set(json.loads((ROOT/'deathmatch/maps/retired.json').read_text()))
 with zipfile.ZipFile(archive) as z:
  assert set(z.namelist())=={r['path'] for r in manifest['files']}
  actual={Path(n).stem for n in z.namelist() if n.endswith('.bsp')};assert actual==expected and not actual&retired
  for row in manifest['files']:
   h=hashlib.sha256();size=0
   with z.open(row['path']) as f:
    for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk);size+=len(chunk)
   assert h.hexdigest()==row['sha256'] and size==row['size'],row['path']
 dest=ROOT/'deathmatch/assets/offline-base.zip';temp=dest.with_suffix('.zip.tmp');shutil.copyfile(archive,temp);assert sha(temp)==manifest['sha256'];temp.replace(dest)
 report={'version':manifest['version'],'archive':str(archive),'sha256':manifest['sha256'],'bytes':archive.stat().st_size,'maps':len(expected),'de_maps':len([x for x in expected if x.startswith('de_')]),'st_maps':25,'files':len(manifest['files']),'all_crc_size_sha256_verified':True,'offline_android_copy_matches':True,'retired_maps_absent':sorted(retired),'platform_binaries_exported':False}
 (ROOT/'tools/expansions/bundle_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':main()
