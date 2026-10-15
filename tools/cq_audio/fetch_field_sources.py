"""Fetch the pinned OGA/Freesound build inputs; no account or API token required."""
import concurrent.futures,hashlib,json,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];CACHE=ROOT/'tools/audio-sources/cq-field'
ROWS=json.loads((ROOT/'deathmatch/audio/cq_field/sources.json').read_text())
def fetch(row):
 if row['id']=='tabasco_existing':return
 target=CACHE/row['file'];target.parent.mkdir(parents=True,exist_ok=True)
 if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest()!=row['sha256']:
  if not row.get('download'):raise FileNotFoundError('Place manually downloaded source at '+str(target)+'; source: '+row['page'])
  temp=target.with_suffix(target.suffix+'.part')
  with urllib.request.urlopen(row['download'],timeout=120) as response, temp.open('wb') as output:
   while chunk:=response.read(1024*1024):output.write(chunk)
  if hashlib.sha256(temp.read_bytes()).hexdigest()!=row['sha256']:raise ValueError('Source hash mismatch: '+row['id'])
  temp.replace(target)
 if target.suffix=='.zip':
  destination=CACHE/row['id'];destination.mkdir(exist_ok=True)
  with zipfile.ZipFile(target) as archive:
   for info in archive.infolist():
    if not (destination/info.filename).resolve().is_relative_to(destination.resolve()):raise ValueError('Unsafe archive path')
   archive.extractall(destination)
 print('VERIFIED',row['id'])
if __name__=='__main__':
 CACHE.mkdir(parents=True,exist_ok=True);(CACHE/'.gdignore').touch()
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(fetch,ROWS))
