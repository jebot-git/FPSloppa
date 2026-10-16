"""Fetch pinned CQ tier sources; BlendSwap acquisition uses its authenticated MCP API.
Credentials stay outside the repository (BLENDSWAP_KEY_FILE, default ~/bsk).
"""
import hashlib,json,os,subprocess,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/weapon-sources'
def mcp(name,arguments=None):
 key=Path(os.environ.get('BLENDSWAP_KEY_FILE',str(Path.home()/'bsk'))).read_text().strip()
 body=json.dumps({'jsonrpc':'2.0','id':1,'method':'tools/call','params':{'name':name,'arguments':arguments or {}}}).encode()
 request=urllib.request.Request('https://blendswap.com/api/mcp',data=body,headers={'Authorization':'Bearer '+key,'Content-Type':'application/json','Accept':'application/json, text/event-stream'})
 with urllib.request.urlopen(request,timeout=60) as response:
  text=response.read().decode();kind=response.headers.get('Content-Type','')
 data=next(json.loads(line[6:]) for line in text.splitlines() if line.startswith('data: ')) if 'text/event-stream' in kind else json.loads(text)
 if 'error' in data:raise RuntimeError('BlendSwap MCP request failed')
 result=data['result']
 if result.get('isError'):raise RuntimeError('BlendSwap MCP tool failed')
 return result.get('structuredContent') or json.loads(next(c['text'] for c in result['content'] if c['type']=='text'))
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 for row in json.loads(Path(__file__).with_name('tier_sources.json').read_text()):
  target=OUT/row['file']
  if not target.exists():
   if row.get('procured_via'):
    if mcp('get_balance')['api_free_downloads_remaining_today']<1:raise RuntimeError('No free BlendSwap downloads remain')
    info=mcp('download_asset',{'asset_id':15177})
    if info['credits_spent']!=0:raise RuntimeError('Unexpected BlendSwap download charge')
    url=info['download_url']
   else:url=row['url']
   urllib.request.urlretrieve(url,target)
  if hashlib.sha256(target.read_bytes()).hexdigest()!=row['sha256']:raise RuntimeError('Source hash mismatch: '+row['file'])
  directory={'energy_rifle.7z':'energy','burst_textures.7z':'burst_textures','minigun.zip':'minigun'}.get(row['file'])
  if directory:
   destination=OUT/directory;destination.mkdir(exist_ok=True)
   if target.suffix=='.zip':
    with zipfile.ZipFile(target) as archive:
     for member in archive.infolist():
      if not (destination/member.filename).resolve().is_relative_to(destination.resolve()):raise RuntimeError('Unsafe source archive path')
      archive.extract(member,destination)
   else:subprocess.run(['7z','x','-y','-o'+str(destination),str(target)],check=True,stdout=subprocess.DEVNULL)
  print(row['file'],row['author'])
if __name__=='__main__':main()
