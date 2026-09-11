"""Fetch pinned FortressOne source maps/readmes into a LOCAL directory. CC0."""
from pathlib import Path
import argparse,hashlib,json,urllib.request
p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);a=p.parse_args()
data=json.loads(Path(__file__).with_name('sources.json').read_text())
for row in data['files']:
    target=a.output/row['map']/Path(row['upstream_path']).name
    raw=target.read_bytes() if target.exists() else urllib.request.urlopen(row['url'],timeout=60).read(row['size']+1)
    if len(raw)!=row['size'] or hashlib.sha256(raw).hexdigest()!=row['sha256']:raise SystemExit('Source verification failed: '+str(target))
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw);print(target)
(a.output/'SOURCES.json').write_text(json.dumps(data,indent=2)+'\n')
