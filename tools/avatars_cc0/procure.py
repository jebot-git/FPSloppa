"""Fetch only the CC0 historical VRoid collection named by the user.
Keep archives/receipts in ignored test-results; admit files only after native validation.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib, json, requests, zipfile
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/avatars-cc0';OUT.mkdir(parents=True,exist_ok=True)
NAMES=['avatarsample_d_darkness','avatarsample_e','base_female','base_male','hairsample_female','hairsample_male','sakurada_fumiriya','sendagaya_shino']
def fetch(name):
 url=f'https://opengameart.org/sites/default/files/{name}.zip';archive=OUT/(name+'.zip')
 if not archive.exists():
  r=requests.get(url,timeout=60);r.raise_for_status();archive.write_bytes(r.content)
 rows=[]
 with zipfile.ZipFile(archive) as z:
  for info in z.infolist():
   if not info.filename.lower().endswith('.vrm'):continue
   assert info.file_size<100_000_000
   data=z.read(info);dest=OUT/(name+'.vrm');dest.write_bytes(data)
   rows.append({'key':name,'archive_url':url,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'source_member':info.filename,'file':str(dest.relative_to(ROOT)),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 return rows
with ThreadPoolExecutor(max_workers=4) as pool:
 rows=[row for batch in pool.map(fetch,NAMES) for row in batch]
(OUT/'downloads.json').write_text(json.dumps(rows,indent=2)+'\n')
for r in rows:print(r['key'],r['bytes'],r['sha256'])
