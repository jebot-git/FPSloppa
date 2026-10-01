"""Small Streamable HTTP MCP client; credentials remain outside the repository."""
import json,pathlib,requests,sys,hashlib,zipfile,os
ROOT=pathlib.Path(__file__).resolve().parent
def call(method,params=None):
    key=pathlib.Path(os.environ.get('BLENDSWAP_KEY_FILE',str(pathlib.Path.home()/'bsk'))).read_text().strip()
    response=requests.post('https://blendswap.com/api/mcp',headers={'Authorization':'Bearer '+key,'Content-Type':'application/json','Accept':'application/json, text/event-stream'},json={'jsonrpc':'2.0','id':1,'method':method,'params':params or {}},timeout=60)
    response.raise_for_status()
    if 'text/event-stream' in response.headers.get('Content-Type',''):
        data=next(json.loads(line[6:]) for line in response.text.splitlines() if line.startswith('data: '))
    else:data=response.json()
    if 'error' in data:raise RuntimeError(data['error'])
    return data['result']
def tool(name,args=None):
    result=call('tools/call',{'name':name,'arguments':args or {}})
    if result.get('isError'):raise RuntimeError('BlendSwap tool returned an error')
    return result.get('structuredContent') or json.loads(next(c['text'] for c in result['content'] if c['type']=='text'))
if __name__=='__main__':
    name=sys.argv[1]
    if name=='tools':result=call('tools/list');(ROOT/'blendswap-tools.json').write_text(json.dumps(result,indent=2))
    elif name=='download_selected':
        result=[]
        for item in json.loads((ROOT/'blendswap-selected.json').read_text()):
            folder=ROOT/'sources'/str(item['id']);folder.mkdir(exist_ok=True)
            path=folder/item['files'][0]['filename']
            if not path.exists():
                balance=tool('get_balance')
                cached=pathlib.Path('/tmp/fps-blendswap-download.json')
                if item['id']==28872 and cached.exists():info=json.loads(cached.read_text())
                else:
                    assert balance['api_free_downloads_remaining_today']>0,'Free allowance exhausted'
                    info=tool('download_asset',{'asset_id':item['id']})
                assert info['credits_spent']==0
                response=requests.get(info['download_url'],timeout=180);response.raise_for_status();path.write_bytes(response.content)
            if path.suffix=='.zip':
                dest=folder/'unpacked';dest.mkdir(exist_ok=True)
                with zipfile.ZipFile(path) as z:
                    for entry in z.infolist():
                        if (dest/entry.filename).resolve().is_relative_to(dest.resolve()):z.extract(entry,dest)
            row={'id':item['id'],'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'credits_spent':0};result.append(row)
            print(item['title'],'downloaded',path.stat().st_size,flush=True)
        (ROOT/'blendswap-downloads.json').write_text(json.dumps(result,indent=2))
    elif name=='selected':
        result=[]
        for asset_id in [28872,12291,25753,12345,8856,22552,29096]:
            item=tool('get_asset',{'id':asset_id})['data'];result.append(item)
        (ROOT/'blendswap-selected.json').write_text(json.dumps(result,indent=2))
        result=[{k:a[k] for k in ['id','title','author','license','files']} for a in result]
    else:
        result=tool(name,json.loads(sys.argv[2]) if len(sys.argv)>2 else {})
        if name=='get_balance':result={k:result[k] for k in ['credits','api_free_downloads_remaining_today','download_credits']}
        elif 'data' in result:result=result['data']
    print(json.dumps(result,indent=2))
