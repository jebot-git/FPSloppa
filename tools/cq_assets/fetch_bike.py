"""Fetch the pinned Desert Bike through authenticated BlendSwap MCP."""
from pathlib import Path
import hashlib,json,urllib.request,zipfile
from fetch_tiers import mcp,ROOT
root=ROOT/'test-results/bike-source';root.mkdir(parents=True,exist_ok=True)
source=json.loads((ROOT/'deathmatch/models/desert_bike/manifest.json').read_text())['source']
archive=root/'desert-bike.zip'
if not archive.exists():
 if mcp('get_balance')['api_free_downloads_remaining_today']<1:raise RuntimeError('No free BlendSwap downloads remain')
 receipt=mcp('download_asset',{'asset_id':10358})
 if receipt['credits_spent']!=0:raise RuntimeError('Unexpected download charge')
 urllib.request.urlretrieve(receipt['download_url'],archive)
if hashlib.sha256(archive.read_bytes()).hexdigest()!=source['sha256']:raise RuntimeError('Bike source hash mismatch')
with zipfile.ZipFile(archive) as z:
 for member in z.infolist():
  if not (root/member.filename).resolve().is_relative_to(root.resolve()):raise RuntimeError('Unsafe archive path')
  z.extract(member,root)
(root/'source.json').write_text(json.dumps(source,indent=2)+'\n')
print('CQ_BIKE_SOURCE verified BlendSwap 10358')
